local fileExtensions = require("@src/feature/file/modules/fileExtensions")
local fileTypes = require("@src/feature/file/fileTypes")
local strings = require("@share/strings")
local logger = require("@share/logger")

local HttpService = game:GetService("HttpService")

local fileLoader = {}

function fileLoader.load(fileData: any, filePath: string): (fileTypes.fileType, any?)
	local fileType = fileExtensions[fileExtensions.getExtensionFromPath(filePath)]

	if fileType == "image" or fileType == "sound" then
		return fileType, fileLoader.loadGeneric(fileData, filePath)
	elseif fileType == "font" then
		return fileType, fileLoader.loadFont(fileData, filePath)
	elseif fileType == "mesh" then
		return fileType, fileLoader.loadGeneric(fileData, filePath)
	end

	return "unknown", nil
end

function fileLoader.loadFont(fileData: any, filePath: string): ()
	local fileName = strings.randomSafe()
	local fontPath = fileName .. ".font.json"

	writefile(
		fontPath,
		HttpService:JSONEncode({
			["name"] = fileName,
			["faces"] = {
				{
					["name"] = "Regular",
					["weight"] = 100,
					["style"] = "normal",
					["assetId"] = getcustomasset(filePath),
				},
			},
		})
	)

	local font = Font.new(getcustomasset(fontPath), Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	delfile(fontPath)

	return font
end

function fileLoader.loadGeneric(fileData: any, filePath: string): ()
	return getcustomasset(filePath)
end

return fileLoader
