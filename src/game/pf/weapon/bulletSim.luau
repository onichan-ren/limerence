local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local localThirdPerson = require("@game/pf/thirdperson/localThirdPerson")

local bulletSim = {}

local DT = 1 / 20
local MAX_STEPS = 60
local MAX_RANGE = 5000
local EPSILON = 0.02

local IGNORE_NAMES = { "Ignore", "Debris", "Players" }

export type Trajectory = {
	points: { Vector3 },
	impacts: { Vector3 },
	blocked: boolean,
}

local function canPass(instance: BasePart): boolean
	return not instance.CanCollide or instance.Transparency >= 1
end

function bulletSim.defaultIgnore(): { Instance }
	local filter = { Workspace.CurrentCamera :: Instance, Workspace.Terrain :: Instance }
	for i = 1, #IGNORE_NAMES do
		local found = Workspace:FindFirstChild(IGNORE_NAMES[i])
		if found then
			filter[#filter + 1] = found
		end
	end
	return filter
end

bulletSim.simulate = LPH_NO_VIRTUALIZE(function(
	origin: Vector3,
	velocity: Vector3,
	acceleration: Vector3,
	penetrationDepth: number,
	ignore: { Instance }
): Trajectory
	local points = { origin }
	local impacts: { Vector3 } = {}
	local position = origin
	local pen = penetrationDepth or 0

	local filter = table.clone(ignore)
	local fakeBody = localThirdPerson.getCharacterModel()
	if fakeBody then
		filter[#filter + 1] = fakeBody
	end
	local fakeWeapon = localThirdPerson.getWeaponModel()
	if fakeWeapon then
		filter[#filter + 1] = fakeWeapon
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = filter

	local exitParams = RaycastParams.new()
	exitParams.FilterType = Enum.RaycastFilterType.Include
	exitParams.IgnoreWater = true

	local traveled = 0
	local blocked = false

	for _ = 1, MAX_STEPS do
		local displacement = DT * velocity + (DT * DT / 2) * acceleration
		if displacement.Magnitude < 1e-3 then
			break
		end

		local unit = displacement.Unit
		local result = Workspace:Raycast(position, displacement, params)
		while result and canPass(result.Instance) do
			filter[#filter + 1] = result.Instance
			params.FilterDescendantsInstances = filter
			result = Workspace:Raycast(position, displacement, params)
		end

		if not result then
			position += displacement
			velocity += DT * acceleration
			points[#points + 1] = position
			traveled += displacement.Magnitude
			if traveled >= MAX_RANGE then
				break
			end
		else
			local instance = result.Instance
			local entry = result.Position
			points[#points + 1] = entry
			impacts[#impacts + 1] = entry

			local probe = unit * (instance.Size.Magnitude + 1)
			exitParams.FilterDescendantsInstances = { instance }
			local back = Workspace:Raycast(entry + probe, -probe, exitParams)
			local thickness = back and unit:Dot(back.Position - entry) or nil

			if thickness and thickness >= pen then
				blocked = true
				break
			end
			if thickness then
				pen -= thickness
			end

			filter[#filter + 1] = instance
			params.FilterDescendantsInstances = filter
			position = entry + EPSILON * unit
		end
	end

	return { points = points, impacts = impacts, blocked = blocked }
end)

return bulletSim
