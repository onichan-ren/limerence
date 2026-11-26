local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local worldMapSource = {}

function worldMapSource.GetAll(): { string }
	local maps = {}
	local database = ReplicatedStorage:FindFirstChild("Database")
	local custom = database and database:FindFirstChild("Custom")
	local stats = custom and custom:FindFirstChild("GameStats")
	local folder = stats and stats:FindFirstChild("Maps")
	if folder then
		for _, child in next, folder:GetChildren() do
			table.insert(maps, child.Name)
		end
		table.sort(maps)
	end
	return maps
end

function worldMapSource.GetCurrent(): string?
	local map = Workspace:GetAttribute("Map")
	if type(map) == "string" and map ~= "" then
		return map
	end
	return nil
end

function worldMapSource.Changed(callback: (map: string?) -> ()): () -> ()
	local connection = Workspace:GetAttributeChangedSignal("Map"):Connect(function()
		callback(worldMapSource.GetCurrent())
	end)
	return function()
		connection:Disconnect()
	end
end

return worldMapSource
