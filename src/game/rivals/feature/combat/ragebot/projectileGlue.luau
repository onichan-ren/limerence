local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local PROJECTILE_NAMES: { [string]: boolean } = {
	Slingshot = true,
	CoreProjectile = true,
	OuterProjectile = true,
}

local TOUCH_DELAY = 0.1
local TOUCH_FRAMES = 240

local projectileGlue = {}

local _active = false
local _targetPart: BasePart? = nil
local _conn: RBXScriptConnection? = nil

local function onProjectile(d: Instance): ()
	if not (d:IsA("BasePart") or d:IsA("Model")) then
		return
	end
	if not PROJECTILE_NAMES[d.Name] then
		return
	end
	task.spawn(function(): ()
		task.wait(TOUCH_DELAY)
		local part = d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart")
		if not part then
			return
		end
		part.CanTouch = true
		for _ = 1, TOUCH_FRAMES do
			if not _active or not part.Parent or not part:IsDescendantOf(Workspace) then
				break
			end
			local target = _targetPart
			if target and target.Parent and target:IsDescendantOf(Workspace) then
				firetouchinterest(target, part, 0)
				firetouchinterest(target, part, 1)
			end

			part.CFrame = target.CFrame + Vector3.new(0, 2, 0)
			part.Velocity = Vector3.new(math.random(-32, 32), math.random(-32, 32), math.random(-32, 32))
			sethiddenproperty(part, "PhysicsRepRootPart", target)
			part.CFrame = target.CFrame + Vector3.new(0, 2, 0)
		end
	end)
end

function projectileGlue.setTarget(part: BasePart?): ()
	_targetPart = part
end

function projectileGlue.setActive(state: boolean): ()
	state = state == true
	if _active == state then
		return
	end
	_active = state
	if state then
		if not _conn then
			_conn = Workspace.DescendantAdded:Connect(onProjectile)
		end
	else
		_targetPart = nil
		if _conn then
			_conn:Disconnect()
			_conn = nil
		end
	end
end

function projectileGlue.uninstall(): ()
	projectileGlue.setActive(false)
end

return projectileGlue
