return LPH_JIT_MAX(function()
	local MAX_HEALTH = 100
	local HEALTH_PLACEHOLDER = 100 -- theres no way to get the health, we will just keep this as a placeholder for now

	local Janitor = require("@pkg/Janitor")
	local Charm = require("@pkg/Charm")
	local Sift = require("@pkg/Sift")
	local BasePlayer = require("@feature/player/BasePlayer")
	local ModuleController = require("@game/ar2/module/ModuleController")
	local WeaponController = require("@game/ar2/weapon/WeaponController")

	local at = Charm.atom
	local peek = Charm.peek

	local healByAnimation: { [string]: number }?

	local function getHealMap(): { [string]: number }
		if healByAnimation then
			return healByAnimation
		end

		local map: { [string]: number } = {}
		healByAnimation = map

		local itemData = ModuleController.GetItemData()
		if type(itemData) ~= "table" then
			return map
		end

		for _, item in next, itemData do
			if type(item) ~= "table" then
				continue
			end

			local consume = item.ConsumeConfig
			local animation = consume and consume.Animation
			if type(animation) ~= "string" then
				continue
			end

			local heal = 0
			local useValue = item.UseValue
			if type(useValue) == "table" and type(useValue.Health) == "number" then
				heal += useValue.Health
			end

			local useBoost = item.UseBoost
			if type(useBoost) == "table" and type(useBoost.Health) == "table" and type(useBoost.Health.Value) == "number" then
				heal += useBoost.Health.Value
			end

			if heal > 0 then
				map[animation] = heal
			end
		end

		return map
	end

	local function ammoState(equipped: any): (number?, number?)
		if type(equipped) ~= "table" or type(equipped.ItemName) ~= "string" then
			return nil, nil
		end

		local itemData = ModuleController.GetItemData()
		local weapon = itemData and itemData[equipped.ItemName]
		if type(weapon) ~= "table" or weapon.Type ~= "Firearm" then
			return nil, nil
		end

		local fireConfig = weapon.FireConfig
		if fireConfig and fireConfig.InternalMag then
			local capacity = tonumber(fireConfig.InternalMagSize)
			local amount = tonumber(equipped.WorkingAmount) or tonumber(equipped.Amount)
			return amount, capacity
		end

		local attachments = equipped.Attachments
		local ammo = type(attachments) == "table" and attachments.Ammo or nil
		if type(ammo) ~= "table" and type(attachments) == "table" then
			for _, attachment in next, attachments do
				if type(attachment) ~= "table" then
					continue
				end
				local attachmentName = attachment.ItemName or attachment.Name
				local config = attachmentName and itemData[attachmentName]
				if config and config.Type == "Ammo" and config.SubType == "Magazine" then
					ammo = attachment
					break
				end
			end
		end

		if type(ammo) == "table" then
			local ammoName = ammo.ItemName or ammo.Name
			local config = ammoName and itemData[ammoName]
			local capacity = tonumber(ammo.Capacity) or (config and tonumber(config.Capacity))
			local amount = tonumber(ammo.WorkingAmount) or tonumber(ammo.Amount)
			return amount, capacity
		end

		local magazineTypes = weapon.MagazineTypes
		if type(magazineTypes) == "table" then
			local config = itemData[magazineTypes[1]]
			return nil, config and tonumber(config.Capacity) or nil
		end

		return nil, nil
	end

	local ARPlayer = {}
	ARPlayer.__index = ARPlayer

	setmetatable(ARPlayer, { __index = BasePlayer })

	function ARPlayer.new(player: Player): ARPlayer
		local self = BasePlayer.new(player) :: any
		setmetatable(self, ARPlayer)

		self.parts = at({})
		self.character = at(nil)
		self.hrp = at(nil)
		self.alive = at(false)
		self.health = at(HEALTH_PLACEHOLDER)
		self.maxHealth = at(MAX_HEALTH)
		self.weapon = at("")
		self.ammo = at(nil :: number?)
		self.ammoCapacity = at(nil :: number?)
		self.ammoExact = at(false)
		self.isReloading = at(false)
		self.isHealing = at(false)

		self._weaponToken = 0
		self._healToken = 0
		self._reloadToken = 0

		self._janitor = Janitor.new()
		self._characterJanitor = Janitor.new()
		self._janitor:Add(self._characterJanitor, "Destroy")

		self._janitor:Add(
			player.CharacterAdded:Connect(function(character: Model)
				self:_onCharacterAdded(character)
			end),
			"Disconnect"
		)
		self._janitor:Add(
			player.CharacterRemoving:Connect(function()
				self:_onCharacterRemoving()
			end),
			"Disconnect"
		)

		self._janitor:Add(
			WeaponController.gameDamaged:Connect(function(hitPlayer: Player, damage: number): ()
				if hitPlayer ~= player then
					return
				end
				if type(damage) ~= "number" or damage <= 0 then
					return
				end
				if not peek(self.alive) then
					return
				end
				self.health(math.max(peek(self.health) - damage, 0))
			end),
			"Disconnect"
		)

		self._janitor:Add(
			WeaponController.enemyShotFired:Connect(function(shotPlayer: Player, itemName: string): ()
				if shotPlayer == player then
					self:_recordShot(itemName)
				end
			end),
			"Disconnect"
		)

		self._janitor:Add(
			WeaponController.enemyWeaponEmpty:Connect(function(shotPlayer: Player, itemName: string): ()
				if shotPlayer == player and (peek(self.weapon) == itemName or peek(self.weapon) == "") then
					self.weapon(itemName)
					self.ammo(0)
					self.ammoExact(true)
				end
			end),
			"Disconnect"
		)

		if player.Character then
			task.spawn(function()
				self:_onCharacterAdded(player.Character)
			end)
		end

		return self
	end

	function ARPlayer._onCharacterAdded(self: ARPlayer, character: Model)
		self._characterJanitor:Cleanup()

		local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?

		if not hrp or not humanoid then
			return
		end

		if self._player.Character ~= character then
			return
		end

		self.alive(true)
		self.hrp(hrp)
		self.character(character)
		self.maxHealth(MAX_HEALTH)
		self.health(HEALTH_PLACEHOLDER)

		self:_bindWeapon(character)

		local parts: { [string]: Instance } = {}
		for _, part in next, character:GetChildren() do
			parts[part.Name] = part
		end
		self.parts(parts)

		self._characterJanitor:Add(
			character.ChildAdded:Connect(function(part: Instance): ()
				self:_onPartAdded(part)
			end),
			"Disconnect"
		)

		self._characterJanitor:Add(
			character.ChildRemoved:Connect(function(part: Instance): ()
				self:_onPartRemoved(part)
			end),
			"Disconnect"
		)

		self._characterJanitor:Add(
			humanoid.Died:Connect(function(): ()
				self.alive(false)
			end),
			"Disconnect"
		)

		local liveParent = character.Parent
		self._characterJanitor:Add(
			character.AncestryChanged:Connect(function(_, parent: Instance?): ()
				if parent ~= liveParent then
					self.alive(false)
				end
			end),
			"Disconnect"
		)
	end

	function ARPlayer._bindWeapon(self: ARPlayer, character: Model): ()
		self._weaponToken += 1
		self._healToken += 1
		self._reloadToken += 1
		self.weapon("")
		self.ammo(nil)
		self.ammoCapacity(nil)
		self.ammoExact(false)
		self.isReloading(false)
		self.isHealing(false)

		local animatorsModule = ModuleController.GetModule("Animators")
		if not animatorsModule or not animatorsModule.module then
			return
		end
		local animators = animatorsModule.module

		local function sync(animator: any, refill: boolean?): ()
			local states = animator.States
			local equipped = states and states.EquippedItem
			local name = equipped and equipped.ItemName
			name = type(name) == "string" and name or ""
			local previous = peek(self.weapon)
			self.weapon(name)
			if name == "" then
				self.ammo(nil)
				self.ammoCapacity(nil)
				self.ammoExact(false)
				return
			end

			local amount, capacity = ammoState(equipped)
			if capacity then
				self.ammoCapacity(capacity)
			end
			if amount then
				self.ammo(math.max(amount, 0))
				self.ammoExact(true)
			elseif refill and capacity then
				self.ammo(capacity)
				self.ammoExact(false)
			elseif previous ~= name then
				self.ammo(capacity)
				self.ammoExact(false)
			end
		end

		local function bind(animator: any): ()
			sync(animator)
			local changed = animator.StateChanged
			if changed then
				self._characterJanitor:Add(
					changed:Connect(function(stateName: any): ()
						if stateName == "EquippedItem" then
							sync(animator)
						end
					end),
					"Disconnect"
				)
			end

			local played = animator.AnimationPlayed
			if played then
				local healMap = getHealMap()
				self._characterJanitor:Add(
					played:Connect(function(animationName: any, track: any): ()
						local heal = healMap[animationName]
						if heal then
							self:_trackConsume(track, heal)
						end
					end),
					"Disconnect"
				)
			end

			local reloadPlayed = animator.ReloadAnimationPlayed
			if reloadPlayed then
				self._characterJanitor:Add(
					reloadPlayed:Connect(function(): ()
						self:_trackReload(animator)
					end),
					"Disconnect"
				)
			end

			local reloadStopped = animator.ReloadAnimationStopped
			if reloadStopped then
				self._characterJanitor:Add(
					reloadStopped:Connect(function(): ()
						sync(animator, true)
						self:_clearReload()
					end),
					"Disconnect"
				)
			end

			local slept = animator.Slept
			if slept then
				self._characterJanitor:Add(
					slept:Connect(function(): ()
						self:_clearReload()
						self:_clearHealing()
					end),
					"Disconnect"
				)
			end

			local function syncActions(): ()
				local isReloadPlaying = animator.IsReloadPlaying
				if type(isReloadPlaying) == "function" then
					if isReloadPlaying(animator) then
						self:_trackReload(animator)
					else
						self:_clearReload()
					end
				end

				local healMap = getHealMap()
				for animationName in next, healMap do
					local track = animator:GetTrack(animationName)
					if track and track.IsPlaying then
						self:_trackConsume(track, healMap[animationName])
						return
					end
				end
				self:_clearHealing()
			end

			local woken = animator.Woken
			if woken then
				self._characterJanitor:Add(
					woken:Connect(function(): ()
						task.defer(syncActions)
					end),
					"Disconnect"
				)
			end

			syncActions()
		end

		local existing = animators.find(character)
		if existing then
			bind(existing)
			return
		end

		local token = self._weaponToken
		task.spawn(function(): ()
			for _ = 1, 50 do
				if self._weaponToken ~= token then
					return
				end
				local animator = animators.find(character)
				if animator then
					if self._weaponToken == token then
						bind(animator)
					end
					return
				end
				task.wait(0.1)
			end
		end)
	end

	function ARPlayer._recordShot(self: ARPlayer, itemName: string): ()
		local currentWeapon = peek(self.weapon)
		if currentWeapon ~= itemName then
			self.weapon(itemName)
			local itemData = ModuleController.GetItemData()
			local weapon = itemData and itemData[itemName]
			local fireConfig = weapon and weapon.FireConfig
			local capacity = fireConfig and fireConfig.InternalMag and tonumber(fireConfig.InternalMagSize) or nil
			if not capacity and weapon and type(weapon.MagazineTypes) == "table" then
				local magazine = itemData[weapon.MagazineTypes[1]]
				capacity = magazine and tonumber(magazine.Capacity) or nil
			end
			self.ammoCapacity(capacity)
			self.ammo(capacity and math.max(capacity - 1, 0) or nil)
			self.ammoExact(false)
			return
		end

		local amount = peek(self.ammo)
		local capacity = peek(self.ammoCapacity)
		if amount == nil then
			amount = capacity
		end
		if amount ~= nil then
			self.ammo(math.max(amount - 1, 0))
		end
	end

	function ARPlayer._clearReload(self: ARPlayer): ()
		self._reloadToken += 1
		self.isReloading(false)
	end

	function ARPlayer._trackReload(self: ARPlayer, _animator: any): ()
		self._reloadToken += 1
		local token = self._reloadToken
		self.isReloading(true)

		task.delay(30, function(): ()
			if self._reloadToken == token then
				self:_clearReload()
			end
		end)
	end

	function ARPlayer._clearHealing(self: ARPlayer): ()
		self._healToken += 1
		self.isHealing(false)
	end

	function ARPlayer._trackConsume(self: ARPlayer, track: any, heal: number): ()
		if not track then
			return
		end
		self._healToken += 1
		local token = self._healToken
		self.isHealing(true)

		local expected = 1
		local timeout = 15
		local length = tonumber(track.Length) or 0
		local speed = tonumber(track.Speed) or 1
		if speed <= 0 then
			speed = 1
		end
		if length > 0 then
			expected = length / speed
			timeout = expected + 1
		end

		local function clearHealing(): ()
			if self._healToken == token then
				self:_clearHealing()
			end
		end

		local start = os.clock()
		local connection
		connection = track.Stopped:Connect(function(): ()
			connection:Disconnect()

			clearHealing()

			if not peek(self.alive) then
				return
			end

			if expected > 0 and os.clock() - start < expected * 0.85 then
				return
			end

			self.health(math.min(peek(self.health) + heal, peek(self.maxHealth)))
		end)

		self._characterJanitor:Add(connection, "Disconnect")

		task.delay(timeout, clearHealing)
	end

	function ARPlayer.Destroy(self: ARPlayer): ()
		self._janitor:Destroy()
	end

	function ARPlayer.GetVelocity(self: ARPlayer): Vector3
		local hrp = peek(self.hrp)
		return hrp and hrp.AssemblyLinearVelocity or Vector3.zero
	end

	function ARPlayer.IsAlive(self: ARPlayer): boolean
		return peek(self.alive)
	end

	function ARPlayer.GetCharacter(self: ARPlayer): Model?
		return peek(self.character)
	end

	function ARPlayer.GetParts(self: ARPlayer): { [string]: Instance }
		return peek(self.parts)
	end

	function ARPlayer._onPartAdded(self: ARPlayer, part: Instance): ()
		local parts = self.parts
		parts(Sift.Dictionary.set(peek(parts), part.Name :: any, part))
	end

	function ARPlayer._onPartRemoved(self: ARPlayer, part: Instance): ()
		local parts = self.parts
		parts(Sift.Dictionary.removeKey(peek(parts), part.Name :: any))
	end

	function ARPlayer._onCharacterRemoving(self: ARPlayer)
		self._characterJanitor:Cleanup()
		self._weaponToken += 1
		self._healToken += 1
		self._reloadToken += 1
		self.character(nil)
		self.hrp(nil)
		self.alive(false)
		self.health(0)
		self.weapon("")
		self.ammo(nil)
		self.ammoCapacity(nil)
		self.ammoExact(false)
		self.isReloading(false)
		self.isHealing(false)
		self.parts({})
	end

	export type ARPlayer =
		typeof(setmetatable(
			{} :: {
				_janitor: Janitor.Janitor,
				_characterJanitor: Janitor.Janitor,
				_weaponToken: number,
				_healToken: number,
				_reloadToken: number,
				character: Charm.Atom<Model?>,
				hrp: Charm.Atom<BasePart?>,
				alive: Charm.Atom<boolean>,
				health: Charm.Atom<number>,
				maxHealth: Charm.Atom<number>,
				weapon: Charm.Atom<string>,
				ammo: Charm.Atom<number?>,
				ammoCapacity: Charm.Atom<number?>,
				ammoExact: Charm.Atom<boolean>,
				isReloading: Charm.Atom<boolean>,
				isHealing: Charm.Atom<boolean>,
				parts: Charm.Atom<{ [string]: Instance }>,
			},
			ARPlayer
		))
		& BasePlayer.BasePlayer

	return ARPlayer
end)()
