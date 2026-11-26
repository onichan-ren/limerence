return LPH_JIT_MAX(function()
	local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService
	local Players = cloneref(game:GetService("Players")) :: Players
	local RunService = cloneref(game:GetService("RunService")) :: RunService

	local Janitor = require("@pkg/Janitor")
	local Sift = require("@pkg/Sift")
	local Charm = require("@pkg/Charm")
	local hook = require("@share/hook")
	local logger = require("@share/logger").new("GrenadeController")
	local clientApi = require("@game/rivals/client/clientApi")
	local grenadeState = require("@game/rivals/grenade/grenadeState")
	local simulator = require("@game/rivals/grenade/simulator")
	local ModuleController = require("@game/rivals/module/ModuleController")

	local LocalPlayer = Players.LocalPlayer
	local peek = Charm.peek

	local SMOKE_TAG = "SmokeCloud"
	local SMOKE_MATCH_RADIUS_SQ = 900
	local SMOKE_MATCH_WINDOW = 2.5
	local PREDICTION_INTERVAL = 0.06
	local PREDICTION_POSITION_EPSILON_SQ = 1
	local PREDICTION_TIME_EPSILON = 0.03

	local ITEM_TIMINGS = {
		["Flashbang"] = {
			fuse = 1.5,
		},
		["Smoke Grenade"] = {
			fuse = 2,
			smokeDuration = 15,
		},
		["Grenade"] = {
			fuse = 2,
		},
		["Molotov"] = {
			fuse = 2,
			fireDuration = 7,
		},
	}

	type PendingSmoke = {
		position: Vector3,
		team: string?,
		isFriendly: boolean,
		capturedAt: number,
		duration: number,
		startedAt: number,
	}

	local GrenadeController = {
		_janitor = Janitor.new() :: Janitor.Janitor,
		_projectileJanitors = {} :: { [string]: Janitor.Janitor },
		_smokeJanitors = {} :: { [string]: Janitor.Janitor },
		_fireTimers = {} :: { [string]: thread },
		_pendingSmokes = {} :: { PendingSmoke },
		_throwableHookTarget = nil :: ((...any) -> ...any)?,
		_throwableOriginal = nil :: ((...any) -> ...any)?,
		_molotovHookTarget = nil :: ((...any) -> ...any)?,
		_molotovOriginal = nil :: ((...any) -> ...any)?,
		_nextProjectileId = 0,
		_nextFireId = 0,
	}

	local runtimeModules = {} :: { [string]: any }

	local function makeRaycastParams(projectilePart: BasePart?, visualModel: Model?): RaycastParams
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.RespectCanCollide = false
		params.IgnoreWater = true

		local filter: { Instance } = {}
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.Character then
			filter[#filter + 1] = localPlayer.Character
		end
		if projectilePart then
			filter[#filter + 1] = projectilePart
		end
		if visualModel then
			filter[#filter + 1] = visualModel
		end
		params.FilterDescendantsInstances = filter
		return params
	end

	local function requireModuleAtIdentity(mod: ModuleScript): any?
		local value = require(mod)
		setthreadidentity(8)
		if type(value) ~= "table" then
			return nil
		end
		return value
	end

	local function getPlayerModule(folderName: string, moduleName: string): any?
		local cacheKey = folderName .. "/" .. moduleName
		local cached = runtimeModules[cacheKey]
		if cached then
			return cached
		end

		local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
			or LocalPlayer:WaitForChild("PlayerScripts", 10)
		local modules = playerScripts
			and (playerScripts:FindFirstChild("Modules") or playerScripts:WaitForChild("Modules", 10))
		local folder = modules and (modules:FindFirstChild(folderName) or modules:WaitForChild(folderName, 10))
		local mod = folder and (folder:FindFirstChild(moduleName) or folder:WaitForChild(moduleName, 10))
		if not mod or not mod:IsA("ModuleScript") then
			logger:warn("module not found at PlayerScripts.Modules." .. cacheKey:gsub("/", "."))
			return nil
		end

		local required = requireModuleAtIdentity(mod)
		if not required then
			logger:warn("failed to require " .. cacheKey)
			return nil
		end

		runtimeModules[cacheKey] = required
		return required
	end

	local function getInstanceKey(inst: Instance): string
		local key = inst.GetDebugId(inst)
		if type(key) == "string" and key ~= "" then
			return key
		end
		return tostring(inst)
	end

	local function getTiming(weapon: string, field: string, fallback: number): number
		local timing = ITEM_TIMINGS[weapon]
		local value = timing and timing[field]
		return (type(value) == "number" and value or fallback)
	end

	local DEFAULT_THROW_GRAVITY = 0.375

	local function computeGravityY(weapon: string): number
		local mult = DEFAULT_THROW_GRAVITY
		local itemLibrary = ModuleController.GetModule("ItemLibrary")
		local items = itemLibrary and rawget(itemLibrary, "Items")
		local info = type(items) == "table" and items[weapon]
		if type(info) == "table" and type(info.ThrowGravity) == "number" and info.ThrowGravity > 0 then
			mult = info.ThrowGravity
		end
		return -(workspace.Gravity * mult)
	end

	local function readWeaponName(item: any): string?
		if type(item) ~= "table" then
			return nil
		end
		local name = rawget(item, "Name")
		if type(name) == "string" and name ~= "" then
			return name
		end
		local viewModel = rawget(item, "ViewModel")
		if type(viewModel) == "table" then
			local vmName = rawget(viewModel, "Name")
			if type(vmName) == "string" and vmName ~= "" then
				return vmName
			end
		end
		return nil
	end

	local function readTeam(player: Player?): string?
		if not player then
			return nil
		end
		local team = player:GetAttribute("TeamID")
		if type(team) == "string" and team ~= "" then
			return team
		end
		return nil
	end

	local function isFriendlyTeam(team: string?): boolean
		if not team then
			return false
		end
		local localTeam = clientApi.GetTeam()
		return type(localTeam) == "string" and localTeam ~= "" and localTeam == team
	end

	local function readSourceTeam(item: any): (string?, boolean)
		local clientFighter = type(item) == "table" and rawget(item, "ClientFighter") or nil
		local player = type(clientFighter) == "table" and rawget(clientFighter, "Player") or nil
		local team = (typeof(player) == "Instance" and player:IsA("Player") and readTeam(player) or nil)
		return team, isFriendlyTeam(team)
	end

	local function readProjectilePosition(entry: grenadeState.ProjectileEntry): Vector3
		local projectilePart = entry.projectilePart
		if projectilePart and projectilePart.Parent then
			return projectilePart.Position
		end

		local visualModel = entry.visualModel
		if visualModel and visualModel.Parent then
			local pivot = visualModel.GetPivot(visualModel)
			return pivot.Position
		end

		return entry.landingPosition
	end

	local function readProjectileVelocity(entry: grenadeState.ProjectileEntry): Vector3?
		local projectilePart = entry.projectilePart
		if projectilePart and projectilePart.Parent then
			local velocity = projectilePart.AssemblyLinearVelocity
			if velocity.Magnitude > 0.01 then
				return velocity
			end

			local legacyVelocity = projectilePart.Velocity
			if legacyVelocity.Magnitude > 0.01 then
				return legacyVelocity
			end
		end

		return nil
	end

	local function updateProjectilePrediction(id: string): ()
		local current = peek(grenadeState.activeProjectiles)
		local entry = current[id]
		if not entry then
			return
		end

		local profile = simulator.PROFILES[entry.weapon]
		if not profile then
			return
		end

		local velocity = readProjectileVelocity(entry)
		if not velocity then
			return
		end

		local startPos = readProjectilePosition(entry)
		local remainingFuse = math.max(0, entry.detonateAt - os.clock())
		local remainingMinFuse = (
			profile.minFuse and math.max(0, profile.minFuse - (os.clock() - entry.startedAt)) or nil
		)
		local character = LocalPlayer.Character
		local params = entry.raycastParams
		if not params or entry.raycastCharacter ~= character then
			params = makeRaycastParams(entry.projectilePart, entry.visualModel)
			entry.raycastParams = params
			entry.raycastCharacter = character
		end
		local result = simulator.simulate(
			startPos,
			velocity,
			profile.radius,
			remainingFuse,
			remainingMinFuse,
			profile.floorExplode,
			params,
			entry.gravityY
		)
		local predictedLanding = result.points[#result.points]
		local predictedDetonateAt = os.clock() + result.detonateTime

		local delta = predictedLanding - entry.landingPosition
		local shiftSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
		if
			shiftSq < PREDICTION_POSITION_EPSILON_SQ
			and math.abs(predictedDetonateAt - entry.detonateAt) < PREDICTION_TIME_EPSILON
		then
			return
		end

		local updated: grenadeState.ProjectileEntry = {
			id = entry.id,
			weapon = entry.weapon,
			landingPosition = predictedLanding,
			detonateAt = predictedDetonateAt,
			startedAt = entry.startedAt,
			team = entry.team,
			isFriendly = entry.isFriendly,
			projectilePart = entry.projectilePart,
			visualModel = entry.visualModel,
			sourceItem = entry.sourceItem,
			gravityY = entry.gravityY,
			raycastParams = entry.raycastParams,
			raycastCharacter = entry.raycastCharacter,
		}

		grenadeState.activeProjectiles((Sift.Dictionary.set :: any)(current, id, updated))
	end

	local function removeFire(id: string): ()
		local timer = GrenadeController._fireTimers[id]
		if timer then
			if coroutine.status(timer) ~= "dead" then
				task.cancel(timer)
			end
			GrenadeController._fireTimers[id] = nil
		end

		local current = peek(grenadeState.activeFires)
		if current[id] then
			grenadeState.activeFires((Sift.Dictionary.removeKey :: any)(current, id))
		end
	end

	local function removeSmoke(key: string): ()
		local janitor = GrenadeController._smokeJanitors[key]
		if janitor then
			janitor:Destroy()
			GrenadeController._smokeJanitors[key] = nil
		end

		local current = peek(grenadeState.activeSmokes)
		if current[key] then
			grenadeState.activeSmokes((Sift.Dictionary.removeKey :: any)(current, key))
		end
	end

	local function pushPendingSmoke(entry: grenadeState.ProjectileEntry, position: Vector3): ()
		table.insert(GrenadeController._pendingSmokes, {
			position = position,
			team = entry.team,
			isFriendly = entry.isFriendly == true,
			capturedAt = os.clock(),
			duration = getTiming(entry.weapon, "smokeDuration", 15),
			startedAt = os.clock(),
		})
	end

	local function removeProjectile(id: string, suppressSmokePending: boolean?): ()
		local current = peek(grenadeState.activeProjectiles)
		local entry = current[id]
		if not entry then
			return
		end

		local livePosition = readProjectilePosition(entry)
		if entry.weapon == "Smoke Grenade" and suppressSmokePending ~= true then
			pushPendingSmoke(entry, livePosition)
		end

		local janitor = GrenadeController._projectileJanitors[id]
		if janitor then
			janitor:Destroy()
			GrenadeController._projectileJanitors[id] = nil
		end

		grenadeState.activeProjectiles((Sift.Dictionary.removeKey :: any)(current, id))
	end

	local function findProjectileIdForItem(item: any, weapon: string?): string?
		local bestId: string? = nil
		local bestStartedAt = -math.huge

		for id, entry in next, peek(grenadeState.activeProjectiles) do
			if
				entry.sourceItem == item
				and (weapon == nil or entry.weapon == weapon)
				and entry.startedAt > bestStartedAt
			then
				bestId = id
				bestStartedAt = entry.startedAt
			end
		end

		return bestId
	end

	local function trackProjectile(id: string, projectilePart: BasePart?): ()
		local janitor = Janitor.new()
		GrenadeController._projectileJanitors[id] = janitor

		if projectilePart then
			janitor:Add(
				projectilePart.AncestryChanged:Connect(function(_, parent: Instance?): ()
					if parent == nil then
						removeProjectile(id, false)
					end
				end),
				"Disconnect"
			)
		end

		local elapsed = 0
		janitor:Add(
			RunService.Heartbeat:Connect(function(dt: number): ()
				elapsed += dt
				if elapsed < PREDICTION_INTERVAL then
					return
				end
				elapsed = 0
				updateProjectilePrediction(id)
			end),
			"Disconnect"
		)

		task.defer(function()
			updateProjectilePrediction(id)
		end)
	end

	local function addProjectile(item: any, projectilePart: BasePart?, visualModel: Model?): ()
		local weapon = readWeaponName(item)
		if type(weapon) ~= "string" or not ITEM_TIMINGS[weapon] then
			return
		end

		GrenadeController._nextProjectileId += 1
		local id = string.format("rivals_proj_%d", GrenadeController._nextProjectileId)
		local position = (projectilePart and projectilePart.Position or Vector3.zero)
		local team, friendly = readSourceTeam(item)
		local startedAt = os.clock()

		local entry: grenadeState.ProjectileEntry = {
			id = id,
			weapon = weapon,
			landingPosition = position,
			detonateAt = startedAt + getTiming(weapon, "fuse", 2),
			startedAt = startedAt,
			team = team,
			isFriendly = friendly,
			projectilePart = projectilePart,
			visualModel = visualModel,
			sourceItem = item,
			gravityY = computeGravityY(weapon),
		}

		grenadeState.activeProjectiles((Sift.Dictionary.set :: any)(peek(grenadeState.activeProjectiles), id, entry))
		trackProjectile(id, projectilePart)
	end

	local function consumePendingSmoke(position: Vector3): PendingSmoke?
		local now = os.clock()
		local bestIndex: number? = nil
		local bestDistSq = SMOKE_MATCH_RADIUS_SQ

		for index = #GrenadeController._pendingSmokes, 1, -1 do
			local entry = GrenadeController._pendingSmokes[index]
			if now - entry.capturedAt > SMOKE_MATCH_WINDOW then
				table.remove(GrenadeController._pendingSmokes, index)
			else
				local delta = entry.position - position
				local distSq = delta.X * delta.X + delta.Z * delta.Z
				if distSq < bestDistSq then
					bestDistSq = distSq
					bestIndex = index
				end
			end
		end

		if not bestIndex then
			return nil
		end

		local match = GrenadeController._pendingSmokes[bestIndex]
		table.remove(GrenadeController._pendingSmokes, bestIndex)
		return match
	end

	local function getSmokeRegistry(): { [BasePart]: any }?
		local smokeClouds = ModuleController.GetModule("SmokeClouds")
		if not smokeClouds then
			return nil
		end
		local registry = rawget(smokeClouds, "_smoke_clouds")
		if type(registry) == "table" then
			return registry
		end
		return nil
	end

	local function registerSmokePart(part: Instance): ()
		if not part:IsA("BasePart") then
			return
		end

		task.defer(function(): ()
			local registry = getSmokeRegistry()
			local smoke = registry and registry[part] or nil
			if not smoke then
				return
			end

			local key = getInstanceKey(part)
			if peek(grenadeState.activeSmokes)[key] then
				return
			end

			local position = part.Position
			local pending = consumePendingSmoke(position)
			local startedAt = (pending and pending.startedAt or os.clock())
			local duration = (pending and pending.duration or getTiming("Smoke Grenade", "smokeDuration", 15))

			local entry: grenadeState.SmokeEntry = {
				smokeId = (type(smoke.Name) == "string" and smoke.Name or key),
				position = position,
				duration = duration,
				startedAt = startedAt,
				team = pending and pending.team or nil,
				isFriendly = pending and pending.isFriendly or false,
				part = part,
				model = (typeof(smoke.Model) == "Instance" and smoke.Model:IsA("Model") and smoke.Model or nil),
			}

			grenadeState.activeSmokes((Sift.Dictionary.set :: any)(peek(grenadeState.activeSmokes), key, entry))

			local janitor = Janitor.new()
			GrenadeController._smokeJanitors[key] = janitor
			janitor:Add(
				part.AncestryChanged:Connect(function(_, parent: Instance?): ()
					if parent == nil then
						removeSmoke(key)
					end
				end),
				"Disconnect"
			)

			if entry.model then
				janitor:Add(
					entry.model.AncestryChanged:Connect(function(_, parent: Instance?): ()
						if parent == nil then
							removeSmoke(key)
						end
					end),
					"Disconnect"
				)
			end

			local timer = task.delay(duration + 1, function()
				removeSmoke(key)
			end)
			janitor:Add(function()
				if timer and coroutine.status(timer) ~= "dead" then
					task.cancel(timer)
				end
			end, true)
		end)
	end

	local function addFireForItem(item: any, position: Vector3, fireId: string?): ()
		local id = fireId
		if type(id) ~= "string" or id == "" then
			GrenadeController._nextFireId += 1
			id = string.format("rivals_fire_%d", GrenadeController._nextFireId)
		end
		local team, friendly = readSourceTeam(item)
		local duration = getTiming("Molotov", "fireDuration", 7)

		local entry: grenadeState.FireEntry = {
			fireId = id,
			position = position,
			duration = duration,
			startedAt = os.clock(),
			team = team,
			isFriendly = friendly,
		}

		grenadeState.activeFires((Sift.Dictionary.set :: any)(peek(grenadeState.activeFires), id, entry))
		GrenadeController._fireTimers[id] = task.delay(duration, function()
			GrenadeController._fireTimers[id] = nil
			removeFire(id)
		end)
	end

	local function extractVector3(...: any): Vector3?
		for i = 1, select("#", ...) do
			local value = select(i, ...)
			if typeof(value) == "Vector3" then
				return value
			end
			if typeof(value) == "CFrame" then
				return value.Position
			end
			if typeof(value) == "Instance" and value:IsA("BasePart") then
				return value.Position
			end
		end
		return nil
	end

	local function installThrowableHook(): ()
		local throwable = getPlayerModule("ItemTypes", "Throwable")
		if not throwable then
			return
		end

		local original = rawget(throwable, "ReplicateFromServer")
		if type(original) ~= "function" then
			return
		end

		GrenadeController._throwableHookTarget = original
		GrenadeController._throwableOriginal = hook.add(original, function(item: any, eventName: any, ...): ()
			task.spawn(function(...)
				setthreadidentity(8)
				if eventName == "ThrowEffect" then
					local args = { ... }
					local projectilePart = (
						typeof(args[1]) == "Instance" and args[1]:IsA("BasePart") and args[1] or nil
					)
					local visualModel = (typeof(args[2]) == "Instance" and args[2]:IsA("Model") and args[2] or nil)
					addProjectile(item, projectilePart, visualModel)
				end
			end, ...)
			setthreadidentity(2)
			return (GrenadeController._throwableOriginal :: any)(item, eventName, ...)
		end)
	end

	local function installMolotovHook(): ()
		local molotov = getPlayerModule("Items", "Molotov")
		if not molotov then
			return
		end

		local original = rawget(molotov, "ReplicateFromServer")
		if type(original) ~= "function" then
			return
		end

		GrenadeController._molotovHookTarget = original
		GrenadeController._molotovOriginal = hook.add(original, function(item: any, eventName: any, ...): ()
			task.spawn(function(...)
				setthreadidentity(8)
				if eventName == "MolotovExplode" then
					local position = extractVector3(...) or nil
					local projectileId = findProjectileIdForItem(item, "Molotov")
					if not position and projectileId then
						local entry = peek(grenadeState.activeProjectiles)[projectileId]
						if entry then
							position = readProjectilePosition(entry)
						end
					end

					if position then
						addFireForItem(item, position :: Vector3, projectileId)
					end

					if projectileId then
						removeProjectile(projectileId, true)
					end
				end
			end, ...)
			setthreadidentity(2)
			return (GrenadeController._molotovOriginal :: any)(item, eventName, ...)
		end)
	end

	function GrenadeController.new(): typeof(GrenadeController)
		installThrowableHook()
		installMolotovHook()

		for _, inst in next, CollectionService:GetTagged(SMOKE_TAG) do
			registerSmokePart(inst)
		end

		GrenadeController._janitor:Add(
			CollectionService:GetInstanceAddedSignal(SMOKE_TAG):Connect(function(inst: Instance): ()
				registerSmokePart(inst)
			end),
			"Disconnect"
		)

		return GrenadeController
	end

	function GrenadeController.Destroy(): ()
		GrenadeController._janitor:Destroy()
		GrenadeController._janitor = Janitor.new()

		if GrenadeController._throwableHookTarget then
			hook.restore(GrenadeController._throwableHookTarget)
			GrenadeController._throwableHookTarget = nil
		end
		GrenadeController._throwableOriginal = nil

		if GrenadeController._molotovHookTarget then
			hook.restore(GrenadeController._molotovHookTarget)
			GrenadeController._molotovHookTarget = nil
		end
		GrenadeController._molotovOriginal = nil

		for id, janitor in next, GrenadeController._projectileJanitors do
			janitor:Destroy()
			GrenadeController._projectileJanitors[id] = nil
		end

		for key, janitor in next, GrenadeController._smokeJanitors do
			janitor:Destroy()
			GrenadeController._smokeJanitors[key] = nil
		end

		for id, timer in next, GrenadeController._fireTimers do
			if coroutine.status(timer) ~= "dead" then
				task.cancel(timer)
			end
			GrenadeController._fireTimers[id] = nil
		end

		GrenadeController._pendingSmokes = {}
		grenadeState.activeProjectiles({})
		grenadeState.activeSmokes({})
		grenadeState.activeFires({})
	end

	export type GrenadeController = typeof(GrenadeController)

	return GrenadeController
end)()
