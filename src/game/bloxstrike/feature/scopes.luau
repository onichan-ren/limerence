local ScopeController = require("@feature/ui/scope/ScopeController")
local Registry = require("@game/bloxstrike/registry/Registry")

local scopes = {}

local _built = false

function scopes.build(): ()
	if _built then
		return
	end
	_built = true

	local weapons = Registry.Weapons
	local groups = {}
	local groupSet: { [string]: true } = {}
	for _, weapon in next, weapons do
		local group = weapon.group
		if not groupSet[group] then
			groupSet[group] = true
			groups[#groups + 1] = group
		end
	end
	for _, group in next, groups do
		ScopeController.RegisterGroup(group:lower(), group)
	end
	for weapon, data in next, weapons do
		ScopeController.RegisterWeapon(weapon:lower(), weapon, data.group:lower())
	end
end

return scopes
