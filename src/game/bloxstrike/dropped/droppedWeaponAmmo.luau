local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local weaponLimitsCache: { [string]: { maxRounds: number } } = {}

local droppedWeaponAmmo = {}

droppedWeaponAmmo.getMaxRounds = LPH_NO_VIRTUALIZE(function(weaponName: string): number
	local cached = weaponLimitsCache[weaponName]
	if cached then
		return cached.maxRounds
	end

	local database = (ReplicatedStorage :: any).Database
	local defInst = database.Custom.Weapons:FindFirstChild(weaponName)
	if not defInst then
		return 0
	end

	setthreadidentity(2)
	local def = require(defInst)
	setthreadidentity(8)
	if type(def) ~= "table" then
		return 0
	end

	if (def :: any).Class ~= "Weapon" or (def :: any).MuzzleType == "Zeus x27" then
		return 0
	end

	local maxRounds = (def :: any).Rounds
	if type(maxRounds) ~= "number" or maxRounds <= 0 then
		return 0
	end

	weaponLimitsCache[weaponName] = { maxRounds = maxRounds }
	return maxRounds
end)

function droppedWeaponAmmo.isAmmoWeapon(weaponName: string): boolean
	return droppedWeaponAmmo.getMaxRounds(weaponName) > 0
end

return droppedWeaponAmmo
