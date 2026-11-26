local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local instances = require("@share/instances")
local espProject = require("@share/screenProject")

local HIDDEN_UI = cloneref(gethui())

local mdeg = math.deg
local matan2 = math.atan2
local msqrt = math.sqrt

local NEAR_PLANE = 0.2

export type LineState = {
	from: Vector3,
	to: Vector3,
	thickness: number,
	transparency: number,
	visible: boolean,
	outline: boolean,
	outlineTransparency: number,
}

export type LineHandle = {
	frame: Frame,
	gradient: UIGradient,
	outline: Frame,
	state: LineState,
	color: Color3,
	outlineColor: Color3,
}

local _gui: ScreenGui? = nil
local _entries: { LineHandle } = {}

local function ensureGui(): ScreenGui
	local gui = _gui
	if gui and gui.Parent then
		return gui
	end
	gui = instances.new("ScreenGui", {
		Name = "EspSkeletonLines",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 4,
		Secure = true,
	}, HIDDEN_UI) :: ScreenGui
	_gui = gui
	return gui :: ScreenGui
end

local applyLine = LPH_NO_VIRTUALIZE(function(project: espProject.Projector, invX: number, invY: number, handle: LineHandle): ()
	local frame = handle.frame
	local outline = handle.outline
	local state = handle.state
	if not state.visible then
		frame.Visible = false
		outline.Visible = false
		return
	end

	local fromS = project(state.from)
	local toS = project(state.to)
	local fromDepth = fromS.Z
	local toDepth = toS.Z
	if fromDepth <= NEAR_PLANE and toDepth <= NEAR_PLANE then
		frame.Visible = false
		outline.Visible = false
		return
	end

	if fromDepth <= NEAR_PLANE then
		local t = (toDepth - NEAR_PLANE) / (toDepth - fromDepth)
		fromS = project(state.to:Lerp(state.from, t))
	elseif toDepth <= NEAR_PLANE then
		local t = (fromDepth - NEAR_PLANE) / (fromDepth - toDepth)
		toS = project(state.from:Lerp(state.to, t))
	end

	local dx = toS.X - fromS.X
	local dy = toS.Y - fromS.Y
	local distance = msqrt(dx * dx + dy * dy)
	local thickness = state.thickness
	local scaleX = (fromS.X + toS.X) * 0.5 * invX
	local scaleY = (fromS.Y + toS.Y) * 0.5 * invY
	local rotation = mdeg(matan2(dy, dx))
	frame.Position = UDim2.new(scaleX, 0, scaleY, 0)
	frame.Size = UDim2.new((distance + thickness) * invX, 0, 0, thickness)
	frame.Rotation = rotation
	frame.BackgroundTransparency = state.transparency

	if state.outline then
		outline.Position = UDim2.new(scaleX, 0, scaleY, 0)
		outline.Size = UDim2.new((distance + thickness + 2) * invX, 0, 0, thickness + 2)
		outline.Rotation = rotation
		outline.BackgroundTransparency = state.outlineTransparency
		outline.Visible = true
	else
		outline.Visible = false
	end

	frame.Visible = true
end)

local applyStandalone = LPH_NO_VIRTUALIZE(function(handle: LineHandle): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local project = espProject.make(camera, viewport)
	applyLine(project, 1 / viewport.X, 1 / viewport.Y, handle)
end)

local function create(color: Color3): LineHandle
	local gui = ensureGui()
	local outline = instances.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Visible = false,
		Size = UDim2.fromOffset(0, 3),
		ZIndex = 1,
		Secure = true,
	}, gui) :: Frame

	local frame = instances.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Size = UDim2.fromOffset(0, 1),
		ZIndex = 2,
		Secure = true,
	}, gui) :: Frame

	local gradient = instances.new("UIGradient", {
		Color = ColorSequence.new(color),
		Secure = true,
	}, frame) :: UIGradient

	local handle: LineHandle = {
		frame = frame,
		gradient = gradient,
		outline = outline,
		color = color,
		outlineColor = Color3.new(0, 0, 0),
		state = {
			from = Vector3.zero,
			to = Vector3.zero,
			thickness = 1,
			transparency = 0,
			visible = false,
			outline = false,
			outlineTransparency = 0,
		},
	}

	table.insert(_entries, handle)
	return handle
end

local function destroy(handle: LineHandle): ()
	for i = 1, #_entries do
		if _entries[i] == handle then
			table.remove(_entries, i)
			break
		end
	end
	handle.frame:Destroy()
	handle.outline:Destroy()
	if #_entries == 0 then
		if _gui then
			_gui:Destroy()
			_gui = nil
		end
	end
end

local function setColor(handle: LineHandle, color: Color3): ()
	if handle.color == color then
		return
	end
	handle.color = color
	handle.frame.BackgroundColor3 = color
	handle.gradient.Color = ColorSequence.new(color)
end

local function setOutlineColor(handle: LineHandle, color: Color3): ()
	if handle.outlineColor == color then
		return
	end
	handle.outlineColor = color
	handle.outline.BackgroundColor3 = color
end

local function hide(handle: LineHandle): ()
	handle.state.visible = false
	handle.frame.Visible = false
	handle.outline.Visible = false
end

local function detach(handle: LineHandle, parent: Instance): ()
	for i = 1, #_entries do
		if _entries[i] == handle then
			table.remove(_entries, i)
			break
		end
	end
	handle.outline.Parent = parent
	handle.frame.Parent = parent
end

local applyDetached = LPH_NO_VIRTUALIZE(function(handle: LineHandle, project: espProject.Projector, invX: number, invY: number): ()
	applyLine(project, invX, invY, handle)
end)

return {
	create = create,
	destroy = destroy,
	setColor = setColor,
	setOutlineColor = setOutlineColor,
	hide = hide,
	detach = detach,
	applyDetached = applyDetached,
	applyStandalone = applyStandalone,
}
