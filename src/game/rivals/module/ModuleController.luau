local logger = require("@share/logger").new("ModuleController")

local Players = cloneref(game:GetService("Players")) :: Players
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local ModuleController = {
	_modules = {},
}

local PathModules = {
	MatchmakingController = { "PlayerScripts", "Controllers", "MatchmakingController" },
	DuelController = { "PlayerScripts", "Controllers", "DuelController" },
	DuelDisplay = { "PlayerScripts", "Modules", "DuelsDisplay", "DuelDisplay" },
	Gun = { "PlayerScripts", "Modules", "ItemTypes", "Gun" },
	TracerEffect = { "PlayerScripts", "Modules", "TracerEffect" },
	TrajectoryVisual = { "PlayerScripts", "Modules", "TrajectoryVisual" },
	FootstepSounds = {
		"PlayerScripts",
		"Modules",
		"ClientReplicatedClasses",
		"ClientFighter",
		"ClientFighterCharacter",
		"Sounds",
	},
	Throwable = { "PlayerScripts", "Modules", "ItemTypes", "Throwable" },
	EliminationFeed = {
		"PlayerScripts",
		"Modules",
		"ClientReplicatedClasses",
		"ClientDuel",
		"DuelInterface",
		"EliminationFeed",
	},
	ViewModelAnimator = {
		"PlayerScripts",
		"Modules",
		"ClientReplicatedClasses",
		"ClientFighter",
		"ClientItem",
		"ClientViewModel",
		"ViewModelAnimator",
	},
	Molotov = { "PlayerScripts", "Modules", "Items", "Molotov" },
	AimVignette = {
		"PlayerScripts",
		"Modules",
		"ClientReplicatedClasses",
		"ClientFighter",
		"ClientItem",
		"ItemInterface",
		"Other",
	},
	SeasonLibrary = { "Modules", "SeasonLibrary", root = "ReplicatedStorage" },
	CosmeticLibrary = { "Modules", "CosmeticLibrary", root = "ReplicatedStorage" },
	MonetizationLibrary = { "Modules", "MonetizationLibrary", root = "ReplicatedStorage" },
}

local Modules = {
	ReplicatedClass = {
		"GetReplicatedClass",
		"Get",
		"Set",
		"GetDataChangedSignal",
		"Replicate",
		"ReplicateFromServer",
		"ToEnum",
		check = function(module: any): boolean
			local get = rawget(module, "Get")
			if type(get) ~= "function" then
				return false
			end
			local source = debug.info(get, "s")
			return type(source) == "string" and string.find(source, "ReplicatedClass", 1, true) ~= nil
		end,
	},
	FighterController = {
		"_player_to_fighter",
		"_model_to_fighter",
		"_network_id_map",
		"_character_model_cache",
	},
	ItemLibrary = {
		"Items",
		"Classes",
		"Types",
		"Ammos",
		"Crosshairs",
		"ViewModels",
		"Statuses",
		"FormatWeaponNamesByClass",
	},
	Camera = {
		"GetCameraSway",
		"GetCameraLean",
	},
	GameplayUtility = {
		"GetSpread",
		"GetMousePositionFromCameraData",
	},
	AnimationLibrary = {
		"Info",
		check = function(module: any): boolean
			local info = rawget(module, "Info")
			if type(info) ~= "table" then
				return false
			end
			local entry = info["katana_deflect_idle"]
			return type(entry) == "table" and type(entry.AnimationID) == "string"
		end,
	},
	CameraController = {
		"_base_fov",
		"_fov_offset_strength_scoped",
		"_external_fov_offsets",
		"_fov_gameplay_spring",
	},
	Scope = {
		"SetActive",
		"IsActive",
		"_Setup",
		"_Init",
		check = function(module: any): boolean
			local setActive = rawget(module, "SetActive")
			if type(setActive) ~= "function" then
				return false
			end
			local source = debug.info(setActive, "s")
			if type(source) ~= "string" then
				return false
			end
			return string.find(source, "Scope") ~= nil
		end,
	},
	Crosshair = {
		"SetHitmarkerVisuals",
		"SetHitmarkerColor",
		"SetAppearance",
		"GetDisplayAppearance",
		check = function(module: any): boolean
			local fn = rawget(module, "SetHitmarkerVisuals")
			if type(fn) ~= "function" then
				return false
			end
			local source = debug.info(fn, "s")
			if type(source) ~= "string" then
				return false
			end
			return string.find(source, "Crosshair") ~= nil
		end,
	},
	ClientViewModel = {
		"PlayHitmarkerSound",
		"_CreateHitmarkerSound",
		"Update",
		"Destroy",
		"ApplyRecoil",
		"Impulse",
	},
	SmokeClouds = {
		"_smoke_clouds",
		check = function(module: any): boolean
			local clouds = rawget(module, "_smoke_clouds")
			if type(clouds) ~= "table" then
				return false
			end
			local mt = getmetatable(module)
			if type(mt) ~= "table" then
				return false
			end
			return type(rawget(mt, "_ObjectAdded")) == "function" and type(rawget(mt, "_ObjectRemoved")) == "function"
		end,
	},
	FireHitboxes = {
		"_fire_hitboxes",
		check = function(module: any): boolean
			local list = rawget(module, "_fire_hitboxes")
			if type(list) ~= "table" then
				return false
			end
			local mt = getmetatable(module)
			if type(mt) ~= "table" then
				return false
			end
			return type(rawget(mt, "Extinguish")) == "function" and type(rawget(mt, "_Setup")) == "function"
		end,
	},
	SmokeScreen = {
		"_GetSmokeCloud",
		"Update",
		"Hide",
		"Clear",
		check = function(module: any): boolean
			local getSmokeCloud = rawget(module, "_GetSmokeCloud")
			if type(getSmokeCloud) ~= "function" then
				return false
			end
			local source = debug.info(getSmokeCloud, "s")
			return type(source) == "string" and string.find(source, "SmokeScreen", 1, true) ~= nil
		end,
	},
	Flashed = {
		"AttemptToFlash",
		"Flash",
		"_CameraSnapshot",
		"_IsOccluded",
		"_RegisterFlashObjects",
	},
	CameraShaker = {
		"ShakeOnce",
		"Shake",
		"ShakeSustain",
		"StartShake",
		"Stop",
		"StopSustained",
		"Update",
	},
	MechanicsController = {
		"_auto_shoot_hash",
		"_double_jumps_used",
		"_jump_hash",
		"LocalFighter",
		check = function(module: any): boolean
			return type(module.EquippedItemInput) == "function"
		end,
	},
	EnumLibrary = {
		"_enum_builder_completed_internal",
		"_enum_builder_complete",
	},
	ControlsController = {
		"CurrentControls",
		"_toggled_inputs",
	},
	ClientEntity = {
		"_PlayFinisher",
		"_UpdateInvincibilityVisual",
		"_BlipEffect",
		check = function(module: any): boolean
			local fn = rawget(module, "_PlayFinisher")
			if type(fn) ~= "function" then
				return false
			end
			local source = debug.info(fn, "s")
			return type(source) == "string" and string.find(source, "ClientEntity") ~= nil
		end,
	},
	DamageIndicators = {
		"Create",
		"Update",
		"Clear",
		check = function(module: any): boolean
			local create = rawget(module, "Create")
			if type(create) ~= "function" then
				return false
			end
			local source = debug.info(create, "s")
			return type(source) == "string" and string.find(source, "DamageIndicator") ~= nil
		end,
	},
	--[[AimVignette = {
		"Update",
		"_Setup",
		"_Init",
		check = function(module: any): boolean
			local setup = rawget(module, "_Setup")
			if type(setup) ~= "function" then
				return false
			end
			local upvalue, ok = pcall(getupvalue, setup, 1)
			if not upvalue or upvalue ~= game:GetService("GuiService") then
				return false
			end
			return true
		end,
	},--]]
}

local scan = LPH_NO_VIRTUALIZE(function(): ()
	local modules = ModuleController._modules

	for _, module in next, filtergc("table", {}, false) do
		if next(Modules) == nil then
			break
		end

		if not module or type(module) ~= "table" then
			continue
		end

		for moduleName, strings in next, Modules do
			local found = true
			for key, value in next, strings do
				if key == "check" then
					continue
				end
				if not rawget(module, value) then
					found = false
					break
				end
			end
			if found then
				local check = (strings :: any).check
				if check and not check(module) then
					continue
				end
				modules[moduleName] = module
				Modules[moduleName] = nil
				break
			end
		end
	end
end)

function ModuleController.new(): ModuleController
	local maxAttempts = 60
	local attempts = 0
	repeat
		attempts += 1
		task.wait(1)
		scan()
	until next(Modules) == nil or attempts >= maxAttempts

	if next(Modules) then
		local missing = {}
		for name in next, Modules do
			table.insert(missing, name)
		end
		logger:warn("failed to find modules: " .. table.concat(missing, ", "))
	end

	return ModuleController
end

local resolvePathModule = function(path: { string }): any?
	local instance: Instance? = (path :: any).root == "ReplicatedStorage" and ReplicatedStorage or Players.LocalPlayer
	for index = 1, #path do
		if not instance then
			return nil
		end
		instance = instance:FindFirstChild(path[index])
	end
	if not instance or not instance:IsA("ModuleScript") then
		return nil
	end
	local value = require(instance) :: any
	if type(value) ~= "table" then
		return nil
	end
	return value
end

function ModuleController.GetModule(name: string): any
	local cached = ModuleController._modules[name]
	if cached then
		return cached
	end

	local path = PathModules[name]
	if path then
		local resolved = resolvePathModule(path)
		if resolved then
			ModuleController._modules[name] = resolved
		end
		return resolved
	end

	return nil
end

function ModuleController.Destroy(): ()
	for key in next, ModuleController._modules do
		ModuleController._modules[key] = nil
	end
end

export type ModuleController = typeof(ModuleController)
return ModuleController
