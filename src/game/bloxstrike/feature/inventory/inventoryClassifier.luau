local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local inventoryClassifier = {}

local TYPE_TO_CATEGORY: { [string]: string } = {
	Pistol = "Pistols",
	SMG = "Mid Tier",
	Heavy = "Mid Tier",
	Rifle = "Rifles",
}

local SPECIAL_BY_CLASS: { [string]: string } = {
	Melee = "Equipped Melee",
	Glove = "Equipped Gloves",
}

local SPECIAL_BY_NAME: { [string]: string } = {
	["Zeus x27"] = "Equipped Zeus x27",
}

inventoryClassifier.TEAMS = { "Counter-Terrorists", "Terrorists" }

inventoryClassifier.KNIFE_BY_TEAM = {
	["Counter-Terrorists"] = "CT Knife",
	Terrorists = "T Knife",
}

inventoryClassifier.GLOVE_BY_TEAM = {
	["Counter-Terrorists"] = "CT Glove",
	Terrorists = "T Glove",
}

local defCache: { [string]: any } = {}

function inventoryClassifier.getDefinition(weaponName: string): any?
	if defCache[weaponName] ~= nil then
		return defCache[weaponName] or nil
	end
	local folder = ReplicatedStorage:FindFirstChild("Database")
	folder = folder and folder:FindFirstChild("Custom")
	folder = folder and folder:FindFirstChild("Weapons")
	local def = folder and folder:FindFirstChild(weaponName)
	if not def then
		defCache[weaponName] = false
		return nil
	end
	setthreadidentity(2)
	local ok, mod = pcall(require, def)
	setthreadidentity(8)
	if not ok or type(mod) ~= "table" then
		defCache[weaponName] = false
		return nil
	end
	defCache[weaponName] = mod
	return mod
end

function inventoryClassifier.getCategory(weaponName: string): string?
	local def = inventoryClassifier.getDefinition(weaponName)
	if not def then
		return nil
	end
	if SPECIAL_BY_NAME[weaponName] then
		return nil
	end
	if def.Class == "Melee" or def.Class == "Glove" then
		return nil
	end
	if def.Class == "Grenade" or def.Class == "C4" then
		return nil
	end
	return TYPE_TO_CATEGORY[def.Type]
end

function inventoryClassifier.getSpecialPath(weaponName: string): string?
	local named = SPECIAL_BY_NAME[weaponName]
	if named then
		return named
	end
	local def = inventoryClassifier.getDefinition(weaponName)
	if not def then
		return nil
	end
	return SPECIAL_BY_CLASS[def.Class]
end

function inventoryClassifier.getTeamsForWeapon(weaponName: string): { string }
	local def = inventoryClassifier.getDefinition(weaponName)
	if not def then
		return inventoryClassifier.TEAMS
	end
	if def.Team == "Counter-Terrorists" then
		return { "Counter-Terrorists" }
	elseif def.Team == "Terrorists" then
		return { "Terrorists" }
	end
	return inventoryClassifier.TEAMS
end

function inventoryClassifier.isMeleeName(weaponName: string): boolean
	local def = inventoryClassifier.getDefinition(weaponName)
	return def ~= nil and def.Class == "Melee"
end

function inventoryClassifier.isGloveName(weaponName: string): boolean
	local def = inventoryClassifier.getDefinition(weaponName)
	return def ~= nil and def.Class == "Glove"
end

return inventoryClassifier
