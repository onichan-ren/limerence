-- the modules in ar2 sometimes don't have alot of things, because alot of functions are local functions, therefore we must go through the gc

export type ModuleData = {
	module: any,
	infoSource: string,
	protos: any,
}

local ModuleController = {
	_modules = {} :: { [string]: ModuleData },
	_frameworkCache = {} :: { [string]: any },
}

local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local ReplicatedFirst = cloneref(game:GetService("ReplicatedFirst"))

local function getSource(module: any, moduleScript: LocalScript | ModuleScript): string?
	local source

	if type(module) == "function" then
		source = debug.getinfo(module).source
	end

	if type(module) == "table" then
		for i, v in module do
			if type(v) == "function" then
				source = debug.getinfo(v).source
				break
			end
		end
	end

	-- I really wanna avoid the protos part as much as possible
	if source then
		return source
	end

	for i, v in debug.getprotos(getscriptclosure(moduleScript) :: any) do
		source = debug.getinfo(v).source
		break
	end

	return source
end

local findPath = LPH_NO_VIRTUALIZE(function(root: Instance, ...: string): Instance?
	local current: Instance? = root
	for i = 1, select("#", ...) do
		if not current then
			return nil
		end
		current = current:FindFirstChild((select(i, ...)))
	end
	return current
end)

local Modules = {
	Bullets = {
		"GetSpreadAngle",
		"Fire",
	},
	Animators = {
		"SetAction",
		"GetTrack",
		"PlayAnimation",
		"get",
		"find",
	},
	LocalPlayer = {
		"playButtonPress",
		"new",
		"get",
		"UnloadCharacter",
	},
	Network = {
		"Remove",
		"Add",
		"GetPing",
		"ReplicationWait",
	},
	Cameras = {
		"SetCurrent",
		"GetCamera",
		"LoadCamera",
	},
	Globals = {
		"isProdPlace",
		"isTestPlace",
		"isBanLand",
	},
	Raycasting = {
		"CameraCast",
		"DrinkCast",
		"InteractCast",
		"BulletCastLight",
	},
	Reticle = {
		"GetWorldCastInfo",
		"GetFirearmTargetInfo",
		"GetMeleeTargetInfo",
		"SetStabalizeBarValue",
	},
	Interactables = {
		"find",
		"new",
		"inputPrompt",
		"statBar",
		"GetInteractPromptData",
	},
	Springs = {
		"SetGoal",
		"GetPosition",
		"GetVelocity",
		"Update",
		"StepTo",
	},
	Framework = function()
		return findPath(ReplicatedFirst, "Framework")
	end,
	World = function()
		return findPath(ReplicatedStorage, "Client", "Libraries", "World")
	end,
	Firearm = function()
		return findPath(ReplicatedStorage, "Client", "Abstracts", "ItemInitializers", "Firearm")
	end,
	CharacterAnimator = function()
		return findPath(ReplicatedStorage, "Client", "Abstracts", "Animators", "Character")
	end,
	CharacterCamera = function()
		return findPath(ReplicatedStorage, "Client", "Abstracts", "Cameras", "Character")
	end,
	CorpseCamera = function()
		return findPath(ReplicatedStorage, "Client", "Abstracts", "Cameras", "Corpse")
	end,
}

ModuleController.new = function(): ModuleController
	local modules = ModuleController._modules

	local processModule = LPH_NO_VIRTUALIZE(function(module: any, loadedModule: ModuleScript, moduleName: string)
		local infoSource = getSource(module, loadedModule)

		if not infoSource then
			return
		end

		if not modules[moduleName] then
			modules[moduleName] = {
				module = module,
				infoSource = infoSource,
				script = loadedModule,
				protos = {},
			}
		end
	end)

	local robloxRequire = getrenv().require

	local badRequire = LPH_NO_VIRTUALIZE(function(moduleScript: ModuleScript)
		local old = getthreadidentity()
		setthreadidentity(2)
		local ok, module = pcall(robloxRequire, moduleScript)
		setthreadidentity(old)
		return ok and module
	end)

	LPH_NO_VIRTUALIZE(function()
		local deadline = os.clock() + 60
		while os.clock() < deadline do
			local frameworkScript = findPath(ReplicatedFirst, "Framework")
			local framework = frameworkScript and badRequire(frameworkScript)
			if type(framework) == "table" and framework.IsLoaded and framework:IsLoaded() then
				break
			end
			task.wait(0.1)
		end
	end)()

	local resolve = LPH_NO_VIRTUALIZE(function()
		for moduleName, moduleFunc in Modules do
			if modules[moduleName] then
				continue
			end
			if type(moduleFunc) == "function" then
				local moduleScript = moduleFunc()

				if moduleScript then
					processModule(badRequire(moduleScript), moduleScript, moduleName)
				end
			end
		end

		for _, loadedModule in getloadedmodules(false) do
			if not loadedModule.Parent then -- this might break in the future, but i kept getting an error about roblox complaining im trying to require a destroyed module script
				continue
			end

			local module = badRequire(loadedModule)

			if not module then
				continue
			end

			local foundAll = false
			local finalModuleName

			for moduleName, moduleChecks in Modules do
				local amountFound = 0

				if modules[moduleName] then
					continue
				end

				if type(moduleChecks) == "table" and type(module) == "table" then
					for _, moduleCheck in moduleChecks do
						if rawget(module, moduleCheck) then
							amountFound += 1
						end
					end

					if amountFound == #moduleChecks then
						foundAll = true
						finalModuleName = moduleName
					end
				end
			end

			if not foundAll then
				continue
			end

			processModule(module, loadedModule, finalModuleName)
		end
	end)

	local missingCount = LPH_NO_VIRTUALIZE(function(): number
		local missing = 0
		for moduleName in Modules do
			if not modules[moduleName] then
				missing += 1
			end
		end
		return missing
	end)

	local maxAttempts = 20
	local attempts = 0
	repeat
		attempts += 1
		resolve()
		if missingCount() == 0 then
			break
		end
		task.wait(0.5)
	until attempts >= maxAttempts

	LPH_NO_VIRTUALIZE(function()
		local sourceToModule: { [string]: ModuleData } = {}
		for _, data in modules do
			if sourceToModule[data.infoSource] == nil then
				sourceToModule[data.infoSource] = data
			end
		end

		for i, v in filtergc("function", {}, false) do
			if type(v) ~= "function" then
				continue
			end

			if iscclosure(v) or isexecutorclosure(v) then
				continue
			end

			local info = debug.getinfo(v)

			if info.name:len() <= 0 then -- anonymous function
				continue
			end

			local moduleData = sourceToModule[info.source]

			if not moduleData then
				continue
			end

			if type(moduleData.module) == "table" and rawget(moduleData.module, info.name) then
				continue
			end

			moduleData.protos[info.name] = v
		end

		--[[
		for moduleName, moduleData in modules do
			local closure = getscriptclosure(moduleData.script :: ModuleScript)

			if not closure then
				continue
			end

			for _, proto in debug.getprotos(closure) do
				local name = debug.getinfo(proto).name

				if name:len() <= 0 then
					continue
				end

				moduleData.protos[name] = proto
			end
		end
		]]
	end)()

	return ModuleController
end

function ModuleController.GetModule(name: string): any
	return ModuleController._modules[name]
end

function ModuleController.FrameworkRequire(category: string, name: string): any
	local cacheKey = category .. "/" .. name
	local cached = ModuleController._frameworkCache[cacheKey]
	if cached ~= nil then
		return cached or nil
	end

	local framework = ModuleController.GetModule("Framework")
	local frameworkModule = framework and framework.module
	local result

	if frameworkModule then
		pcall(function()
			result = frameworkModule.require(category, name)
		end)
	end

	ModuleController._frameworkCache[cacheKey] = result or false

	return result
end

function ModuleController.GetItemData(): any
	return ModuleController.FrameworkRequire("Configs", "ItemData")
end

function ModuleController.Destroy(): ()
	for key in next, ModuleController._modules do
		ModuleController._modules[key] = nil
	end

	for key in next, ModuleController._frameworkCache do
		ModuleController._frameworkCache[key] = nil
	end
end

export type ModuleController = typeof(ModuleController)
return ModuleController
