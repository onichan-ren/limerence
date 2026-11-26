local ballistics = {}

local PREDICTION_ITERATIONS = 5

local LEAD_DAMP_START = 0.35
local LEAD_DAMP_RATE = 0.4
local LEAD_DAMP_FLOOR = 0.6

local solveBallisticY = LPH_NO_VIRTUALIZE(
	function(shooterPos: Vector3, point: Vector3, projectileSpeed: number, projectileGravity: number): number
		local dx = point.X - shooterPos.X
		local dz = point.Z - shooterPos.Z
		local horizontalSq = dx * dx + dz * dz
		if horizontalSq < 1e-6 or projectileSpeed < 1e-6 then
			return point.Y
		end

		local h = point.Y - shooterPos.Y
		local c = projectileGravity / (projectileSpeed * projectileSpeed)
		if math.abs(c) < 1e-12 then
			return point.Y
		end

		local disc = 1 - 4 * c * (c * horizontalSq - h)
		if disc < 0 then
			return point.Y
		end

		return shooterPos.Y + (math.sqrt(disc) - 1) / (2 * c)
	end
)

ballistics.solveBallisticY = solveBallisticY

ballistics.predictAimPosition = LPH_NO_VIRTUALIZE(
	function(
		shooterPos: Vector3,
		targetPos: Vector3,
		vel: Vector3,
		airborne: boolean,
		targetGravity: number,
		speed: number,
		projGravity: number
	): (Vector3, number)
		local t = (targetPos - shooterPos).Magnitude / speed
		local aimPos = targetPos

		for _ = 1, PREDICTION_ITERATIONS do
			local leadScale = 1
			if t > LEAD_DAMP_START then
				leadScale = math.max(LEAD_DAMP_FLOOR, 1 - (t - LEAD_DAMP_START) * LEAD_DAMP_RATE)
			end

			local horizontalVel = Vector3.new(vel.X, 0, vel.Z) * leadScale
			local verticalVel = vel.Y * leadScale

			local verticalOffset = verticalVel * t
			if airborne then
				verticalOffset = verticalOffset - 0.5 * targetGravity * t * t
			end

			local futureTargetPos = targetPos + horizontalVel * t + Vector3.new(0, verticalOffset, 0)
			local aimY = solveBallisticY(shooterPos, futureTargetPos, speed, projGravity)
			aimPos = Vector3.new(futureTargetPos.X, aimY, futureTargetPos.Z)
			t = (aimPos - shooterPos).Magnitude / speed
		end

		return aimPos, t
	end
)

return ballistics
