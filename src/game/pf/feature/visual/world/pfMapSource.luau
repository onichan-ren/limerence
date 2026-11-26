local ModuleController = require("@game/pf/module/ModuleController")

local pfMapSource = {}

function pfMapSource.GetCurrent(): string?
	local round = ModuleController.GetModule("RoundSystemClientInterface")
	if not round then
		return nil
	end
	local name = round.getMapName()
	if type(name) == "string" and name ~= "" and name ~= "N/A" then
		return name
	end
	return nil
end

function pfMapSource.GetAll(): { string }
	local maps = {}
	local content = ModuleController.GetModule("ContentInterface")
	if content then
		local database = content.getCurrentMapDatabase()
		if type(database) == "table" then
			for _, entry in next, database do
				if type(entry) == "table" and type(entry.Name) == "string" then
					table.insert(maps, entry.Name)
				end
			end
		end
	end
	table.sort(maps)
	return maps
end

function pfMapSource.Changed(callback: (map: string?) -> ()): () -> ()
	local events = ModuleController.GetModule("RoundSystemClientEvents")
	if not events or not events.onMatchChanged or type(events) ~= "table" then
		return function(): () end
	end
	local connection = events.onMatchChanged:connect(function(): ()
		callback(pfMapSource.GetCurrent())
	end)
	return function(): ()
		if connection then
			connection:disconnect()
		end
	end
end

return pfMapSource
