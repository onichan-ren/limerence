return LPH_JIT_MAX(function()
	local Charm = require("@pkg/Charm")
	local Janitor = require("@pkg/Janitor")
	local BasePlayer = require("@feature/player/BasePlayer")
	local Sift = require("@pkg/Sift")
	local HttpService = cloneref(game:GetService("HttpService"))
	local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage & any

	local at = Charm.atom
	local peek = Charm.peek

	local C4_USE_ANIM_ID = ReplicatedStorage.Assets.WeaponAnimations.C4.CharacterAnimations.Use.AnimationId
	local FLASH_ANIM_ID = ReplicatedStorage.Assets.CharacterAnimations.Actions.Blinded.AnimationId
	local CULLED_FOLDER_NAME = "_PVS_CulledCharacters"

	local function isCharacterCulled(character: Instance?): boolean
		if not character then
			return false
		end
		local parent = character.Parent
		if not parent or parent.Name == CULLED_FOLDER_NAME or parent == ReplicatedStorage then
			return true
		end
		return not character:IsDescendantOf(workspace)
	end

	type Character = Model & {
		HumanoidRootPart: BasePart,
		Humanoid: Humanoid,
	}

	export type ArmorState = {
		kevlar: boolean,
		helmet: boolean,
		health: number,
	}

	local EMPTY_ARMOR: ArmorState = { kevlar = false, helmet = false, health = 0 }

	local RELOAD_ANIM_IDS = {}

	for _, anim in next, ReplicatedStorage.Assets.WeaponAnimations:QueryDescendants("#Reload") do
		if anim.ClassName == "Animation" then
			RELOAD_ANIM_IDS[anim.AnimationId] = true
		end
	end

	local BloxstrikePlayer = {}
	BloxstrikePlayer.__index = BloxstrikePlayer

	setmetatable(BloxstrikePlayer, { __index = BasePlayer })

	function BloxstrikePlayer.new(player: Player): BloxstrikePlayer
		local self = BasePlayer.new(player) :: any
		setmetatable(self, BloxstrikePlayer)

		self.character = at(nil :: Character?)
		self.hrp = at(nil :: BasePart?)
		self.humanoid = at(nil :: Humanoid?)
		self.alive = at(false)
		self.health = at(0)
		self.maxHealth = at(100)
		self.parts = at({})
		self.team = at(player:GetAttribute("Team"))
		self.currentEquipped = at(nil :: PlayerItem?)
		self.isPlanting = at(false)
		self.isDefusing = at(false)
		self.isRescuing = at(false)
		self.isCarrying = at(false)
		self.hasC4 = at(false)
		self.hasDefuseKit = at(false)
		self.invincible = at(false)
		self.armor = at(EMPTY_ARMOR)
		self.isReloading = at(false)
		self.isBlind = at(false)
		self.isScoped = at(false)
		self.culled = at(false)

		self._reloadActiveCount = 0
		self._blindActiveCount = 0

		self._lastCurrentEquippedRaw = nil
		self._lastSlot5Raw = nil
		self._lastArmorRaw = nil

		self._janitor = Janitor.new()
		self._characterJanitor = Janitor.new()
		self._janitor:Add(self._characterJanitor, "Destroy")

		self._janitor:Add(player.CharacterAdded:Connect(function(character: Model): ()
			self:_onCharacterAdded(character :: Character)
		end))

		self._janitor:Add(player.CharacterRemoving:Connect(function(): ()
			self:_onCharacterRemoving()
		end))

		self._janitor:Add(player:GetAttributeChangedSignal("Team"):Connect(function(): ()
			self.team(player:GetAttribute("Team"))
		end))

		self._janitor:Add(player:GetAttributeChangedSignal("CurrentEquipped"):Connect(LPH_NO_VIRTUALIZE(function(): ()
			local data = player:GetAttribute("CurrentEquipped") :: string?
			if data == self._lastCurrentEquippedRaw then
				return
			end
			self._lastCurrentEquippedRaw = data
			if not data then
				self.currentEquipped(nil)
				return
			end
			local newData = HttpService:JSONDecode(data)
			self.currentEquipped(newData)
		end)))

		local currentEquipped = player:GetAttribute("CurrentEquipped") :: string?
		if currentEquipped then
			self._lastCurrentEquippedRaw = currentEquipped
			self.currentEquipped(HttpService:JSONDecode(currentEquipped))
		end

		self._janitor:Add(player:GetAttributeChangedSignal("IsDefusingBomb"):Connect(function(): ()
			self.isDefusing(player:GetAttribute("IsDefusingBomb") == true)
		end))
		self.isDefusing(player:GetAttribute("IsDefusingBomb") == true)

		self._janitor:Add(player:GetAttributeChangedSignal("IsRescuingHostage"):Connect(function(): ()
			self.isRescuing(player:GetAttribute("IsRescuingHostage") == true)
		end))
		self.isRescuing(player:GetAttribute("IsRescuingHostage") == true)

		self._janitor:Add(player:GetAttributeChangedSignal("IsCarryingHostage"):Connect(function(): ()
			self.isCarrying(player:GetAttribute("IsCarryingHostage") == true)
		end))
		self.isCarrying(player:GetAttribute("IsCarryingHostage") == true)

		self._janitor:Add(player:GetAttributeChangedSignal("HasDefuseKit"):Connect(function(): ()
			self.hasDefuseKit(player:GetAttribute("HasDefuseKit") == true)
		end))
		self.hasDefuseKit(player:GetAttribute("HasDefuseKit") == true)

		self._janitor:Add(player:GetAttributeChangedSignal("ScopeIncrement"):Connect(function(): ()
			self.isScoped((player:GetAttribute("ScopeIncrement") or 0) > 0)
		end))
		self.isScoped((player:GetAttribute("ScopeIncrement") or 0) > 0)

		self._janitor:Add(player:GetAttributeChangedSignal("Slot5"):Connect(function(): ()
			self:_syncSlot5()
		end))
		self:_syncSlot5()

		self._janitor:Add(player:GetAttributeChangedSignal("Armor"):Connect(function(): ()
			self:_syncArmor()
		end))
		self:_syncArmor()

		if player.Character then
			task.spawn(function()
				self:_onCharacterAdded(player.Character :: Character)
			end)
		end

		return self
	end

	function BloxstrikePlayer._syncSlot5(self: BloxstrikePlayer): ()
		local raw = self._player:GetAttribute("Slot5")
		if raw == self._lastSlot5Raw then
			return
		end
		self._lastSlot5Raw = raw
		if type(raw) ~= "string" or raw == "" then
			self.hasC4(false)
			return
		end
		local data = HttpService:JSONDecode(raw)
		if type(data) ~= "table" then
			self.hasC4(false)
			return
		end
		self.hasC4(data.Weapon == "C4")
	end

	function BloxstrikePlayer._syncArmor(self: BloxstrikePlayer): ()
		local raw = self._player:GetAttribute("Armor")
		if raw == self._lastArmorRaw then
			return
		end
		self._lastArmorRaw = raw
		if type(raw) ~= "string" or raw == "" then
			self.armor(EMPTY_ARMOR)
			return
		end
		local data = HttpService:JSONDecode(raw)
		if type(data) ~= "table" then
			self.armor(EMPTY_ARMOR)
			return
		end
		local t = tostring(data.Type or "")
		local hp = tonumber(data.Health) or 0
		if hp <= 0 then
			self.armor(EMPTY_ARMOR)
			return
		end
		local hasKevlar = t == "Kevlar" or t == "Kevlar + Helmet"
		local hasHelmet = t == "Kevlar + Helmet"
		if not hasKevlar then
			self.armor(EMPTY_ARMOR)
			return
		end
		self.armor({ kevlar = hasKevlar, helmet = hasHelmet, health = hp })
	end

	function BloxstrikePlayer._onCharacterAdded(self: BloxstrikePlayer, character: Character): ()
		self._characterJanitor:Cleanup()

		local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		if not hrp then
			return
		end

		if self._player.Character ~= character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?

		local parts = {}
		for _, part in next, character:GetChildren() do
			local name = part.Name
			parts[name] = part
		end
		self.parts(parts)

		self.character(character)
		self.hrp(hrp)
		self.humanoid(humanoid)
		self.culled(isCharacterCulled(character))
		self.invincible(character:GetAttribute("Invincible") == true)

		self._characterJanitor:Add(character:GetPropertyChangedSignal("Parent"):Connect(function(): ()
			self.culled(isCharacterCulled(character))
		end))

		self._characterJanitor:Add(character.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(part: Instance): ()
			self:_onPartAdded(part)
		end)))

		self._characterJanitor:Add(character.ChildRemoved:Connect(LPH_NO_VIRTUALIZE(function(part: Instance): ()
			self:_onPartRemoved(part)
		end)))

		self._characterJanitor:Add(character:GetAttributeChangedSignal("Invincible"):Connect(function(): ()
			self.invincible(character:GetAttribute("Invincible") == true)
		end))

		if humanoid then
			self.health(humanoid.Health)
			self.maxHealth(humanoid.MaxHealth)
			self.alive(humanoid.Health > 0)

			self._characterJanitor:Add(humanoid.HealthChanged:Connect(function(health: number): ()
				self.health(health)
				self.alive(health > 0)
			end))

			self._characterJanitor:Add(humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function(): ()
				self.maxHealth(humanoid.MaxHealth)
			end))

			self._characterJanitor:Add(humanoid.Died:Connect(function(): ()
				self.alive(false)
			end))
		else
			local function syncAttributes(): ()
				local maxHp = tonumber(character:GetAttribute("MaxHealth")) or tonumber(self._player:GetAttribute("MaxHealth")) or 100
				local hp = tonumber(character:GetAttribute("Health"))
				if hp == nil then
					hp = tonumber(self._player:GetAttribute("Health"))
				end
				if hp == nil then
					hp = maxHp
				end
				local dead = character:GetAttribute("Dead") == true or self._player:GetAttribute("Dead") == true
				self.maxHealth(maxHp)
				self.health(hp :: number)
				self.alive(not dead and (hp :: number) > 0)
			end

			syncAttributes()
			self._characterJanitor:Add(character:GetAttributeChangedSignal("Health"):Connect(syncAttributes))
			self._characterJanitor:Add(character:GetAttributeChangedSignal("MaxHealth"):Connect(syncAttributes))
			self._characterJanitor:Add(character:GetAttributeChangedSignal("Dead"):Connect(syncAttributes))
			self._characterJanitor:Add(self._player:GetAttributeChangedSignal("Health"):Connect(syncAttributes))
			self._characterJanitor:Add(self._player:GetAttributeChangedSignal("MaxHealth"):Connect(syncAttributes))
			self._characterJanitor:Add(self._player:GetAttributeChangedSignal("Dead"):Connect(syncAttributes))
		end

		self:_watchCharacterAnimations(character, humanoid)
	end

	function BloxstrikePlayer._watchCharacterAnimations(self: BloxstrikePlayer, character: Character, humanoid: Humanoid?): ()
		local animator: Animator? = if humanoid then humanoid:FindFirstChildOfClass("Animator") :: Animator? else nil
		if not animator then
			animator = character:FindFirstChild("Animator", true) :: Animator?
		end
		if not animator and humanoid then
			animator = humanoid:WaitForChild("Animator", 3) :: Animator?
		end
		if not animator then
			return
		end
		local resolvedAnimator = animator :: Animator

		self._reloadActiveCount = 0
		self._blindActiveCount = 0

		local trackPlay = LPH_NO_VIRTUALIZE(function(track: AnimationTrack): ()
			local animation = track.Animation
			if not animation then
				return
			end
			local animId = animation.AnimationId
			local isPlant = animId == C4_USE_ANIM_ID
			local isBlind = animId == FLASH_ANIM_ID
			local isReload = RELOAD_ANIM_IDS[animId] == true

			if not isPlant and not isReload and not isBlind then
				return
			end

			if isPlant then
				self.isPlanting(true)
			end
			if isReload then
				self._reloadActiveCount += 1
				self.isReloading(true)
			end
			if isBlind then
				self._blindActiveCount += 1
				self.isBlind(true)
			end

			local stopConn: RBXScriptConnection?
			stopConn = track.Stopped:Connect(function(): ()
				if stopConn then
					stopConn:Disconnect()
					stopConn = nil
				end
				if isPlant then
					self.isPlanting(false)
				end
				if isReload then
					self._reloadActiveCount = math.max(0, self._reloadActiveCount - 1)
					if self._reloadActiveCount == 0 then
						self.isReloading(false)
					end
				end
				if isBlind then
					self._blindActiveCount = math.max(0, self._blindActiveCount - 1)
					if self._blindActiveCount == 0 then
						self.isBlind(false)
					end
				end
			end)
			self._characterJanitor:Add(function(): ()
				if stopConn then
					stopConn:Disconnect()
					stopConn = nil
				end
			end, true)
		end)

		self._characterJanitor:Add(resolvedAnimator.AnimationPlayed:Connect(trackPlay), "Disconnect")

		for _, track in next, resolvedAnimator:GetPlayingAnimationTracks() do
			trackPlay(track)
		end
	end

	BloxstrikePlayer._onPartAdded = LPH_NO_VIRTUALIZE(function(self: BloxstrikePlayer, part: Instance): ()
		local parts = self.parts
		parts(Sift.Dictionary.set(peek(parts), part.Name :: any, part))
	end)

	BloxstrikePlayer._onPartRemoved = LPH_NO_VIRTUALIZE(function(self: BloxstrikePlayer, part: Instance): ()
		local parts = self.parts
		parts(Sift.Dictionary.removeKey(peek(parts), part.Name :: any))
	end)

	function BloxstrikePlayer._onCharacterRemoving(self: BloxstrikePlayer): ()
		self._characterJanitor:Cleanup()
		self.character(nil)
		self.hrp(nil)
		self.humanoid(nil)
		self.alive(false)
		self.parts({})
		self.isPlanting(false)
		self._reloadActiveCount = 0
		self._blindActiveCount = 0
		self.isReloading(false)
		self.isBlind(false)
		self.culled(false)
	end

	function BloxstrikePlayer.IsAlive(self: BloxstrikePlayer): boolean
		return peek(self.alive)
	end

	function BloxstrikePlayer.GetHealthFraction(self: BloxstrikePlayer): number
		local maxHealth = peek(self.maxHealth)
		if maxHealth <= 0 then
			return 0
		end
		return math.clamp(peek(self.health) / maxHealth, 0, 1)
	end

	function BloxstrikePlayer.GetTeam(self: BloxstrikePlayer): string
		return peek(self.team)
	end

	function BloxstrikePlayer.GetCharacter(self: BloxstrikePlayer): Character?
		return peek(self.character)
	end

	function BloxstrikePlayer.GetParts(self: BloxstrikePlayer): { [string]: Instance }
		return peek(self.parts)
	end

	function BloxstrikePlayer.Destroy(self: BloxstrikePlayer): ()
		self._janitor:Destroy()
	end

	export type BloxstrikePlayer =
		typeof(setmetatable(
			{} :: {
				_janitor: Janitor.Janitor,
				_characterJanitor: Janitor.Janitor,
				_reloadActiveCount: number,
				_blindActiveCount: number,
				_lastCurrentEquippedRaw: any,
				_lastSlot5Raw: any,
				_lastArmorRaw: any,
				character: Charm.Atom<Character?>,
				hrp: Charm.Atom<BasePart?>,
				humanoid: Charm.Atom<Humanoid?>,
				alive: Charm.Atom<boolean>,
				health: Charm.Atom<number>,
				maxHealth: Charm.Atom<number>,
				invincible: Charm.Atom<number>,
				parts: Charm.Atom<{ [string]: Instance }>,
				team: Charm.Atom<string>,
				isPlanting: Charm.Atom<boolean>,
				isDefusing: Charm.Atom<boolean>,
				isRescuing: Charm.Atom<boolean>,
				isCarrying: Charm.Atom<boolean>,
				hasC4: Charm.Atom<boolean>,
				hasDefuseKit: Charm.Atom<boolean>,
				armor: Charm.Atom<ArmorState>,
				isReloading: Charm.Atom<boolean>,
				isBlind: Charm.Atom<boolean>,
				isScoped: Charm.Atom<boolean>,
			},
			BloxstrikePlayer
		))
		& BasePlayer.BasePlayer
	export type PlayerItem = {
		Identifier: string,
		Slot: number,
		Name: string,
		Rounds: number,
		Skin: string?,
		Float: number,
		Stickers: {},
		NameTag: boolean,
		StatTrack: boolean,
		Charm: boolean,
		RechargeStartTime: number,
		Capacity: number,
	}
	return BloxstrikePlayer
end)()
