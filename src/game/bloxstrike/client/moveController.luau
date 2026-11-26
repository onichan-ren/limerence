local Players = cloneref(game:GetService("Players")) :: Players
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local LocalPlayer = Players.LocalPlayer

local moveController = {}

local _playerModule: any = nil

function moveController.getActive(): any?
	if not _playerModule then
		local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
		local moduleScript = playerScripts and playerScripts:FindFirstChild("PlayerModule")
		if not moduleScript then
			return nil
		end
		setthreadidentity(2)
		local pm = require(moduleScript)
		setthreadidentity(8)
		_playerModule = pm
	end
	local controls = _playerModule:GetControls()
	if type(controls) ~= "table" then
		return nil
	end
	return controls.activeController
end

function moveController.realMoveVector(controller: any): Vector3
	local x = (controller.leftValue or 0) + (controller.rightValue or 0)
	local z = (controller.forwardValue or 0) + (controller.backwardValue or 0)
	return Vector3.new(x, 0, z)
end

function moveController.worldToMoveVector(worldDir: Vector3): Vector3
	local cf = Workspace.CurrentCamera.CFrame
	local lookFlat = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local rightFlat = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	if lookFlat.Magnitude < 1e-4 or rightFlat.Magnitude < 1e-4 then
		return Vector3.zero
	end
	lookFlat = lookFlat.Unit
	rightFlat = rightFlat.Unit
	local flat = Vector3.new(worldDir.X, 0, worldDir.Z)
	local mag = flat.Magnitude
	if mag < 1e-4 then
		return Vector3.zero
	end
	flat = flat / mag
	return Vector3.new(flat:Dot(rightFlat), 0, -flat:Dot(lookFlat))
end

function moveController.moveVectorToWorld(moveVector: Vector3): Vector3
	local cf = Workspace.CurrentCamera.CFrame
	local lookFlat = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local rightFlat = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	if lookFlat.Magnitude < 1e-4 or rightFlat.Magnitude < 1e-4 then
		return Vector3.zero
	end
	lookFlat = lookFlat.Unit
	rightFlat = rightFlat.Unit
	local world = rightFlat * moveVector.X - lookFlat * moveVector.Z
	local mag = world.Magnitude
	if mag < 1e-4 then
		return Vector3.zero
	end
	return world / mag
end

return moveController
