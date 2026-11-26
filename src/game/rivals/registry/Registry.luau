local ModuleController = require("@game/rivals/module/ModuleController")

export type ItemEntry = {
	name: string,
	class: string,
	type: string,
	status: string,
	canEliminate: boolean?,
	ammoType: string?,
	maxAmmo: number?,
}

local Registry = {
	Weapons = {} :: { [string]: ItemEntry },
	Melees = {} :: { [string]: ItemEntry },
	Throwables = {} :: { [string]: ItemEntry },
	Custom = {} :: { [string]: ItemEntry },
	All = {} :: { [string]: ItemEntry },
}

local function classify(item: any): ItemEntry?
	if type(item) ~= "table" then
		return nil
	end

	local name = item.Name
	local class = item.Class
	local itemType = item.Type
	local status = item.Status

	if type(name) ~= "string" or type(class) ~= "string" or type(itemType) ~= "string" then
		return nil
	end

	if name == "MISSING_WEAPON" or name:find("BUBBLE") then
		return nil
	end

	return {
		name = name,
		class = class,
		type = itemType,
		status = (type(status) == "string" and status or "Standard"),
		canEliminate = item.CanEliminate == true,
		ammoType = (type(item.AmmoType) == "string" and item.AmmoType or nil),
		maxAmmo = (type(item.MaxAmmo) == "number" and item.MaxAmmo or nil),
	}
end

local function clearAll(): ()
	for k in next, Registry.Weapons do
		Registry.Weapons[k] = nil
	end
	for k in next, Registry.Melees do
		Registry.Melees[k] = nil
	end
	for k in next, Registry.Throwables do
		Registry.Throwables[k] = nil
	end
	for k in next, Registry.Custom do
		Registry.Custom[k] = nil
	end
	for k in next, Registry.All do
		Registry.All[k] = nil
	end
end

local scan = LPH_NO_VIRTUALIZE(function(): ()
	setthreadidentity(2)

	local itemLibrary = ModuleController.GetModule("ItemLibrary")
	if not itemLibrary then
		setthreadidentity(8)
		return
	end

	local items = rawget(itemLibrary, "Items")
	if type(items) ~= "table" then
		setthreadidentity(8)
		return
	end

	for _, item in next, items do
		local entry = classify(item)
		if not entry then
			continue
		end

		Registry.All[entry.name] = entry
		if entry.type == "Gun" then
			Registry.Weapons[entry.name] = entry
		elseif entry.type == "Melee" then
			Registry.Melees[entry.name] = entry
		elseif entry.type == "Throwable" then
			Registry.Throwables[entry.name] = entry
		else
			Registry.Custom[entry.name] = entry
		end
	end

	setthreadidentity(8)
end)

function Registry.Rescan(): ()
	clearAll()
	pcall(scan)
end

return Registry
