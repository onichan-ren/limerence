local TYPE_FLAGS = {
	REGTYPE = "0",
	AREGTYPE = "\0",
	LNKTYPE = "1",
	SYMTYPE = "2",
	CHRTYPE = "3",
	BLKTYPE = "4",
	DIRTYPE = "5",
	FIFOTYPE = "6",
	CONTTYPE = "7",
	XHDTYPE = "x",
	XGLTYPE = "g",
}

local POSIX_HEADER_SIZES = {
	name = 100,
	mode = 8,
	uid = 8,
	gid = 8,
	size = 12,
	mtime = 12,
	chksum = 8,
	typeflag = 1,
	linkname = 100,
	magic = 6,
	version = 2,
	uname = 32,
	gname = 32,
	devmajor = 8,
	devminor = 8,
	prefix = 155,
	reserved = 12,
}

local POSIX_HEADER_OFFSET = {
	name = 0,
	mode = 100,
	uid = 108,
	gid = 116,
	size = 124,
	mtime = 136,
	chksum = 148,
	typeflag = 156,
	linkname = 157,
	magic = 257,
	version = 263,
	uname = 265,
	gname = 297,
	devmajor = 329,
	devminor = 337,
	prefix = 345,
}

local PADDING = 512
local GNU_HEADER = "ustar "
local PAX_HEADER = "ustar\x00"

export type Data = {
	name: string,
	content: string?,
	size: number?,
	typeFlag: string,
}

local TarReader = {}
TarReader.__index = TarReader

function TarReader.new(content: buffer)
	local self = setmetatable({}, TarReader)
	self.content = content
	self.currentOffset = 0

	if not self:isValid() then
		error("Not a valid tar file!")
	end

	return self
end

-- this is something
function TarReader.hasNext(self): boolean
	return buffer.readstring(self.content, self.currentOffset, PADDING):find("[^%z]") ~= nil
end

function TarReader.next(self, nextFileName: string?): Data?
	local function hasDataAfterFirstNull(str)
		local pos = str:find("%z")
		if not pos then
			return false
		end

		return str:sub(pos + 1):find("[^%z]") ~= nil
	end

	local currentOffset = self.currentOffset
	local content = self.content

	local fileName = nextFileName
		or buffer.readstring(content, currentOffset + POSIX_HEADER_OFFSET.name, POSIX_HEADER_SIZES.name)
	local prefix = buffer.readstring(content, currentOffset + POSIX_HEADER_OFFSET.prefix, POSIX_HEADER_SIZES.prefix)

	if hasDataAfterFirstNull(fileName) then
		error("Unexpected null byte in file name")
	end

	fileName = fileName:gsub("%z", "")

	if prefix:find("[^%z]") then
		if hasDataAfterFirstNull(prefix) then
			error("Unexpected null byte in prefix")
		end

		fileName = prefix:gsub("%z", "") .. "/" .. fileName
	end

	local fileSize = buffer.readstring(content, currentOffset + POSIX_HEADER_OFFSET.size, POSIX_HEADER_SIZES.size)
	local typeFlag =
		buffer.readstring(content, currentOffset + POSIX_HEADER_OFFSET.typeflag, POSIX_HEADER_SIZES.typeflag)

	fileSize = tonumber(fileSize:match("^[^%z ]+") or "0", 8) or 0
	local filePadding = (PADDING - (fileSize % PADDING)) % PADDING
	local fileContent = buffer.readstring(content, currentOffset + PADDING, fileSize)

	self.currentOffset += PADDING + fileSize + filePadding

	if typeFlag == "L" then
		return self:next(fileContent)
	end

	local data: Data = {
		name = fileName,
		typeFlag = typeFlag,
	}

	if typeFlag == TYPE_FLAGS.REGTYPE or typeFlag == TYPE_FLAGS.AREGTYPE then
		data.content = fileContent
		data.size = fileSize
	end

	return data
end

function TarReader.isValid(self): boolean
	local content = self.content

	if buffer.len(content) < POSIX_HEADER_OFFSET.magic + POSIX_HEADER_SIZES.magic then
		return false
	end

	local str = buffer.readstring(content, POSIX_HEADER_OFFSET.magic, POSIX_HEADER_SIZES.magic)
	return str == GNU_HEADER or str == PAX_HEADER
end

return {
	read = function(file: buffer)
		return TarReader.new(file)
	end,
	typeFlags = TYPE_FLAGS,
}
