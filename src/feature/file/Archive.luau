local Archive = {}
Archive.__index = Archive

export type Files = { [string]: string | Files }

local strings = require("@share/strings")

local MOUNT_PATH = "limerence.biz/cache/mounts"

export type Archive = typeof(setmetatable(
	{} :: {
		id: string,
		path: string,
	},
	Archive
))

-- just to be safe
local function getIdSafe(length: number): string
	local id = strings.randomSafe(length)
	local path = MOUNT_PATH .. "/" .. id

	if isfolder(path) or isfile(path) then
		return getIdSafe(length)
	end

	return id
end

function Archive.new(files: Files): Archive
	local self = setmetatable({}, Archive) :: Archive
	local id = getIdSafe(12)

	self.id = id
	self.path = MOUNT_PATH .. "/" .. id

	if not isfolder(self.path) then
		makefolder(self.path)
	end

	local visited = {}

	local function mount(path: string, allFiles: Files)
		if visited[allFiles] then
			error(("Cycle detected while mounting '%s'"):format(path))
		end

		visited[allFiles] = true

		for name, file in allFiles do
			local newPath = path .. "/" .. name

			if type(file) == "table" then
				makefolder(newPath)
				mount(newPath, file)
			else
				writefile(newPath, file)
			end
		end

		visited[allFiles] = nil
	end

	mount(self.path, files)

	return self
end

function Archive.readFile(self: Archive, path: string): string
	return readfile(self.path .. "/" .. path)
end

function Archive.listFiles(self: Archive, path: string): { string }
	return listfiles(self.path .. "/" .. path)
end

function Archive.isFolder(self: Archive, path: string): boolean
	return isfolder(self.path .. "/" .. path)
end

function Archive.isFile(self: Archive, path: string): boolean
	return isfile(self.path .. "/" .. path)
end

return Archive
