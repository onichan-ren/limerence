local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local ModuleController = require("@game/ar2/module/ModuleController")

local SKINS_FOLDER = "WeaponSkins"

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

local skinLibrary = {}

local _skins: { SkinEntry }? = nil
local _folders: { FolderEntry }? = nil
local _skinCollection: { [string]: string }? = nil
local _weapons: { string }? = nil
local _previewCache: { [string]: SkinPreview | false } = {}
local _skinFolder: Instance? = nil

local function skinFolder(): Instance?
	if _skinFolder and _skinFolder.Parent then
		return _skinFolder
	end
	_skinFolder = ReplicatedStorage:FindFirstChild(SKINS_FOLDER)
	return _skinFolder
end

function skinLibrary.listSkins(): { SkinEntry }
	if _skins then
		return _skins
	end

	local out: { SkinEntry } = {}
	local folder = skinFolder()
	if folder then
		for _, collection in next, folder:GetChildren() do
			for _, desc in next, collection:QueryDescendants("ModuleScript") do
				out[#out + 1] = {
					name = desc.Name,
					displayName = desc.Name,
					collection = collection.Name,
				}
			end
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

function skinLibrary.listFolders(): { FolderEntry }
	if _folders then
		return _folders
	end

	local order: { string } = {}
	local byName: { [string]: FolderEntry } = {}
	for _, entry in next, skinLibrary.listSkins() do
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

function skinLibrary.collectionOf(name: string): string?
	if not _skinCollection then
		local map: { [string]: string } = {}
		for _, entry in next, skinLibrary.listSkins() do
			map[entry.name] = entry.collection
		end
		_skinCollection = map
	end
	return _skinCollection[name]
end

function skinLibrary.getPreview(name: string): SkinPreview?
	local cached = _previewCache[name]
	if cached ~= nil then
		return cached or nil
	end

	local preview: SkinPreview | false = false
	local folder = skinFolder()
	if folder then
		local module = folder:FindFirstChild(name, true)
		if module and module:IsA("ModuleScript") then
			setthreadidentity(2)
			local ok, lib = pcall(require, module)
			setthreadidentity(8)
			if ok and type(lib) == "table" and type(lib.Patterns) == "table" then
				local pattern = lib.Patterns["1"]
				local channel = type(pattern) == "table" and pattern.Channel1 or nil
				if type(channel) == "table" and type(channel[1]) == "string" then
					preview = {
						image = channel[1],
						color = Color3.new(
							tonumber(channel[2]) or 1,
							tonumber(channel[3]) or 1,
							tonumber(channel[4]) or 1
						),
					}
				end
			end
		end
	end

	_previewCache[name] = preview
	return preview or nil
end

function skinLibrary.getWeapons(): { string }
	if _weapons then
		return _weapons
	end

	local out: { string } = {}
	local items = ModuleController.GetItemData()
	if type(items) == "table" then
		for name, config in next, items do
			if type(name) == "string" and type(config) == "table" then
				if config.Type == "Firearm" and config.CanTakeCosmeticSkins then
					out[#out + 1] = name
				end
			end
		end
	end

	table.sort(out)
	_weapons = out
	return out
end

function skinLibrary.displayName(name: string): string
	local items = ModuleController.GetItemData()
	local config = type(items) == "table" and items[name] or nil
	if type(config) == "table" and type(config.DisplayName) == "string" then
		return config.DisplayName
	end
	return name
end

return skinLibrary
