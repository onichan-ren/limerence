local logger = require("@share/logger").new("fileDownloader")

local fileDownloader = {}

function fileDownloader.download(url: string, path: string): any?
	if isfile(path) then
		return true
	end

	local ok, data = pcall(game.HttpGet, game, url)
	if not ok or type(data) ~= "string" or #data == 0 or data == "404: Not Found" then
		logger:error(`failed to download file from {url}`)
		return nil
	end
	writefile(path, data)
	return data
end

export type fileDownloader = typeof(fileDownloader)

return fileDownloader
