local Charm = require("@pkg/Charm")

local strings = require("@share/strings")
local customAssets = require("@game/rivals/feature/inventory/customAssets")
local rivalsInventoryState = require("@game/rivals/feature/inventory/rivalsInventoryState")

local at = Charm.atom
local peek = Charm.peek

export type CustomWrap = {
	id: string,
	name: string,
	image: string,
	animated: boolean,
	speedU: number,
	speedV: number,
	tint: Color3?,
	material: string,
	version: number,
}

export type ImageEntry = {
	name: string,
	fullName: string,
	path: string,
}

local customWrapStore = {
	wraps = at({} :: { [string]: CustomWrap }),
	modal = at({
		open = false,
		mode = "create",
		kind = "Wrap",
		editId = nil :: string?,
	}),
}

local function bumpRev(): ()
	rivalsInventoryState.customWrapsRev(peek(rivalsInventoryState.customWrapsRev) + 1)
end

function customWrapStore.ensureDir(): ()
	customAssets.ensureDir()
end

function customWrapStore.getAssetPath(image: string): string
	return customAssets.path(image)
end

function customWrapStore.list(): { CustomWrap }
	local out: { CustomWrap } = {}
	for _, wrap in next, peek(customWrapStore.wraps) do
		out[#out + 1] = wrap
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

function customWrapStore.get(id: string): CustomWrap?
	return peek(customWrapStore.wraps)[id]
end

function customWrapStore.set(wrap: CustomWrap): ()
	local current = table.clone(peek(customWrapStore.wraps))
	current[wrap.id] = wrap
	customWrapStore.wraps(current)
	bumpRev()
end

function customWrapStore.remove(id: string): ()
	local current = table.clone(peek(customWrapStore.wraps))
	current[id] = nil
	customWrapStore.wraps(current)
	bumpRev()
end

function customWrapStore.replaceAll(map: { [string]: CustomWrap }): ()
	customWrapStore.wraps(map)
	bumpRev()
end

function customWrapStore.newId(): string
	return "customwrap_" .. strings.randomSafe(10)
end

function customWrapStore.listImages(): { ImageEntry }
	return customAssets.list("image")
end

function customWrapStore.imageExists(image: string): boolean
	return customAssets.exists(image)
end

local function toSaved(wrap: CustomWrap): { [string]: any }
	local saved: { [string]: any } = {
		id = wrap.id,
		name = wrap.name,
		image = wrap.image,
		animated = wrap.animated,
		speedU = wrap.speedU,
		speedV = wrap.speedV,
		material = wrap.material,
		version = wrap.version,
	}
	if wrap.tint then
		saved.tint = { r = wrap.tint.R, g = wrap.tint.G, b = wrap.tint.B }
	end
	return saved
end

local function fromSaved(saved: any): CustomWrap?
	if type(saved) ~= "table" then
		return nil
	end
	if type(saved.id) ~= "string" or type(saved.name) ~= "string" or type(saved.image) ~= "string" then
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
		image = saved.image,
		animated = saved.animated == true,
		speedU = type(saved.speedU) == "number" and saved.speedU or 0,
		speedV = type(saved.speedV) == "number" and saved.speedV or 0,
		tint = tint,
		material = type(saved.material) == "string" and saved.material or "Plastic",
		version = type(saved.version) == "number" and saved.version or 1,
	}
end

function customWrapStore.serialize(): { [string]: any }
	local out: { [string]: any } = {}
	for id, wrap in next, peek(customWrapStore.wraps) do
		out[id] = toSaved(wrap)
	end
	return { version = 1, wraps = out }
end

function customWrapStore.deserialize(data: any): ()
	local map: { [string]: CustomWrap } = {}
	if type(data) == "table" and type(data.wraps) == "table" then
		for id, saved in next, data.wraps do
			local wrap = fromSaved(saved)
			if wrap and wrap.id == id then
				map[id] = wrap
			end
		end
	end
	customWrapStore.replaceAll(map)
end

function customWrapStore.openCreate(kind: string?): ()
	customWrapStore.modal({ open = true, mode = "create", kind = kind or "Wrap", editId = nil })
end

function customWrapStore.openEdit(id: string, kind: string?): ()
	customWrapStore.modal({ open = true, mode = "edit", kind = kind or "Wrap", editId = id })
end

function customWrapStore.closeModal(): ()
	customWrapStore.modal({ open = false, mode = "create", kind = "Wrap", editId = nil })
end

return customWrapStore
