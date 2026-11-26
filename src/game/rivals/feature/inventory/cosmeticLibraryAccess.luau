local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local logger = require("@share/logger").new("cosmeticLibraryAccess")
local rankCharms = require("@game/rivals/feature/inventory/rankCharms")

export type CosmeticEntry = {
	name: string,
	displayName: string,
	type: string,
	rarity: string,
	rarityValue: number,
	rarityColor: Color3,
	image: string,
	imageScale: number,
	weapon: string?,
	hidden: boolean,
	description: string?,
	isRankCharm: boolean?,
	isArchnemesis: boolean?,
	isCustom: boolean?,
	customId: string?,
}

export type CosmeticTypeEntry = {
	name: string,
	value: number,
	image: string?,
	isWeaponCosmetic: boolean,
	notCosmetic: boolean,
}

local cosmeticLibraryAccess = {
	_library = nil :: any,
	_itemLibrary = nil :: any,
	_replicatedClass = nil :: any,
	_skinnedWeapons = nil :: { [string]: boolean }?,
}

local requireModule = LPH_NO_VIRTUALIZE(function(parent: Instance?, name: string): any?
	if not parent then
		return nil
	end
	local mod = parent:FindFirstChild(name)
	if not mod then
		return nil
	end
	setthreadidentity(2)
	local value = require(mod)
	setthreadidentity(8)
	if type(value) ~= "table" then
		return nil
	end
	return value
end)

local loadLibrary = LPH_NO_VIRTUALIZE(function(): any?
	if cosmeticLibraryAccess._library then
		return cosmeticLibraryAccess._library
	end
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local lib = requireModule(modules, "CosmeticLibrary")
	if not lib then
		logger:warn("CosmeticLibrary not found")
		return nil
	end
	cosmeticLibraryAccess._library = lib
	return lib
end)

local loadItemLibrary = LPH_NO_VIRTUALIZE(function(): any?
	if cosmeticLibraryAccess._itemLibrary then
		return cosmeticLibraryAccess._itemLibrary
	end
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local lib = requireModule(modules, "ItemLibrary")
	if not lib then
		logger:warn("ItemLibrary not found")
		return nil
	end
	cosmeticLibraryAccess._itemLibrary = lib
	return lib
end)

function cosmeticLibraryAccess.getLibrary(): any?
	return loadLibrary()
end

function cosmeticLibraryAccess.getItemLibrary(): any?
	return loadItemLibrary()
end

function cosmeticLibraryAccess.getReplicatedClass(): any?
	if cosmeticLibraryAccess._replicatedClass then
		return cosmeticLibraryAccess._replicatedClass
	end
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local cls = requireModule(modules, "ReplicatedClass")
	if not cls then
		logger:warn("ReplicatedClass not found")
		return nil
	end
	cosmeticLibraryAccess._replicatedClass = cls
	return cls
end

function cosmeticLibraryAccess.runElevated(fn: () -> ()): ()
	setthreadidentity(8)
	fn()
	setthreadidentity(8)
end

function cosmeticLibraryAccess.ensureCustomRarity(lib: any): ()
	if type(lib.Rarities) ~= "table" then
		return
	end
	if lib.Rarities.Custom == nil then
		lib.Rarities.Custom = {
			Value = 99,
			Color = Color3.fromRGB(150, 90, 255),
		}
	end
end

function cosmeticLibraryAccess.getTypes(): { CosmeticTypeEntry }
	local lib = loadLibrary()
	if not lib or type(lib.Types) ~= "table" then
		return {}
	end
	local out: { CosmeticTypeEntry } = {}
	for name, info in next, lib.Types do
		if type(info) == "table" and not info.NotCosmetic then
			out[#out + 1] = {
				name = name,
				value = type(info.Value) == "number" and info.Value or 0,
				image = type(info.Image) == "string" and info.Image or nil,
				isWeaponCosmetic = info.IsWeaponCosmetic == true,
				notCosmetic = info.NotCosmetic == true,
			}
		end
	end
	table.sort(
		out,
		LPH_NO_VIRTUALIZE(function(a, b)
			return a.value < b.value
		end)
	)
	return out
end

local buildEntry = LPH_NO_VIRTUALIZE(function(name: string, info: any): CosmeticEntry?
	if type(info) ~= "table" then
		return nil
	end
	local lib = loadLibrary()
	local rarity = type(info.Rarity) == "string" and info.Rarity or "None"
	local rarityInfo = lib and lib.Rarities and lib.Rarities[rarity]
	local customId = type(info.__customId) == "string" and info.__customId or nil
	return {
		name = name,
		displayName = type(info.__customName) == "string" and info.__customName or name,
		type = type(info.Type) == "string" and info.Type or "Skin",
		rarity = rarity,
		rarityValue = rarityInfo and type(rarityInfo.Value) == "number" and rarityInfo.Value or 0,
		rarityColor = rarityInfo and typeof(rarityInfo.Color) == "Color3" and rarityInfo.Color or Color3.new(1, 1, 1),
		image = type(info.Image) == "string" and info.Image or "",
		imageScale = type(info.ImageScale) == "number" and info.ImageScale or 1,
		weapon = type(info.ItemName) == "string" and info.ItemName or nil,
		hidden = info.Hidden == true,
		description = type(info.Description) == "string" and info.Description or nil,
		isCustom = customId ~= nil,
		customId = customId,
	}
end)

cosmeticLibraryAccess.buildEntry = buildEntry

function cosmeticLibraryAccess.getCosmetic(name: string): CosmeticEntry?
	local lib = loadLibrary()
	if not lib or type(lib.Cosmetics) ~= "table" then
		return nil
	end
	return buildEntry(name, lib.Cosmetics[name])
end

function cosmeticLibraryAccess.listByType(typeName: string, weaponName: string?): { CosmeticEntry }
	local lib = loadLibrary()
	if not lib or type(lib.Cosmetics) ~= "table" then
		return {}
	end
	local out: { CosmeticEntry } = {}
	for name, info in next, lib.Cosmetics do
		if type(info) ~= "table" or info.Type ~= typeName or info.Hidden then
			continue
		end
		if weaponName and type(info.ItemName) == "string" and info.ItemName ~= weaponName then
			continue
		end
		local entry = buildEntry(name, info)
		if entry then
			out[#out + 1] = entry
		end
	end
	table.sort(
		out,
		LPH_NO_VIRTUALIZE(function(a, b)
			if a.rarityValue ~= b.rarityValue then
				return a.rarityValue > b.rarityValue
			end
			return a.name < b.name
		end)
	)
	if typeName == "Charm" then
		for _, entry in next, rankCharms.listEntries() do
			out[#out + 1] = entry
		end
	end
	return out
end

local buildSkinnedWeapons = LPH_NO_VIRTUALIZE(function(): { [string]: boolean }?
	if cosmeticLibraryAccess._skinnedWeapons then
		return cosmeticLibraryAccess._skinnedWeapons
	end
	local lib = loadLibrary()
	if not lib or type(lib.Cosmetics) ~= "table" then
		return nil
	end
	local out: { [string]: boolean } = {}
	for _, info in next, lib.Cosmetics do
		if type(info) == "table" and info.Type == "Skin" and not info.Hidden and type(info.ItemName) == "string" then
			out[info.ItemName] = true
		end
	end
	cosmeticLibraryAccess._skinnedWeapons = out
	return out
end)

function cosmeticLibraryAccess.hasSkins(weaponName: string): boolean
	local skinned = buildSkinnedWeapons()
	return skinned ~= nil and skinned[weaponName] == true
end

function cosmeticLibraryAccess.getWeapons(): { string }
	local items = loadItemLibrary()
	if not items or type(items.Items) ~= "table" then
		return {}
	end
	local skinned = buildSkinnedWeapons()
	if not skinned then
		return {}
	end
	local out: { string } = {}
	for name, info in next, items.Items do
		if type(name) ~= "string" or type(info) ~= "table" or not skinned[name] then
			continue
		end
		out[#out + 1] = name
	end
	table.sort(out)
	return out
end

function cosmeticLibraryAccess.viewModelExists(name: string): boolean
	local items = loadItemLibrary()
	if not items or type(items.ViewModels) ~= "table" then
		return false
	end
	return type(items.ViewModels[name]) == "table"
end

function cosmeticLibraryAccess.getTypeImage(typeName: string): string?
	local lib = loadLibrary()
	if not lib or type(lib.Types) ~= "table" then
		return nil
	end
	local info = lib.Types[typeName]
	if type(info) ~= "table" then
		return nil
	end
	if type(info.Image) == "string" and info.Image ~= "" then
		return info.Image
	end
	return nil
end

function cosmeticLibraryAccess.getWrapColor(cosmeticName: string): Color3?
	local lib = loadLibrary()
	if not lib or type(lib.Cosmetics) ~= "table" then
		return nil
	end
	local info = lib.Cosmetics[cosmeticName]
	if type(info) ~= "table" or info.Type ~= "Wrap" then
		return nil
	end
	local groups = info.WrapGroups
	if type(groups) ~= "table" then
		return nil
	end
	for _, g in next, groups do
		if typeof(g) == "table" and typeof(g.Color) == "Color3" then
			return g.Color
		end
	end
	return nil
end

function cosmeticLibraryAccess.getWrapGroupCount(cosmeticName: string): number
	local lib = loadLibrary()
	if not lib or type(lib.Cosmetics) ~= "table" then
		return 0
	end
	local info = lib.Cosmetics[cosmeticName]
	if type(info) ~= "table" or info.Type ~= "Wrap" then
		return 0
	end
	local groups = info.WrapGroups
	if type(groups) ~= "table" then
		return 0
	end
	return #groups
end

function cosmeticLibraryAccess.getWeaponSkinImage(weaponName: string, skinName: string?): string?
	local items = loadItemLibrary()
	if not items then
		return nil
	end
	local viewModels = items.ViewModels
	if type(viewModels) ~= "table" then
		return nil
	end
	local key = (type(skinName) == "string" and skinName ~= "" and skinName ~= "RANDOM_COSMETIC") and skinName
		or weaponName
	local entry = viewModels[key]
	if type(entry) ~= "table" and key ~= weaponName then
		entry = viewModels[weaponName]
	end
	if type(entry) ~= "table" then
		return nil
	end
	if type(entry.ImageHighResolution) == "string" and entry.ImageHighResolution ~= "" then
		return entry.ImageHighResolution
	end
	if type(entry.Image) == "string" and entry.Image ~= "" then
		return entry.Image
	end
	return nil
end

function cosmeticLibraryAccess.getWeaponImage(weaponName: string): string?
	return cosmeticLibraryAccess.getWeaponSkinImage(weaponName, nil)
end

return cosmeticLibraryAccess
