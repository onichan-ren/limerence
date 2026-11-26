local Workspace = cloneref(game:GetService("Workspace"))
local RunService = cloneref(game:GetService("RunService")) :: RunService

local Ripple = require("@pkg/Ripple")
local Signal = require("@pkg/Signal")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local screenProject = require("@share/screenProject")
local FileController = require("@feature/file/FileController")

local DEFAULT_HIT = Color3.fromRGB(245, 245, 245)
local DEFAULT_HEADSHOT = Color3.fromRGB(255, 96, 96)
local DEFAULT_OUTLINE = Color3.fromRGB(10, 10, 12)
local OUTLINE_TRANSPARENCY = 0.55

local ARM = 5
local DIAG = 5
local BASE_SIZE = 16
local FADE_START = 0.45
local POP_START = 1.5
local REST_SCALE = 1
local HEADSHOT_REST_SCALE = 1.15
local FADE_EXPAND = 0.25
local SPIN_DEG = 25
local GLOW_TRANSPARENCY = 0.6
local GLOW_RATIO = 2.2
local GLOW_FADE_END = 0.5

local POP_SPRING = {
	dampingRatio = 0.6,
	frequency = 7,
	precision = 0.001,
}

-- { offsetX, offsetY, rotation, topOuter }
local ARMS = {
	{ DIAG, -DIAG, 45, true },
	{ -DIAG, DIAG, 45, false },
	{ -DIAG, -DIAG, -45, true },
	{ DIAG, DIAG, -45, false },
}

-- gradient runs along arm length (UIGradient.Rotation 90 => offset 0 top, 1 bottom)
local FADE_TOP = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.6, 0),
	NumberSequenceKeypoint.new(1, 0),
})
local FADE_BOTTOM = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.4, 0),
	NumberSequenceKeypoint.new(1, 1),
})

export type Hitmarker3dOpts = {
	connect: (emit: (position: Vector3, headshot: boolean) -> ()) -> Signal.Connection,
	body: string?,
	headshotBody: string?,
}

type Effect = {
	container: Frame,
	scale: UIScale,
	arms: { Frame },
	strokes: { UIStroke },
	glow: ImageLabel,
	basePos: Vector3,
	lifetime: number,
	start: number,
	spring: any,
	unsub: () -> (),
	settle: number,
	rest: number,
	outlineBase: number,
	dying: boolean,
}

local Hitmarker3d = {}
Hitmarker3d.__index = Hitmarker3d

setmetatable(Hitmarker3d, { __index = BaseFeature })

function Hitmarker3d.new(link: gameUi.Linker, opts: Hitmarker3dOpts): Hitmarker3d
	local self = BaseFeature.new() :: any
	setmetatable(self, Hitmarker3d)

	self._connect = opts.connect
	self._hitConn = nil :: Signal.Connection?
	self._effects = {} :: { [Effect]: boolean }
	self._renderConn = nil :: RBXScriptConnection?
	self._link = link

	self._screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = 8,
	}, cloneref(gethui())) :: ScreenGui

	link:Toggle("hitmarker3d", "3D Hit Marker", false):SetTip({
		title = "3D Hit Marker",
		body = opts.body or "Marks where in the world your shots land on a player.",
	})
	local rootLink = link:OnKey("hitmarker3d")
	rootLink:Submenu("opts", "3D Hit Marker")
	local optsLink = rootLink:OnKey("opts")
	optsLink:Colorpicker("hitColor", "Hit", DEFAULT_HIT, 0):SetTip({
		title = "Hit",
		body = "Color for body hits.",
	})
	optsLink:Colorpicker("headshotColor", "Headshot", DEFAULT_HEADSHOT, 0):SetTip({
		title = "Headshot",
		body = opts.headshotBody or "Color when the hit part is the head.",
	})
	optsLink:Colorpicker("outlineColor", "Outline", DEFAULT_OUTLINE, OUTLINE_TRANSPARENCY):SetTip({
		title = "Outline",
		body = "Color and transparency of the marker outline.",
	})
	optsLink:Slider("size", "Size", 16, 8, 48, 1, nil, "px"):SetTip({
		title = "Size",
		body = "Marker size on screen.",
	})
	optsLink:Slider("thickness", "Thickness", 2, 1, 6, 1):SetTip({
		title = "Thickness",
		body = "Width of the marker arms.",
	})
	optsLink:Slider("lifetime", "Lifetime", 0.4, 0.1, 2, 0.1, nil, "s"):SetTip({
		title = "Lifetime",
		body = "Seconds before the marker fades out.",
	})

	self._optsLink = optsLink
	self._enabledLink = link:Get("hitmarker3d")

	self:Track(self._enabledLink:OnChange(function(on: boolean): ()
		self:_setListening(on)
	end))

	if link:Peek("hitmarker3d") then
		self:_setListening(true)
	end

	return self
end

function Hitmarker3d._setListening(self: Hitmarker3d, on: boolean): ()
	if self._hitConn then
		self._hitConn:Disconnect()
		self._hitConn = nil
	end
	if not on then
		return
	end
	self._hitConn = self._connect(function(position: Vector3, headshot: boolean): ()
		self:_spawn(position, headshot)
	end)
end

Hitmarker3d._cleanup = LPH_NO_VIRTUALIZE(function(self: Hitmarker3d, effect: Effect): ()
	if effect.dying then
		return
	end
	effect.dying = true
	effect.unsub()
	effect.spring:destroy()
	effect.container:Destroy()
	self._effects[effect] = nil
end)

Hitmarker3d._spawn = LPH_NO_VIRTUALIZE(function(self: Hitmarker3d, position: Vector3, headshot: boolean): ()
	local optsLink = self._optsLink
	local size = optsLink:Peek("size") or 16
	local thickness = optsLink:Peek("thickness") or 2
	local lifetime = optsLink:Peek("lifetime") or 0.4

	local color = headshot and DEFAULT_HEADSHOT or DEFAULT_HIT
	local colorEl: any = optsLink:Get(headshot and "headshotColor" or "hitColor")
	if colorEl then
		color = (colorEl._currentColor :: any):getValue() :: Color3
	end
	local outline = DEFAULT_OUTLINE
	local outlineTransparency = OUTLINE_TRANSPARENCY
	local outlineEl: any = optsLink:Get("outlineColor")
	if outlineEl then
		outline = (outlineEl._currentColor :: any):getValue() :: Color3
		local transparency = outlineEl:GetTransparency()
		if type(transparency) == "number" then
			outlineTransparency = transparency
		end
	end

	local ratio = size / BASE_SIZE
	local armLength = ARM * ratio

	local container = instances.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		Visible = false,
	}, self._screenGui) :: Frame

	local scale = instances.new("UIScale", { Scale = POP_START }, container) :: UIScale

	local glowSize = math.floor(size * GLOW_RATIO + 0.5)
	local glow = instances.new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(glowSize, glowSize),
		Image = FileController.Get("image", "circle_shadow"),
		ImageColor3 = color,
		ImageTransparency = GLOW_TRANSPARENCY,
		ZIndex = 1,
	}, container) :: ImageLabel

	local arms: { Frame } = {}
	local strokes: { UIStroke } = {}
	local armSize = UDim2.fromOffset(thickness, armLength)
	for i = 1, #ARMS do
		local d = ARMS[i]
		local arm = instances.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = color,
			BackgroundTransparency = 0,
			Size = armSize,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, d[1] * ratio, 0.5, d[2] * ratio),
			Rotation = d[3],
			ZIndex = 2,
		}, container) :: Frame
		instances.new("UICorner", { CornerRadius = UDim.new(1, 0) }, arm)
		local fade = d[4] and FADE_TOP or FADE_BOTTOM
		instances.new("UIGradient", { Rotation = 90, Transparency = fade }, arm)
		local stroke = instances.new("UIStroke", {
			Color = outline,
			Thickness = 1,
			Transparency = outlineTransparency,
			LineJoinMode = Enum.LineJoinMode.Round,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, arm) :: UIStroke
		instances.new("UIGradient", { Rotation = 90, Transparency = fade }, stroke)
		arms[i] = arm
		strokes[i] = stroke
	end

	local spring = Ripple.createSpring(POP_START, POP_SPRING)
	local effect: Effect = {
		container = container,
		scale = scale,
		arms = arms,
		strokes = strokes,
		glow = glow,
		basePos = position,
		lifetime = lifetime,
		start = os.clock(),
		spring = spring,
		unsub = function() end,
		settle = POP_START,
		rest = headshot and HEADSHOT_REST_SCALE or REST_SCALE,
		outlineBase = outlineTransparency,
		dying = false,
	}

	effect.unsub = spring:onChange(function(alpha: number): ()
		effect.settle = math.max(alpha, 0)
	end)

	self._effects[effect] = true

	spring:start()
	spring:setGoal(headshot and HEADSHOT_REST_SCALE or REST_SCALE)

	self:_ensureRenderLoop()
end)

Hitmarker3d._ensureRenderLoop = function(self: Hitmarker3d): ()
	local effects = self._effects :: { [Effect]: boolean }
	if not next(effects) then
		if self._renderConn then
			self._renderConn:Disconnect()
			self._renderConn = nil
		end
		return
	end
	if self._renderConn then
		return
	end
	self._renderConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local project = screenProject.make(camera, camera.ViewportSize)
		local now = os.clock()
		for effect in next, effects do
			local t = math.min((now - effect.start) / effect.lifetime, 1)
			local screenPos = project(effect.basePos)
			if screenPos.Z > 0 then
				effect.container.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
				effect.container.Visible = true
			else
				effect.container.Visible = false
			end

			local fade = 0
			if t > FADE_START then
				fade = (t - FADE_START) / (1 - FADE_START)
				local outlineBase = effect.outlineBase
				local strokeFade = outlineBase + (1 - outlineBase) * fade
				for i = 1, #effect.arms do
					effect.arms[i].BackgroundTransparency = fade
					effect.strokes[i].Transparency = strokeFade
				end
			end
			effect.scale.Scale = effect.settle * (1 + fade * FADE_EXPAND)
			effect.container.Rotation = (effect.settle - effect.rest) / (POP_START - effect.rest) * SPIN_DEG
			effect.glow.ImageTransparency = GLOW_TRANSPARENCY
				+ (1 - GLOW_TRANSPARENCY) * math.min(t / GLOW_FADE_END, 1)

			if t >= 1 then
				self:_cleanup(effect)
			end
		end
		if not next(effects) then
			if self._renderConn then
				self._renderConn:Disconnect()
				self._renderConn = nil
			end
		end
	end))
end

function Hitmarker3d.Destroy(self: Hitmarker3d): ()
	self:_setListening(false)
	local effects = self._effects :: { [Effect]: boolean }
	for effect in next, effects do
		self:_cleanup(effect)
	end
	if self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end
	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
	end
	BaseFeature.Destroy(self)
end

export type Hitmarker3d =
	typeof(setmetatable(
		{} :: {
			_connect: (emit: (position: Vector3, headshot: boolean) -> ()) -> Signal.Connection,
			_hitConn: Signal.Connection?,
			_effects: { [Effect]: boolean },
			_renderConn: RBXScriptConnection?,
			_link: gameUi.Linker,
			_optsLink: gameUi.Linker,
			_enabledLink: any,
			_screenGui: ScreenGui?,
		},
		Hitmarker3d
	))
	& BaseFeature.BaseFeature

return Hitmarker3d
