local configState = require("@src/feature/config/configState")
local stateConverter = require("@src/feature/config/module/stateConverter")

local visualImport = {}

export type Category = {
	id: string,
	label: string,
	groups: { { string } },
}

visualImport.CATEGORIES = {
	{ id = "esp", label = "Player ESP", groups = { { "esp" } } },
	{ id = "effects", label = "Effects", groups = { { "effects" } } },
	{ id = "self", label = "Self", groups = { { "selfEsp", "self" } } },
	{
		id = "world",
		label = "World",
		groups = {
			{ "modulations", "worldModulations" },
			{ "overlay", "view" },
			{ "projectiles" },
			{ "worldEsp" },
		},
	},
} :: { Category }

function visualImport.Apply(json: string, selected: { [string]: boolean }): number
	local aliasFor: { [string]: { string } } = {}
	for _, category in next, visualImport.CATEGORIES do
		if selected[category.id] then
			for _, group in next, category.groups do
				for _, prefix in next, group do
					aliasFor[prefix] = group
				end
			end
		end
	end

	local function remap(key: string): string?
		local head = key
		local rest = ""
		local dot = string.find(key, ".", 1, true)
		if dot then
			head = string.sub(key, 1, dot - 1)
			rest = string.sub(key, dot)
		end

		local group = aliasFor[head]
		if not group then
			return nil
		end

		for _, prefix in next, group do
			local localKey = prefix .. rest
			if configState.elements[localKey] then
				return localKey
			end
		end
		return nil
	end

	return stateConverter.applyRemapped(json, remap)
end

return visualImport
