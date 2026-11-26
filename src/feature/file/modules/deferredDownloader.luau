local fileDownloader = require("@feature/file/modules/fileDownloader")
local fileExtensions = require("@feature/file/modules/fileExtensions")
local fileLoader = require("@feature/file/modules/fileLoader")
local fileState = require("@feature/file/fileState")
local NotifyController = require("@ui/hud/notify/NotifyController")
local logger = require("@share/logger").new("deferredDownloader")

export type DeferredFile = {
	remote: string,
	name: string,
}

export type DeferredCollection = {
	id: string,
	title: string,
	icon: string?,
	urlPrefix: string,
	folder: string,
	files: { DeferredFile },
	autoLoad: boolean?,
	onComplete: ((loaded: number, failed: number) -> ())?,
}

local deferredDownloader = {}

local function ensureFolder(folder: string): ()
	if isfolder and not isfolder(folder) then
		makefolder(folder)
	end
end

function deferredDownloader.queue(collection: DeferredCollection): ()
	ensureFolder(collection.folder)

	local pending: { DeferredFile } = {}
	for _, entry in next, collection.files do
		local path = `{collection.folder}/{entry.name}`
		if not isfile(path) then
			table.insert(pending, entry)
		end
	end

	local total = #pending
	if total == 0 then
		if collection.onComplete then
			collection.onComplete(0, 0)
		end
		return
	end

	local notifId = NotifyController.Push({
		title = collection.title,
		subtext = `0 / {total}`,
		icon = collection.icon,
		showProgress = true,
		progress = 0,
	})

	task.spawn(function(): ()
		local loaded = 0
		local failed = 0

		for index, entry in next, pending do
			local path = `{collection.folder}/{entry.name}`
			local url = collection.urlPrefix .. entry.remote

			local ok, fileData = pcall(fileDownloader.download, url, path)
			if not ok or fileData == nil then
				failed += 1
				logger:warn(`failed to download {url}`)
			else
				if collection.autoLoad ~= false then
					local fileType = fileExtensions[fileExtensions.getExtensionFromPath(path) or ""]
					if fileType and fileType ~= "unknown" then
						local _, data = fileLoader.load(fileData, path)
						local fileName = fileExtensions.getNameFromPath(path)
						if data and fileName then
							fileState[fileType][fileName] = data
						end
					end
				end
				loaded += 1
			end

			NotifyController.Update(notifId, {
				progress = index / total,
				subtext = `{index} / {total}`,
			})
		end

		NotifyController.Update(notifId, {
			title = collection.title,
			subtext = failed > 0 and `Done ({failed} failed)` or "Done",
			progress = 1,
		})

		task.delay(2, function(): ()
			NotifyController.Dismiss(notifId)
		end)

		if collection.onComplete then
			collection.onComplete(loaded, failed)
		end
	end)
end

return deferredDownloader
