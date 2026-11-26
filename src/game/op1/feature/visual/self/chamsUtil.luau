local chamsSession = require("@game/universal/feature/visual/chams/chamsSession")

local chamsUtil = {}

local MATERIAL_OPTIONS = { "ForceField", "Neon", "Glass" }
local MATERIAL_MAP: { [string]: Enum.Material } = {
	Neon = Enum.Material.Neon,
	ForceField = Enum.Material.ForceField,
	Plastic = Enum.Material.Plastic,
	SmoothPlastic = Enum.Material.SmoothPlastic,
	Glass = Enum.Material.Glass,
	Metal = Enum.Material.Metal,
}

export type Store = { [BasePart]: true }

local sessions: { [Store]: chamsSession.Session } = setmetatable({}, { __mode = "k" }) :: any

chamsUtil.MATERIAL_OPTIONS = MATERIAL_OPTIONS

function chamsUtil.material(name: any): Enum.Material
	return MATERIAL_MAP[name] or Enum.Material.Neon
end

function chamsUtil.collectByRoots(container: Instance, roots: { [string]: boolean }): { BasePart }
	local parts: { BasePart } = {}

	for _, desc in next, container:QueryDescendants("BasePart") do
		local node: Instance? = desc
		while node and node ~= container do
			if roots[node.Name] then
				parts[#parts + 1] = desc
				break
			end
			node = node.Parent
		end
	end

	return parts
end

local function sessionFor(store: Store): chamsSession.Session
	local session = sessions[store]
	if not session then
		session = chamsSession.new({ lockTransparency = true })
		sessions[store] = session
	end
	return session
end

function chamsUtil.apply(
	store: Store,
	part: BasePart,
	material: Enum.Material,
	color: Color3,
	transparency: number
): ()
	if store[part] == nil and part.Transparency >= 1 then
		return
	end
	store[part] = true
	sessionFor(store).apply(part, {
		material = material,
		color = color,
		transparency = transparency,
		reflectance = 0,
	})
end

function chamsUtil.restoreAll(store: Store): ()
	local session = sessions[store]
	if session then
		session.restoreAll()
		sessions[store] = nil
	end
	table.clear(store)
end

return chamsUtil
