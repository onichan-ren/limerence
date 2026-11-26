local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local ClientState = require("@game/overkill/client/clientState")
local ModuleController = require("@game/overkill/module/ModuleController")
local originState = require("@game/universal/feature/visual/crosshair/originState")

local peek = Charm.peek

local RANGE = 5000
local CAMERA_FORWARD = 2

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local filter: { Instance } = {}
local _viewModel: any = nil

local muzzleCFrame = LPH_NO_VIRTUALIZE(function(): CFrame?
	local viewModel = _viewModel
	if type(viewModel) ~= "table" then
		viewModel = ModuleController.GetModule("viewModel")
		_viewModel = viewModel
	end
	if type(viewModel) ~= "table" or type(viewModel.getEquipped) ~= "function" then
		return nil
	end

	local character = peek(ClientState.character)
	if not character then
		return nil
	end

	local vmc = viewModel.getEquipped(character)
	if type(vmc) ~= "table" or not vmc.muzzle then
		return nil
	end

	local worldCFrame = vmc.muzzle.WorldCFrame
	if typeof(worldCFrame) ~= "CFrame" then
		return nil
	end
	return worldCFrame
end)

local muzzlePosition = LPH_NO_VIRTUALIZE(function(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local camCFrame = camera.CFrame
	local camDir = camCFrame.LookVector
	local origin: Vector3
	local dir: Vector3

	local muzzle = muzzleCFrame()
	if muzzle then
		origin = muzzle.Position
		local barrelDir = muzzle.LookVector
		dir = barrelDir:Dot(camDir) > 0.5 and barrelDir or camDir
	else
		dir = camDir
		origin = camCFrame.Position + camDir * CAMERA_FORWARD
	end

	table.clear(filter)
	filter[1] = camera
	local character = peek(ClientState.character)
	if character then
		filter[#filter + 1] = character
	end
	params.FilterDescendantsInstances = filter

	local result = Workspace:Raycast(origin, dir * RANGE, params)
	if result then
		return result.Position
	end
	return nil
end)

local overkillMuzzleOrigin = {}

function overkillMuzzleOrigin.Setup(): ()
	originState.SetMuzzlePositionProvider(muzzlePosition)
end

function overkillMuzzleOrigin.Destroy(): ()
	originState.SetMuzzlePositionProvider(nil)
	_viewModel = nil
end

return overkillMuzzleOrigin
