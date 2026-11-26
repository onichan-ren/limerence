local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local worldRaycast = {}

local MAX_PENETRATIONS = 8

local _params = RaycastParams.new()
_params.FilterType = Enum.RaycastFilterType.Exclude
_params.IgnoreWater = true
_params.RespectCanCollide = false

local isPenetrable = LPH_NO_VIRTUALIZE(function(instance: BasePart): boolean
	return instance:HasTag("Water Part")
		or instance:HasTag("Bullets Penetrate")
		or instance:HasTag("World Mesh")
		or (instance.Transparency == 1 and instance.CanCollide == false)
end)

worldRaycast.isPenetrable = isPenetrable

worldRaycast.clearLineOfSight = LPH_NO_VIRTUALIZE(
	function(origin: Vector3, target: Vector3, ignore: { Instance }): boolean
		local toTarget = target - origin
		local distance = toTarget.Magnitude
		if distance < 1e-3 then
			return true
		end

		_params.FilterDescendantsInstances = ignore
		local current = origin
		for _ = 1, MAX_PENETRATIONS do
			local segment = target - current
			local result = Workspace:Raycast(current, segment, _params)
			if not result then
				return true
			end
			if not isPenetrable(result.Instance) then
				return false
			end
			_params:AddToFilter(result.Instance)
			current = result.Position + segment.Unit * 0.01
		end
		return false
	end
)

worldRaycast.losBlocker = LPH_NO_VIRTUALIZE(
	function(origin: Vector3, target: Vector3, ignore: { Instance }): (boolean, Instance?)
		local toTarget = target - origin
		if toTarget.Magnitude < 1e-3 then
			return true, nil
		end

		_params.FilterDescendantsInstances = ignore
		local current = origin
		for _ = 1, MAX_PENETRATIONS do
			local segment = target - current
			local result = Workspace:Raycast(current, segment, _params)
			if not result then
				return true, nil
			end
			local instance = result.Instance
			if not isPenetrable(instance) then
				return false, instance
			end
			_params:AddToFilter(instance)
			current = result.Position + segment.Unit * 0.01
		end
		return false, nil
	end
)

return worldRaycast
