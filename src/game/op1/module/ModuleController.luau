local logger = require("@share/logger").new("ModuleController")

local services = {
	ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")),
	ReplicatedFirst = cloneref(game:GetService("ReplicatedFirst")),
	Players = cloneref(game:GetService("Players")),
	Workspace = cloneref(game:GetService("Workspace")),
	Lighting = cloneref(game:GetService("Lighting")),
}

local robloxRequire = getrenv().require

local Modules = {
	Util = "ReplicatedStorage.Modules.Util",
	StateObject = "ReplicatedStorage.Modules.StateObject",
	State = "ReplicatedStorage.Modules.State",
	Net = "ReplicatedStorage.Modules.Net",
	Character = "ReplicatedStorage.Modules.Character",
	Globals = "ReplicatedStorage.Modules.Globals",
	Gun = "ReplicatedStorage.Modules.Items.Item.Gun",
	Animator = "ReplicatedStorage.Modules.Animator",
	Items = "ReplicatedStorage.Modules.Items",
	Trajectory = "ReplicatedStorage.Modules.Trajectory",
	Effects = "ReplicatedStorage.Modules.Effects",
	UI = "ReplicatedStorage.Modules.UI",
	Loadout = "ReplicatedStorage.Modules.Loadout",
	Game = "ReplicatedStorage.Modules.Game",
}

local ModuleController = {
	_cache = {},
}

local function resolve(path: string): Instance?
	local segments = string.split(path, ".")
	local current: Instance? = services[segments[1]]

	if not current then
		return nil
	end

	for index = 2, #segments do
		current = current:FindFirstChild(segments[index])

		if not current then
			return nil
		end
	end

	return current
end

local function _getModule(path: string): any
	local cache = ModuleController._cache
	local cached = cache[path]

	if cached ~= nil then
		return cached or nil
	end

	local instance = resolve(path)

	if not instance then
		logger:log(`module not found {path}`)
		cache[path] = false
		return nil
	end

	setthreadidentity(2)
	local module = robloxRequire(instance)
	setthreadidentity(8)

	if module == nil then
		cache[path] = false
		return nil
	end

	cache[path] = module
	return module
end

function ModuleController.GetModule(name: string): any
	local path = Modules[name]

	if not path then
		logger:log(`unknown module {name}`)
		return nil
	end

	return _getModule(path)
end

function ModuleController.GetInstance(name: string): Instance?
	local path = Modules[name]

	if not path then
		logger:log(`unknown module {name}`)
		return nil
	end

	return resolve(path)
end

function ModuleController.new(): ModuleController
	return ModuleController
end

function ModuleController.Destroy(): ()
	table.clear(ModuleController._cache)
end

export type ModuleController = typeof(ModuleController)

return ModuleController
