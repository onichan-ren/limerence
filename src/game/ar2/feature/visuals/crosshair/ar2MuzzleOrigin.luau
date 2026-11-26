local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local clientState = require("@game/ar2/client/clientState")
local originState = require("@game/universal/feature/visual/crosshair/originState")

local peek = Charm.peek
local sub = Charm.subscribe

local RANGE = 5000
local CAMERA_FORWARD = 2

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local filter: { Instance } = {}

local muzzle: BasePart? = nil
local equippedFolder: Instance? = nil
local weaponModel: Instance? = nil
local ignoreFolder: Instance? = nil
local effectsFolder: Instance? = nil

local partsUnsub: (() -> ())? = nil
local equippedAddConn: RBXScriptConnection? = nil
local equippedRemConn: RBXScriptConnection? = nil
local muzzleAddConn: RBXScriptConnection? = nil
local workspaceAddConn: RBXScriptConnection? = nil

local function bindWeaponModel(model: Instance?): ()
	if muzzleAddConn then
		muzzleAddConn:Disconnect()
		muzzleAddConn = nil
	end
	weaponModel = model
	muzzle = nil
	if not model then
		return
	end

	for _, descendant in next, model:QueryDescendants("BasePart") do
		if descendant.Name == "Muzzle" then
			muzzle = descendant :: BasePart
			break
		end
	end

	muzzleAddConn = model.DescendantAdded:Connect(function(descendant: Instance): ()
		if not muzzle and descendant.Name == "Muzzle" and descendant:IsA("BasePart") then
			muzzle = descendant :: BasePart
		end
	end)
end

local function bindEquipped(folder: Instance?): ()
	if equippedAddConn then
		equippedAddConn:Disconnect()
		equippedAddConn = nil
	end
	if equippedRemConn then
		equippedRemConn:Disconnect()
		equippedRemConn = nil
	end

	equippedFolder = folder
	bindWeaponModel(nil)
	if not folder then
		return
	end

	bindWeaponModel(folder:GetChildren()[1])

	equippedAddConn = folder.ChildAdded:Connect(function(child: Instance): ()
		bindWeaponModel(child)
	end)

	equippedRemConn = folder.ChildRemoved:Connect(function(child: Instance): ()
		if child == weaponModel then
			bindWeaponModel(folder:GetChildren()[1])
		end
	end)
end

local function refreshEquipped(parts: { [string]: Instance }?): ()
	local equipped = parts and parts.Equipped or nil
	if equipped ~= equippedFolder then
		bindEquipped(equipped)
	end
end

local function trackWorkspaceFolder(child: Instance): ()
	if child.Name == "Ignore" then
		ignoreFolder = child
	elseif child.Name == "Effects" then
		effectsFolder = child
	end
end

local lastCamera: Camera? = nil
local lastModel: Model? = nil
local lastIgnore: Instance? = nil
local lastEffects: Instance? = nil

local muzzlePosition = LPH_NO_VIRTUALIZE(function(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local camDir = camera.CFrame.LookVector
	local origin: Vector3
	local dir: Vector3

	local m = muzzle
	if m and m.Parent then
		local cf = m.CFrame
		origin = cf.Position
		dir = cf.LookVector:Dot(camDir) > 0.5 and cf.LookVector or camDir
	else
		dir = camDir
		origin = camera.CFrame.Position + camDir * CAMERA_FORWARD
	end

	local model = peek(clientState.character)
	if camera ~= lastCamera or model ~= lastModel or ignoreFolder ~= lastIgnore or effectsFolder ~= lastEffects then
		lastCamera = camera
		lastModel = model
		lastIgnore = ignoreFolder
		lastEffects = effectsFolder

		table.clear(filter)
		filter[1] = camera
		if model then
			filter[#filter + 1] = model
		end
		if ignoreFolder then
			filter[#filter + 1] = ignoreFolder
		end
		if effectsFolder then
			filter[#filter + 1] = effectsFolder
		end
		params.FilterDescendantsInstances = filter
	end

	local result = Workspace:Raycast(origin, dir * RANGE, params)
	if result then
		return result.Position
	end
	return origin + dir * RANGE
end)

local ar2MuzzleOrigin = {}

function ar2MuzzleOrigin.Setup(): ()
	for _, child in next, Workspace:GetChildren() do
		trackWorkspaceFolder(child)
	end
	workspaceAddConn = Workspace.ChildAdded:Connect(trackWorkspaceFolder)

	refreshEquipped(peek(clientState.parts))
	partsUnsub = sub(clientState.parts, refreshEquipped)

	originState.SetMuzzlePositionProvider(muzzlePosition)
end

function ar2MuzzleOrigin.Destroy(): ()
	originState.SetMuzzlePositionProvider(nil)

	if partsUnsub then
		partsUnsub()
		partsUnsub = nil
	end
	if workspaceAddConn then
		workspaceAddConn:Disconnect()
		workspaceAddConn = nil
	end

	bindEquipped(nil)

	ignoreFolder = nil
	effectsFolder = nil
end

return ar2MuzzleOrigin
