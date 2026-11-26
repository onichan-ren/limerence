local Workspace = cloneref(game:GetService("Workspace"))

local SAMPLE_STEP = 0.04
local MAX_POINTS = 240
local SIM_TIME = 6
local RADIUS_FACTOR = 0.3
local THROWN_GROUP = "thrown"

local ROLL_ELASTICITY = 0.35
local ROLL_FRICTION = 0.34
local ROLL_STOP_SPEED2 = 0.25
local CONTACT_SPEED = 8
local SURFACE_OFFSET = 0.05

local grenadeSim = {}

local function gravityVector(): Vector3
	return Vector3.new(0, -Workspace.Gravity, 0)
end

export type Result = {
	points: { Vector3 },
	landing: Vector3,
	normal: Vector3,
}

local sharedPoints: { Vector3 } = {}
local sharedResult: Result = { points = sharedPoints, landing = Vector3.zero, normal = Vector3.yAxis }

local fallbackParams = RaycastParams.new()
fallbackParams.FilterType = Enum.RaycastFilterType.Exclude

local sphereParams = RaycastParams.new()
sphereParams.FilterType = Enum.RaycastFilterType.Exclude
sphereParams.RespectCanCollide = true
sphereParams.CollisionGroup = THROWN_GROUP

local function fallback(startPos: Vector3, startVel: Vector3, ignore: { Instance }): Result
	local gravity = gravityVector()
	local points = sharedPoints
	table.clear(points)
	points[1] = startPos
	local landing = startPos
	local normal = Vector3.yAxis

	fallbackParams.FilterDescendantsInstances = ignore
	local params = fallbackParams

	local prev = startPos
	local t = SAMPLE_STEP

	while t <= SIM_TIME and #points < MAX_POINTS do
		local point = startPos + startVel * t + gravity * (0.5 * t * t)
		local hit = Workspace:Raycast(prev, point - prev, params)

		if hit then
			points[#points + 1] = hit.Position
			landing = hit.Position
			normal = hit.Normal
			break
		end

		points[#points + 1] = point
		prev = point
		t += SAMPLE_STEP
		landing = point
	end

	sharedResult.landing = landing
	sharedResult.normal = normal
	return sharedResult
end

local simulateSphere = LPH_NO_VIRTUALIZE(function(
	part: BasePart,
	startPos: Vector3,
	startVel: Vector3,
	ignore: { Instance },
	stopOnFirst: boolean
): Result
	local radius = math.max(part.Size.Magnitude * RADIUS_FACTOR, 0.05)
	local gravity = gravityVector()
	local frictionDrop = ROLL_FRICTION * gravity.Magnitude * SAMPLE_STEP

	sphereParams.FilterDescendantsInstances = ignore
	local params = sphereParams

	local points = sharedPoints
	table.clear(points)
	points[1] = startPos
	local pos = startPos
	local vel = startVel
	local landing = startPos
	local normal = Vector3.yAxis
	local t = 0
	local resting = 0

	while #points < MAX_POINTS and t < SIM_TIME do
		local delta = vel * SAMPLE_STEP + gravity * (0.5 * SAMPLE_STEP * SAMPLE_STEP)
		local moved = delta.Magnitude
		local hit = moved > 0 and Workspace:Spherecast(pos, radius, delta, params) or nil

		if hit then
			local n = hit.Normal

			if stopOnFirst then
				landing = hit.Position
				normal = n
				points[#points + 1] = pos + delta.Unit * hit.Distance
				break
			end

			local into = vel:Dot(n)

			if into < -CONTACT_SPEED then
				local reflected = vel - 2 * into * n
				local tangentialFactor = 1 - math.abs(vel.Unit:Dot(n))
				vel = reflected * ROLL_ELASTICITY + vel * ROLL_FRICTION * tangentialFactor
				resting = 0
			else
				local tangentVel = vel - into * n
				local speed = tangentVel.Magnitude
				if speed <= frictionDrop then
					vel = Vector3.zero
				else
					vel = tangentVel * ((speed - frictionDrop) / speed)
				end
				resting += SAMPLE_STEP
			end

			pos = pos + (moved > 0 and delta.Unit or Vector3.zero) * hit.Distance + n * SURFACE_OFFSET
			landing = hit.Position
			normal = n
		else
			vel += gravity * SAMPLE_STEP
			pos += delta
			landing = pos
			resting = 0
		end

		points[#points + 1] = pos
		t += SAMPLE_STEP

		if resting > 0 and vel:Dot(vel) < ROLL_STOP_SPEED2 then
			break
		end
	end

	sharedResult.landing = landing
	sharedResult.normal = normal
	return sharedResult
end)

grenadeSim.simulate = LPH_NO_VIRTUALIZE(function(
	part: BasePart?,
	startPos: Vector3,
	startVel: Vector3,
	ignore: { Instance },
	bounces: number
): Result
	if not part then
		return fallback(startPos, startVel, ignore)
	end

	return simulateSphere(part, startPos, startVel, ignore, bounces <= 0)
end)

return grenadeSim
