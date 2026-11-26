local EDGE_PADDING = 24

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local worldToViewportPoint = Workspace.CurrentCamera.WorldToViewportPoint

local isWorldPosOnScreen = LPH_NO_VIRTUALIZE(function(camera: Camera, worldPos: Vector3): (boolean, number, number)
	local viewport = camera.ViewportSize
	local vx = viewport.X
	local vy = viewport.Y
	local screenPos = worldToViewportPoint(camera, worldPos)
	local sx = screenPos.X
	local sy = screenPos.Y
	if screenPos.Z <= 0 then
		return false, sx, sy
	end
	if sx < EDGE_PADDING or sx > vx - EDGE_PADDING or sy < EDGE_PADDING or sy > vy - EDGE_PADDING then
		return false, sx, sy
	end
	return true, sx, sy
end)

return {
	EDGE_PADDING = EDGE_PADDING,
	isWorldPosOnScreen = isWorldPosOnScreen,
}
