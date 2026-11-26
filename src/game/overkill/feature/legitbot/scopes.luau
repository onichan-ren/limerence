local ScopeController = require("@feature/ui/scope/ScopeController")
local ModuleController = require("@game/overkill/module/ModuleController")
local gunCategories = require("@game/overkill/weapon/gunCategories")

local CATEGORY_ORDER: { string } = {
	"assault_rifle",
	"heavy",
	"shotgun",
	"sniper_rifle",
	"pistol",
}

local scopes = {}

local _built = false

local function prettify(text: string): string
	local spaced = text:gsub("_", " ")
	return (spaced:gsub("(%a)([%w]*)", function(first: string, rest: string): string
		return first:upper() .. rest:lower()
	end))
end

function scopes.build(): ()
	if _built then
		return
	end

	local items = ModuleController.GetModule("items")
	if not items or not items.all then
		return
	end
	_built = true

	for order, category in next, CATEGORY_ORDER do
		ScopeController.RegisterGroup(category, prettify(category), order)
	end

	for _, item in next, items.all do
		local category = item.category
		local name = item.name
		if type(category) ~= "string" or not gunCategories[category] then
			continue
		end
		if type(name) ~= "string" or name == "" then
			continue
		end
		ScopeController.RegisterWeapon(name:lower(), name, category)
	end
end

return scopes
