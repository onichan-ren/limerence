local Janitor = require("@pkg/Janitor")
local Signal = require("@pkg/Signal")

local Workspace = cloneref(game:GetService("Workspace"))

local SMOKE_PART_NAME = "SmokePart"

local SmokeController = {
	_janitor = nil :: Janitor.Janitor?,
	_voxels = {} :: { [BasePart]: any },
	voxelAdded = Signal.new() :: Signal.Signal<BasePart>,
}

local function add(instance: Instance): ()
	if instance:IsA("BasePart") and instance.Name == SMOKE_PART_NAME then
		SmokeController._voxels[instance] = true
		SmokeController.voxelAdded:Fire(instance)
	end
end

local function remove(instance: Instance): ()
	local part = instance :: BasePart
	if SmokeController._voxels[part] then
		SmokeController._voxels[part] = nil
	end
end

function SmokeController.GetVoxels(): { [Part]: any }
	local voxels = SmokeController._voxels
	for part in next, voxels do
		if part.Parent == nil then
			voxels[part] = nil
		end
	end
	return voxels :: any
end

function SmokeController.new(): SmokeController
	local janitor = Janitor.new()
	SmokeController._janitor = janitor

	for _, child in next, Workspace:GetChildren() do
		add(child)
	end

	janitor:Add(Workspace.ChildAdded:Connect(add), "Disconnect")
	janitor:Add(Workspace.ChildRemoved:Connect(remove), "Disconnect")

	return SmokeController
end

function SmokeController.Destroy(): ()
	local janitor = SmokeController._janitor
	if janitor then
		janitor:Destroy()
		SmokeController._janitor = nil
	end
	table.clear(SmokeController._voxels)
end

export type SmokeController = typeof(SmokeController)

return SmokeController
