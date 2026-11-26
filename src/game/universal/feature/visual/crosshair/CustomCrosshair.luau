local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local instances = require("@share/instances")
local FileController = require("@feature/file/FileController")
local gameUi = require("@game/gameUi")
local legitbotState = require("@game/universal/feature/combat/legitbot/legitbotState")
local originState = require("@game/universal/feature/visual/crosshair/originState")

local peek = Charm.peek
local subscribeToBinding = (React :: any).__subscribeToBinding

local ORIGIN_OPTIONS = { "Legitbot Target", "Ragebot Target", "Gun Muzzle", "Mouse Cursor", "Screen Center" }
local RAGEBOT_FRESH = 0.25
local POS_RESPONSE = 22
local MUZZLE_FORWARD = 0.05

local HIDDEN_UI = cloneref(gethui())

local WHITE = Color3.new(1, 1, 1)
local DEFAULT_COLOR = Color3.fromRGB(120, 200, 255)
local DEFAULT_OUTLINE = Color3.fromRGB(12, 12, 12)

local SPIN_RATE = 140
local TAU = math.pi * 2

type ColorSnapshot = {
	gradient: ColorSequence,
	rotation: number,
	transparency: number,
}

type Part = {
	frame: GuiObject,
	gradient: UIGradient,
	stroke: UIStroke?,
	isImage: boolean,
}

export type CustomCrosshairOpts = {
	setGameCrosshairHidden: ((hidden: boolean) -> ())?,
}

local CustomCrosshair = {}
CustomCrosshair.__index = CustomCrosshair

setmetatable(CustomCrosshair, { __index = BaseFeature })

local STRUCTURAL = {
	"mode",
	"lines.length",
	"lines.thickness",
	"lines.gap",
	"lines.dot",
	"lines.dot.dotSize",
	"lines.outline",
	"lines.outline.outlineThickness",
	"image.imageId",
	"image.imageSize",
}

function CustomCrosshair.new(link: gameUi.Linker, opts: CustomCrosshairOpts?): CustomCrosshair
	local self = BaseFeature.new() :: any
	setmetatable(self, CustomCrosshair)

	self._setGameHidden = opts and opts.setGameCrosshairHidden
	self._hideGame = false
	self._enabled = false
	self._gui = nil
	self._container = nil
	self._spinner = nil
	self._scale = nil
	self._renderConn = nil
	self._parts = {} :: { Part }
	self._colorSnap = {
		gradient = ColorSequence.new(DEFAULT_COLOR),
		rotation = 0,
		transparency = 0,
	} :: ColorSnapshot
	self._outlineSnap = { color = DEFAULT_OUTLINE, transparency = 0 }
	self._start = 0
	self._curX = 0
	self._curY = 0
	self._hasPos = false
	self._animSpin = "None"
	self._animEffect = "None"
	self._animSpeed = 1
	self._animBase = 0

	link:Toggle("customCrosshair", "Custom Crosshair", false):SetTip({
		title = "Custom Crosshair",
		body = "Draws your own crosshair in the center of the screen.",
	})
	local rootLink = link:OnKey("customCrosshair")
	rootLink:Submenu("opts", "Crosshair Options")
	local opts = rootLink:OnKey("opts")

	opts:Dropdown("mode", "Mode", { "Lines", "Image" }, "Lines"):SetTip({
		title = "Mode",
		body = "Draw the crosshair from lines or from an image.",
	})

	opts:PriorityList("priority", "Origin Priority", ORIGIN_OPTIONS, ORIGIN_OPTIONS):SetTip({
		title = "Origin Priority",
		body = "Where the crosshair sits. Top available source wins, the rest fall back down the list.",
	})

	if self._setGameHidden then
		opts:Toggle("hideGame", "Hide Game Crosshair", false):SetTip({
			title = "Hide Game Crosshair",
			body = "Hides the crosshair the game draws so only yours is left.",
		})
	end

	opts:Colorpicker("color", "Color", ColorSequence.new(DEFAULT_COLOR), 0):SetTip({
		title = "Color",
		body = "Crosshair color. Supports gradients.",
	})

	opts:Options("lines", "Line Settings")
	local lineOpts = opts:OnKey("lines")
	lineOpts:Slider("length", "Length", 7, 0, 40, 1, nil, "px"):SetTip({
		title = "Length",
		body = "Length of each crosshair line.",
	})
	lineOpts:Slider("thickness", "Thickness", 2, 1, 12, 1, nil, "px"):SetTip({
		title = "Thickness",
		body = "Width of each crosshair line.",
	})
	lineOpts:Slider("gap", "Gap", 4, 0, 40, 1, nil, "px"):SetTip({
		title = "Gap",
		body = "Space between the center and each line.",
	})
	lineOpts:Toggle("dot", "Center Dot", false):SetTip({
		title = "Center Dot",
		body = "Draws a dot in the center.",
	})
	lineOpts:OnKey("dot"):Slider("dotSize", "Dot Size", 2, 1, 16, 1, nil, "px"):SetTip({
		title = "Dot Size",
		body = "Size of the center dot.",
	})
	lineOpts:Toggle("outline", "Outline", true):SetTip({
		title = "Outline",
		body = "Draws an outline around the crosshair lines.",
	})
	local outlineLink = lineOpts:OnKey("outline")
	outlineLink:Slider("outlineThickness", "Outline Thickness", 1, 1, 4, 1, nil, "px")
	outlineLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)

	opts:Options("image", "Image Settings")
	local imageOpts = opts:OnKey("image")
	imageOpts:Textbox("imageId", "Image ID", ""):SetTip({
		title = "Image ID",
		body = "Asset id or link for image mode. Leave blank to use the logo.",
	})
	imageOpts:Slider("imageSize", "Image Size", 36, 8, 160, 1, nil, "px"):SetTip({
		title = "Image Size",
		body = "Size of the crosshair image.",
	})

	opts:Options("animation", "Animation")
	local animOpts = opts:OnKey("animation")
	animOpts:Dropdown("spin", "Spin", { "None", "Linear", "Smooth" }, "None"):SetTip({
		title = "Spin",
		body = "Rotates the crosshair. Linear holds a constant speed, Smooth eases each turn.",
	})
	animOpts:Dropdown("effect", "Effect", { "None", "Pulse", "Bounce" }, "None"):SetTip({
		title = "Effect",
		body = "Adds a secondary motion on top of the spin.",
	})
	animOpts:Slider("speed", "Speed", 1, 0.1, 8, 0.1, nil, "x"):SetTip({
		title = "Speed",
		body = "How fast the animation plays.",
	})
	animOpts:Slider("rotation", "Base Rotation", 0, 0, 360, 1, nil, "°"):SetTip({
		title = "Base Rotation",
		body = "Starting angle of the crosshair.",
	})

	self._opts = opts

	self:Track(link:Get("customCrosshair"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	local colorLink = opts:Get("color")
	local initial = colorLink:GetSnapshot()
	self._colorSnap = {
		gradient = initial.gradient,
		rotation = initial.rotation,
		transparency = initial.transparency,
	}
	self:Track(colorLink:OnUpdate(function(snap: any): ()
		self._colorSnap = {
			gradient = snap.gradient,
			rotation = snap.rotation,
			transparency = snap.transparency,
		}
		self:_applyColor()
	end))

	local outlineColorLink = opts:Get("lines.outline.outlineColor")
	self._outlineSnap.color = (outlineColorLink._currentColor :: any):getValue()
	self._outlineSnap.transparency = (outlineColorLink._currentTransparency :: any):getValue()
	self:Track(subscribeToBinding(outlineColorLink._currentColor, function(value: Color3): ()
		self._outlineSnap.color = value
		self._outlineSnap.transparency = (outlineColorLink._currentTransparency :: any):getValue()
		self:_applyColor()
	end))

	for _, key in next, STRUCTURAL do
		self:Track(opts:Watch(key, function(): ()
			if self._enabled then
				self:_build()
			end
		end))
	end

	self._animSpin = opts:Peek("animation.spin") or "None"
	self._animEffect = opts:Peek("animation.effect") or "None"
	self._animSpeed = opts:Peek("animation.speed") or 1
	self._animBase = opts:Peek("animation.rotation") or 0
	self:Track(opts:Watch("animation.spin", function(): ()
		self._animSpin = opts:Peek("animation.spin") or "None"
	end))
	self:Track(opts:Watch("animation.effect", function(): ()
		self._animEffect = opts:Peek("animation.effect") or "None"
	end))
	self:Track(opts:Watch("animation.speed", function(): ()
		self._animSpeed = opts:Peek("animation.speed") or 1
	end))
	self:Track(opts:Watch("animation.rotation", function(): ()
		self._animBase = opts:Peek("animation.rotation") or 0
	end))

	self._priority = opts:Peek("priority") or ORIGIN_OPTIONS
	self:Track(opts:Watch("priority", function(): ()
		self._priority = opts:Peek("priority") or ORIGIN_OPTIONS
	end))

	if self._setGameHidden then
		self._hideGame = opts:Peek("hideGame") == true
		self:Track(opts:Watch("hideGame", function(): ()
			self._hideGame = opts:Peek("hideGame") == true
			self:_applyGameHidden()
		end))
		self:Track(function(): ()
			(self._setGameHidden :: any)(false)
		end)
	end

	if link:Peek("customCrosshair") then
		self:Enable()
	end

	return self
end

function CustomCrosshair._ensureGui(self: CustomCrosshair): ()
	if self._gui and self._gui.Parent then
		return
	end
	local gui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 9,
		Secure = true,
	}, HIDDEN_UI) :: ScreenGui

	local container = instances.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Secure = true,
	}, gui) :: Frame

	local scale = instances.new("UIScale", { Scale = 1, Secure = true }, container) :: UIScale

	local spinner = instances.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Secure = true,
	}, container) :: Frame

	self._gui = gui
	self._container = container
	self._scale = scale
	self._spinner = spinner
end

local function makeLine(self: CustomCrosshair, x: number, y: number, w: number, h: number, parent: Frame?): Part
	local frame = instances.new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 2,
		Secure = true,
	}, parent or self._spinner) :: Frame

	local gradient = instances.new("UIGradient", { Secure = true }, frame) :: UIGradient

	local part: Part = { frame = frame, gradient = gradient, stroke = nil, isImage = false }
	return part
end

CustomCrosshair._build = function(self: CustomCrosshair): ()
	self:_ensureGui()

	for i = 1, #self._parts do
		self._parts[i].frame:Destroy()
	end
	self._parts = {}

	local opts = self._opts
	local parts: { Part } = {}

	if opts:Peek("mode") == "Image" then
		local size = opts:Peek("image.imageSize") or 36
		local id = opts:Peek("image.imageId")
		local image = (id and id ~= "" and FileController.ResolveImage(id)) or FileController.Get("image", "logov2.png")
		local imgHalf = math.floor(size * 0.5)
		local img = instances.new("ImageLabel", {
			Position = UDim2.fromOffset(-imgHalf, -imgHalf),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Image = image,
			ImageColor3 = WHITE,
			ZIndex = 2,
			Secure = true,
		}, self._spinner) :: ImageLabel
		local gradient = instances.new("UIGradient", { Secure = true }, img) :: UIGradient
		parts[#parts + 1] = { frame = img, gradient = gradient, stroke = nil, isImage = true }
	else
		local length = opts:Peek("lines.length") or 7
		local thickness = opts:Peek("lines.thickness") or 2
		local gap = opts:Peek("lines.gap") or 4
		local half = math.floor(thickness * 0.5)
		local far = gap + length

		parts[#parts + 1] = makeLine(self, -half, -far, thickness, length)
		parts[#parts + 1] = makeLine(self, -half, gap, thickness, length)
		parts[#parts + 1] = makeLine(self, -far, -half, length, thickness)
		parts[#parts + 1] = makeLine(self, gap, -half, length, thickness)

		if opts:Peek("lines.dot") then
			local dotSize = opts:Peek("lines.dot.dotSize") or 2
			local dotHalf = math.floor(dotSize * 0.5)
			parts[#parts + 1] = makeLine(self, -dotHalf, -dotHalf, dotSize, dotSize, self._container)
		end

		if opts:Peek("lines.outline") then
			local outlineThickness = opts:Peek("lines.outline.outlineThickness") or 1
			for i = 1, #parts do
				parts[i].stroke = instances.new("UIStroke", {
					Thickness = outlineThickness,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					LineJoinMode = Enum.LineJoinMode.Miter,
					Secure = true,
				}, parts[i].frame) :: UIStroke
			end
		end
	end

	self._parts = parts
	self:_applyColor()
end

function CustomCrosshair._applyColor(self: CustomCrosshair): ()
	local snap = self._colorSnap
	local outline = self._outlineSnap
	for i = 1, #self._parts do
		local part = self._parts[i]
		part.gradient.Color = snap.gradient
		part.gradient.Rotation = snap.rotation
		if part.isImage then
			(part.frame :: ImageLabel).ImageTransparency = snap.transparency
		else
			part.frame.BackgroundTransparency = snap.transparency
		end
		local stroke = part.stroke
		if stroke then
			stroke.Color = outline.color
			stroke.Transparency = outline.transparency
		end
	end
end

CustomCrosshair._resolveOrigin = LPH_NO_VIRTUALIZE(function(self: CustomCrosshair, camera: Camera): (number, number, boolean)
	local viewport = camera.ViewportSize

	if originState.ShouldForceCenter() then
		return viewport.X * 0.5, viewport.Y * 0.5, false
	end

	local order = self._priority

	for i = 1, #order do
		local src = order[i]
		if src == "Screen Center" then
			return viewport.X * 0.5, viewport.Y * 0.5, false
		elseif src == "Mouse Cursor" then
			local location = UserInputService:GetMouseLocation()
			return location.X, location.Y, true
		end

		local worldPos: Vector3? = nil
		if src == "Legitbot Target" then
			local part = peek(legitbotState.targetPart)
			if part then
				worldPos = (part :: BasePart).Position
			end
		elseif src == "Ragebot Target" then
			local part = originState.GetRagebotPart(RAGEBOT_FRESH)
			if part then
				worldPos = part.Position
			end
		elseif src == "Gun Muzzle" then
			local muzzle = originState.GetMuzzlePart()
			if muzzle then
				local cf = muzzle.CFrame
				worldPos = cf.Position + cf.LookVector * MUZZLE_FORWARD
			else
				worldPos = originState.GetMuzzlePosition()
			end
		end

		if worldPos then
			local vp = camera:WorldToViewportPoint(worldPos)
			if vp.Z > 0 then
				return vp.X, vp.Y, false
			end
		end
	end

	return viewport.X * 0.5, viewport.Y * 0.5, false
end)

CustomCrosshair._render = LPH_NO_VIRTUALIZE(function(self: CustomCrosshair, dt: number): ()
	local container = self._container :: Frame
	local spinner = self._spinner :: Frame
	local scale = self._scale :: UIScale

	local camera = Workspace.CurrentCamera
	if camera then
		local tx, ty, instant = self:_resolveOrigin(camera)
		if not self._hasPos or instant then
			self._curX, self._curY = tx, ty
			self._hasPos = true
		else
			local alpha = 1 - math.exp(-dt * POS_RESPONSE)
			self._curX += (tx - self._curX) * alpha
			self._curY += (ty - self._curY) * alpha
		end
		container.Position = UDim2.fromOffset(math.round(self._curX), math.round(self._curY))
	end

	local spin = self._animSpin
	local effect = self._animEffect
	local base = self._animBase

	if spin == "None" and effect == "None" then
		spinner.Rotation = base
		scale.Scale = 1
		return
	end

	local t = os.clock() - self._start
	local speed = self._animSpeed
	local rot = base
	local s = 1

	if spin == "Linear" then
		rot += (t * speed * SPIN_RATE) % 360
	elseif spin == "Smooth" then
		local cycle = t * speed
		rot += ((cycle - math.sin(cycle * TAU) / TAU) * SPIN_RATE) % 360
	end

	if effect == "Pulse" then
		s = 1 + 0.22 * math.sin(t * speed * TAU)
	elseif effect == "Bounce" then
		s = 1 + 0.32 * math.abs(math.sin(t * speed * math.pi)) ^ 0.6
	end

	spinner.Rotation = rot
	scale.Scale = s
end)

function CustomCrosshair._applyGameHidden(self: CustomCrosshair): ()
	local setter = self._setGameHidden
	if setter then
		setter(self._enabled and self._hideGame)
	end
end

function CustomCrosshair.Enable(self: CustomCrosshair): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._start = os.clock()
	self._hasPos = false

	self:_applyGameHidden()
	self:_build()

	if not self._renderConn then
		self._renderConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
			self:_render(dt)
		end))
	end
	if self._gui then
		self._gui.Enabled = true
	end
end

function CustomCrosshair.Disable(self: CustomCrosshair): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self:_applyGameHidden()

	if self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end
	if self._gui then
		self._gui.Enabled = false
	end
end

function CustomCrosshair.Destroy(self: CustomCrosshair): ()
	self:Disable()
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	BaseFeature.Destroy(self)
end

export type CustomCrosshair =
	typeof(setmetatable(
		{} :: {
			_opts: gameUi.Linker,
			_enabled: boolean,
			_gui: ScreenGui?,
			_container: Frame?,
			_spinner: Frame?,
			_scale: UIScale?,
			_renderConn: RBXScriptConnection?,
			_parts: { Part },
			_colorSnap: ColorSnapshot,
			_outlineSnap: { color: Color3, transparency: number },
			_start: number,
			_curX: number,
			_curY: number,
			_hasPos: boolean,
			_animSpin: string,
			_animEffect: string,
			_animSpeed: number,
			_animBase: number,
			_priority: { string },
			_setGameHidden: ((hidden: boolean) -> ())?,
			_hideGame: boolean,
		},
		CustomCrosshair
	))
	& BaseFeature.BaseFeature

return CustomCrosshair
