local ScopeController = require("@feature/ui/scope/ScopeController")
local ModuleController = require("@game/pf/module/ModuleController")

local CATEGORIES = {
	"ASSAULT RIFLE",
	"BATTLE RIFLE",
	"CARBINE",
	"DMR",
	"LMG",
	"PDW",
	"SHOTGUN",
	"SNIPER RIFLE",
	"PISTOLS",
	"REVOLVERS",
	"MACHINE PISTOLS",
	"OTHER",
}

local scopes = {}

local _built = false

local function titleCase(text: string): string
	return (text:gsub("(%a)([%w]*)", function(first: string, rest: string): string
		return first:upper() .. rest:lower()
	end))
end

local function prettify(text: string): string
	if text:match("%l") or text:match("%d") then
		return text
	end
	return titleCase(text)
end

local function resolveName(entry: any): string?
	if type(entry) == "string" then
		return entry
	end
	if type(entry) == "table" then
		if type(entry.name) == "string" then
			return entry.name
		end
		if type(entry.weaponName) == "string" then
			return entry.weaponName
		end
		if type(entry[1]) == "string" then
			return entry[1]
		end
	end
	return nil
end

function scopes.build(): ()
	if _built then
		return
	end
	_built = true

	local ContentInterface = ModuleController.GetModule("ContentInterface")
	if not ContentInterface then
		return
	end

	for order, category in next, CATEGORIES do
		local list = ContentInterface.getWeaponListFromClass(category)
		if type(list) ~= "table" then
			continue
		end

		local groupId = category:lower()
		ScopeController.RegisterGroup(groupId, prettify(category), order)

		for _, entry in next, list do
			local weaponName = resolveName(entry)
			if weaponName then
				ScopeController.RegisterWeapon(weaponName:lower(), prettify(weaponName), groupId)
			end
		end
	end
end

return scopes
