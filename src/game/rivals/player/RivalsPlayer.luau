return LPH_JIT_MAX(function()
	local Charm = require("@pkg/Charm")
	local Janitor = require("@pkg/Janitor")
	local BasePlayer = require("@feature/player/BasePlayer")
	local ModuleController = require("@game/rivals/module/ModuleController")
	local Sift = require("@pkg/Sift")

	local at = Charm.atom
	local peek = Charm.peek

	local function animKeyLooksLikeDeflect(animKey: any): boolean
		if type(animKey) ~= "string" then
			return false
		end
		return animKey:find("Deflect") ~= nil
	end

	local function animKeyLooksLikeHeal(animKey: any): boolean
		return animKey == "Use" or animKey == "UseQuick"
	end

	local function animKeyLooksLikeReload(animKey: any): boolean
		if type(animKey) ~= "string" then
			return false
		end
		return animKey:find("Reload") ~= nil
	end

	local function itemIsMedkit(item: any): boolean
		if not item then
			return false
		end
		local info = item.Info
		if type(info) ~= "table" then
			return false
		end
		return info.LongHeal ~= nil or info.QuickHeal ~= nil
	end

	type Character = Model & {
		HumanoidRootPart: BasePart,
		Humanoid: Humanoid,
	}

	local function readStringAttribute(inst: Instance, name: string): string
		local value = inst:GetAttribute(name)
		if type(value) == "string" then
			return value
		end
		return ""
	end

	local function readNumberAttribute(inst: Instance, name: string): number
		local value = inst:GetAttribute(name)
		if type(value) == "number" then
			return value
		end
		return 0
	end

	local function readEnvironmentFromInstance(inst: Instance?): string
		local current = inst
		while current and current:IsDescendantOf(workspace) do
			local value = readStringAttribute(current, "EnvironmentID")
			if value ~= "" then
				return value
			end
			current = current.Parent
		end
		return ""
	end

	local function readEnvironmentId(player: Player, fromInstance: Instance?): string
		local playerEnv = readStringAttribute(player, "EnvironmentID")
		if playerEnv ~= "" then
			return playerEnv
		end
		return readEnvironmentFromInstance(fromInstance)
	end

	local function safeGet(obj: any, key: string): any
		setthreadidentity(2)
		local value = obj.Get(obj, key)
		setthreadidentity(8)
		return value
	end

	local function safeDataChangedSignal(obj: any, key: string): RBXScriptSignal?
		setthreadidentity(2)
		local signal = obj.GetDataChangedSignal(obj, key)
		setthreadidentity(8)
		return signal
	end

	local function safeConnect(signal: any, fn: (...any) -> ()): RBXScriptConnection?
		if not signal then
			return nil
		end
		local function wrapped(...): ()
			setthreadidentity(8)
			fn(...)
			setthreadidentity(2)
		end
		setthreadidentity(2)
		local connection = signal.Connect(signal, wrapped)
		setthreadidentity(8)
		return connection
	end

	local readFighterEquippedItem = LPH_NO_VIRTUALIZE(function(fighter: any): EquippedItem?
		if not fighter then
			return nil
		end

		local item = fighter.EquippedItem
		if not item then
			return nil
		end

		local name: string? = nil
		if type(item.Name) == "string" and item.Name ~= "" then
			name = item.Name
		elseif type(item.GetViewModelDetails) == "function" then
			setthreadidentity(2)
			local details = item.GetViewModelDetails(item)
			setthreadidentity(8)
			if
				type(details) == "table"
				and type(details.ViewModelName) == "string"
				and details.ViewModelName ~= ""
			then
				name = details.ViewModelName
			end
		end

		if not name then
			return nil
		end

		local hasScope = false
		local info = item.Info
		if type(info) == "table" and info.AimScopePercent ~= nil then
			hasScope = true
		end

		return {
			Name = name,
			hasScope = hasScope,
		}
	end)

	local readFighterItems = LPH_NO_VIRTUALIZE(function(fighter: any): { string }
		local items = rawget(fighter, "Items")
		if type(items) ~= "table" then
			return {}
		end
		local names: { string } = {}
		for i, item in next, items do
			if type(i) == "number" and type(item) == "table" and type(item.Name) == "string" and item.Name ~= "" then
				table.insert(names, item.Name)
			end
		end
		return names
	end)

	local RivalsPlayer = {}
	RivalsPlayer.__index = RivalsPlayer

	setmetatable(RivalsPlayer, { __index = BasePlayer })

	function RivalsPlayer.new(player: Player): RivalsPlayer
		local self = BasePlayer.new(player) :: any
		setmetatable(self, RivalsPlayer)

		self.character = at(nil :: Character?)
		self.hrp = at(nil :: BasePart?)
		self.humanoid = at(nil :: Humanoid?)
		self.alive = at(false)
		self.health = at(0)
		self.maxHealth = at(150)
		self.parts = at({})
		self.team = at(player:GetAttribute("TeamID") or "")
		self.environmentId = at(readEnvironmentId(player, player.Character))
		self.currentEquipped = at(nil :: EquippedItem?)

		self.isInDuel = at(false)
		self.isSpectating = at(false)
		self.isHidden = at(false)
		self.isCrouching = at(false)
		self.isSliding = at(false)
		self.isFirstPerson = at(false)
		self.isFrozen = at(false)
		self.isInvincible = at(false)
		self.controls = at("")
		self.aimCFrame = at(CFrame.identity)
		self.items = at({} :: { string })
		self.velocity = at(Vector3.zero)
		self.level = at(readNumberAttribute(player, "Level"))
		self.winStreak = at(readNumberAttribute(player, "StatisticDuelsWinStreak"))
		self.displayElo = at(readNumberAttribute(player, "DisplayELO"))

		self.isReloading = at(false)
		self.isAiming = at(false)
		self.isBlind = at(false)
		self.isScoped = at(false)
		self.isBlocking = at(false)
		self.isDeflecting = at(false)
		self.isHealing = at(false)

		self._janitor = Janitor.new()
		self._characterJanitor = Janitor.new()
		self._fighterJanitor = Janitor.new()
		self._entityJanitor = Janitor.new()
		self._viewModelJanitor = Janitor.new()
		self._janitor:Add(self._characterJanitor, "Destroy")
		self._janitor:Add(self._fighterJanitor, "Destroy")
		self._janitor:Add(self._entityJanitor, "Destroy")
		self._janitor:Add(self._viewModelJanitor, "Destroy")

		self._janitor:Add(player.CharacterAdded:Connect(function(character: Model): ()
			self:_onCharacterAdded(character :: Character)
		end))

		self._janitor:Add(player.CharacterRemoving:Connect(function(): ()
			self:_onCharacterRemoving()
		end))

		self._janitor:Add(player:GetAttributeChangedSignal("TeamID"):Connect(function(): ()
			self.team(player:GetAttribute("TeamID") or "")
		end))

		self._janitor:Add(player:GetAttributeChangedSignal("EnvironmentID"):Connect(function(): ()
			self.environmentId(readEnvironmentId(player, peek(self.character)))
		end))

		self._janitor:Add(player:GetAttributeChangedSignal("Level"):Connect(function(): ()
			self.level(readNumberAttribute(player, "Level"))
		end))

		self._janitor:Add(player:GetAttributeChangedSignal("StatisticDuelsWinStreak"):Connect(function(): ()
			self.winStreak(readNumberAttribute(player, "StatisticDuelsWinStreak"))
		end))

		self._janitor:Add(player:GetAttributeChangedSignal("DisplayELO"):Connect(function(): ()
			self.displayElo(readNumberAttribute(player, "DisplayELO"))
		end))

		if player.Character then
			task.spawn(function()
				self:_onCharacterAdded(player.Character :: Character)
			end)
		end

		self:_bindFighter()

		return self
	end

	function RivalsPlayer._resetFighterState(self: RivalsPlayer): ()
		self.currentEquipped(nil)
		self.isInDuel(false)
		self.isSpectating(false)
		self.isHidden(false)
		self.isCrouching(false)
		self.isSliding(false)
		self.isFirstPerson(false)
		self.controls("")
		self.aimCFrame(CFrame.identity)
		self.items({})
		self:_watchEquippedViewModel(nil)
		self:_resetEntityState()
	end

	function RivalsPlayer._resetDeflectState(self: RivalsPlayer): ()
		self.isDeflecting(false)
	end

	function RivalsPlayer._watchEquippedViewModel(self: RivalsPlayer, item: any?): ()
		self._viewModelJanitor:Cleanup()
		self:_resetDeflectState()
		self.isHealing(false)
		self.isReloading(false)
		self.isAiming(false)

		if not item then
			return
		end

		local function syncAiming(): ()
			self.isAiming(safeGet(item, "IsAiming") == true)
		end
		syncAiming()
		local aimConn = safeConnect(safeDataChangedSignal(item, "IsAiming"), syncAiming)
		if aimConn then
			self._viewModelJanitor:Add(aimConn, "Disconnect")
		end

		local viewModel = item.ViewModel
		if not viewModel then
			return
		end

		local playedSignal = viewModel.AnimationPlayed
		local stoppedSignal = viewModel.AnimationStopped
		if not playedSignal or not stoppedSignal then
			return
		end

		local isMedkit = itemIsMedkit(item)

		local function onPlay(animKey: any): ()
			if animKeyLooksLikeDeflect(animKey) then
				self.isDeflecting(true)
			elseif isMedkit and animKeyLooksLikeHeal(animKey) then
				self.isHealing(true)
			elseif animKeyLooksLikeReload(animKey) then
				self.isReloading(true)
			end
		end

		local function onStop(animKey: any): ()
			if animKeyLooksLikeDeflect(animKey) then
				self.isDeflecting(false)
			elseif isMedkit and animKeyLooksLikeHeal(animKey) then
				self.isHealing(false)
			elseif animKeyLooksLikeReload(animKey) then
				self.isReloading(false)
			end
		end

		local playedConn = safeConnect(playedSignal, onPlay)
		if playedConn then
			self._viewModelJanitor:Add(playedConn, "Disconnect")
		end

		local stoppedConn = safeConnect(stoppedSignal, onStop)
		if stoppedConn then
			self._viewModelJanitor:Add(stoppedConn, "Disconnect")
		end
	end

	function RivalsPlayer._resetEntityState(self: RivalsPlayer): ()
		self.isFrozen(false)
		self.isInvincible(false)
		self.velocity(Vector3.zero)
	end

	RivalsPlayer._bindFighter = function(self: RivalsPlayer): ()
		local fighterController = ModuleController.GetModule("FighterController")
		if not fighterController then
			self:_resetFighterState()
			return
		end

		local playerToFighter = rawget(fighterController, "_player_to_fighter")
		if type(playerToFighter) ~= "table" then
			self:_resetFighterState()
			return
		end

		local function bindEntity(entity: any?): ()
			self._entityJanitor:Cleanup()
			if not entity then
				self:_resetEntityState()
				return
			end

			local function syncFrozen(): ()
				self.isFrozen(safeGet(entity, "IsFrozen") == true)
			end
			syncFrozen()
			local frozenConn = safeConnect(safeDataChangedSignal(entity, "IsFrozen"), syncFrozen)
			if frozenConn then
				self._entityJanitor:Add(frozenConn, "Disconnect")
			end

			local function syncInvincible(): ()
				self.isInvincible(safeGet(entity, "IsInvincible") == true)
			end
			syncInvincible()
			local invincibleConn = safeConnect(safeDataChangedSignal(entity, "IsInvincible"), syncInvincible)
			if invincibleConn then
				self._entityJanitor:Add(invincibleConn, "Disconnect")
			end
		end

		local function attachFighter(fighter: any?): ()
			self._fighterJanitor:Cleanup()
			if not fighter then
				self:_resetFighterState()
				return
			end

			local function syncEquipped(): ()
				self.currentEquipped(readFighterEquippedItem(fighter))
				self:_watchEquippedViewModel(fighter.EquippedItem)
			end

			local function syncItems(): ()
				self.items(readFighterItems(fighter))
			end

			local function bindData(key: string, atom: any, transform: (any) -> any): ()
				local function sync(): ()
					atom(transform(safeGet(fighter, key)))
				end
				sync()
				local conn = safeConnect(safeDataChangedSignal(fighter, key), sync)
				if conn then
					self._fighterJanitor:Add(conn, "Disconnect")
				end
			end

			local function syncHidden(): ()
				local emotes = safeGet(fighter, "IsHiddenByEmotes") == true
				local cutscene = safeGet(fighter, "IsHiddenByCutscene") == true
				self.isHidden(emotes or cutscene)
			end

			syncEquipped()
			syncItems()
			syncHidden()

			local equippedConn = safeConnect(fighter.EquippedItemChanged, syncEquipped)
			if equippedConn then
				self._fighterJanitor:Add(equippedConn, "Disconnect")
			end
			local itemAddedConn = safeConnect(fighter.ItemAdded, function(): ()
				syncEquipped()
				syncItems()
			end)
			if itemAddedConn then
				self._fighterJanitor:Add(itemAddedConn, "Disconnect")
			end
			local itemRemovedConn = safeConnect(fighter.ItemRemoved, function(): ()
				syncEquipped()
				syncItems()
			end)
			if itemRemovedConn then
				self._fighterJanitor:Add(itemRemovedConn, "Disconnect")
			end

			bindData("IsInDuel", self.isInDuel, function(v): boolean
				return v == true
			end)
			bindData("IsSpectating", self.isSpectating, function(v): boolean
				return v == true
			end)
			bindData("IsCrouching", self.isCrouching, function(v): boolean
				return v == true
			end)
			bindData("IsSliding", self.isSliding, function(v): boolean
				return v == true
			end)
			bindData("Controls", self.controls, function(v): string
				if type(v) == "string" then
					return v
				end
				return ""
			end)

			local emotesConn = safeConnect(safeDataChangedSignal(fighter, "IsHiddenByEmotes"), syncHidden)
			if emotesConn then
				self._fighterJanitor:Add(emotesConn, "Disconnect")
			end
			local cutsceneConn = safeConnect(safeDataChangedSignal(fighter, "IsHiddenByCutscene"), syncHidden)
			if cutsceneConn then
				self._fighterJanitor:Add(cutsceneConn, "Disconnect")
			end

			bindEntity(rawget(fighter, "Entity"))
			local entityAddedConn = safeConnect(fighter.EntityAdded, function(entity: any?): ()
				bindEntity(entity or rawget(fighter, "Entity"))
			end)
			if entityAddedConn then
				self._fighterJanitor:Add(entityAddedConn, "Disconnect")
			end
			local entityRemovedConn = safeConnect(fighter.EntityRemoved, function(): ()
				bindEntity(nil)
			end)
			if entityRemovedConn then
				self._fighterJanitor:Add(entityRemovedConn, "Disconnect")
			end
		end

		local function refreshFromCache(): ()
			attachFighter(playerToFighter[self._player])
		end

		refreshFromCache()

		local objectAddedConn = safeConnect(fighterController.ObjectAdded, function(fighter: any): ()
			if fighter.Player == self._player then
				refreshFromCache()
			end
		end)
		if objectAddedConn then
			self._janitor:Add(objectAddedConn, "Disconnect")
		end

		local objectRemovedConn = safeConnect(fighterController.ObjectRemoved, function(fighter: any): ()
			if fighter.Player == self._player then
				refreshFromCache()
			end
		end)
		if objectRemovedConn then
			self._janitor:Add(objectRemovedConn, "Disconnect")
		end
	end

	RivalsPlayer._onCharacterAdded = LPH_NO_VIRTUALIZE(function(self: RivalsPlayer, character: Character): ()
		self._characterJanitor:Cleanup()

		self.character(character)
		self.environmentId(readEnvironmentId(self._player, character))

		local parts = {}
		for _, child in next, character:GetChildren() do
			parts[child.Name] = child
		end
		self.parts(parts)

		self._characterJanitor:Add(character.ChildAdded:Connect(function(part: Instance): ()
			self.parts(Sift.Dictionary.set(peek(self.parts), part.Name :: any, part))
			self.environmentId(readEnvironmentId(self._player, character))
		end))

		self._characterJanitor:Add(character.ChildRemoved:Connect(function(part: Instance): ()
			self.parts(Sift.Dictionary.removeKey(peek(self.parts), part.Name :: any))
			self.environmentId(readEnvironmentId(self._player, character))
		end))

		self._characterJanitor:Add(character:GetAttributeChangedSignal("EnvironmentID"):Connect(function(): ()
			self.environmentId(readEnvironmentId(self._player, character))
		end))

		self._characterJanitor:Add(character.AncestryChanged:Connect(function(): ()
			self.environmentId(readEnvironmentId(self._player, character))
		end))

		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?

		local function bindHumanoid(h: Humanoid): ()
			self.humanoid(h)
			self.health(h.Health)
			self.maxHealth(h.MaxHealth)
			self.alive(h.Health > 0)

			self._characterJanitor:Add(h.HealthChanged:Connect(function(health: number): ()
				self.health(health)
				self.alive(health > 0)
			end))

			self._characterJanitor:Add(h:GetPropertyChangedSignal("MaxHealth"):Connect(function(): ()
				self.maxHealth(h.MaxHealth)
			end))

			self._characterJanitor:Add(h.Died:Connect(function(): ()
				self.alive(false)
			end))
		end

		if hrp then
			self.hrp(hrp)
		end
		if humanoid then
			bindHumanoid(humanoid)
		end

		if not hrp or not humanoid then
			local waitConn: RBXScriptConnection
			waitConn = character.ChildAdded:Connect(function(child: Instance): ()
				if not hrp and child.Name == "HumanoidRootPart" and child:IsA("BasePart") then
					hrp = child :: BasePart
					self.hrp(hrp)
				end
				if not humanoid and child:IsA("Humanoid") then
					humanoid = child :: Humanoid
					bindHumanoid(child :: Humanoid)
				end
				if hrp and humanoid then
					waitConn:Disconnect()
				end
			end)
			self._characterJanitor:Add(waitConn, "Disconnect")
		end
	end)

	RivalsPlayer._onCharacterRemoving = LPH_NO_VIRTUALIZE(function(self: RivalsPlayer): ()
		self._characterJanitor:Cleanup()
		self.character(nil)
		self.hrp(nil)
		self.humanoid(nil)
		self.alive(false)
		self.parts({})
		self.environmentId(readEnvironmentId(self._player, nil))
	end)

	function RivalsPlayer.IsAlive(self: RivalsPlayer): boolean
		return peek(self.alive)
	end

	RivalsPlayer.GetHealthFraction = LPH_NO_VIRTUALIZE(function(self: RivalsPlayer): number
		local maxHealth = peek(self.maxHealth)
		if maxHealth <= 0 then
			return 0
		end
		return math.clamp(peek(self.health) / maxHealth, 0, 1)
	end)

	function RivalsPlayer.GetTeam(self: RivalsPlayer): string
		return peek(self.team)
	end

	function RivalsPlayer.GetCharacter(self: RivalsPlayer): Character?
		return peek(self.character)
	end

	function RivalsPlayer.GetParts(self: RivalsPlayer): { [string]: Instance }
		return peek(self.parts)
	end

	function RivalsPlayer.Destroy(self: RivalsPlayer): ()
		self._janitor:Destroy()
	end

	export type RivalsPlayer =
		typeof(setmetatable(
			{} :: {
				_janitor: Janitor.Janitor,
				_characterJanitor: Janitor.Janitor,
				_fighterJanitor: Janitor.Janitor,
				_entityJanitor: Janitor.Janitor,
				_viewModelJanitor: Janitor.Janitor,
				character: Charm.Atom<Character?>,
				hrp: Charm.Atom<BasePart?>,
				humanoid: Charm.Atom<Humanoid?>,
				alive: Charm.Atom<boolean>,
				health: Charm.Atom<number>,
				maxHealth: Charm.Atom<number>,
				parts: Charm.Atom<{ [string]: Instance }>,
				team: Charm.Atom<string>,
				environmentId: Charm.Atom<string>,
				currentEquipped: Charm.Atom<EquippedItem?>,
				isInDuel: Charm.Atom<boolean>,
				isSpectating: Charm.Atom<boolean>,
				isHidden: Charm.Atom<boolean>,
				isCrouching: Charm.Atom<boolean>,
				isSliding: Charm.Atom<boolean>,
				isFirstPerson: Charm.Atom<boolean>,
				isFrozen: Charm.Atom<boolean>,
				isInvincible: Charm.Atom<boolean>,
				controls: Charm.Atom<string>,
				aimCFrame: Charm.Atom<CFrame>,
				items: Charm.Atom<{ string }>,
				velocity: Charm.Atom<Vector3>,
				level: Charm.Atom<number>,
				winStreak: Charm.Atom<number>,
				displayElo: Charm.Atom<number>,
				isReloading: Charm.Atom<boolean>,
				isAiming: Charm.Atom<boolean>,
				isBlind: Charm.Atom<boolean>,
				isScoped: Charm.Atom<boolean>,
				isDeflecting: Charm.Atom<boolean>,
				isHealing: Charm.Atom<boolean>,
			},
			RivalsPlayer
		))
		& BasePlayer.BasePlayer

	export type EquippedItem = {
		Name: string,
		hasScope: boolean?,
		Rounds: number?,
		Capacity: number?,
	}

	return RivalsPlayer
end)()
