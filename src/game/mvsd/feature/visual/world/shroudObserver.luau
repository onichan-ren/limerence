local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local PROJECTILE_NAME = "ShadowProjectile"

local listeners: { [(model: Model) -> ()]: true } = {}
local connection: RBXScriptConnection? = nil

local function onChildAdded(child: Instance): ()
	if child.Name ~= PROJECTILE_NAME or not child:IsA("Model") then
		return
	end
	for fn in next, listeners do
		task.spawn(fn, child)
	end
end

local shroudObserver = {}

function shroudObserver.subscribe(fn: (model: Model) -> ()): () -> ()
	listeners[fn] = true
	if not connection then
		connection = Workspace.ChildAdded:Connect(onChildAdded)
	end

	local active = true
	return function(): ()
		if not active then
			return
		end
		active = false
		listeners[fn] = nil
		if connection and not next(listeners) then
			connection:Disconnect()
			connection = nil
		end
	end
end

return shroudObserver
