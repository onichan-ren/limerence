local clientState = require("@game/bloxstrike/client/clientState")
local Charm = require("@pkg/Charm")

local peek = Charm.peek

local _lastWeapon: any = nil
local _storedIsInAir = false
local _jumpStartSpeed: number? = nil
local _isAtJumpPeak = false
local _characterSpeed = 0
local _reductionScale = 1

local weaponSpreadState = {}

function weaponSpreadState.getCharacterSpeed(): number
	return _characterSpeed
end

function weaponSpreadState.setReductionScale(scale: number): ()
	_reductionScale = math.clamp(scale, 0, 1)
end

function weaponSpreadState.getReductionScale(): number
	return _reductionScale
end

local movementSpread = LPH_NO_VIRTUALIZE(function(characterSpeed: number, spreadCfg: any): number
	local mult = spreadCfg.MovementMultiplier or 1
	if characterSpeed < 6.4 then
		return 0
	end
	return characterSpeed * mult
end)

local baseSpreadFromBullet = LPH_NO_VIRTUALIZE(function(weapon: any): number
	local bullet = weapon.Bullet
	if not bullet or type(bullet.getBaseSpread) ~= "function" then
		return 0
	end
	return (bullet :: any):getBaseSpread()
end)

local spreadConfigOf = LPH_NO_VIRTUALIZE(function(weapon: any): any
	return (weapon.Bullet and weapon.Bullet.ActiveSpreadConfig) or (weapon.Properties and weapon.Properties.Spread)
end)

local replicatedTrueSpreadDegrees = LPH_NO_VIRTUALIZE(function(weapon: any, perShotOffset: number): number?
	local spreadCfg = spreadConfigOf(weapon)
	if not spreadCfg then
		return nil
	end

	local range = spreadCfg.Range
	local rangeMin = range and range.Min or 0
	local rangeMax = range and range.Max or math.huge

	local base = math.clamp(baseSpreadFromBullet(weapon) - perShotOffset, rangeMin, rangeMax)

	return base + movementSpread(weaponSpreadState.getCharacterSpeed(), spreadCfg)
end)

local spreadDegreesWithOffset = LPH_NO_VIRTUALIZE(function(weapon: any, perShotOffset: number): number?
	if not weapon or not weapon.Properties or weapon.Properties.Class ~= "Weapon" then
		return nil
	end
	local spread = replicatedTrueSpreadDegrees(weapon, perShotOffset)
	if spread == nil then
		return nil
	end
	return spread * _reductionScale
end)

weaponSpreadState.getSpreadDegrees = LPH_NO_VIRTUALIZE(function(weapon: any): number?
	return spreadDegreesWithOffset(weapon, 0)
end)

weaponSpreadState.getFiredSpreadDegrees = LPH_NO_VIRTUALIZE(function(weapon: any): number?
	local spreadCfg = spreadConfigOf(weapon)
	return spreadDegreesWithOffset(weapon, spreadCfg and spreadCfg.PerShot or 0)
end)

local _spreadRng = Random.new()

weaponSpreadState.applyBulletSpread = LPH_NO_VIRTUALIZE(function(direction: Vector3, spreadDegrees: number): Vector3
	if spreadDegrees <= 0 then
		return direction
	end
	local clamped = math.min(spreadDegrees, 69)
	local theta = _spreadRng:NextNumber(-math.pi, math.pi)
	local phi = _spreadRng:NextNumber(0, math.rad(clamped * 0.5))
	local lookDir = direction.Magnitude > 0 and direction.Unit or Vector3.new(0, 0, 1)
	local baseCFrame = CFrame.new(Vector3.zero, lookDir)
	local thetaRot = CFrame.fromAxisAngle(baseCFrame.LookVector, theta)
	local intermediate = thetaRot * baseCFrame
	local rightVec = intermediate.RightVector
	return (CFrame.fromAxisAngle(rightVec, phi) * intermediate).LookVector
end)

weaponSpreadState.step = LPH_NO_VIRTUALIZE(function(weapon: any): ()
	if weapon ~= _lastWeapon then
		_lastWeapon = weapon
		_storedIsInAir = false
		_jumpStartSpeed = nil
		_isAtJumpPeak = false
		_characterSpeed = 0
	end

	if not weapon or not weapon.Properties or weapon.Properties.Class ~= "Weapon" then
		_characterSpeed = 0
		return
	end

	local parts = peek(clientState.parts)
	local primaryPart = parts.HumanoidRootPart :: BasePart
	if not primaryPart then
		_characterSpeed = 0
		return
	end

	local humanoid = parts.Humanoid :: Humanoid
	if not humanoid then
		_characterSpeed = 0
		return
	end

	local assemblyVel = primaryPart.AssemblyLinearVelocity
	local state = humanoid:GetState()
	local verticalVelocity = assemblyVel.Y

	local wasInAir = _storedIsInAir
	_storedIsInAir = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall

	local props = weapon.Properties
	local bullet = weapon.Bullet
	local spreadCfg = (bullet and bullet.ActiveSpreadConfig) or props.Spread
	if not spreadCfg then
		_characterSpeed = 0
		return
	end

	local range = spreadCfg.Range
	local rangeMin = range and range.Min or 0
	local perShot = spreadCfg.PerShot or 0
	local movementMult = spreadCfg.MovementMultiplier or 1
	local sniperJumpPeakMode = props.AimingOptions == "SniperScope"
		and props.MuzzleType == "Sniper"
		and rangeMin == 0
		and perShot == 0
		and movementMult == 2

	if sniperJumpPeakMode and _storedIsInAir then
		_isAtJumpPeak = math.abs(verticalVelocity) <= 3
	else
		_isAtJumpPeak = false
	end

	if _storedIsInAir and not wasInAir then
		local jm = spreadCfg.JumpShotMinimum or 100
		_jumpStartSpeed = assemblyVel.Magnitude + jm
	elseif not _storedIsInAir and wasInAir then
		_jumpStartSpeed = nil
		_isAtJumpPeak = false
	end

	if _storedIsInAir and _jumpStartSpeed then
		if sniperJumpPeakMode and _isAtJumpPeak then
			_characterSpeed = Vector3.new(assemblyVel.X, 0, assemblyVel.Z).Magnitude
		else
			_characterSpeed = _jumpStartSpeed
		end
		return
	end

	_characterSpeed = assemblyVel.Magnitude
end)

function weaponSpreadState.reset(): ()
	_lastWeapon = nil
	_storedIsInAir = false
	_jumpStartSpeed = nil
	_isAtJumpPeak = false
	_characterSpeed = 0
end

return weaponSpreadState
