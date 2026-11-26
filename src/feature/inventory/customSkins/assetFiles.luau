local fileExtensions = require("@feature/file/modules/fileExtensions")

export type AssetEntry = {
	name: string,
	fullName: string,
	path: string,
}

export type AssetLibrary = {
	dir: string,
	ensureDir: () -> (),
	path: (fullName: string) -> string,
	list: (kind: string) -> { AssetEntry },
	exists: (fullName: string) -> boolean,
	import: (source: string) -> (string?, string?),
	resolve: (source: string) -> string?,
}

local assetFiles = {}

local function trim(value: string): string
	return value:match("^%s*(.-)%s*$") or ""
end

local function sanitizeName(value: string): string
	local cleaned = value:gsub("[<>:\"/\\|?*%s]", "_")
	if #cleaned > 48 then
		cleaned = cleaned:sub(-48)
	end
	return cleaned
end

function assetFiles.makeLibrary(dir: string): AssetLibrary
	local library = {} :: AssetLibrary
	library.dir = dir

	function library.ensureDir(): ()
		if isfolder and makefolder and not isfolder(dir) then
			makefolder(dir)
		end
	end

	function library.path(fullName: string): string
		return `{dir}/{fullName}`
	end

	function library.list(kind: string): { AssetEntry }
		library.ensureDir()
		local out: { AssetEntry } = {}
		if not listfiles or not isfolder or not isfolder(dir) then
			return out
		end
		local results = listfiles(dir)
		if type(results) ~= "table" then
			return out
		end
		for _, raw in next, results do
			local full = ((raw :: string):gsub("\\", "/"))
			local fullName = fileExtensions.getFullNameFromPath(full)
			local name = fileExtensions.getNameFromPath(full)
			local ext = fileExtensions.getExtensionFromPath(full)
			if not name or not fullName or not ext then
				continue
			end
			if fileExtensions[string.lower(ext)] ~= kind then
				continue
			end
			out[#out + 1] = {
				name = name,
				fullName = fullName,
				path = library.path(fullName),
			}
		end
		table.sort(out, function(a, b)
			return a.name < b.name
		end)
		return out
	end

	function library.exists(fullName: string): boolean
		if type(fullName) ~= "string" or fullName == "" then
			return false
		end
		return isfile ~= nil and isfile(library.path(fullName)) == true
	end

	local function uniqueName(fullName: string): string
		if not library.exists(fullName) then
			return fullName
		end
		local base, ext = fullName:match("^(.*)%.([^%.]+)$")
		if not base or not ext then
			return fullName
		end
		for i = 2, 99 do
			local candidate = `{base}_{i}.{ext}`
			if not library.exists(candidate) then
				return candidate
			end
		end
		return fullName
	end

	function library.import(source: string): (string?, string?)
		local trimmed = trim(source)
		if trimmed == "" then
			return nil, "Enter a link or file path"
		end
		library.ensureDir()

		local data: string? = nil
		local rawName: string? = nil

		if trimmed:match("^https?://") then
			local urlPath = trimmed:gsub("[?#].*$", "")
			rawName = urlPath:match("([^/]+)$")
			local ok, body = pcall(function(): string
				return game:HttpGet(trimmed)
			end)
			if not ok or type(body) ~= "string" or #body == 0 then
				return nil, "Download failed"
			end
			data = body
		elseif isfile and isfile(trimmed) then
			local normalized = trimmed:gsub("\\", "/")
			rawName = normalized:match("([^/]+)$")
			data = readfile(trimmed)
			if type(data) ~= "string" or #data == 0 then
				return nil, "Could not read file"
			end
		else
			return nil, "Not a link or existing file"
		end

		if not rawName or rawName == "" then
			return nil, "Could not resolve a file name"
		end
		local ext = rawName:match("%.([^%.]+)$")
		local kind = ext and fileExtensions[string.lower(ext)]
		if kind ~= "image" and kind ~= "mesh" then
			return nil, "Unsupported file type"
		end

		local fullName = uniqueName(sanitizeName(rawName))
		writefile(library.path(fullName), data :: string)
		return fullName, nil
	end

	function library.resolve(source: string): string?
		if type(source) ~= "string" or source == "" then
			return nil
		end
		if source:match("^%d+$") then
			return `rbxassetid://{source}`
		end
		if source:match("^rbxassetid://%d+$") then
			return source
		end
		if library.exists(source) then
			local asset = getcustomasset(library.path(source))
			if type(asset) == "string" then
				return asset
			end
		end
		return nil
	end

	return library
end

return assetFiles
