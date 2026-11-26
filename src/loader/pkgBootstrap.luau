local manifest = require("@loader/pkgManifest")

local CACHE_DIR = "limerence.biz/cache"
local CACHE_PATH = `{CACHE_DIR}/packages-v{manifest.version}.luau`
local CHUNK_NAME = "@limerence_pkgs"

local pkgBootstrap = {}

local packages: { [string]: any }? = nil

local function fetchSource(): string
	local response = game:HttpGet(manifest.url)

	if not response or #response == 0 then
		error(`pkgBootstrap: response body is empty)`)
	end

	return response
end

local function readCache(): string?
	if not isfile or not readfile then
		return nil
	end
	if not isfile(CACHE_PATH) then
		return nil
	end
	local contents = readfile(CACHE_PATH)
	if type(contents) ~= "string" or #contents == 0 then
		return nil
	end
	return contents
end

local function ensureFolder(path: string): ()
	if not isfolder or not makefolder then
		return
	end
	local accumulated = ""
	for segment in string.gmatch(path, "[^/]+") do
		accumulated = accumulated == "" and segment or `{accumulated}/{segment}`
		if not isfolder(accumulated) then
			makefolder(accumulated)
		end
	end
end

local function writeCache(source: string): ()
	if not writefile then
		return
	end
	ensureFolder(CACHE_DIR)
	local ok, err = pcall(writefile, CACHE_PATH, source)
	if not ok then
		warn(`pkgBootstrap: writefile failed: {tostring(err)}`)
	end
end

local function cleanupOldCaches(): ()
	if not isfile or not delfile then
		return
	end
	local current = tonumber(manifest.version) or 0
	for v = 1, current - 1 do
		local path = `{CACHE_DIR}/packages-v{v}.luau`
		if isfile(path) then
			pcall(delfile, path)
		end
	end
end

local function load(): ()
	if packages then
		return
	end

	cleanupOldCaches()

	local source = readCache()
	if not source then
		local newSource = fetchSource()
		writeCache(newSource)
		source = newSource
	end

	local chunk, err = loadstring(source :: string, CHUNK_NAME)
	if not chunk then
		error(`pkgBootstrap: loadstring failed: {tostring(err)}`)
	end

	local ok, result = pcall(chunk)
	if not ok then
		error(`pkgBootstrap: package bundle threw on load: {tostring(result)}`)
	end

	if type(result) ~= "table" then
		local globalTable = getgenv().__limerence_pkgs
		if type(globalTable) == "table" then
			result = globalTable
		end
	end

	packages = result
end

function pkgBootstrap.get(name: string): any
	if not packages then
		load()
	end
	local value = (packages :: { [string]: any })[name]
	if value == nil then
		error(`pkgBootstrap: package "{name}" not registered in bundle`)
	end
	return value
end

return pkgBootstrap
