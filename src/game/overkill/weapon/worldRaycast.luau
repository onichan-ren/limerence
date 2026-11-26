local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local worldRaycast = {}

local sharedParams = RaycastParams.new()
sharedParams.FilterType = Enum.RaycastFilterType.Include
sharedParams.RespectCanCollide = true

local mapRef: Instance? = nil

local function ensureFilter(): ()
	if mapRef and mapRef.Parent then
		return
	end
	local world = Workspace:FindFirstChild("World")
	local map = world and world:FindFirstChild("Map")
	mapRef = map
	sharedParams.FilterDescendantsInstances = map and { map } or {}
end

worldRaycast.cast = LPH_NO_VIRTUALIZE(
	function(origin: Vector3, target: Vector3, _ignore: { Instance }?): RaycastResult?
		local direction = target - origin
		if direction.Magnitude < 1e-4 then
			return nil
		end
		ensureFilter()
		return Workspace:Raycast(origin, direction, sharedParams)
	end
) :: (origin: Vector3, target: Vector3, _ignore: { Instance }?) -> RaycastResult?

function worldRaycast.clearLineOfSight(origin: Vector3, target: Vector3, _ignore: { Instance }?): boolean
	return worldRaycast.cast(origin, target) == nil
end

return worldRaycast
