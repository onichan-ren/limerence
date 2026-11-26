local ModuleController = require("@game/overkill/module/ModuleController")

export type CosmeticEntry = {
	name: string,
	displayName: string,
	type: string,
	collection: string,
	rarity: string,
	rarityValue: number,
	rarityColor: Color3,
	image: string,
	color: Color3,
}

local WHITE = Color3.new(1, 1, 1)

local TYPES = { "Skin", "Wrap", "Charm", "Finisher", "KillEffect" }

local cosmeticCatalog = {}

cosmeticCatalog.TYPES = TYPES

local _items: any = nil
local _directory: any = nil
local _weapons: { string }? = nil
local _listCache: { [string]: { CosmeticEntry } } = {}

local function items(): any
	if _items == nil then
		_items = ModuleController.GetModule("items") or false
	end
	return _items or nil
end

local function directory(): any
	if _directory == nil then
		_directory = ModuleController.GetModule("directory") or false
	end
	return _directory or nil
end

local function weaponDef(weaponId: string): any
	local lib = items()
	local all = lib and lib.all
	return all and all[weaponId] or nil
end

local function isTemp(def: any): boolean
	local name = type(def) == "table" and def.name
	return type(name) == "string" and string.sub(name, -5) == "_temp"
end

local function rarityInfo(rarity: string?): any
	local dir = directory()
	local rarities = dir and dir.Rarities
	return type(rarities) == "table" and rarity and rarities[rarity] or nil
end

function cosmeticCatalog.rarityColor(rarity: string?): Color3
	local info = rarityInfo(rarity)
	if info and typeof(info.color) == "Color3" then
		return info.color
	end
	return WHITE
end

function cosmeticCatalog.rarityValue(rarity: string?): number
	local info = rarityInfo(rarity)
	if info and type(info.priority) == "number" then
		return info.priority
	end
	return 0
end

function cosmeticCatalog.getNID(weaponId: string): string?
	local def = weaponDef(weaponId)
	return def and def.nID or nil
end

function cosmeticCatalog.skinExists(weaponId: string, skinId: string): boolean
	local def = weaponDef(weaponId)
	local skins = def and def.skins
	return type(skins) == "table" and skins[skinId] ~= nil
end

function cosmeticCatalog.displayName(weaponId: string): string
	local def = weaponDef(weaponId)
	if type(def) == "table" and type(def.name) == "string" then
		return def.name
	end
	return weaponId
end

function cosmeticCatalog.getWeapons(): { string }
	if _weapons then
		return _weapons
	end

	local out: { string } = {}
	local lib = items()
	local all = lib and lib.all
	if type(all) == "table" then
		for weaponId, def in next, all do
			if type(weaponId) == "string" and type(def) == "table" and not isTemp(def) then
				out[#out + 1] = weaponId
			end
		end
	end

	table.sort(out, function(a: string, b: string): boolean
		return cosmeticCatalog.displayName(a) < cosmeticCatalog.displayName(b)
	end)

	_weapons = out
	return out
end

local function wrapColor(def: any): Color3
	local textures = def and def.textures
	if type(textures) == "table" then
		for _, tex in next, textures do
			if type(tex) == "table" and typeof(tex.partColor) == "Color3" then
				return tex.partColor
			end
		end
	end
	return cosmeticCatalog.rarityColor(def and def.rarity)
end

local function sortEntries(out: { CosmeticEntry }): ()
	table.sort(out, function(a: CosmeticEntry, b: CosmeticEntry): boolean
		if a.rarityValue ~= b.rarityValue then
			return a.rarityValue > b.rarityValue
		end
		return a.displayName < b.displayName
	end)
end

local function listSkins(weaponId: string): { CosmeticEntry }
	local out: { CosmeticEntry } = {}
	local def = weaponDef(weaponId)
	local skins = def and def.skins
	if type(skins) ~= "table" then
		return out
	end
	for skinId, skinDef in next, skins do
		if type(skinId) ~= "string" or type(skinDef) ~= "table" or (skinId ~= "base" and isTemp(skinDef)) then
			continue
		end
		local isBase = skinId == "base"
		local rarity = isBase and "Default" or (type(skinDef.rarity) == "string" and skinDef.rarity or "Skin")
		out[#out + 1] = {
			name = skinId,
			displayName = isBase and "Default" or (type(skinDef.name) == "string" and skinDef.name or skinId),
			type = "Skin",
			collection = string.upper(rarity),
			rarity = rarity,
			rarityValue = isBase and -1 or cosmeticCatalog.rarityValue(skinDef.rarity),
			rarityColor = isBase and WHITE or cosmeticCatalog.rarityColor(skinDef.rarity),
			image = type(skinDef.icon) == "string" and skinDef.icon or "",
			color = WHITE,
		}
	end
	table.sort(out, function(a: CosmeticEntry, b: CosmeticEntry): boolean
		if (a.name == "base") ~= (b.name == "base") then
			return a.name == "base"
		end
		if a.rarityValue ~= b.rarityValue then
			return a.rarityValue > b.rarityValue
		end
		return a.displayName < b.displayName
	end)
	return out
end

local function listFromSource(typeName: string, source: any, kind: string?): { CosmeticEntry }
	local out: { CosmeticEntry } = {}
	if type(source) ~= "table" then
		return out
	end
	for id, def in next, source do
		if type(id) ~= "string" or type(def) ~= "table" then
			continue
		end
		if kind ~= nil and def.kind ~= kind then
			continue
		end
		local rarity = type(def.rarity) == "string" and def.rarity or "Common"
		local isWrap = typeName == "Wrap"
		out[#out + 1] = {
			name = id,
			displayName = type(def.name) == "string" and def.name or id,
			type = typeName,
			collection = string.upper(rarity),
			rarity = rarity,
			rarityValue = cosmeticCatalog.rarityValue(rarity),
			rarityColor = cosmeticCatalog.rarityColor(rarity),
			image = (not isWrap and type(def.icon) == "string") and def.icon or "",
			color = isWrap and wrapColor(def) or WHITE,
		}
	end
	sortEntries(out)
	return out
end

function cosmeticCatalog.listByType(typeName: string, weaponId: string?): { CosmeticEntry }
	if typeName == "Skin" then
		if not weaponId then
			return {}
		end
		local cacheKey = "Skin:" .. weaponId
		local cached = _listCache[cacheKey]
		if cached then
			return cached
		end
		local out = listSkins(weaponId)
		_listCache[cacheKey] = out
		return out
	end

	local cached = _listCache[typeName]
	if cached then
		return cached
	end

	local dir = directory()
	local out: { CosmeticEntry }
	if typeName == "Wrap" then
		out = listFromSource("Wrap", dir and dir.Wraps)
	elseif typeName == "Charm" then
		out = listFromSource("Charm", dir and dir.Charms)
	elseif typeName == "Finisher" then
		out = listFromSource("Finisher", dir and dir.Finishers, "finisher")
	elseif typeName == "KillEffect" then
		out = listFromSource("KillEffect", dir and dir.Finishers, "killEffect")
	else
		out = {}
	end

	_listCache[typeName] = out
	return out
end

function cosmeticCatalog.exists(typeName: string, weaponId: string?, name: string): boolean
	for _, entry in next, cosmeticCatalog.listByType(typeName, weaponId) do
		if entry.name == name then
			return true
		end
	end
	return false
end

function cosmeticCatalog.cosmeticDisplay(typeName: string, weaponId: string?, name: string): string
	for _, entry in next, cosmeticCatalog.listByType(typeName, weaponId) do
		if entry.name == name then
			return entry.displayName
		end
	end
	return name
end

return cosmeticCatalog
