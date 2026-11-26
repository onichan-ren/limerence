local Signal = require("@pkg/Signal")
local Charm = require("@pkg/Charm")
local ModuleController = require("@game/ar2/module/ModuleController")
local NetworkController = require("@game/ar2/network/NetworkController")
local PlayerController = require("@feature/player/PlayerController")
local spreadMath = require("@game/ar2/weapon/spreadMath")
local hook = require("@share/hook")

local WeaponController = {
	shotFired = Signal.new(),
	pelletFired = Signal.new(),
	hitPlayer = Signal.new(),
	shotClaimed = Signal.new(),
	playerDamaged = Signal.new(),
	gameDamaged = Signal.new(),
	onImpact = Signal.new(),
	enemyShotFired = Signal.new(),
	enemyPelletFired = Signal.new(),
	enemyWeaponEmpty = Signal.new(),
}

local Players = cloneref(game:GetService("Players"))
local Workspace = cloneref(game:GetService("Workspace"))
local peek = Charm.peek

local FIRE_RATE_KEYS = {
	Semiautomatic = "SemiFireRate",
	Automatic = "AutoFireRate",
	Burst = "BurstFireRate",
}

local SHOT_ID_STEP = 69
local SHOT_ID_MOD = 420

local function ammoCount(weapon: any): number
	local attachments = weapon.Attachments
	local ammo = attachments and attachments.Ammo
	if ammo and ammo.WorkingAmount then
		return ammo.WorkingAmount
	end
	local fireConfig = weapon.FireConfig
	if fireConfig and fireConfig.InternalMag and weapon.WorkingAmount then
		return weapon.WorkingAmount
	end
	return 0
end

local MAX_HIT_DISTANCE = 8

local resolveVictim = LPH_NO_VIRTUALIZE(function(position: Vector3): Player?
	local best: Player? = nil
	local bestDist = MAX_HIT_DISTANCE

	for player, basePlayer in next, PlayerController.GetAll() do
		local ap = basePlayer :: any
		if not peek(ap.alive) then
			continue
		end

		for _, part in next, peek(ap.parts) do
			if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
				continue
			end
			local dist = (part.Position - position).Magnitude
			if dist < bestDist then
				bestDist = dist
				best = player
			end
		end
	end

	return best
end)

local Bullets
local PlayersModule
local Cameras
local Raycasting
local _bulletsProtos

local impactEffectsSuppressed = false

local _noSpreadEnabled = false
local _noSpreadScale = 1
local _spreadVectorHooked = false
local _spreadVectorTarget

local _fireTarget
local _fireOriginal
local _fireHooked = false
local _bulletFiredHook
local _impactObserver

local function installFireHook(): ()
	if _fireHooked then
		return
	end
	local fire = Bullets and Bullets.module and Bullets.module.Fire
	if type(fire) ~= "function" then
		return
	end
	local original
	original = hook.add(
		fire,
		LPH_NO_VIRTUALIZE(function(...)
			return original(...)
		end)
	)
	_fireOriginal = original
	_fireTarget = fire
	_fireHooked = true
end

local function installSpreadHook(): ()
	if _spreadVectorHooked then
		return
	end
	local gsv = _bulletsProtos and _bulletsProtos.getSpreadVector
	if type(gsv) ~= "function" then
		return
	end
	local original
	original = hook.add(
		gsv,
		LPH_NO_VIRTUALIZE(function(rng: any, dir: Vector3, angle: number): Vector3
			if not _noSpreadEnabled then
				return original(rng, dir, angle)
			end
			local polar = rng:NextNumber(0, angle)
			local az = rng:NextNumber(-math.pi, math.pi)
			return spreadMath.applySpread(dir, polar * _noSpreadScale, az)
		end)
	)
	_spreadVectorTarget = gsv
	_spreadVectorHooked = true
end

function WeaponController.new(): WeaponController
	Bullets = ModuleController.GetModule("Bullets")
	PlayersModule = ModuleController.GetModule("LocalPlayer")
	Cameras = ModuleController.GetModule("Cameras")
	Raycasting = ModuleController.GetModule("Raycasting")

	local playersModule = PlayersModule.module
	local camerasModule = Cameras.module
	local bulletsProtos = Bullets.protos
	local raycastingModule = Raycasting.module
	_bulletsProtos = bulletsProtos

	installFireHook()

	local arLocalPlayer = playersModule.get()

	_bulletFiredHook = LPH_JIT_MAX(function(bulletId, fireTime, itemId, origin, direction)
		local rng = Random.new(fireTime * 10000)

		local originEncode = rng:NextUnitVector() * bulletId
		local directionEncode = rng:NextUnitVector() * bulletId

		local decodedOrigin =
			Vector3.new(origin.X / originEncode.X, origin.Y / originEncode.Y, origin.Z / originEncode.Z)
		local decodedDirection = Vector3.new(
			direction.X / directionEncode.X,
			direction.Y / directionEncode.Y,
			direction.Z / directionEncode.Z
		)

		local character = arLocalPlayer.Character
		if not character then
			return
		end

		local weapon = character.EquippedItem
		local spreadAngle = bulletsProtos.getSpredAngle(character, camerasModule:GetCamera("Character"), weapon)
		local pelletCount = math.max((weapon and weapon.FireConfig and weapon.FireConfig.PelletCount) or 1, 1)

		local newEncodedDirection: Vector3? = nil

		for i = 1, pelletCount do
			local polar = rng:NextNumber(0, spreadAngle)
			local az = rng:NextNumber(-math.pi, math.pi)

			local spreadDirection: Vector3
			if _noSpreadEnabled then
				spreadDirection = spreadMath.applySpread(decodedDirection, polar * _noSpreadScale, az)
				if i == 1 then
					local newDir = spreadMath.inverseSpread(spreadDirection, polar, az)
					newEncodedDirection = Vector3.new(
						newDir.X * directionEncode.X,
						newDir.Y * directionEncode.Y,
						newDir.Z * directionEncode.Z
					)
				end
			else
				spreadDirection = spreadMath.applySpread(decodedDirection, polar, az)
			end

			local target = decodedOrigin + spreadDirection * 1000

			if i == 1 then
				WeaponController.shotFired:Fire(itemId, decodedOrigin, target)
			end

			WeaponController.pelletFired:Fire(itemId, decodedOrigin, target)
		end

		if newEncodedDirection then
			return bulletId, fireTime, itemId, origin, newEncodedDirection
		end
		return
	end)
	NetworkController.hookSend("Bullet Fired", _bulletFiredHook)

	local computeDamage = LPH_NO_VIRTUALIZE(function(weaponData: any, hitPart: BasePart): number
		local fireConfig = weaponData and weaponData.FireConfig

		if not fireConfig then
			return 0
		end

		local damage = math.abs(fireConfig.Damage or 0)
		local hitModifiers = weaponData.HitModifiers

		if hitModifiers and hitPart.Name == "Head" and hitModifiers.Head then
			damage *= math.abs(hitModifiers.Head)
		end

		return damage
	end)

	local processHit = LPH_NO_VIRTUALIZE(
		function(isLocal: boolean, hitPart: BasePart, hitPosition: Vector3, weaponData: any)
			local character = raycastingModule:IsHitCharacter(hitPart)

			if not character then
				return
			end

			local player = Players:GetPlayerFromCharacter(character)

			if not player then
				return
			end

			local damage = computeDamage(weaponData, hitPart)

			WeaponController.playerDamaged:Fire(player, hitPart, damage, isLocal)

			if isLocal then
				WeaponController.hitPlayer:Fire(player, hitPart, hitPosition, damage)
			end
		end
	)

	local oldImpactEffects
	oldImpactEffects = hook.add(
		bulletsProtos.impactEffects,
		LPH_NO_VIRTUALIZE(function(isLocal, hitPart, hitPosition, hitNormal, weaponData, damage)
			WeaponController.onImpact:Fire(hitPart, hitPosition, isLocal)

			processHit(isLocal, hitPart, hitPosition, weaponData)

			if impactEffectsSuppressed then
				return
			end

			return oldImpactEffects(isLocal, hitPart, hitPosition, hitNormal, weaponData, damage)
		end)
	)

	_impactObserver = LPH_NO_VIRTUALIZE(function(shotId, _itemId, _fireTime, pelletIndex, hitPart)
		if type(shotId) ~= "number" or typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") then
			return
		end

		local character = raycastingModule:IsHitCharacter(hitPart)
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		WeaponController.shotClaimed:Fire(player, hitPart, shotId, pelletIndex)
	end)
	NetworkController.observeSend("Bullet Impact", _impactObserver)

	NetworkController.hookReceiver(
		"Bullet Damage",
		LPH_NO_VIRTUALIZE(function(_key, position, damage)
			if typeof(position) ~= "Vector3" or type(damage) ~= "number" or damage <= 0 then
				return
			end

			local victim = resolveVictim(position)
			if victim then
				WeaponController.gameDamaged:Fire(victim, damage, position)
			end
		end)
	)

	NetworkController.hookReceiver(
		"Replicate Shot",
		LPH_NO_VIRTUALIZE(function(player, itemName, origin, direction, _step, seed, spread): ()
			if
				player == Players.LocalPlayer
				or typeof(player) ~= "Instance"
				or not player:IsA("Player")
				or type(itemName) ~= "string"
				or typeof(origin) ~= "Vector3"
				or typeof(direction) ~= "Vector3"
				or type(seed) ~= "number"
				or type(spread) ~= "number"
			then
				return
			end

			WeaponController.enemyShotFired:Fire(player, itemName, origin, direction)

			local itemData = ModuleController.GetItemData()
			local weapon = itemData and itemData[itemName]
			local pelletCount = math.max((weapon and weapon.FireConfig and weapon.FireConfig.PelletCount) or 1, 1)
			local rng = Random.new(seed * 10000)
			for _ = 1, pelletCount do
				local polar = rng:NextNumber(0, spread)
				local azimuth = rng:NextNumber(-math.pi, math.pi)
				WeaponController.enemyPelletFired:Fire(
					player,
					itemName,
					origin,
					spreadMath.applySpread(direction, polar, azimuth)
				)
			end
		end)
	)

	NetworkController.hookReceiver(
		"Last Bullet Sound Play",
		LPH_NO_VIRTUALIZE(function(player, _position, itemName): ()
			if
				player ~= Players.LocalPlayer
				and typeof(player) == "Instance"
				and player:IsA("Player")
				and type(itemName) == "string"
			then
				WeaponController.enemyWeaponEmpty:Fire(player, itemName)
			end
		end)
	)

	return WeaponController
end

function WeaponController.GetNextShotId(): number
	local fire = _fireOriginal
	if not fire then
		return 0
	end

	local upvalues = debug.getupvalues(fire)
	if not upvalues then
		return 0
	end

	for i, value in upvalues do
		if type(value) == "number" then
			local id = (value + SHOT_ID_STEP) % SHOT_ID_MOD
			debug.setupvalue(fire, i, id)
			return id
		end
	end

	return 0
end

function WeaponController.GetEquippedWeapon()
	local arLocalPlayer = PlayersModule.module.get()
	local arCharacter = arLocalPlayer.Character

	local result
	local equippedItem = arCharacter and arCharacter.EquippedItem

	if equippedItem and equippedItem.Type == "Firearm" then
		result = equippedItem
	end

	return result
end

function WeaponController.GetFireInterval(weapon: any): number
	local fireConfig = weapon and weapon.FireConfig
	if not fireConfig then
		return 0
	end
	local rateKey = FIRE_RATE_KEYS[weapon.FireMode] or "FireRate"
	if not fireConfig[rateKey] then
		rateKey = "FireRate"
	end
	local rpm = fireConfig[rateKey] or 100
	if rpm <= 0 then
		rpm = 100
	end
	return 60 / rpm
end

function WeaponController.CanShoot(): boolean
	local weapon = WeaponController.GetEquippedWeapon()
	if not weapon or weapon.Reloading == true then
		return false
	end
	return ammoCount(weapon) > 0
end

function WeaponController.CanFire(): boolean
	local weapon = WeaponController.GetEquippedWeapon()
	if not weapon or weapon.Reloading == true then
		return false
	end
	if ammoCount(weapon) <= 0 then
		return false
	end
	if not weapon.FireConfig then
		return false
	end
	local interval = WeaponController.GetFireInterval(weapon)
	return Workspace:GetServerTimeNow() - (weapon.LastShot or 0) >= interval
end

function WeaponController.SetImpactEffectsSuppressed(suppressed: boolean): ()
	impactEffectsSuppressed = suppressed
end

function WeaponController.SetNoSpread(enabled: boolean, scale: number?): ()
	_noSpreadEnabled = enabled == true
	if scale ~= nil then
		_noSpreadScale = math.clamp(scale, 0, 1)
	end
	if _noSpreadEnabled then
		installSpreadHook()
	end
end

function WeaponController.Destroy()
	_noSpreadEnabled = false
	if _spreadVectorHooked and _spreadVectorTarget then
		hook.restore(_spreadVectorTarget)
	end
	_spreadVectorHooked = false
	_spreadVectorTarget = nil
	if _fireHooked and _fireTarget then
		hook.restore(_fireTarget)
	end
	_fireHooked = false
	_fireTarget = nil
	_fireOriginal = nil
	if _bulletFiredHook then
		NetworkController.restoreSend("Bullet Fired", _bulletFiredHook)
		_bulletFiredHook = nil
	end
	if _impactObserver then
		NetworkController.unobserveSend("Bullet Impact", _impactObserver)
		_impactObserver = nil
	end
	NetworkController.restoreReceiver("Bullet Damage")
	NetworkController.restoreReceiver("Replicate Shot")
	NetworkController.restoreReceiver("Last Bullet Sound Play")
	hook.restore(Bullets.protos.impactEffects)
end

export type WeaponController = typeof(WeaponController)

return WeaponController
