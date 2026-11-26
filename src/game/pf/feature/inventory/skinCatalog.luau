local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local ModuleController = require("@game/pf/module/ModuleController")

export type SkinEntry = {
	name: string,
	displayName: string,
	collection: string,
}

export type SkinPreview = {
	image: string,
	color: Color3,
}

export type FolderEntry = {
	name: string,
	count: number,
	sample: string,
}

export type CamoSlot = {
	label: string,
	tag: string,
}

local skinCatalog = {}

local _database: { [string]: any }? = nil
local _skins: { SkinEntry }? = nil
local _folders: { FolderEntry }? = nil
local _skinCollection: { [string]: string }? = nil
local _weapons: { string }? = nil
local _previewCache: { [string]: SkinPreview | false } = {}

local function database(): { [string]: any }
	if _database then
		return _database
	end
	local content = ReplicatedStorage:FindFirstChild("Content")
	local production = content and content:FindFirstChild("ProductionContent")
	local module = production and production:FindFirstChild("CamoDatabase")
	if not module or not module:IsA("ModuleScript") then
		_database = {}
		return _database
	end
	local old = getthreadidentity()
	setthreadidentity(2)
	local data = require(module)
	setthreadidentity(old)
	_database = type(data) == "table" and data or {}
	return _database
end

function skinCatalog.listSkins(): { SkinEntry }
	if _skins then
		return _skins
	end

	local out: { SkinEntry } = {}
	for name, entry in next, database() do
		if type(name) == "string" and type(entry) == "table" and type(entry.Case) == "string" and entry.Case:find("%S") then
			out[#out + 1] = {
				name = name,
				displayName = type(entry.DisplayName) == "string" and entry.DisplayName or name,
				collection = entry.Case,
			}
		end
	end

	table.sort(out, function(a: SkinEntry, b: SkinEntry): boolean
		if a.collection ~= b.collection then
			return a.collection < b.collection
		end
		return a.name < b.name
	end)

	_skins = out
	return out
end

function skinCatalog.listFolders(): { FolderEntry }
	if _folders then
		return _folders
	end

	local order: { string } = {}
	local byName: { [string]: FolderEntry } = {}
	for _, entry in next, skinCatalog.listSkins() do
		local folder = byName[entry.collection]
		if not folder then
			folder = { name = entry.collection, count = 0, sample = entry.name }
			byName[entry.collection] = folder
			order[#order + 1] = entry.collection
		end
		folder.count += 1
	end

	table.sort(order)
	local out: { FolderEntry } = {}
	for _, name in next, order do
		out[#out + 1] = byName[name]
	end

	_folders = out
	return out
end

function skinCatalog.collectionOf(name: string): string?
	if not _skinCollection then
		local map: { [string]: string } = {}
		for _, entry in next, skinCatalog.listSkins() do
			map[entry.name] = entry.collection
		end
		_skinCollection = map
	end
	return _skinCollection[name]
end

function skinCatalog.getPreview(name: string): SkinPreview?
	local cached = _previewCache[name]
	if cached ~= nil then
		return cached or nil
	end

	local preview: SkinPreview | false = false
	local entry = database()[name]
	if type(entry) == "table" and entry.TextureId then
		preview = {
			image = "rbxassetid://" .. tostring(entry.TextureId),
			color = typeof(entry.ImageColor) == "Color3" and entry.ImageColor or Color3.new(1, 1, 1),
		}
	end

	_previewCache[name] = preview
	return preview or nil
end

function skinCatalog.getWeapons(): { string }
	if _weapons then
		return _weapons
	end

	local out: { string } = {}
	local content = ModuleController.GetModule("ContentInterface")
	if content then
		local getAll = rawget(content, "getAllWeaponsList")
		local getData = rawget(content, "getWeaponData")
		if type(getAll) == "function" and type(getData) == "function" then
			local old = getthreadidentity()
			setthreadidentity(8)
			local list = getAll()
			if type(list) == "table" then
				for _, name in next, list do
					if type(name) == "string" then
						local data = getData(name)
						local kind = type(data) == "table" and data.type or nil
						if kind ~= "KNIFE" and kind ~= "Grenade" then
							out[#out + 1] = name
						end
					end
				end
			end
			setthreadidentity(old)
		end
	end

	table.sort(out)
	_weapons = out
	return out
end

function skinCatalog.getEquippedWeapons(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local dataInterface = ModuleController.GetModule("PlayerDataClientInterface")
	local loadout = ModuleController.GetModule("ActiveLoadoutUtils")
	local getData = dataInterface and rawget(dataInterface, "getPlayerData")
	local getActive = loadout and rawget(loadout, "getActiveLoadoutData")
	if type(getData) ~= "function" or type(getActive) ~= "function" then
		return out
	end

	local old = getthreadidentity()
	setthreadidentity(8)
	local playerData = getData()
	local slots = playerData and getActive(playerData) or nil
	setthreadidentity(old)

	if type(slots) ~= "table" then
		return out
	end
	for _, entry in next, slots do
		if type(entry) == "table" and type(entry.Name) == "string" then
			out[entry.Name] = true
		end
	end
	return out
end

function skinCatalog.displayName(name: string): string
	return name
end

function skinCatalog.isCustomizable(name: string): boolean
	local entry = database()[name]
	return type(entry) == "table" and entry.Customizable == true
end

function skinCatalog.excludedProperties(name: string): { string }?
	local entry = database()[name]
	local excluded = type(entry) == "table" and entry.excludedProperties or nil
	return type(excluded) == "table" and excluded or nil
end

local _slotCache: { [string]: { CamoSlot } } = {}

function skinCatalog.getCamoSlots(weaponName: string): { CamoSlot }
	local cached = _slotCache[weaponName]
	if cached then
		return cached
	end

	local out: { CamoSlot } = {}
	local content = ModuleController.GetModule("ContentInterface")
	local getSlots = content and rawget(content, "getCamoSlots")
	if type(getSlots) == "function" then
		local old = getthreadidentity()
		setthreadidentity(8)
		local slots = getSlots(weaponName)
		setthreadidentity(old)
		if type(slots) == "table" then
			for label, tag in next, slots do
				if type(label) == "string" and type(tag) == "string" then
					out[#out + 1] = { label = label, tag = tag }
				end
			end
		end
	end

	table.sort(out, function(a: CamoSlot, b: CamoSlot): boolean
		return a.label < b.label
	end)

	_slotCache[weaponName] = out
	return out
end

return skinCatalog
