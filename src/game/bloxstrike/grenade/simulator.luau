local STEP = 0.0078125
local MAX_SIM_TIME = 10
local MAX_SEGMENTS = 640
local STOP_EPS = 0.0076388888888888895
local SLEEP_SQ = 2.3341049382716053
local GRAVITY_Y = -23.83333396911621
local THROW_POWER_MAX = 57.29166666666667
local VELOCITY_SCALE = 0.58
local JUMP_THROW_THRESHOLD = 5
local MAX_THROW_SPEED = 50
local MAX_JUMP_THROW_SPEED = 62
local PLAYER_VELOCITY_INHERITANCE = 1.5
local RANGE_SCALE = 1.45

local V3_ZERO = Vector3.zero
local V3_GROUND_RAY = Vector3.new(0, -0.2, 0)
local V3_DEFAULT_FLAT = Vector3.new(0, 0, -1)
local V3_JUMP_VERT = Vector3.new(0, 20, 0)

local COLLISION_SKIN_AXES = {
	{ 1, 0, 0 },
	{ -1, 0, 0 },
	{ 0, 1, 0 },
	{ 0, -1, 0 },
	{ 0, 0, 1 },
	{ 0, 0, -1 },
}

export type ThrowType = "Far" | "Near"

export type GrenadeProfile = {
	leavesFire: boolean,
	minFuse: number?,
	floorExplode: boolean,
	radius: number,
	fuse: number?,
}

export type SimulationResult = {
	points: { Vector3 },
	bounceIndices: { number },
	detonateTime: number,
	endReason: string,
}

local simulator = {}

simulator.STEP = STEP
simulator.MAX_SIM_TIME = MAX_SIM_TIME

simulator.PROFILES = {
	["HE Grenade"]         = { leavesFire = false, minFuse = nil, floorExplode = false, radius = 0.49748870730400085, fuse = 1.6 },
	["Flashbang"]          = { leavesFire = false, minFuse = nil, floorExplode = false, radius = 0.613989531993866, fuse = 1.5 },
	["Smoke Grenade"]      = { leavesFire = false, minFuse = nil, floorExplode = false, radius = 0.5661420226097107, fuse = nil },
	["Molotov"]            = { leavesFire = true,  minFuse = 0.1, floorExplode = true,  radius = 0.9210354089736938, fuse = 2.4 },
	["Incendiary Grenade"] = { leavesFire = true,  minFuse = 0.1, floorExplode = true,  radius = 0.9210354089736938, fuse = 2.4 },
	["Decoy Grenade"]      = { leavesFire = false, minFuse = nil, floorExplode = false, radius = 0.5, fuse = 15.0 },
} :: { [string]: GrenadeProfile }

local clipVelocity = LPH_NO_VIRTUALIZE(function(vel: Vector3, normal: Vector3, overbounce: number): Vector3
	local d = (vel.X * normal.X + vel.Y * normal.Y + vel.Z * normal.Z) * overbounce
	local x = vel.X - normal.X * d
	local y = vel.Y - normal.Y * d
	local z = vel.Z - normal.Z * d
	if math.abs(x) < STOP_EPS then x = 0 end
	if math.abs(y) < STOP_EPS then y = 0 end
	if math.abs(z) < STOP_EPS then z = 0 end
	return Vector3.new(x, y, z)
end)

local integrate = LPH_NO_VIRTUALIZE(function(pos: Vector3, vel: Vector3, dt: number, grounded: boolean): (Vector3, Vector3)
	local vx, vy, vz = vel.X, vel.Y, vel.Z
	if grounded then
		return Vector3.new(pos.X + vx * dt, pos.Y + vy * dt, pos.Z + vz * dt), vel
	end
	local nvy = vy + dt * GRAVITY_Y
	local avgY = (vy + nvy) * 0.5
	return Vector3.new(pos.X + vx * dt, pos.Y + avgY * dt, pos.Z + vz * dt), Vector3.new(vx, nvy, vz)
end)

local detectCollision = LPH_NO_VIRTUALIZE(function(from: Vector3, to: Vector3, radius: number, params: RaycastParams): (Vector3?, Vector3?, boolean)
	local dirX = to.X - from.X
	local dirY = to.Y - from.Y
	local dirZ = to.Z - from.Z
	local mag = math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
	if mag < 0.001 then
		return nil, nil, false
	end

	local dir = Vector3.new(dirX, dirY, dirZ)

	local best = workspace:Raycast(from, dir, params)
	if not best then
		return nil, nil, false
	end

	local skin = radius * 0.01
	local bestDist = best.Distance
	local offX, offY, offZ = 0, 0, 0

	for i = 1, 6 do
		local axis = COLLISION_SKIN_AXES[i]
		local ax, ay, az = axis[1] * skin, axis[2] * skin, axis[3] * skin
		local res = workspace:Raycast(Vector3.new(from.X + ax, from.Y + ay, from.Z + az), dir, params)
		if res and res.Distance < bestDist then
			best = res
			bestDist = res.Distance
			offX, offY, offZ = ax, ay, az
		end
	end

	local hit = best.Position
	local px, py, pz = hit.X - offX, hit.Y - offY, hit.Z - offZ
	local ddx, ddy, ddz = px - from.X, py - from.Y, pz - from.Z
	local adjDist = math.sqrt(ddx * ddx + ddy * ddy + ddz * ddz)
	if adjDist > mag + skin + 0.1 then
		return nil, nil, false
	end

	local instance = best.Instance
	local parent = instance and instance.Parent
	local isPlayer = parent ~= nil and parent:FindFirstChildOfClass("Humanoid") ~= nil

	return Vector3.new(px, py, pz), best.Normal, isPlayer
end)

local function checkGrounded(pos: Vector3, params: RaycastParams): boolean
	return workspace:Raycast(pos, V3_GROUND_RAY, params) ~= nil
end

simulator.simulate = LPH_NO_VIRTUALIZE(function(
	startPos: Vector3,
	startVel: Vector3,
	isJumpThrow: boolean,
	radius: number,
	fuseTime: number?,
	minFuse: number?,
	floorExplode: boolean,
	params: RaycastParams
): SimulationResult
	local pos = startPos
	local vel = startVel
	local grounded = false
	local hasTouched = false
	local bounceCount = 0
	local simTime = 0
	local hasFuse = fuseTime ~= nil
	local fuseVal: number = fuseTime or 0
	local hasMinFuse = minFuse ~= nil
	local minFuseVal: number = minFuse or 0

	local points = table.create(MAX_SEGMENTS + 1)
	local bounceIndices = table.create(8)
	points[1] = pos
	local pointCount = 1

	for _ = 1, MAX_SEGMENTS do
		simTime += STEP

		if simTime >= MAX_SIM_TIME then
			return { points = points, bounceIndices = bounceIndices, detonateTime = simTime, endReason = "timeout" }
		end
		if hasFuse and simTime >= fuseVal then
			return { points = points, bounceIndices = bounceIndices, detonateTime = fuseVal, endReason = "fuse" }
		end
		if bounceCount >= 20 then
			return { points = points, bounceIndices = bounceIndices, detonateTime = simTime, endReason = "rest" }
		end

		local newPos, newVel = integrate(pos, vel, STEP, grounded)
		local colPos, colNormal, isPlayer = detectCollision(pos, newPos, radius, params)

		if colPos and colNormal then
			local elast = (isJumpThrow and 0.32 or 0.4) * (isPlayer and 0.3 or 1)
			if elast > 0.9 then elast = 0.9 elseif elast < 0 then elast = 0 end
			local bounced = clipVelocity(newVel, colNormal, 2) * elast

			if colNormal.Y > 0.7 and (bounced.X * bounced.X + bounced.Y * bounced.Y + bounced.Z * bounced.Z) < SLEEP_SQ then
				bounced = V3_ZERO
			end

			pos = colPos + colNormal * 0.05
			vel = bounced
			bounceCount += 1
			hasTouched = true

			pointCount += 1
			points[pointCount] = pos
			bounceIndices[#bounceIndices + 1] = pointCount

			if floorExplode and colNormal.Y > 0.7 then
				if not hasMinFuse or simTime >= minFuseVal then
					return { points = points, bounceIndices = bounceIndices, detonateTime = simTime, endReason = "floor_impact" }
				end
			end
		else
			pos = newPos
			vel = newVel
			pointCount += 1
			points[pointCount] = pos
		end

		if hasTouched then
			grounded = checkGrounded(pos, params)
			if grounded and not hasFuse and (vel.X * vel.X + vel.Y * vel.Y + vel.Z * vel.Z) < SLEEP_SQ then
				return { points = points, bounceIndices = bounceIndices, detonateTime = simTime, endReason = "rest" }
			end
		else
			grounded = false
		end
	end

	return { points = points, bounceIndices = bounceIndices, detonateTime = simTime, endReason = "maxiter" }
end)

simulator.calcThrowParams = LPH_NO_VIRTUALIZE(function(rootPos: Vector3, lookVec: Vector3, throwType: ThrowType): (Vector3, Vector3)
	local isNear = throwType == "Near"
	local upBias = (isNear and 0.04 or 0.06) * math.clamp(RANGE_SCALE, 0.8, 1.2)
	local fwdOff = (isNear and 1.35 * 0.55 or 1.35)
	local hOff = (isNear and 2.4 * 0.8 or 2.5)

	if isNear then
		upBias += 0.08
	end

	local dir = Vector3.new(lookVec.X, lookVec.Y + upBias, lookVec.Z).Unit
	local fx, fz = lookVec.X, lookVec.Z
	local flatMag = math.sqrt(fx * fx + fz * fz)
	local flat: Vector3
	if flatMag < 0.01 then
		flat = V3_DEFAULT_FLAT
	else
		flat = Vector3.new(fx / flatMag, 0, fz / flatMag)
	end

	local origin = Vector3.new(rootPos.X + flat.X * fwdOff, rootPos.Y + hOff, rootPos.Z + flat.Z * fwdOff)
	return origin, dir
end)

simulator.calcInitialVelocity = LPH_NO_VIRTUALIZE(function(dir: Vector3, throwType: ThrowType, playerVel: Vector3): Vector3
	local throwPower = (((throwType == "Far" and 1 or 0)) * 0.7 + 0.3) * THROW_POWER_MAX * VELOCITY_SCALE * RANGE_SCALE
	local isJump = playerVel.Y > JUMP_THROW_THRESHOLD
	local dampening = 1

	local vertAdd: Vector3
	if isJump then
		vertAdd = V3_JUMP_VERT
	else
		vertAdd = Vector3.new(0, playerVel.Y * 2 * VELOCITY_SCALE, 0)
	end

	local throwDir: Vector3
	if isJump then
		throwDir = Vector3.new(dir.X * dampening, dir.Y, dir.Z * dampening).Unit
	else
		throwDir = dir
	end

	local baseVel = throwDir * throwPower + vertAdd
	local scaledDir = Vector3.new(dir.X * ((isJump and dampening or 1)), dir.Y, dir.Z * ((isJump and dampening or 1))).Unit
	local upVel = scaledDir * throwPower * 0.15 + Vector3.new(0, 6.5 * VELOCITY_SCALE * RANGE_SCALE, 0)
	local combined = baseVel + upVel

	local cap = (isJump and ((dir.Y - 0.4) * 20 + MAX_JUMP_THROW_SPEED) or MAX_THROW_SPEED)
	if combined.Magnitude > cap then
		combined = combined.Unit * cap
	end

	local pvelScale = (isJump and dampening or 1)
	combined += Vector3.new(playerVel.X, 0, playerVel.Z) * PLAYER_VELOCITY_INHERITANCE * pvelScale

	return combined
end)

function simulator.isJumpThrow(playerVel: Vector3): boolean
	return playerVel.Y > JUMP_THROW_THRESHOLD
end

return simulator
