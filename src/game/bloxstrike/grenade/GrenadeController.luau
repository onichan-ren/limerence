local Janitor = require("@pkg/Janitor")
local grenadeState = require("@game/bloxstrike/grenade/grenadeState")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local NetworkController = require("@game/bloxstrike/network/NetworkController")
local ClientController = require("@game/bloxstrike/client/ClientController")
local simulator = require("@game/bloxstrike/grenade/simulator")
local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local hook = require("@share/hook")

local Players = cloneref(game:GetService("Players")) :: Players
local LocalPlayer = Players.LocalPlayer
local Debris = workspace:WaitForChild("Debris")
local peek = Charm.peek

local TEAM_MATCH_RADIUS_SQ = 900
local TEAM_MATCH_WINDOW = 1.5

type PendingTeam = {
	position: Vector3,
	team: string?,
	isFriendly: boolean,
	capturedAt: number,
}

local GrenadeController = {
	_internalSmokeVoxels = {} :: { [Part]: SmokeVoxelData },
	_janitor = Janitor.new() :: Janitor.Janitor,
	_fireHookTarget = nil :: ((...any) -> ...any)?,
	_oldFireCreate = nil :: ((...any) -> ...any)?,
	_smokeHookTarget = nil :: ((...any) -> ...any)?,
	_oldSmokeCreate = nil :: ((...any) -> ...any)?,
	_pendingFireMeta = {} :: { [string]: { duration: number, position: Vector3, startedAt: number } },
	_pendingSmokeMeta = {} :: { [string]: { duration: number, deployTime: number, position: Vector3, startedAt: number } },
	_pendingFireTeams = {} :: { PendingTeam },
	_pendingSmokeTeams = {} :: { PendingTeam },
	_projectileJanitors = {} :: { [string]: Janitor.Janitor },
}

local consumePendingTeam = LPH_NO_VIRTUALIZE(
	function(list: { PendingTeam }, position: Vector3): (string?, boolean, Vector3?)
		local now = os.clock()
		local bestIndex: number?
		local bestDistSq = TEAM_MATCH_RADIUS_SQ
		for i = #list, 1, -1 do
			local entry = list[i]
			if now - entry.capturedAt > TEAM_MATCH_WINDOW then
				table.remove(list, i)
			else
				local dx = entry.position.X - position.X
				local dz = entry.position.Z - position.Z
				local distSq = dx * dx + dz * dz
				if distSq < bestDistSq then
					bestDistSq = distSq
					bestIndex = i
				end
			end
		end
		if not bestIndex then
			return nil, false, nil
		end
		local match = list[bestIndex]
		table.remove(list, bestIndex)
		return match.team, match.isFriendly, match.position
	end
)

local makeRaycastParams = LPH_NO_VIRTUALIZE(function(): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.RespectCanCollide = false
	p.IgnoreWater = true
	local filter: { Instance } = { Debris }
	if LocalPlayer and LocalPlayer.Character then
		table.insert(filter, LocalPlayer.Character)
	end
	p.FilterDescendantsInstances = filter
	return p
end)

local function removeProjectile(id: string): ()
	local janitor = GrenadeController._projectileJanitors[id]
	if janitor then
		janitor:Destroy()
		GrenadeController._projectileJanitors[id] = nil
	end
	local current = peek(grenadeState.activeProjectiles)
	if current[id] then
		grenadeState.activeProjectiles((Sift.Dictionary.removeKey :: any)(current, id))
	end
end

local onProjectileSpawn = LPH_NO_VIRTUALIZE(function(data: any): ()
	if typeof(data) ~= "table" then
		return
	end

	local id = data.Id
	local weapon = data.Weapon
	local state = data.State
	local physics = data.Physics
	if type(id) ~= "string" or type(weapon) ~= "string" or typeof(state) ~= "table" or typeof(physics) ~= "table" then
		return
	end

	local profile = simulator.PROFILES[weapon]
	if not profile then
		return
	end

	local startPos = state.Position
	local startVel = state.Velocity
	if typeof(startPos) ~= "Vector3" or typeof(startVel) ~= "Vector3" then
		return
	end

	local fuseTime: number? = (physics.FuseTime and physics.FuseTime > 0 and physics.FuseTime or nil)
	local radius = physics.Radius or profile.radius

	local params = makeRaycastParams()
	local result = simulator.simulate(
		startPos,
		startVel,
		state.IsJumpThrow == true,
		radius,
		fuseTime,
		profile.minFuse,
		profile.floorExplode,
		params
	)

	local landingPosition = result.points[#result.points]
	local now = os.clock()

	local team: string? = (
		type(physics.CollisionGroup) == "string"
			and physics.CollisionGroup ~= ""
			and physics.CollisionGroup ~= "Default"
			and physics.CollisionGroup
		or nil
	)
	local localTeam = ClientController.GetTeam()
	local isFriendly = team ~= nil and localTeam ~= nil and team == localTeam

	local entry: grenadeState.ProjectileEntry = {
		id = id,
		weapon = weapon,
		pathPoints = result.points,
		bounceIndices = result.bounceIndices,
		landingPosition = landingPosition,
		detonateAt = now + result.detonateTime,
		startedAt = now,
		fuseTime = fuseTime,
		leavesFire = profile.leavesFire,
		resolved = false,
		team = team,
		isFriendly = isFriendly,
	}

	local janitor = Janitor.new()
	local timeoutThread: thread?
	local maxLifetime = (fuseTime or profile.fuse or simulator.MAX_SIM_TIME) + 1.5
	timeoutThread = task.delay(maxLifetime, function()
		timeoutThread = nil
		removeProjectile(id)
	end)
	janitor:Add(function()
		local th = timeoutThread
		if th then
			timeoutThread = nil
			task.cancel(th)
		end
	end, true)
	GrenadeController._projectileJanitors[id] = janitor

	grenadeState.activeProjectiles((Sift.Dictionary.set :: any)(peek(grenadeState.activeProjectiles), id, entry))
end)

local onProjectileBounce = LPH_NO_VIRTUALIZE(function(data: any): ()
	if typeof(data) ~= "table" then
		return
	end
	local id = data.Id
	if type(id) ~= "string" then
		return
	end

	local current = peek(grenadeState.activeProjectiles)
	local entry = current[id]
	if not entry or entry.resolved then
		return
	end

	local pos = data.Position
	local vel = data.Velocity
	if typeof(pos) ~= "Vector3" or typeof(vel) ~= "Vector3" then
		return
	end

	local profile = simulator.PROFILES[entry.weapon]
	if not profile then
		return
	end

	local elapsed = os.clock() - entry.startedAt
	local remainingFuse: number? = (entry.fuseTime and math.max(0, entry.fuseTime - elapsed) or nil)
	local remainingMinFuse: number? = (profile.minFuse and math.max(0, profile.minFuse - elapsed) or nil)

	local params = makeRaycastParams()
	local result = simulator.simulate(
		pos,
		vel,
		false,
		profile.radius,
		remainingFuse,
		remainingMinFuse,
		profile.floorExplode,
		params
	)

	local updated: grenadeState.ProjectileEntry = {
		id = entry.id,
		weapon = entry.weapon,
		pathPoints = result.points,
		bounceIndices = result.bounceIndices,
		landingPosition = result.points[#result.points],
		detonateAt = os.clock() + result.detonateTime,
		startedAt = entry.startedAt,
		fuseTime = entry.fuseTime,
		leavesFire = entry.leavesFire,
		resolved = false,
		team = entry.team,
		isFriendly = entry.isFriendly,
	}

	grenadeState.activeProjectiles((Sift.Dictionary.set :: any)(current, id, updated))
end)

local FIRE_GRENADES: { [string]: boolean } = {
	["Molotov"] = true,
	["Incendiary Grenade"] = true,
}

local function onProjectileResolve(data: any): ()
	if typeof(data) ~= "table" then
		return
	end
	local id = data.Id
	if type(id) ~= "string" then
		return
	end

	local current = peek(grenadeState.activeProjectiles)
	local entry = current[id]
	if entry then
		local position = (typeof(data.Position) == "Vector3" and data.Position :: Vector3 or entry.landingPosition)
		local pending: PendingTeam = {
			position = position,
			team = entry.team,
			isFriendly = entry.isFriendly == true,
			capturedAt = os.clock(),
		}
		if FIRE_GRENADES[entry.weapon] then
			table.insert(GrenadeController._pendingFireTeams, pending)
		elseif entry.weapon == "Smoke Grenade" then
			table.insert(GrenadeController._pendingSmokeTeams, pending)
		end
	end

	removeProjectile(id)
end

local function hookProjectileRemotes(): ()
	local projectile = NetworkController.GetPacketGroup("Projectile")
	if not projectile then
		return
	end

	local spawnPacket = projectile.Spawn
	local bouncePacket = projectile.Bounce
	local resolvePacket = projectile.Resolve

	if spawnPacket and type(spawnPacket.Listen) == "function" then
		local disconnect = spawnPacket.Listen(onProjectileSpawn)
		if type(disconnect) == "function" then
			GrenadeController._janitor:Add(disconnect, true)
		end
	end
	if bouncePacket and type(bouncePacket.Listen) == "function" then
		local disconnect = bouncePacket.Listen(onProjectileBounce)
		if type(disconnect) == "function" then
			GrenadeController._janitor:Add(disconnect, true)
		end
	end
	if resolvePacket and type(resolvePacket.Listen) == "function" then
		local disconnect = resolvePacket.Listen(onProjectileResolve)
		if type(disconnect) == "function" then
			GrenadeController._janitor:Add(disconnect, true)
		end
	end
end

local function onSmokeAdded(child: Instance): ()
	local smokeId = child.Name:match("VoxelSmoke_(.+)")
	local meta = smokeId and GrenadeController._pendingSmokeMeta[smokeId] or nil

	local voxels = {}

	local function onVoxelAdded(voxel: Instance): ()
		voxels[#voxels + 1] = voxel
	end

	for _, voxel in next, child:GetChildren() do
		if voxel.Name == "SmokeVoxel" then
			onVoxelAdded(voxel)
		end
	end

	child.ChildAdded:Connect(function(voxel: Instance)
		if voxel.Name == "SmokeVoxel" then
			onVoxelAdded(voxel)
		end
	end)

	child:GetPropertyChangedSignal("Parent"):Connect(function()
		if child.Parent == nil then
			grenadeState.activeSmokes((Sift.Dictionary.removeKey :: any)(peek(grenadeState.activeSmokes), child.Name))
		end
	end)

	local smokePosition = meta and meta.position or nil
	local team: string?, isFriendly: boolean = nil, false
	local resolvedPosition: Vector3? = nil
	if smokePosition then
		team, isFriendly, resolvedPosition = consumePendingTeam(GrenadeController._pendingSmokeTeams, smokePosition)
	end

	local smokeData: grenadeState.SmokeEntry = {
		voxels = voxels,
		smokeId = smokeId,
		position = resolvedPosition or smokePosition,
		duration = meta and meta.duration or nil,
		deployTime = meta and meta.deployTime or nil,
		startedAt = meta and meta.startedAt or nil,
		team = team,
		isFriendly = isFriendly,
	}

	grenadeState.activeSmokes((Sift.Dictionary.set :: any)(peek(grenadeState.activeSmokes), child.Name, smokeData))

	if smokeId then
		GrenadeController._pendingSmokeMeta[smokeId] = nil
	end
end

local function onFireAdded(child: Instance): ()
	local fireId = child.Name:match("VoxelFire_(.+)")
	local meta = fireId and GrenadeController._pendingFireMeta[fireId] or nil

	local voxels = {}

	local function onVoxelAdded(voxel: Instance): ()
		voxels[#voxels + 1] = voxel
	end

	for _, voxel in next, child:GetChildren() do
		if voxel.Name:find("FireVoxel") then
			onVoxelAdded(voxel)
		end
	end

	child.ChildAdded:Connect(function(voxel: Instance)
		if voxel.Name:find("FireVoxel") then
			onVoxelAdded(voxel)
		end
	end)

	child:GetPropertyChangedSignal("Parent"):Connect(function()
		if child.Parent == nil then
			grenadeState.activeFires((Sift.Dictionary.removeKey :: any)(peek(grenadeState.activeFires), child.Name))
		end
	end)

	local firePosition = meta and meta.position or nil
	local team: string?, isFriendly: boolean = nil, false
	local resolvedPosition: Vector3? = nil
	if firePosition then
		team, isFriendly, resolvedPosition = consumePendingTeam(GrenadeController._pendingFireTeams, firePosition)
	end

	local fireData: grenadeState.FireEntry = {
		voxels = voxels,
		fireId = fireId,
		position = resolvedPosition or firePosition,
		duration = meta and meta.duration or nil,
		startedAt = meta and meta.startedAt or nil,
		team = team,
		isFriendly = isFriendly,
	}

	grenadeState.activeFires((Sift.Dictionary.set :: any)(peek(grenadeState.activeFires), child.Name, fireData))

	if fireId then
		GrenadeController._pendingFireMeta[fireId] = nil
	end
end

local function hookFireCreate(): ()
	local fireClass = ModuleController.GetModule("FireClass")
	if not fireClass then
		return
	end

	local original = rawget(fireClass, "Create")
	if type(original) ~= "function" then
		return
	end

	GrenadeController._fireHookTarget = original
	GrenadeController._oldFireCreate = hook.add(original, function(payload: any)
		setthreadidentity(8)
		if type(payload) == "table" and type(payload.FireId) == "string" then
			GrenadeController._pendingFireMeta[payload.FireId] = {
				duration = tonumber(payload.Duration) or 0,
				position = typeof(payload.Position) == "Vector3" and payload.Position or Vector3.zero,
				startedAt = os.clock(),
			}
		end
		setthreadidentity(2)
		return (GrenadeController._oldFireCreate :: any)(payload)
	end)
end

local averageVoxelPosition = LPH_NO_VIRTUALIZE(function(voxels: any): Vector3?
	if type(voxels) ~= "table" then
		return nil
	end
	local sum = Vector3.zero
	local count = 0
	for _, v in next, voxels do
		if type(v) == "table" and typeof(v.Position) == "Vector3" then
			sum += v.Position
			count += 1
		end
	end
	if count == 0 then
		return nil
	end
	return sum / count
end)

local function hookSmokeCreate(): ()
	local smokeClass = ModuleController.GetModule("SmokeClass")
	if not smokeClass then
		return
	end

	local original = rawget(smokeClass, "Create")
	if type(original) ~= "function" then
		return
	end

	GrenadeController._smokeHookTarget = original
	GrenadeController._oldSmokeCreate = hook.add(original, function(payload: any)
		setthreadidentity(8)
		if type(payload) == "table" and type(payload.SmokeId) == "string" then
			GrenadeController._pendingSmokeMeta[payload.SmokeId] = {
				duration = tonumber(payload.Duration) or 0,
				deployTime = tonumber(payload.DeployTime) or 0,
				position = averageVoxelPosition(payload.Voxels) or Vector3.zero,
				startedAt = os.clock(),
			}
		end
		setthreadidentity(2)
		return (GrenadeController._oldSmokeCreate :: any)(payload)
	end)
end

function GrenadeController.new(): GrenadeController
	local smokeClass = ModuleController.GetModule("SmokeClass")

	local doesRayIntersect = rawget(smokeClass, "DoesRayIntersectActiveSmoke") :: any
	local internalSmokeVoxels = if type(doesRayIntersect) == "function" then debug.getupvalue(doesRayIntersect, 1) else nil
	if type(internalSmokeVoxels) ~= "table" then
		local create = rawget(smokeClass, "Create") :: any
		for _, value in next, debug.getupvalues(create) do
			if type(value) == "function" then
				local candidate = debug.getupvalue(value, 2)
				if type(candidate) == "table" then
					internalSmokeVoxels = candidate
					break
				end
			end
		end
	end
	GrenadeController._internalSmokeVoxels = (internalSmokeVoxels or {}) :: { [Part]: SmokeVoxelData }
	hookFireCreate()
	hookSmokeCreate()
	hookProjectileRemotes()

	GrenadeController._janitor:Add(
		Debris.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(child: Instance)
			local name = child.Name
			if name:find("VoxelSmoke") then
				onSmokeAdded(child)
			elseif name:find("VoxelFire") then
				onFireAdded(child)
			end
		end)),
		"Disconnect"
	)

	return GrenadeController
end

function GrenadeController.GetInternalSmokeVoxels(): { [Part]: SmokeVoxelData }
	return GrenadeController._internalSmokeVoxels
end

function GrenadeController.Destroy(): ()
	GrenadeController._janitor:Destroy()
	GrenadeController._janitor = Janitor.new()

	if GrenadeController._fireHookTarget then
		hook.restore(GrenadeController._fireHookTarget)
		GrenadeController._fireHookTarget = nil
	end
	GrenadeController._oldFireCreate = nil

	if GrenadeController._smokeHookTarget then
		hook.restore(GrenadeController._smokeHookTarget)
		GrenadeController._smokeHookTarget = nil
	end
	GrenadeController._oldSmokeCreate = nil

	GrenadeController._pendingFireMeta = {}
	GrenadeController._pendingSmokeMeta = {}
	GrenadeController._pendingFireTeams = {}
	GrenadeController._pendingSmokeTeams = {}
	for id, janitor in next, GrenadeController._projectileJanitors do
		janitor:Destroy()
		GrenadeController._projectileJanitors[id] = nil
	end
	grenadeState.activeProjectiles({})
end

export type GrenadeController = typeof(GrenadeController)
export type SmokeVoxelData = {
	emitConnection: RBXScriptConnection?,
	isActive: boolean,
	lastEmitTime: number,
	lifetimeExtended: boolean,
	activatedTime: number,
	emissionStopped: boolean,
	totalParticlesEmitted: number,
	voxel: Part,
	emitters: {
		[number]: ParticleEmitter,
	},
	scaleFactor: number,
	teamColor: Color3,
}
return GrenadeController
