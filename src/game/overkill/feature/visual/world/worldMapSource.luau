local ModuleController = require("@game/overkill/module/ModuleController")
local NetworkController = require("@game/overkill/network/NetworkController")

local CHANGE_PACKETS = {
	"map_selected",
	"joined_range",
	"left_duel",
	"ended",
	"active_duels",
}

local worldMapSource = {}

local function getDirectory(): any?
	return ModuleController.GetModule("maps")
end

function worldMapSource.GetAll(): { string }
	local maps = {}
	local directory = getDirectory()
	if directory and type(directory.all) == "table" then
		for _, entry in next, directory.all do
			if type(entry) == "table" and type(entry.name) == "string" then
				table.insert(maps, entry.name)
			end
		end
	end
	table.sort(maps)
	return maps
end

function worldMapSource.GetCurrent(): string?
	local gameplayHandler = ModuleController.GetModule("gameplayHandler")
	if not gameplayHandler then
		return nil
	end

	local duel = gameplayHandler:GetLocalDuel()
	local mapID = duel and duel.mapID
	if type(mapID) ~= "string" or mapID == "" then
		return nil
	end

	local directory = getDirectory()
	local entry = directory and type(directory.all) == "table" and directory.all[mapID]
	if entry and type(entry.name) == "string" then
		return entry.name
	end
	return mapID
end

function worldMapSource.Changed(callback: (map: string?) -> ()): () -> ()
	local unhooks: { () -> () } = {}

	local function fire(): ()
		task.defer(function(): ()
			callback(worldMapSource.GetCurrent())
		end)
	end

	for _, name in next, CHANGE_PACKETS do
		table.insert(unhooks, NetworkController.HookInbound(name, fire))
	end

	return function(): ()
		for _, unhook in next, unhooks do
			unhook()
		end
		table.clear(unhooks)
	end
end

return worldMapSource
