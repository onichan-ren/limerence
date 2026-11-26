local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local SEGMENT_LENGTH = 16
local MAX_STEPS = 96

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local ignoreList = {}
local effects = Workspace:FindFirstChild("Effects")

local tracerTrajectory = {}

tracerTrajectory.compute = LPH_NO_VIRTUALIZE(
	function(
		origin: Vector3,
		direction: Vector3,
		speed: number,
		gravity: number,
		ignore: Instance?,
		maxDistance: number?
	): { Vector3 }
		table.clear(ignoreList)
		if ignore then
			ignoreList[#ignoreList + 1] = ignore
		end
		if effects then
			ignoreList[#ignoreList + 1] = effects
		end
		params.FilterDescendantsInstances = ignoreList

		local limit = maxDistance or 500
		local points = { origin }
		local previous = origin
		local elapsed = 0
		local traveled = 0
		local step = math.max(SEGMENT_LENGTH / speed, 1 / 120)

		for _ = 1, MAX_STEPS do
			elapsed += step
			local position = origin + direction * (speed * elapsed) + Vector3.new(0, gravity * elapsed * elapsed, 0)
			local segment = position - previous
			local result = Workspace:Raycast(previous, segment, params)
			if result then
				points[#points + 1] = result.Position
				return points
			end

			points[#points + 1] = position
			traveled += segment.Magnitude
			previous = position
			if traveled >= limit then
				return points
			end
		end

		return points
	end
)

return tracerTrajectory
