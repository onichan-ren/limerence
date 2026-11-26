local FileController = require("@src/feature/file/FileController")

local instances = require("@share/instances")
local cameraState = require("@share/cameraState")

local WHITE = Color3.fromRGB(255, 255, 255)

local toSequence = LPH_NO_VIRTUALIZE(function(c: Color3 | ColorSequence): ColorSequence
	if typeof(c) == "ColorSequence" then
		return c
	end
	return ColorSequence.new(c :: Color3)
end)

local fovVisualization = {}
fovVisualization.__index = fovVisualization

export type FovOpts = {
	enabled: boolean,
	fov: number,
	color: Color3 | ColorSequence,
	outlineColor: Color3 | ColorSequence,
	transparency: number,
	outlineTransparency: number,
	rotation: number?,
	outlineRotation: number?,
	center: Vector2?,
}

function fovVisualization.new(): FovVisualization
	local self = setmetatable({}, fovVisualization) :: any
	self._screenGui = nil
	self._circle = nil
	self._stroke = nil
	self._fillGradient = nil
	self._outlineGradient = nil
	return self
end

function fovVisualization._setup(self: FovVisualization): ()
	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = 5,
	}, cloneref(gethui())) :: ScreenGui
	self._screenGui = screenGui

	local circle = instances.new("ImageLabel", {
		Image = FileController.Get("image", "circle_shadow"),
		ImageColor3 = WHITE,
		ImageTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, screenGui) :: ImageLabel
	self._circle = circle

	instances.newSimple("UICorner", { CornerRadius = UDim.new(1, 0) }, circle)
	local fillGradient = instances.new("UIGradient", {}, circle) :: UIGradient
	self._fillGradient = fillGradient

	local stroke = instances.new("UIStroke", {
		Color = WHITE,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, circle) :: UIStroke
	self._stroke = stroke

	local outlineGradient = instances.new("UIGradient", {}, stroke) :: UIGradient
	self._outlineGradient = outlineGradient
end

function fovVisualization._teardown(self: FovVisualization): ()
	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
		self._circle = nil
		self._stroke = nil
		self._fillGradient = nil
		self._outlineGradient = nil
	end
end

fovVisualization.Update = LPH_NO_VIRTUALIZE(function(self: FovVisualization, opts: FovOpts): ()
	if not opts.enabled then
		self:_teardown()
		return
	end

	if not self._screenGui then
		self:_setup()
	end

	local diameter = math.max(0, cameraState.FovToPixels(opts.fov) * 2)
	local size = UDim2.fromOffset(diameter, diameter)
	local circle = self._circle :: ImageLabel
	circle.Size = size
	local center = opts.center
	circle.Position = center and UDim2.fromOffset(center.X, center.Y) or UDim2.fromScale(0.5, 0.5)
	circle.ImageColor3 = WHITE
	circle.BackgroundColor3 = WHITE
	local fillGradient = self._fillGradient :: UIGradient
	fillGradient.Color = toSequence(opts.color)
	fillGradient.Rotation = opts.rotation or 0
	local transparency = opts.transparency
	circle.BackgroundTransparency = transparency
	circle.ImageTransparency = transparency < 0.9 and transparency * 1.4 or 1

	local stroke = self._stroke :: UIStroke
	stroke.Color = WHITE
	local outlineGradient = self._outlineGradient :: UIGradient
	outlineGradient.Color = toSequence(opts.outlineColor)
	outlineGradient.Rotation = opts.outlineRotation or 0
	stroke.Transparency = opts.outlineTransparency
	stroke.Thickness = 1.5
end)

function fovVisualization.Destroy(self: FovVisualization): ()
	self:_teardown()
end

export type FovVisualization = typeof(setmetatable(
	{} :: {
		_screenGui: ScreenGui?,
		_circle: ImageLabel?,
		_stroke: UIStroke?,
		_fillGradient: UIGradient?,
		_outlineGradient: UIGradient?,
	},
	fovVisualization
))

return fovVisualization
