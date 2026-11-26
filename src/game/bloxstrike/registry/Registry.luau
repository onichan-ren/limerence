local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

export type WeaponEntry = {
	group: string,
	class: string,
	type: string?,
	muzzleType: string?,
	slot: string?,
}

local Registry = {
	Weapons = {} :: { [string]: WeaponEntry },
	Melees = {} :: { [string]: WeaponEntry },
	Gloves = {} :: { [string]: WeaponEntry },
	All = {} :: { [string]: WeaponEntry },
}

local SKIP_NAMES: { [string]: true } = {
	["Zeus x27"] = true,
}

local classify = LPH_NO_VIRTUALIZE(function(props: any): any
	if type(props) ~= "table" then
		return nil
	end

	local class = (props :: any).Class :: string
	local type_ = (props :: any).Type
	local muzzleType = (props :: any).MuzzleType
	local slot = (props :: any).Slot

	if class == "Glove" then
		return { group = "Glove", class = class, type = type_, muzzleType = muzzleType, slot = slot }
	end
	if class == "Melee" then
		return { group = "Knife", class = class, type = type_, muzzleType = muzzleType, slot = slot }
	end
	if class ~= "Weapon" then
		return nil
	end

	if muzzleType == "Zeus x27" then
		return nil
	end

	local group: string
	if type_ == "Pistol" then
		group = "Pistol"
	elseif type_ == "SMG" then
		group = "SMG"
	elseif type_ == "Rifle" then
		if muzzleType == "Sniper" then
			group = "Sniper"
		else
			group = "Rifle"
		end
	elseif type_ == "Heavy" then
		if muzzleType == "MachineGun" then
			group = "LMG"
		elseif muzzleType == "ShotGun" then
			group = "Shotgun"
		else
			group = "Heavy"
		end
	elseif type_ == "Sniper" then
		group = "Sniper"
	elseif type_ == "Shotgun" then
		group = "Shotgun"
	elseif type_ == "LMG" then
		group = "LMG"
	else
		return nil
	end

	return { group = group, class = class, type = type_, muzzleType = muzzleType, slot = slot }
end)

local scan = LPH_NO_VIRTUALIZE(function(): ()
	local database = (ReplicatedStorage :: any).Database
	local custom = database and database.Custom
	local weaponsFolder = custom and custom.Weapons
	if not weaponsFolder then
		return
	end

	setthreadidentity(2)

	for _, child in next, weaponsFolder:GetChildren() do
		if not child:IsA("ModuleScript") then
			continue
		end

		local name = child.Name
		if SKIP_NAMES[name] then
			continue
		end

		local ok, props = pcall(require, child)
		if not ok or type(props) ~= "table" then
			continue
		end

		local entry = classify(props) :: WeaponEntry?
		if not entry then
			continue
		end

		Registry.All[name] = entry
		if entry.class == "Glove" then
			Registry.Gloves[name] = entry
		elseif entry.class == "Melee" then
			Registry.Melees[name] = entry
		else
			Registry.Weapons[name] = entry
		end
	end

	setthreadidentity(8)
end)

pcall(scan)

function Registry.Rescan(): ()
	for k in next, Registry.Weapons do
		Registry.Weapons[k] = nil
	end
	for k in next, Registry.Melees do
		Registry.Melees[k] = nil
	end
	for k in next, Registry.Gloves do
		Registry.Gloves[k] = nil
	end
	for k in next, Registry.All do
		Registry.All[k] = nil
	end
	pcall(scan)
end

return Registry
