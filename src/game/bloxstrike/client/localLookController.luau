local RunService = cloneref(game:GetService("RunService")) :: RunService
local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local ModuleController = require("@game/bloxstrike/module/ModuleController")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

export type LookAngles = {
	VerticalLook: number,
	HorizontalAngle: number?,
}

type Source = {
	name: string,
	priority: number,
	fn: () -> LookAngles?,
}

local sources: { [string]: Source } = {}
local sortedSources: { Source } = {}
local isThirdPerson = false
local thirdPersonAtom = Charm.atom(false)
local renderConn: RBXScriptConnection? = nil
local _cachedKinematics: any = nil
local realCameraCFrame: CFrame? = nil
local viewOffset = Vector3.zero

local LocalLookController = {
	yaw = 0,
	verticalLook = 0,
	thirdPerson = thirdPersonAtom,
}

local rebuildSorted = LPH_NO_VIRTUALIZE(function(): ()
	local list: { Source } = {}
	for _, source in next, sources do
		list[#list + 1] = source
	end
	table.sort(list, function(a: Source, b: Source): boolean
		return a.priority > b.priority
	end)
	sortedSources = list
end)

local _scratchAngles: LookAngles = { VerticalLook = 0, HorizontalAngle = 0 }

local resolveAngles = LPH_NO_VIRTUALIZE(function(): LookAngles
	local cf = Camera.CFrame
	local _, camYaw = cf:ToEulerAnglesYXZ()
	for i = 1, #sortedSources do
		local result = sortedSources[i].fn()
		if result then
			local yaw = result.HorizontalAngle
			if yaw == nil or yaw ~= yaw then
				result.HorizontalAngle = camYaw
			end
			return result
		end
	end
	_scratchAngles.VerticalLook = cf.LookVector.Y
	_scratchAngles.HorizontalAngle = camYaw
	return _scratchAngles
end)

local tick = LPH_NO_VIRTUALIZE(function(): ()
	local kinematics = _cachedKinematics

	if not kinematics then
		kinematics = ModuleController.GetModule("CharacterKinematics")
		if not kinematics then
			return
		end
		_cachedKinematics = kinematics
	end

	local angles = resolveAngles()
	local yaw = angles.HorizontalAngle :: number
	local verticalLook = angles.VerticalLook

	LocalLookController.yaw = yaw
	LocalLookController.verticalLook = verticalLook
	kinematics.setTargetRotation(LocalPlayer, yaw)
	kinematics.setVerticalLook(LocalPlayer, verticalLook)
	setthreadidentity(8)
end)

function LocalLookController.RegisterSource(name: string, priority: number, fn: () -> LookAngles?): () -> ()
	sources[name] = { name = name, priority = priority, fn = fn }
	rebuildSorted()
	return function(): ()
		if sources[name] then
			sources[name] = nil
			rebuildSorted()
		end
	end
end

function LocalLookController.SetThirdPerson(active: boolean): ()
	if isThirdPerson == active then
		return
	end
	isThirdPerson = active
	thirdPersonAtom(active)
	if active then
		if not renderConn then
			renderConn = RunService.PreRender:Connect(tick)
		end
	else
		if renderConn then
			renderConn:Disconnect()
			renderConn = nil
		end
	end
end

function LocalLookController.IsThirdPerson(): boolean
	return isThirdPerson
end

function LocalLookController.SetRealCameraCFrame(cf: CFrame): ()
	realCameraCFrame = cf
end

function LocalLookController.SetViewOffset(offset: Vector3?): ()
	viewOffset = offset or Vector3.zero
end

function LocalLookController.GetViewOffset(): Vector3
	return viewOffset
end

function LocalLookController.GetRealCameraPosition(): Vector3
	if isThirdPerson and realCameraCFrame then
		return (realCameraCFrame :: CFrame).Position - viewOffset
	end
	return Camera.CFrame.Position - viewOffset
end

return LocalLookController
