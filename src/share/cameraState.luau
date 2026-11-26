local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local tan = math.tan
local rad = math.rad
local min = math.min

local camera: Camera? = Workspace.CurrentCamera
local focalY = 0

local fovConn: RBXScriptConnection? = nil
local viewportConn: RBXScriptConnection? = nil

local recompute = LPH_NO_VIRTUALIZE(function(): ()
	local cam = camera
	if not cam then
		focalY = 0
		return
	end
	local fov = cam.FieldOfView
	if fov <= 0 then
		focalY = 0
		return
	end
	focalY = cam.ViewportSize.Y * 0.5 / tan(rad(min(fov * 0.5, 89.5)))
end)

local function rebind(): ()
	if fovConn then
		fovConn:Disconnect()
		fovConn = nil
	end
	if viewportConn then
		viewportConn:Disconnect()
		viewportConn = nil
	end
	local cam = camera
	if cam then
		fovConn = cam:GetPropertyChangedSignal("FieldOfView"):Connect(recompute)
		viewportConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(recompute)
	end
	recompute()
end

rebind()

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(LPH_NO_VIRTUALIZE(function(): ()
	camera = Workspace.CurrentCamera
	rebind()
end))

local cameraState = {}

cameraState.FovToPixels = LPH_NO_VIRTUALIZE(function(fovDegrees: number): number
	if focalY <= 0 then
		return 0
	end
	return focalY * tan(rad(min(fovDegrees * 0.5, 89.5)))
end)

cameraState.GetFocalY = LPH_NO_VIRTUALIZE(function(): number
	return focalY
end)

cameraState.GetCamera = LPH_NO_VIRTUALIZE(function(): Camera?
	return camera
end)

return cameraState
