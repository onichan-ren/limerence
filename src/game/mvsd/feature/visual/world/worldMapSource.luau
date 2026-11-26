local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local ModuleController = require("@game/mvsd/module/ModuleController")

local worldMapSource = {}

local cachedMaps: { [string]: Instance }?

local function getMaps(): { [string]: Instance }
	if cachedMaps then
		return cachedMaps
	end

	local maps = {}
	local database = ModuleController.GetModule("MapDatabase")
	local models = ModuleController.GetModule("MapModelDatabase")
	if type(database) ~= "table" or type(models) ~= "table" then
		return maps
	end

	for key, model in next, models do
		local info = rawget(database, key)
		local name = type(info) == "table" and rawget(info, "Name")
		if type(name) == "string" and typeof(model) == "Instance" then
			maps[name] = model
		end
	end

	cachedMaps = maps
	return maps
end

function worldMapSource.GetAll(): { string }
	local maps = {}
	for name in next, getMaps() do
		table.insert(maps, name)
	end
	table.sort(maps)
	return maps
end

function worldMapSource.GetCurrent(): string?
	for name, model in next, getMaps() do
		if model.Parent == Workspace then
			return name
		end
	end
	return nil
end

function worldMapSource.GetCurrentModel(): Instance?
	for _, model in next, getMaps() do
		if model.Parent == Workspace then
			return model
		end
	end
	return nil
end

function worldMapSource.Changed(callback: (map: string?) -> ()): () -> ()
	local connections: { RBXScriptConnection } = {}

	for _, model in next, getMaps() do
		table.insert(
			connections,
			model:GetPropertyChangedSignal("Parent"):Connect(function()
				callback(worldMapSource.GetCurrent())
			end)
		)
	end

	return function()
		for _, connection in next, connections do
			connection:Disconnect()
		end
	end
end

return worldMapSource
