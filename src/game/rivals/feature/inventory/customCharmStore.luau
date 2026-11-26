local Charm = require("@pkg/Charm")

local strings = require("@share/strings")
local customAssets = require("@game/rivals/feature/inventory/customAssets")
local rivalsInventoryState = require("@game/rivals/feature/inventory/rivalsInventoryState")

local at = Charm.atom
local peek = Charm.peek

export type CustomCharm = {
	id: string,
	name: string,
	mesh: string,
	texture: string?,
	tint: Color3?,
	scale: number,
	version: number,
}

local customCharmStore = {
	charms = at({} :: { [string]: CustomCharm }),
}

local function bumpRev(): ()
	rivalsInventoryState.customWrapsRev(peek(rivalsInventoryState.customWrapsRev) + 1)
end

function customCharmStore.list(): { CustomCharm }
	local out: { CustomCharm } = {}
	for _, charm in next, peek(customCharmStore.charms) do
		out[#out + 1] = charm
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

function customCharmStore.get(id: string): CustomCharm?
	return peek(customCharmStore.charms)[id]
end

function customCharmStore.set(charm: CustomCharm): ()
	local current = table.clone(peek(customCharmStore.charms))
	current[charm.id] = charm
	customCharmStore.charms(current)
	bumpRev()
end

function customCharmStore.remove(id: string): ()
	local current = table.clone(peek(customCharmStore.charms))
	current[id] = nil
	customCharmStore.charms(current)
	bumpRev()
end

function customCharmStore.replaceAll(map: { [string]: CustomCharm }): ()
	customCharmStore.charms(map)
	bumpRev()
end

function customCharmStore.newId(): string
	return "customcharm_" .. strings.randomSafe(10)
end

function customCharmStore.meshAvailable(mesh: string): boolean
	if type(mesh) ~= "string" or mesh == "" then
		return false
	end
	if mesh:match("^%d+$") or mesh:match("^rbxassetid://%d+$") then
		return true
	end
	return customAssets.exists(mesh)
end

local function toSaved(charm: CustomCharm): { [string]: any }
	local saved: { [string]: any } = {
		id = charm.id,
		name = charm.name,
		mesh = charm.mesh,
		texture = charm.texture,
		scale = charm.scale,
		version = charm.version,
	}
	if charm.tint then
		saved.tint = { r = charm.tint.R, g = charm.tint.G, b = charm.tint.B }
	end
	return saved
end

local function fromSaved(saved: any): CustomCharm?
	if type(saved) ~= "table" then
		return nil
	end
	if type(saved.id) ~= "string" or type(saved.name) ~= "string" or type(saved.mesh) ~= "string" then
		return nil
	end
	local tint: Color3? = nil
	if
		type(saved.tint) == "table"
		and type(saved.tint.r) == "number"
		and type(saved.tint.g) == "number"
		and type(saved.tint.b) == "number"
	then
		tint = Color3.new(saved.tint.r, saved.tint.g, saved.tint.b)
	end
	return {
		id = saved.id,
		name = saved.name,
		mesh = saved.mesh,
		texture = type(saved.texture) == "string" and saved.texture or nil,
		tint = tint,
		scale = type(saved.scale) == "number" and math.clamp(saved.scale, 0.05, 10) or 1,
		version = type(saved.version) == "number" and saved.version or 1,
	}
end

function customCharmStore.serialize(): { [string]: any }
	local out: { [string]: any } = {}
	for id, charm in next, peek(customCharmStore.charms) do
		out[id] = toSaved(charm)
	end
	return { version = 1, charms = out }
end

function customCharmStore.deserialize(data: any): ()
	local map: { [string]: CustomCharm } = {}
	if type(data) == "table" and type(data.charms) == "table" then
		for id, saved in next, data.charms do
			local charm = fromSaved(saved)
			if charm and charm.id == id then
				map[id] = charm
			end
		end
	end
	customCharmStore.replaceAll(map)
end

return customCharmStore
