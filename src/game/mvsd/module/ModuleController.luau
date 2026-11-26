local logger = require("@share/logger").new("ModuleController")

local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local ModuleController = {
	_modules = {} :: { [string]: any },
}

local Modules: { [string]: { string } } = {
	BulletRenderer = { "Modules", "BulletRenderer" },
	WeaponRaycast = { "Modules", "WeaponRaycast" },
	MapService = { "Map", "MapService" },
	MapDatabase = { "Map", "MapDatabase" },
	MapModelDatabase = { "Map", "MapModelDatabase" },
	AbilityConfig = { "Ability", "AbilityConfig" },
	LocalBattlePassService = { "BattlePass", "LocalBattlePassService" },
	BattlePassProvider = { "BattlePass", "BattlePassProvider" },
	EconomyService = { "Economy", "EconomyService" },
}

ModuleController.new = function(): ModuleController
	local modules = ModuleController._modules

	local missing = {}

	for name, path in next, Modules do
		local instance: Instance? = ReplicatedStorage
		for i = 1, #path do
			instance = (instance :: Instance):FindFirstChild(path[i])
			if not instance then
				break
			end
		end

		if not instance then
			missing[#missing + 1] = name
			continue
		end

		modules[name] = (require :: any)(instance)
	end

	if #missing > 0 then
		logger:error("failed to find modules: " .. table.concat(missing, ", "))
	end

	return ModuleController
end

function ModuleController.GetModule(name: string): any
	return ModuleController._modules[name]
end

function ModuleController.Destroy(): ()
	table.clear(ModuleController._modules)
end

export type ModuleController = typeof(ModuleController)

return ModuleController
