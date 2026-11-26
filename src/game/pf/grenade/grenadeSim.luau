local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local GRAVITY = Vector3.new(0, -80, 0)
local ELASTICITY = 0.2
local FRICTION = 0.08
local STEP = 1 / 60
local MAX_STEPS = 90

local grenadeSim = {}

grenadeSim.simulate = LPH_NO_VIRTUALIZE(function(origin: Vector3, velocity: Vector3, fuse: number, params: RaycastParams): { Vector3 }
	local points: { Vector3 } = { origin }
	local pos = origin
	local vel = velocity
	local elapsed = 0
	for _ = 1, MAX_STEPS do
		if elapsed >= fuse then
			break
		end
		vel += GRAVITY * STEP
		local delta = vel * STEP
		local result = Workspace:Raycast(pos, delta, params)
		if result then
			local normal = result.Normal
			pos = result.Position + normal * 0.05
			local vn = vel:Dot(normal)
			vel = (vel - (1 + ELASTICITY) * vn * normal) * (1 - FRICTION)
		else
			pos += delta
		end
		points[#points + 1] = pos
		elapsed += STEP
	end
	return points
end)

return grenadeSim
