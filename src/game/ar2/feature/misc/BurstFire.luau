return LPH_JIT_MAX(function()
	local BaseFeature = require("@game/BaseFeature")
	local gameUi = require("@game/gameUi")
	local WeaponController = require("@game/ar2/weapon/WeaponController")
	local NetworkController = require("@game/ar2/network/NetworkController")
	local ModuleController = require("@game/ar2/module/ModuleController")
	local hook = require("@share/hook")

	local FIRED_PACKET = "Bullet Fired"
	local IMPACT_PACKET = "Bullet Impact"
	local MAX_SHIFT = 0.2
	local SHIFT_TTL = 2

	local function hasAmmo(weapon: any): boolean
		local fc = weapon.FireConfig
		if fc and fc.InternalMag then
			return (weapon.WorkingAmount or 0) >= 1
		end
		local ammo = weapon.Attachments and weapon.Attachments.Ammo
		return ammo ~= nil and (ammo.WorkingAmount or 0) >= 1
	end

	local function consumeAmmo(weapon: any): boolean
		local fc = weapon.FireConfig
		if fc and fc.InternalMag and (weapon.WorkingAmount or 0) >= 1 then
			weapon.WorkingAmount -= 1
			return true
		end
		local ammo = weapon.Attachments and weapon.Attachments.Ammo
		if ammo and (ammo.WorkingAmount or 0) >= 1 then
			ammo.WorkingAmount -= 1
			return true
		end
		return false
	end

	local BurstFire = {}
	BurstFire.__index = BurstFire

	setmetatable(BurstFire, { __index = BaseFeature })

	function BurstFire.new(link: gameUi.Linker): BurstFire
		local self = BaseFeature.new() :: any
		setmetatable(self, BurstFire)

		self._enabled = false
		self._bursting = false
		self._fireInstalled = false
		self._pendingShift = nil :: number?
		self._shiftById = {} :: { [number]: number }
		self._lastBurstClock = nil :: number?

		self._onFired = function(bulletId, fireTime, itemId, encOrigin, encDirection): ()
			if not self._enabled then
				return
			end
			local shift = self._pendingShift
			if not shift or typeof(encOrigin) ~= "Vector3" or typeof(encDirection) ~= "Vector3" then
				return
			end
			local newTime = fireTime - shift

			local rng = Random.new(fireTime * 10000)
			local originEncode = rng:NextUnitVector() * bulletId
			local directionEncode = rng:NextUnitVector() * bulletId
			local origin =
				Vector3.new(encOrigin.X / originEncode.X, encOrigin.Y / originEncode.Y, encOrigin.Z / originEncode.Z)
			local direction = Vector3.new(
				encDirection.X / directionEncode.X,
				encDirection.Y / directionEncode.Y,
				encDirection.Z / directionEncode.Z
			)

			local rng2 = Random.new(newTime * 10000)
			local originEncode2 = rng2:NextUnitVector() * bulletId
			local directionEncode2 = rng2:NextUnitVector() * bulletId

			self._shiftById[bulletId] = shift
			local id = bulletId
			task.delay(SHIFT_TTL, function(): ()
				if self._shiftById[id] == shift then
					self._shiftById[id] = nil
				end
			end)

			return bulletId,
				newTime,
				itemId,
				Vector3.new(origin.X * originEncode2.X, origin.Y * originEncode2.Y, origin.Z * originEncode2.Z),
				Vector3.new(
					direction.X * directionEncode2.X,
					direction.Y * directionEncode2.Y,
					direction.Z * directionEncode2.Z
				)
		end

		self._onImpact = function(shotId, weaponId, serverTime, pellet, hitPart, posObf, t7): ()
			if not self._enabled then
				return
			end
			local shift = self._shiftById[shotId]
			if not shift then
				return
			end
			return shotId, weaponId, serverTime - shift, pellet, hitPart, posObf, t7
		end

		link:Toggle("burstFire", "Burst Fire", false):SetTip({
			title = "Burst Fire",
			body = "Fires several shots at once when you shoot. Faster weapons fire more, slower ones fire fewer.",
		})

		self:Track(link:Get("burstFire"):OnChange(function(value: boolean): ()
			self:_setActive(value == true)
		end))

		if link:Peek("burstFire") == true then
			self:_setActive(true)
		end

		return self
	end

	function BurstFire._installFireHook(self: BurstFire): ()
		if self._fireInstalled then
			return
		end
		local bullets = ModuleController.GetModule("Bullets")
		local module = bullets and bullets.module
		if not module or type(module.Fire) ~= "function" then
			return
		end
		self._fireInstalled = true

		local original
		original = hook.add(
			module.Fire,
			LPH_NO_VIRTUALIZE(function(fireSelf, character, camera, weapon, origin, direction, ...): ...any
				if self._bursting or not self._enabled or not weapon or not weapon.FireConfig then
					return original(fireSelf, character, camera, weapon, origin, direction, ...)
				end

				local interval = WeaponController.GetFireInterval(weapon)
				if interval <= 0 then
					return original(fireSelf, character, camera, weapon, origin, direction, ...)
				end

				local nowClock = os.clock()
				local lastBurst = self._lastBurstClock or -MAX_SHIFT
				if nowClock - lastBurst < MAX_SHIFT then
					return original(fireSelf, character, camera, weapon, origin, direction, ...)
				end

				local extra = math.floor(MAX_SHIFT / interval)
				if extra > 0 then
					self._lastBurstClock = nowClock

					self._bursting = true
					for k = extra, 1, -1 do
						if not hasAmmo(weapon) then
							break
						end
						consumeAmmo(weapon)
						self._pendingShift = k * interval
						original(fireSelf, character, camera, weapon, origin, direction, ...)
						self._pendingShift = nil
					end
					self._bursting = false
				end

				return original(fireSelf, character, camera, weapon, origin, direction, ...)
			end)
		)
	end

	function BurstFire._setActive(self: BurstFire, active: boolean): ()
		if self._enabled == active then
			return
		end
		self._enabled = active
		if active then
			self._lastBurstClock = nil
			self:_installFireHook()
			NetworkController.hookSend(FIRED_PACKET, self._onFired)
			NetworkController.hookSend(IMPACT_PACKET, self._onImpact)
		else
			NetworkController.restoreSend(FIRED_PACKET, self._onFired)
			NetworkController.restoreSend(IMPACT_PACKET, self._onImpact)
			self._pendingShift = nil
			self._bursting = false
			table.clear(self._shiftById)
		end
	end

	function BurstFire.Destroy(self: BurstFire): ()
		self:_setActive(false)
		BaseFeature.Destroy(self)
	end

	export type BurstFire =
		typeof(setmetatable(
			{} :: {
				_enabled: boolean,
				_bursting: boolean,
				_fireInstalled: boolean,
				_pendingShift: number?,
				_shiftById: { [number]: number },
				_lastBurstClock: number?,
				_onFired: (...any) -> ...any,
				_onImpact: (...any) -> ...any,
				_installFireHook: (BurstFire) -> (),
				_setActive: (BurstFire, boolean) -> (),
			},
			BurstFire
		))
		& BaseFeature.BaseFeature

	return BurstFire
end)()
