local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local clientState = require("@game/op1/client/clientState")
local originState = require("@game/universal/feature/visual/crosshair/originState")

local peek = Charm.peek

local RANGE = 5000
local CAMERA_FORWARD = 2

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local filter: { Instance } = {}

local function muzzleCFrame(charObject: any): CFrame?
	local equipped = charObject and charObject.values and charObject.values.equipped
	local shot = type(equipped) == "table" and equipped.shot or nil
	if typeof(shot) == "Instance" and (shot :: Instance):IsA("BasePart") then
		return (shot :: BasePart).CFrame
	end
	return nil
end

local function muzzlePosition(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local charObject = peek(clientState.charObject)
	local camDir = camera.CFrame.LookVector
	local origin: Vector3
	local dir: Vector3

	local muzzle = muzzleCFrame(charObject)
	if muzzle then
		origin = muzzle.Position
		local barrelDir = muzzle.LookVector
		dir = barrelDir:Dot(camDir) > 0.5 and barrelDir or camDir
	else
		dir = camDir
		origin = camera.CFrame.Position + camDir * CAMERA_FORWARD
	end

	table.clear(filter)
	filter[1] = camera

	local viewmodels = charObject and charObject.values and charObject.values.viewmodels
	if viewmodels then
		filter[#filter + 1] = viewmodels
	end
	local character = peek(clientState.character)
	if character then
		filter[#filter + 1] = character
	end
	params.FilterDescendantsInstances = filter

	local result = Workspace:Raycast(origin, dir * RANGE, params)
	if result then
		return result.Position
	end
	return nil
end

local op1MuzzleOrigin = {}

function op1MuzzleOrigin.Setup(): ()
	originState.SetMuzzlePositionProvider(muzzlePosition)
end

function op1MuzzleOrigin.Destroy(): ()
	originState.SetMuzzlePositionProvider(nil)
end

return op1MuzzleOrigin
