local fileTypes = require("@src/feature/file/fileTypes")

local fileExtensions = {
	png = "image",
	jpg = "image",
	jpeg = "image",
	gif = "image",
	webp = "image",
	svg = "image",

	mp3 = "sound",
	wav = "sound",
	ogg = "sound",
	ttf = "font",

	mesh = "mesh",
	obj = "mesh",
}

function fileExtensions.getNameFromPath(path: string): string?
	return path:match("([^/]+)%.[^.]+$") or path:match("([^/]+)$") or nil
end

function fileExtensions.getExtensionFromPath(path: string): string?
	local extension = path:match("%.([^./]+)$")

	if not extension then
		return nil
	end

	return extension
end

function fileExtensions.getFullNameFromPath(path: string): string?
	return path:match("([^/]+)$") or nil
end

return fileExtensions
