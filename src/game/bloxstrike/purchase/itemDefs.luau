local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage & any

local defCache: { [string]: any } = {}

local EQUIPMENT: { [string]: boolean } = {
	["Kevlar"] = true,
	["Kevlar + Helmet"] = true,
	["Defuse Kit"] = true,
	["Rescue Kit"] = true,
}

local itemDefs = {}

function itemDefs.Get(name: string): any
	local cached = defCache[name]
	if cached ~= nil then
		return cached or nil
	end

	local database = ReplicatedStorage.Database.Custom
	local instance = database.Weapons:FindFirstChild(name) or database.GameStats.Equipment:FindFirstChild(name)
	if not instance then
		defCache[name] = false
		return nil
	end

	setthreadidentity(2)
	local def = require(instance)
	setthreadidentity(8)

	if type(def) ~= "table" then
		defCache[name] = false
		return nil
	end

	defCache[name] = def
	return def
end

function itemDefs.GetIcon(name: string): string
	local def = itemDefs.Get(name)
	local icon = def and def.Icon
	if type(icon) ~= "string" then
		return ""
	end
	return icon
end

function itemDefs.GetCost(name: string): number
	local def = itemDefs.Get(name)
	if not def then
		return 0
	end
	return tonumber(def.Cost) or 0
end

function itemDefs.IsEquipment(name: string): boolean
	return EQUIPMENT[name] == true
end

export type ItemDefs = typeof(itemDefs)

return itemDefs
