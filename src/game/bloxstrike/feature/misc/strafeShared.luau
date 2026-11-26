local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Camera = Workspace.CurrentCamera

local strafeShared = {}

strafeShared.computeWishDir = LPH_NO_VIRTUALIZE(function(): Vector3
	local cf = Camera.CFrame
	local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local flatRight = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	if flatLook.Magnitude < 0.001 or flatRight.Magnitude < 0.001 then
		return Vector3.zero
	end
	flatLook = flatLook.Unit
	flatRight = flatRight.Unit

	local wish = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		wish += flatLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		wish -= flatLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		wish += flatRight
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		wish -= flatRight
	end

	if wish.Magnitude < 0.001 then
		return Vector3.zero
	end
	return wish.Unit
end)

function strafeShared.isAirborne(humanoid: Humanoid?): boolean
	if not humanoid then
		return false
	end
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
end

return strafeShared
