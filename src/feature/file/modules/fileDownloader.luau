local logger = require("@share/logger").new("fileDownloader")

local fileDownloader = {}

function fileDownloader.download(url: string, path: string): any?
	if isfile(path) then
		return true
	end

	local data = game:HttpGet(url)
	if not data or #data == 0 then
		logger:error(`failed to download file from {url}`)
		return nil
	end
	writefile(path, data)
	return data
end

export type fileDownloader = typeof(fileDownloader)

return fileDownloader
