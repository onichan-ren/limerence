local Players = cloneref(game:GetService("Players")) :: Players
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local LocalPlayer = Players.LocalPlayer

local worldMapSource = {}

function worldMapSource.GetAll(): { string }
	local maps = {}
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local module = modules and modules:FindFirstChild("DuelLibrary")
	if module then
		local library = require(module :: ModuleScript)
		if type(library) == "table" and type(library.MapOrder) == "table" then
			for _, name in next, library.MapOrder do
				if type(name) == "string" then
					table.insert(maps, name)
				end
			end
			table.sort(maps)
		end
	end
	return maps
end

local function getDuelController(): any?
	local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local controllers = scripts and scripts:FindFirstChild("Controllers")
	local module = controllers and controllers:FindFirstChild("DuelController")
	if not module then
		return nil
	end
	return require(module :: ModuleScript)
end

local function readMap(duel: any): string?
	if not duel or type(duel.Get) ~= "function" then
		return nil
	end
	local map = duel:Get("MapName")
	if type(map) == "string" and map ~= "" then
		return map
	end
	return nil
end

function worldMapSource.GetCurrent(): string?
	local duelController = getDuelController()
	if not duelController or type(duelController.GetDuel) ~= "function" then
		return nil
	end
	return readMap(duelController:GetDuel(LocalPlayer))
end

function worldMapSource.Changed(callback: (map: string?) -> ()): () -> ()
	local duelController = getDuelController()
	if not duelController or type(duelController.Objects) ~= "table" then
		return function() end
	end

	local connections: { RBXScriptConnection } = {}

	local function fire(): ()
		callback(worldMapSource.GetCurrent())
	end

	local function bind(duel: any): ()
		table.insert(
			connections,
			duel:GetDataChangedSignal("MapName"):Connect(function()
				fire()
			end)
		)
	end

	for _, duel in next, duelController.Objects do
		bind(duel)
	end
	table.insert(connections, duelController.ObjectAdded:Connect(bind))
	if duelController.LocalPlayerJoinedOrLeftDuel then
		table.insert(connections, duelController.LocalPlayerJoinedOrLeftDuel:Connect(fire))
	end

	return function()
		for _, connection in next, connections do
			connection:Disconnect()
		end
	end
end

return worldMapSource
