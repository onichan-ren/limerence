local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local FileController = require("@src/feature/file/FileController")
local instances = require("@share/instances")

local WHITE = Color3.fromRGB(255, 255, 255)
local SHOW_SPEED = 16
local MIN_SCALE = 0.45

local currentCamera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function(): ()
	currentCamera = Workspace.CurrentCamera
end)

local aimIndicatorRenderer = {}
aimIndicatorRenderer.__index = aimIndicatorRenderer

export type IndicatorOpts = {
	enabled: boolean,
	part: BasePart?,
	position: Vector3?,
	color: Color3,
	size: number,
}

function aimIndicatorRenderer.new(): AimIndicatorRenderer
	local self = setmetatable({}, aimIndicatorRenderer) :: any
	self._screenGui = nil
	self._circle = nil
	self._alpha = 0
	self._lastClock = nil
	return self
end

function aimIndicatorRenderer._setup(self: AimIndicatorRenderer): ()
	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = 6,
	}, cloneref(gethui())) :: ScreenGui
	self._screenGui = screenGui

	local circle = instances.new("ImageLabel", {
		Image = FileController.Get("image", "circle_shadow"),
		ImageColor3 = WHITE,
		ImageTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 1,
		Visible = false,
	}, screenGui) :: ImageLabel
	self._circle = circle
end

function aimIndicatorRenderer._teardown(self: AimIndicatorRenderer): ()
	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
		self._circle = nil
	end
	self._alpha = 0
	self._lastClock = nil
end

aimIndicatorRenderer.Update = LPH_NO_VIRTUALIZE(function(self: AimIndicatorRenderer, opts: IndicatorOpts): ()
	local now = os.clock()
	local dt = self._lastClock and (now - self._lastClock) or 0
	self._lastClock = now

	local camera = currentCamera
	local part = opts.part
	local position = opts.position
	local hasPart = part ~= nil and part.Parent ~= nil
	local hasTarget = opts.enabled and camera ~= nil and (position ~= nil or hasPart)

	local sx, sy = 0, 0
	local onScreen = false
	if hasTarget then
		local worldPos = position or (part :: BasePart).Position
		local screenPos = (camera :: Camera):WorldToViewportPoint(worldPos)
		if screenPos.Z > 0 then
			sx, sy, onScreen = screenPos.X, screenPos.Y, true
		end
	end

	local goal = (hasTarget and onScreen) and 1 or 0
	local t = dt > 0 and (1 - math.exp(-SHOW_SPEED * dt)) or 1
	self._alpha += (goal - self._alpha) * t

	if self._alpha <= 0.01 and goal == 0 then
		if not opts.enabled then
			self:_teardown()
		elseif self._circle then
			self._circle.Visible = false
		end
		return
	end

	if not self._screenGui then
		self:_setup()
	end

	local circle = self._circle :: ImageLabel
	circle.Visible = true
	if onScreen then
		circle.Position = UDim2.fromOffset(sx, sy)
	end
	local scaled = opts.size * (MIN_SCALE + (1 - MIN_SCALE) * self._alpha)
	circle.Size = UDim2.fromOffset(scaled, scaled)
	circle.ImageColor3 = opts.color
	circle.ImageTransparency = 1 - self._alpha
end)

function aimIndicatorRenderer.Destroy(self: AimIndicatorRenderer): ()
	self:_teardown()
end

export type AimIndicatorRenderer = typeof(setmetatable(
	{} :: {
		_screenGui: ScreenGui?,
		_circle: ImageLabel?,
		_alpha: number,
		_lastClock: number?,
	},
	aimIndicatorRenderer
))

return aimIndicatorRenderer
