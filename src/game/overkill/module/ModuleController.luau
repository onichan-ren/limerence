local logger = require("@share/logger").new("ModuleController")

local FINGERPRINTS: { [string]: { name: string, path: string } } = {
	neuron = { name = "neuron", path = "ReplicatedFirst" },
	items = { name = "Items", path = "Milk" },
	directory = { name = "Directory", path = "Milk" },
	maps = { name = "Maps", path = "Directory" },
	titles = { name = "Titles", path = "Directory" },
	gameplayHandler = { name = "GameplayHandler", path = "Handlers" },
	clientModule = { name = "ClientModule", path = "Chickynoid" },
	clientChickynoid = { name = "ClientChickynoid", path = "Chickynoid" },
	clientMods = { name = "ClientMods", path = "Chickynoid" },
	commandLayout = { name = "CommandLayout", path = "Chickynoid" },
	collisionModule = { name = "CollisionModule", path = "Chickynoid" },
	projectilePhysics = { name = "ProjectilePhysics", path = "WeaponECS" },
	renderState = { name = "ClientState", path = "WeaponECS" },
	remoteWeaponStates = { name = "RemoteWeaponStates", path = "WeaponECS" },
	viewModel = { name = "ViewModel", path = "WeaponECS" },
	animationBridge = { name = "AnimationBridge", path = "WeaponECS" },
	scopeUi = { name = "ScopeUI", path = "WeaponECS" },
	hotbarHud = { name = "HotbarHUD", path = "WeaponECS" },
	inventoryHandler = { name = "InventoryHandler", path = "Handlers" },
	inputHandler = { name = "InputHandler", path = "Handlers" },
	dataHandler = { name = "DataHandler", path = "Handlers" },
	levelHelper = { name = "LevelHelper", path = "Helpers" },
	constants = { name = "Constants", path = "Milk" },
	premiumUpgrade = { name = "PremiumUpgrade", path = "Battlepass" },
	soundManager = { name = "SoundManager", path = "Modules" },
	states = { name = "States", path = "Modules" },
	cameraHandler = { name = "CameraHandler", path = "Handlers" },
	cameraShake = { name = "CameraShake", path = "Modules" },
	animationInterface = { name = "AnimationInterface", path = "Modules" },
	animationObserverCore = { name = "AnimationObserverCore", path = "Shared" },
	eyeOrigin = { name = "EyeOrigin", path = "Shared" },
	damage = { name = "Damage", path = "Effects" },
	gunEffects = { name = "Gun", path = "Effects" },
	crosshairRender = { name = "Crosshair", path = "Render" },
}

local ModuleController = {
	_instances = {} :: { [string]: ModuleScript },
	_required = {} :: { [string]: any },
}

local function missingKeys(): { string }
	local instances = ModuleController._instances
	local missing = {}
	for key in next, FINGERPRINTS do
		if not instances[key] then
			table.insert(missing, key)
		end
	end
	return missing
end

local scan = LPH_JIT_MAX(function(): ()
	local instances = ModuleController._instances

	setthreadidentity(8)
	for _, module in next, getloadedmodules(true) do
		if module:IsA("ModuleScript") then
			local name = module.Name
			for key, fingerprint in next, FINGERPRINTS do
				if not instances[key] and name == fingerprint.name then
					if string.find(module:GetFullName(), fingerprint.path, 1, true) then
						instances[key] = module
					end
				end
			end
		end
	end
end)

function ModuleController.new(): ModuleController
	local maxAttempts = 60
	local attempts = 0
	repeat
		attempts += 1
		scan()
		if #missingKeys() == 0 then
			break
		end
		task.wait(1)
	until attempts >= maxAttempts

	local missing = missingKeys()
	if #missing > 0 then
		logger:error("failed to resolve modules: " .. table.concat(missing, ", "))
	end

	return ModuleController
end

function ModuleController.GetModule(key: string): any
	local cached = ModuleController._required[key]
	if cached ~= nil then
		return cached
	end

	local instance = ModuleController._instances[key]
	if not instance then
		logger:error("unknown module: " .. key)
		return nil
	end

	setthreadidentity(2)
	local result = (require :: any)(instance)
	setthreadidentity(8)
	if key == "neuron" and typeof(result) == "userdata" then
		local unwrapped = filtergc("table", { Keys = { "get_character", "get_player", "signals", "net" } }, true)
		if unwrapped then
			result = unwrapped
		else
			logger:error("failed to unwrap neuron")
		end
	end
	ModuleController._required[key] = result
	return result
end

function ModuleController.Destroy(): ()
	table.clear(ModuleController._instances)
	table.clear(ModuleController._required)
end

export type ModuleController = typeof(ModuleController)

return ModuleController
