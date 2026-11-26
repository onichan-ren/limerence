local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local NetworkController = require("@game/overkill/network/NetworkController")
local ModuleController = require("@game/overkill/module/ModuleController")
local TeamController = require("@game/overkill/team/TeamController")
local ClientState = require("@game/overkill/client/clientState")
local grenadeState = require("@game/overkill/grenade/grenadeState")

local LocalPlayer = Players.LocalPlayer
local peek = Charm.peek

local MODEL_NAMES = {
	Projectile = true,
	Grenade = true,
	Satchel = true,
}

local MATCH_RADIUS_SQ = 200 * 200
local MAX_FUSE = 60
local SAFETY_BUFFER = 3
local MAX_PREDICT_TIME = 5
local SIM_STEP = 1 / 60

local GrenadeController = {
	_entries = {} :: { [string]: grenadeState.ProjectileEntry },
	_modelConns = {} :: { [string]: RBXScriptConnection },
	_timers = {} :: { [string]: thread },
	_claimed = {} :: { [Model]: string },
	_unhooks = {} :: { () -> () },
	_items = nil :: any,
	_physics = nil :: any,
	_collision = nil :: any,
	_fx = nil :: Instance?,
}

local function getFx(): Instance?
	local fx = GrenadeController._fx
	if fx and fx.Parent then
		return fx
	end
	local world = workspace:FindFirstChild("World")
	fx = world and world:FindFirstChild("FX")
	GrenadeController._fx = fx
	return fx
end

local function publish(): ()
	local snapshot: { [string]: grenadeState.ProjectileEntry } = {}
	for id, entry in next, GrenadeController._entries do
		snapshot[id] = entry
	end
	grenadeState.activeProjectiles(snapshot)
end

local function removeEntry(id: string): ()
	local entry = GrenadeController._entries[id]
	if not entry then
		return
	end

	local conn = GrenadeController._modelConns[id]
	if conn then
		conn:Disconnect()
		GrenadeController._modelConns[id] = nil
	end

	local timer = GrenadeController._timers[id]
	if timer then
		if coroutine.status(timer) ~= "dead" then
			task.cancel(timer)
		end
		GrenadeController._timers[id] = nil
	end

	local model = entry.model
	if model and GrenadeController._claimed[model] == id then
		GrenadeController._claimed[model] = nil
	end

	GrenadeController._entries[id] = nil
	publish()
end

local matchModel = LPH_NO_VIRTUALIZE(function(id: string, spawnPosition: Vector3): ()
	local entry = GrenadeController._entries[id]
	if not entry or entry.model then
		return
	end

	local fx = getFx()
	if not fx then
		return
	end

	local best: Model? = nil
	local bestDistSq = MATCH_RADIUS_SQ
	for _, child in next, fx:GetChildren() do
		if MODEL_NAMES[child.Name] and child:IsA("Model") and not GrenadeController._claimed[child] then
			local delta = child:GetPivot().Position - spawnPosition
			local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
			if distSq < bestDistSq then
				bestDistSq = distSq
				best = child
			end
		end
	end

	if not best then
		return
	end

	entry.model = best
	GrenadeController._claimed[best] = id
	GrenadeController._modelConns[id] = best.AncestryChanged:Connect(function(_, parent: Instance?): ()
		if parent == nil then
			removeEntry(id)
		end
	end)
	publish()
end)

local function projectileSweep(from: Vector3, to: Vector3, radius: number): any?
	local collision = GrenadeController._collision
	local result = collision:Sweep(from, to, Vector3.new(radius, radius, radius))
	if result.fraction >= 1 then
		return nil
	end
	local normal = result.normal
	return {
		Position = result.endPos - normal * radius,
		Normal = normal,
		Instance = result.hullRecord and result.hullRecord.instance or nil,
		fraction = result.fraction,
	}
end

local predictDetonation = LPH_NO_VIRTUALIZE(function(payload: any, item: any): Vector3?
	local physics = GrenadeController._physics
	if not physics or not GrenadeController._collision then
		return nil
	end

	local stats = item.stats
	local firing = stats.firing
	local lifetime = type(payload.lifetime) == "number" and payload.lifetime or MAX_PREDICT_TIME
	local fuseTime = firing.projectileFuseTime

	local state = {
		simTime = 0,
		accumulator = 0,
		bounceCount = 0,
		grounded = false,
		groundNormal = nil,
		wallContactNormal = nil,
		alive = true,
		position = payload.position,
		velocity = payload.velocity,
		gravity = payload.gravity,
		fireTimeServer = 0,
		lifetime = lifetime,
		radius = type(payload.radius) == "number" and payload.radius or 0.5,
		maxBounces = payload.maxBounces or 0,
		bounceDamping = payload.bounceDamping or 0.6,
		groundFriction = payload.groundFriction,
		isExplosive = firing.isExplosive or false,
		explosionRadius = firing.explosionRadius or 0,
		fuseTime = fuseTime,
		sticksOnHit = payload.sticksOnHit,
		gunStats = stats,
		hitVictims = {},
	}

	local predicted: Vector3? = nil
	local handler = {
		sweep = projectileSweep,
		raycast = function(): any?
			return nil
		end,
		victimHitCheck = function(): any?
			return nil
		end,
		handleExplosion = function(_: any, pos: any): any?
			if predicted == nil and typeof(pos) == "Vector3" then
				predicted = pos
			end
			return nil
		end,
		broadcastExplosion = function(): () end,
		broadcastDirectHit = function(): () end,
		broadcastExpire = function(p: any): ()
			if predicted == nil then
				predicted = p.position
			end
		end,
		handleDirectHit = function(): () end,
		destroyProjectile = function(p: any): ()
			p.alive = false
		end,
	}

	local horizon = math.min(fuseTime or lifetime, lifetime, MAX_PREDICT_TIME)
	local steps = math.ceil(horizon / SIM_STEP)

	setthreadidentity(2)
	for _ = 1, steps do
		if not state.alive then
			break
		end
		physics.step(state, handler)
		if predicted ~= nil then
			break
		end
	end
	setthreadidentity(8)

	return predicted or state.position
end)

local function resolveTeam(owner: any): (string, boolean)
	if owner == LocalPlayer then
		return TeamController.GetTeam(LocalPlayer), true
	end
	if typeof(owner) ~= "Instance" or not owner:IsA("Player") then
		return "", false
	end
	local team = TeamController.GetTeam(owner)
	local localTeam = peek(ClientState.team)
	local friendly = team ~= "" and type(localTeam) == "string" and team == localTeam
	return team, friendly
end

local onSpawn = LPH_NO_VIRTUALIZE(function(payload: any): ()
	if type(payload) ~= "table" then
		return
	end

	local projectileId = payload.projectileId
	if type(projectileId) ~= "number" or projectileId == 65535 then
		return
	end

	local weaponId = payload.weaponID
	if type(weaponId) ~= "string" then
		return
	end

	local position = payload.position
	if typeof(position) ~= "Vector3" then
		return
	end

	local items = GrenadeController._items
	local all = items and rawget(items, "all")
	if type(all) ~= "table" then
		return
	end
	local item = all[weaponId]
	if type(item) ~= "table" then
		return
	end
	local firing = item.stats and item.stats.firing
	if type(firing) ~= "table" then
		return
	end

	local id = tostring(projectileId)
	if GrenadeController._entries[id] then
		removeEntry(id)
	end

	local fuseRaw = firing.projectileFuseTime
	local fuseTime = (type(fuseRaw) == "number" and fuseRaw > 0 and fuseRaw < MAX_FUSE) and fuseRaw or nil
	local startedAt = os.clock()
	local team, friendly = resolveTeam(payload.owner)

	local entry: grenadeState.ProjectileEntry = {
		id = id,
		weaponId = weaponId,
		displayName = (type(item.name) == "string" and item.name ~= "" and item.name or weaponId),
		isExplosive = firing.isExplosive == true,
		explosionRadius = type(firing.explosionRadius) == "number" and firing.explosionRadius or 0,
		fuseTime = fuseTime,
		startedAt = startedAt,
		detonateAt = fuseTime and (startedAt + fuseTime) or nil,
		team = team,
		isFriendly = friendly,
		spawnPosition = position,
		model = nil,
	}

	GrenadeController._entries[id] = entry

	local lifetime = type(firing.projectileLifetime) == "number" and firing.projectileLifetime or 8
	local timeout = math.min((fuseTime or lifetime) + SAFETY_BUFFER, lifetime + SAFETY_BUFFER)
	GrenadeController._timers[id] = task.delay(timeout, function(): ()
		GrenadeController._timers[id] = nil
		removeEntry(id)
	end)

	publish()

	task.defer(function(): ()
		local predicted = predictDetonation(payload, item)
		if GrenadeController._entries[id] == entry and predicted then
			entry.predictedPosition = predicted
			publish()
		end
		matchModel(id, position)
	end)
end)

local function onRemovePacket(payload: any): ()
	if type(payload) ~= "table" then
		return
	end
	local projectileId = payload.projectileId
	if type(projectileId) ~= "number" then
		return
	end
	removeEntry(tostring(projectileId))
end

function GrenadeController.new(): typeof(GrenadeController)
	GrenadeController._items = ModuleController.GetModule("items")
	GrenadeController._physics = ModuleController.GetModule("projectilePhysics")
	GrenadeController._collision = ModuleController.GetModule("collisionModule")

	table.insert(GrenadeController._unhooks, NetworkController.HookInbound("projectile_spawn", onSpawn))
	table.insert(GrenadeController._unhooks, NetworkController.HookInbound("projectile_detonate", onRemovePacket))
	table.insert(GrenadeController._unhooks, NetworkController.HookInbound("projectile_hit", onRemovePacket))
	table.insert(GrenadeController._unhooks, NetworkController.HookInbound("projectile_expire", onRemovePacket))

	return GrenadeController
end

function GrenadeController.Destroy(): ()
	for _, unhook in next, GrenadeController._unhooks do
		unhook()
	end
	table.clear(GrenadeController._unhooks)

	for id in next, GrenadeController._entries do
		removeEntry(id)
	end

	table.clear(GrenadeController._entries)
	table.clear(GrenadeController._modelConns)
	table.clear(GrenadeController._timers)
	table.clear(GrenadeController._claimed)
	GrenadeController._items = nil
	GrenadeController._physics = nil
	GrenadeController._collision = nil
	GrenadeController._fx = nil

	grenadeState.activeProjectiles({})
end

export type GrenadeController = typeof(GrenadeController)

return GrenadeController
