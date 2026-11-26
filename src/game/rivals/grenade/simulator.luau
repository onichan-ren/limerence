local STEP = 0.0078125
local MAX_SIM_TIME = 10
local MAX_SEGMENTS = 220
local STOP_EPS = 0.0076388888888888895
local SLEEP_SQ = 2.3341049382716053
local GRAVITY_Y = -23.833334

local V3_ZERO = Vector3.zero
local V3_GROUND_RAY = Vector3.new(0, -0.2, 0)
local OFFSET_DIRECTIONS = {
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
}

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
	["Grenade"] = { leavesFire = false, minFuse = nil, floorExplode = false, radius = 0.15, fuse = 2.0 },
	["Flashbang"] = { leavesFire = false, minFuse = nil, floorExplode = false, radius = 0.15, fuse = 1.5 },
	["Smoke Grenade"] = { leavesFire = false, minFuse = nil, floorExplode = false, radius = 0.15, fuse = 2.0 },
	["Molotov"] = { leavesFire = true, minFuse = 0.3, floorExplode = true, radius = 0.15, fuse = 2.0 },
} :: { [string]: GrenadeProfile }

local clipVelocity = LPH_NO_VIRTUALIZE(function(vel: Vector3, normal: Vector3, overbounce: number): Vector3
	local d = (vel.X * normal.X + vel.Y * normal.Y + vel.Z * normal.Z) * overbounce
	local x = vel.X - normal.X * d
	local y = vel.Y - normal.Y * d
	local z = vel.Z - normal.Z * d
	if math.abs(x) < STOP_EPS then
		x = 0
	end
	if math.abs(y) < STOP_EPS then
		y = 0
	end
	if math.abs(z) < STOP_EPS then
		z = 0
	end
	return Vector3.new(x, y, z)
end)

local integrate = LPH_NO_VIRTUALIZE(function(pos: Vector3, vel: Vector3, dt: number, grounded: boolean, gravityY: number): (Vector3, Vector3)
	local vx, vy, vz = vel.X, vel.Y, vel.Z
	if grounded then
		return Vector3.new(pos.X + vx * dt, pos.Y + vy * dt, pos.Z + vz * dt), vel
	end
	local nvy = vy + dt * gravityY
	local avgY = (vy + nvy) * 0.5
	return Vector3.new(pos.X + vx * dt, pos.Y + avgY * dt, pos.Z + vz * dt), Vector3.new(vx, nvy, vz)
end)

local detectCollision = LPH_NO_VIRTUALIZE(function(from: Vector3, to: Vector3, radius: number, params: RaycastParams, paddedOffsets: { Vector3 }): (Vector3?, Vector3?, boolean)
	local dirX = to.X - from.X
	local dirY = to.Y - from.Y
	local dirZ = to.Z - from.Z
	local mag = math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
	if mag < 0.001 then
		return nil, nil, false
	end

	local dir = Vector3.new(dirX, dirY, dirZ)
	local pad = radius * 0.01

	local bestDist = math.huge
	local bestResult: RaycastResult? = nil
	local bestOffset: Vector3 = V3_ZERO

	local r = workspace:Raycast(from, dir, params)
	if r then
		bestDist = r.Distance
		bestResult = r
	else
		for i = 1, 6 do
			local off = paddedOffsets[i]
			local r2 = workspace:Raycast(from + off, dir, params)
			if r2 and r2.Distance < bestDist then
				bestDist = r2.Distance
				bestResult = r2
				bestOffset = off
			end
		end

		if not bestResult then
			return nil, nil, false
		end
	end

	local hitPos = bestResult.Position - bestOffset
	local hdx = hitPos.X - from.X
	local hdy = hitPos.Y - from.Y
	local hdz = hitPos.Z - from.Z
	local dist = math.sqrt(hdx * hdx + hdy * hdy + hdz * hdz)
	if dist > mag + pad + 0.1 then
		return nil, nil, false
	end

	local instance = bestResult.Instance
	local parent = instance and instance.Parent
	local isPlayer = parent ~= nil and parent:FindFirstChildOfClass("Humanoid") ~= nil

	return hitPos, bestResult.Normal, isPlayer
end)

local function checkGrounded(pos: Vector3, params: RaycastParams): boolean
	return workspace:Raycast(pos, V3_GROUND_RAY, params) ~= nil
end

simulator.simulate = LPH_NO_VIRTUALIZE(function(
	startPos: Vector3,
	startVel: Vector3,
	radius: number,
	fuseTime: number?,
	minFuse: number?,
	floorExplode: boolean,
	params: RaycastParams,
	gravityY: number?
): SimulationResult
	local g = gravityY or GRAVITY_Y
	local pos = startPos
	local vel = startVel
	local grounded = false
	local hasTouched = false
	local bounceCount = 0
	local simTime = 0
	local hasFuse = fuseTime ~= nil
	local fuseVal = fuseTime or 0
	local hasMinFuse = minFuse ~= nil
	local minFuseVal = minFuse or 0

	local pad = radius * 0.01
	local paddedOffsets = {
		OFFSET_DIRECTIONS[1] * pad,
		OFFSET_DIRECTIONS[2] * pad,
		OFFSET_DIRECTIONS[3] * pad,
		OFFSET_DIRECTIONS[4] * pad,
		OFFSET_DIRECTIONS[5] * pad,
		OFFSET_DIRECTIONS[6] * pad,
	}

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

		local newPos, newVel = integrate(pos, vel, STEP, grounded, g)
		local colPos, colNormal, isPlayer = detectCollision(pos, newPos, radius, params, paddedOffsets)

		if colPos and colNormal then
			local elast = 0.4 * ((isPlayer and 0.3 or 1))
			if elast > 0.9 then
				elast = 0.9
			elseif elast < 0 then
				elast = 0
			end
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

return simulator
