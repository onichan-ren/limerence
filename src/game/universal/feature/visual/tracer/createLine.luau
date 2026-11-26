local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local RunService = cloneref(game:GetService("RunService")) :: RunService
local instances = require("@share/instances")
local screenProject = require("@share/screenProject")

local HIDDEN_UI = cloneref(gethui())

local mdeg = math.deg
local matan2 = math.atan2
local msqrt = math.sqrt

local NEAR_PLANE = 0.2

local _gui: ScreenGui? = nil

local function ensureGui(): ScreenGui
	local gui = _gui
	if gui and gui.Parent then
		return gui
	end
	gui = instances.new("ScreenGui", {
		Name = "TracerLines",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 50,
		Secure = true,
	}, HIDDEN_UI) :: ScreenGui
	_gui = gui
	return gui :: ScreenGui
end

export type LineState = {
	from: Vector3,
	to: Vector3,
	thickness: number,
	transparency: number,
}

export type LineHandle = {
	frame: Frame,
	gradient: UIGradient,
	state: LineState,
	destroy: () -> (),
}

type ActiveEntry = {
	frame: Frame,
	state: LineState,
}

local _active: { [Frame]: ActiveEntry } = {}
local _activeCount = 0
local _sharedConn: RBXScriptConnection? = nil

local stepLine = LPH_NO_VIRTUALIZE(function(project: screenProject.Projector, frame: Frame, state: LineState): ()
	local fromS = project(state.from)
	local toS = project(state.to)
	local fromDepth = fromS.Z
	local toDepth = toS.Z
	if fromDepth <= NEAR_PLANE and toDepth <= NEAR_PLANE then
		frame.Visible = false
		return
	end
	if fromDepth <= NEAR_PLANE then
		local t = (toDepth - NEAR_PLANE) / (toDepth - fromDepth)
		fromS = project(state.to:Lerp(state.from, t))
	end
	if toDepth <= NEAR_PLANE then
		local t = (fromDepth - NEAR_PLANE) / (fromDepth - toDepth)
		toS = project(state.from:Lerp(state.to, t))
	end
	local dx = toS.X - fromS.X
	local dy = toS.Y - fromS.Y
	local distance = msqrt(dx * dx + dy * dy)
	frame.Position = UDim2.fromOffset((fromS.X + toS.X) * 0.5, (fromS.Y + toS.Y) * 0.5)
	frame.Size = UDim2.fromOffset(distance, state.thickness)
	frame.Rotation = mdeg(matan2(dy, dx))
	frame.BackgroundTransparency = state.transparency
	frame.Visible = true
end)

local function ensureSharedLoop(): ()
	if _sharedConn then
		return
	end
	_sharedConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
		setthreadidentity(8)
		local camera = Workspace.CurrentCamera
		if not camera then
			for _, entry in next, _active do
				entry.frame.Visible = false
			end
			return
		end
		local project = screenProject.make(camera, camera.ViewportSize)
		for _, entry in next, _active do
			stepLine(project, entry.frame, entry.state)
		end
	end))
end

local function teardownSharedLoop(): ()
	if _activeCount > 0 or not _sharedConn then
		return
	end
	_sharedConn:Disconnect()
	_sharedConn = nil
end

local createLine = function(): LineHandle
	local gui = ensureGui()

	local frame = instances.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Size = UDim2.fromOffset(0, 1),
		Secure = true,
	}, gui) :: Frame

	local gradient = instances.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Secure = true,
	}, frame) :: UIGradient

	local state: LineState = {
		from = Vector3.zero,
		to = Vector3.zero,
		thickness = 1,
		transparency = 0,
	}

	_active[frame] = { frame = frame, state = state }
	_activeCount += 1
	ensureSharedLoop()

	local destroyed = false
	return {
		frame = frame,
		gradient = gradient,
		state = state,
		destroy = function(): ()
			if destroyed then
				return
			end
			destroyed = true
			if _active[frame] then
				_active[frame] = nil
				_activeCount -= 1
			end
			frame:Destroy()
			teardownSharedLoop()
		end,
	}
end

return createLine
