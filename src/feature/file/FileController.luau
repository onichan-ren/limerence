local fileDownloader = require("@src/feature/file/modules/fileDownloader")
local fileExtensions = require("@src/feature/file/modules/fileExtensions")
local fileLoader = require("@src/feature/file/modules/fileLoader")
local deferredDownloader = require("@src/feature/file/modules/deferredDownloader")
local fileConfig = require("@src/feature/file/fileConfig")
local fileState = require("@src/feature/file/fileState")
local fileTypes = require("@src/feature/file/fileTypes")
local NotifyController = require("@src/feature/ui/hud/notify/NotifyController")
local fileReady = require("@src/feature/file/fileReady")
local Charm = require("@pkg/Charm")
local logger = require("@share/logger").new("FileController")

local HttpService = game:GetService("HttpService")

local FileController = {}

local REVISIONS_PATH = "limerence.biz/cache/revisions.json"

type FileEntry = {
	path: string,
	url: string,
	missing: boolean,
}

local collectFiles = LPH_NO_VIRTUALIZE(function(): { FileEntry }
	local entries: { FileEntry } = {}

	local function walk(folder: string?, dir: { [string]: any })
		for key, value in next, dir do
			local path = folder and (folder .. "/" .. key) or key
			local valueType = type(value)
			if valueType == "table" then
				if not isfolder(path) then
					makefolder(path)
				end
				walk(path, value)
			elseif valueType == "string" then
				entries[#entries + 1] = {
					path = path,
					url = fileConfig.url .. value,
					missing = not isfile(path),
				}
			end
		end
	end

	walk(nil, fileConfig.dir)

	return entries
end)

local applyRevisions = LPH_NO_VIRTUALIZE(function(entries: { FileEntry }): ()
	local stored: { [string]: number } = {}
	if isfile(REVISIONS_PATH) then
		stored = HttpService:JSONDecode(readfile(REVISIONS_PATH))
	end

	local changed = false
	for _, entry in next, entries do
		local revision = fileConfig.revisions[entry.path]
		if revision and (stored[entry.path] or 0) < revision then
			if not entry.missing then
				delfile(entry.path)
				entry.missing = true
			end
			stored[entry.path] = revision
			changed = true
		end
	end

	if changed then
		writefile(REVISIONS_PATH, HttpService:JSONEncode(stored))
	end
end)

function FileController.new(): FileController
	local entries = collectFiles()
	applyRevisions(entries)

	local missingTotal = 0
	for _, entry in next, entries do
		if entry.missing then
			missingTotal += 1
		end
	end

	local notifId: string? = nil
	if missingTotal > 0 then
		notifId = NotifyController.Push({
			title = "Downloading assets",
			subtext = `0 / {missingTotal}`,
			showProgress = true,
			progress = 0,
		})
	end

	local missingDone = 0
	for _, entry in next, entries do
		local fileData = fileDownloader.download(entry.url, entry.path)

		local didLoad = FileController.Load(entry.path, fileData)
		if not didLoad then
			logger:warn(`failed to load core file {entry.path}`)
		end

		if notifId and entry.missing then
			missingDone += 1
			NotifyController.Update(notifId, {
				progress = missingDone / missingTotal,
				subtext = `{missingDone} / {missingTotal}`,
			})
		end
	end

	if notifId then
		NotifyController.Update(notifId, {
			title = "Assets downloaded",
			subtext = `{missingTotal} / {missingTotal}`,
			progress = 1,
		})
		local dismissId = notifId
		task.delay(1.5, function(): ()
			NotifyController.Dismiss(dismissId)
		end)
	end

	return FileController
end

function FileController.Load(filePath: string, fileData: any?): boolean
	if not fileData and not isfile(filePath) then
		return false
	end
	local fileType, loadedData = fileLoader.load(fileData or readfile(filePath), filePath)
	if not loadedData then
		logger:log(`no data found for file {filePath}`)
		return false
	end

	local fileName = fileExtensions.getNameFromPath(filePath)
	if not fileName then
		return false
	end

	local bucket = fileState[fileType]
	bucket[fileName] = loadedData

	fileReady(Charm.peek(fileReady) + 1)

	logger:log(`loaded file {filePath} as {fileType}`)
	return true
end

function FileController.Get(fileType: fileTypes.fileType, fileName: string): any?
	local bucket = fileState[fileType]
	if not bucket then
		return nil
	end
	return bucket[fileName]
end

local CACHE_DIR = "limerence.biz/cache"

local function hashString(value: string): string
	local hash = 5381
	for i = 1, #value do
		hash = bit32.band(hash * 33 + string.byte(value, i), 0xFFFFFFFF)
	end
	return string.format("%08x", hash)
end

local function urlExtension(url: string): string
	local pathPart = string.match(url, "^[^?#]+")
	local ext = pathPart and string.match(pathPart, "%.([%w]+)$")
	if ext and fileExtensions[string.lower(ext)] == "image" then
		return string.lower(ext)
	end
	return "png"
end

export type UrlCacheOptions = {
	folder: string?,
	maxFiles: number?,
}

local function touchCacheEntry(dir: string, entryName: string, maxFiles: number): ()
	local indexPath = `{dir}/.index`
	local list: { string } = {}
	if isfile(indexPath) then
		for name in string.gmatch(readfile(indexPath), "[^\n]+") do
			if name ~= entryName then
				list[#list + 1] = name
			end
		end
	end
	list[#list + 1] = entryName
	while #list > maxFiles do
		local oldest = table.remove(list, 1) :: string
		local oldPath = `{dir}/{oldest}`
		if isfile(oldPath) then
			delfile(oldPath)
		end
	end
	writefile(indexPath, table.concat(list, "\n"))
end

function FileController.ResolveUrl(url: string, options: UrlCacheOptions?): string?
	local fileName = `url_{hashString(url)}`
	local cached = FileController.Get("image", fileName)
	if cached then
		return cached
	end
	if isfolder and makefolder and not isfolder(CACHE_DIR) then
		makefolder(CACHE_DIR)
	end
	local dir = CACHE_DIR
	if options and options.folder then
		dir = `{CACHE_DIR}/{options.folder}`
		if not isfolder(dir) then
			makefolder(dir)
		end
	end
	local entryName = `{fileName}.{urlExtension(url)}`
	local path = `{dir}/{entryName}`
	local ok, fileData = pcall(fileDownloader.download, url, path)
	if not ok or fileData == nil then
		logger:warn(`failed to resolve image url {url}`)
		return nil
	end
	if FileController.Load(path, fileData) then
		if options and options.maxFiles then
			touchCacheEntry(dir, entryName, options.maxFiles)
		end
		return FileController.Get("image", fileName)
	end
	return nil
end

function FileController.ResolveFile(value: string): string?
	local fileName = fileExtensions.getNameFromPath(value)
	if fileName then
		local cached = FileController.Get("image", fileName)
		if cached then
			return cached
		end
	end
	if not (isfile and isfile(value)) then
		return nil
	end
	if FileController.Load(value) and fileName then
		local loaded = FileController.Get("image", fileName)
		if loaded then
			return loaded
		end
	end
	if getcustomasset then
		local ok, asset = pcall(getcustomasset, value)
		if ok and type(asset) == "string" then
			return asset
		end
	end
	return nil
end

function FileController.ResolveImage(value: string?, options: UrlCacheOptions?): string?
	if type(value) ~= "string" or value == "" then
		return nil
	end
	if string.find(value, "^rbx") then
		return value
	end
	if string.find(value, "^%d+$") then
		return `rbxassetid://{value}`
	end
	if string.find(value, "^https?://") then
		return FileController.ResolveUrl(value, options)
	end
	return FileController.ResolveFile(value)
end

function FileController.QueueDownload(collection: deferredDownloader.DeferredCollection): ()
	deferredDownloader.queue(collection)
end

function FileController.Destroy(): ()
	return
end

export type FileController = typeof(FileController)

return FileController
