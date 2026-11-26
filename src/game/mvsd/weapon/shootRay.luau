local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local Charm = require("@pkg/Charm")
local ClientState = require("@game/mvsd/client/clientState")

local peek = Charm.peek

local MAX_RANGE = 2048

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local filterCharacter: Model? = nil
local filter: { Instance } = {}

local shootRay = {}

shootRay.Origin = LPH_NO_VIRTUALIZE(function(): Vector3?
	local head = peek(ClientState.parts).Head :: BasePart?
	if not head or head.Parent == nil then
		return nil
	end
	local size = head.Size
	return (head.CFrame * CFrame.new(0, size.Y * 0.5, size.Z * 0.5)).Position
end)

shootRay.Landing = LPH_NO_VIRTUALIZE(function(origin: Vector3): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local character = peek(ClientState.character)
	if character ~= filterCharacter then
		filterCharacter = character
		table.clear(filter)
		if character then
			filter[1] = character
		end
		params.FilterDescendantsInstances = filter
	end

	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local screenHit = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RANGE, params)
	local aimPoint = screenHit and screenHit.Position or (ray.Origin + ray.Direction * MAX_RANGE)

	local originHit = Workspace:Raycast(origin, aimPoint - origin, params)
	return originHit and originHit.Position or aimPoint
end)

return shootRay
