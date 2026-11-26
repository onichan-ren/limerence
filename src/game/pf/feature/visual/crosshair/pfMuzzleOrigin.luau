local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Players = cloneref(game:GetService("Players")) :: Players

local WeaponController = require("@game/pf/weapon/WeaponController")
local localThirdPerson = require("@game/pf/thirdperson/localThirdPerson")
local originState = require("@game/universal/feature/visual/crosshair/originState")

local LocalPlayer = Players.LocalPlayer

local RANGE = 5000
local CAMERA_FORWARD = 2

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local filter: { Instance } = {}
local ignoreFolder: Instance? = nil

local function barrelCFrame(): CFrame?
	local weapon = WeaponController.GetWeapon()
	if not weapon or type(weapon.getWeaponType) ~= "function" then
		return nil
	end
	if weapon:getWeaponType() ~= "Firearm" then
		return nil
	end
	local barrel = rawget(weapon, "_barrelPart")
	if typeof(barrel) == "Instance" and (barrel :: Instance):IsA("BasePart") then
		return (barrel :: BasePart).CFrame
	end
	return nil
end

local muzzlePosition = LPH_NO_VIRTUALIZE(function(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local origin: Vector3
	local dir: Vector3
	local camDir = camera.CFrame.LookVector
	local muzzle = barrelCFrame()
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
	local char = LocalPlayer.Character
	if char then
		filter[#filter + 1] = char
	end
	if not ignoreFolder or ignoreFolder.Parent ~= Workspace then
		ignoreFolder = Workspace:FindFirstChild("Ignore")
	end
	if ignoreFolder then
		filter[#filter + 1] = ignoreFolder
	end
	local body = localThirdPerson.getCharacterModel()
	if body then
		filter[#filter + 1] = body
	end
	local weaponModel = localThirdPerson.getWeaponModel()
	if weaponModel then
		filter[#filter + 1] = weaponModel
	end
	params.FilterDescendantsInstances = filter

	local result = Workspace:Raycast(origin, dir * RANGE, params)
	if result then
		return result.Position
	end
	return nil
end)

local pfMuzzleOrigin = {}

function pfMuzzleOrigin.Setup(): ()
	originState.SetMuzzlePositionProvider(muzzlePosition)
end

function pfMuzzleOrigin.Destroy(): ()
	originState.SetMuzzlePositionProvider(nil)
end

return pfMuzzleOrigin
