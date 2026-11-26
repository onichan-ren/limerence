local Workspace = cloneref(game:GetService("Workspace"))
local RunService = cloneref(game:GetService("RunService")) :: RunService

local Ripple = require("@pkg/Ripple")
local Signal = require("@pkg/Signal")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local screenProject = require("@share/screenProject")
local FileController = require("@feature/file/FileController")

local DEFAULT_COLOR = Color3.fromRGB(245, 245, 245)
local DEFAULT_HEADSHOT = Color3.fromRGB(255, 96, 96)
local OUTLINE = Color3.fromRGB(10, 10, 12)
local OUTLINE_TRANSPARENCY = 0.55

local SPAWN_LIFT = 0.35
local RISE = 3
local FADE_START = 0.55
local JITTER = 0.6
local TEXT_SIZE = 18
local POP_START = 1.6
local REST_SCALE = 1
local HEADSHOT_REST_SCALE = 1.15
local STACK_RADIUS = 6
local TILT_RANGE = 12
local GLOW_TRANSPARENCY = 0.6
local GLOW_RATIO = 2.6

local POP_SPRING = {
	dampingRatio = 0.6,
	frequency = 7,
	precision = 0.001,
}

local RISE_SPRING = {
	dampingRatio = 1,
	frequency = 1.4,
	precision = 0.001,
}

export type DamageNumber3dOpts = {
	connect: (emit: (position: Vector3, amount: number, headshot: boolean) -> ()) -> Signal.Connection | () -> (),
	body: string?,
	headshotBody: string?,
}

type Effect = {
	root: Frame,
	label: TextLabel,
	glow: ImageLabel,
	scale: UIScale,
	stroke: UIStroke,
	basePos: Vector3,
	lifetime: number,
	start: number,
	spring: any,
	unsub: () -> (),
	riseSpring: any,
	riseUnsub: () -> (),
	rise: number,
	settle: number,
	screenLift: number,
	amount: number,
	headshot: boolean,
	outlineBase: number,
	dying: boolean,
}

local DamageNumber3d = {}
DamageNumber3d.__index = DamageNumber3d

setmetatable(DamageNumber3d, { __index = BaseFeature })

function DamageNumber3d.new(link: gameUi.Linker, opts: DamageNumber3dOpts): DamageNumber3d
	local self = BaseFeature.new() :: any
	setmetatable(self, DamageNumber3d)

	self._connect = opts.connect
	self._hitConn = nil :: (Signal.Connection | () -> ())?
	self._effects = {} :: { [Effect]: boolean }
	self._renderConn = nil :: RBXScriptConnection?
	self._link = link

	self._screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = 9,
	}, cloneref(gethui())) :: ScreenGui

	link:Toggle("damageNumber3d", "3D Damage Numbers", false):SetTip({
		title = "3D Damage Numbers",
		body = opts.body or "Floats the damage you deal above the spot you hit.",
	})
	local rootLink = link:OnKey("damageNumber3d")
	rootLink:Submenu("opts", "3D Damage Numbers")
	local optsLink = rootLink:OnKey("opts")
	optsLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0):SetTip({
		title = "Color",
		body = "Color for body-shot damage.",
	})
	optsLink:Colorpicker("headshotColor", "Headshot", DEFAULT_HEADSHOT, 0):SetTip({
		title = "Headshot",
		body = opts.headshotBody or "Color when the hit part is the head.",
	})
	optsLink:Colorpicker("outlineColor", "Outline", OUTLINE, OUTLINE_TRANSPARENCY):SetTip({
		title = "Outline",
		body = "Color and transparency of the text outline.",
	})
	optsLink:Slider("lifetime", "Lifetime", 0.9, 0.3, 3, 0.1, nil, "s"):SetTip({
		title = "Lifetime",
		body = "Seconds before the number fades out.",
	})
	optsLink:Slider("size", "Size", TEXT_SIZE, 10, 28, 1, nil, nil):SetTip({
		title = "Size",
		body = "Text size of the damage number.",
	})
	optsLink:Toggle("floatUp", "Float Up", true):SetTip({
		title = "Float Up",
		body = "Number drifts upward as it fades. Off holds it in place above the hit marker.",
	})

	self._optsLink = optsLink
	self._enabledLink = link:Get("damageNumber3d")

	self:Track(self._enabledLink:OnChange(function(on: boolean): ()
		self:_setListening(on)
	end))

	if link:Peek("damageNumber3d") then
		self:_setListening(true)
	end

	return self
end

function DamageNumber3d._setListening(self: DamageNumber3d, on: boolean): ()
	if self._hitConn then
		local conn = self._hitConn :: any
		self._hitConn = nil
		if type(conn) == "function" then
			conn()
		else
			conn:Disconnect()
		end
	end
	if not on then
		return
	end
	self._hitConn = self._connect(function(position: Vector3, amount: number, headshot: boolean): ()
		self:_spawn(position, amount, headshot)
	end)
end

DamageNumber3d._cleanup = LPH_NO_VIRTUALIZE(function(self: DamageNumber3d, effect: Effect): ()
	if effect.dying then
		return
	end
	effect.dying = true
	effect.unsub()
	effect.riseUnsub()
	effect.spring:destroy()
	effect.riseSpring:destroy()
	effect.root:Destroy()
	self._effects[effect] = nil
end)

DamageNumber3d._spawn = function(self: DamageNumber3d, position: Vector3, amount: number, headshot: boolean): ()
	local optsLink = self._optsLink
	local lifetime = optsLink:Peek("lifetime") or 0.9
	local textSize = optsLink:Peek("size") or TEXT_SIZE
	local floatUp = optsLink:Peek("floatUp") ~= false

	for other in next, self._effects :: { [Effect]: boolean } do
		if not other.dying and (other.basePos - position).Magnitude <= STACK_RADIUS then
			amount += other.amount
			headshot = headshot or other.headshot
			self:_cleanup(other)
			break
		end
	end

	local color = headshot and DEFAULT_HEADSHOT or DEFAULT_COLOR
	local colorEl: any = optsLink:Get(headshot and "headshotColor" or "color")
	if colorEl then
		color = (colorEl._currentColor :: any):getValue() :: Color3
	end
	local outline = OUTLINE
	local outlineTransparency = OUTLINE_TRANSPARENCY
	local outlineEl: any = optsLink:Get("outlineColor")
	if outlineEl then
		outline = (outlineEl._currentColor :: any):getValue() :: Color3
		local transparency = outlineEl:GetTransparency()
		if type(transparency) == "number" then
			outlineTransparency = transparency
		end
	end

	local basePos = position
	if floatUp then
		basePos = position + Vector3.new((math.random() - 0.5) * JITTER, SPAWN_LIFT, (math.random() - 0.5) * JITTER)
	end

	local root = instances.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
	}, self._screenGui) :: Frame

	local glowSize = math.floor(textSize * GLOW_RATIO + 0.5)
	local glow = instances.new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(glowSize, glowSize),
		Image = FileController.Get("image", "circle_shadow"),
		ImageColor3 = color,
		ImageTransparency = GLOW_TRANSPARENCY,
		ZIndex = 1,
	}, root) :: ImageLabel

	local label = instances.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		FontFace = FileController.Get("font", "bold") :: Font,
		Text = tostring(amount),
		TextColor3 = color,
		TextSize = textSize,
		TextTransparency = 0,
		Rotation = (math.random() - 0.5) * TILT_RANGE,
		ZIndex = 2,
	}, root) :: TextLabel

	local scale = instances.new("UIScale", { Scale = POP_START }, root) :: UIScale

	local stroke = instances.new("UIStroke", {
		Color = outline,
		Thickness = 1,
		Transparency = outlineTransparency,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, label) :: UIStroke

	local spring = Ripple.createSpring(POP_START, POP_SPRING)
	local riseSpring = Ripple.createSpring(0, RISE_SPRING)
	local effect: Effect = {
		root = root,
		label = label,
		glow = glow,
		scale = scale,
		stroke = stroke,
		basePos = basePos,
		lifetime = lifetime,
		start = os.clock(),
		spring = spring,
		unsub = function() end,
		riseSpring = riseSpring,
		riseUnsub = function() end,
		rise = 0,
		settle = POP_START,
		screenLift = floatUp and 0 or textSize + 8,
		amount = amount,
		headshot = headshot,
		outlineBase = outlineTransparency,
		dying = false,
	}

	effect.unsub = spring:onChange(LPH_NO_VIRTUALIZE(function(alpha: number): ()
		effect.settle = math.max(alpha, 0)
	end))

	effect.riseUnsub = riseSpring:onChange(LPH_NO_VIRTUALIZE(function(value: number): ()
		effect.rise = value
	end))

	local effects = self._effects :: { [Effect]: boolean }
	effects[effect] = true

	spring:start()
	spring:setGoal(headshot and HEADSHOT_REST_SCALE or REST_SCALE)

	if floatUp then
		riseSpring:start()
		riseSpring:setGoal(RISE)
	end

	self:_ensureRenderLoop()
end

DamageNumber3d._ensureRenderLoop = function(self: DamageNumber3d): ()
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
			local screenPos = project(effect.basePos + Vector3.new(0, effect.rise, 0))
			if screenPos.Z > 0 then
				effect.root.Position = UDim2.fromOffset(screenPos.X, screenPos.Y - effect.screenLift)
				effect.root.Visible = true
			else
				effect.root.Visible = false
			end

			local fade = 0
			if t > FADE_START then
				fade = (t - FADE_START) / (1 - FADE_START)
				local outlineBase = effect.outlineBase
				effect.label.TextTransparency = fade
				effect.stroke.Transparency = outlineBase + (1 - outlineBase) * fade
				effect.glow.ImageTransparency = GLOW_TRANSPARENCY + (1 - GLOW_TRANSPARENCY) * fade
			end
			effect.scale.Scale = effect.settle * (1 - fade * 0.2)

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

function DamageNumber3d.Destroy(self: DamageNumber3d): ()
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

export type DamageNumber3d =
	typeof(setmetatable(
		{} :: {
			_connect: (emit: (position: Vector3, amount: number, headshot: boolean) -> ()) -> Signal.Connection,
			_hitConn: (Signal.Connection | () -> ())?,
			_effects: { [Effect]: boolean },
			_renderConn: RBXScriptConnection?,
			_link: gameUi.Linker,
			_optsLink: gameUi.Linker,
			_enabledLink: any,
			_screenGui: ScreenGui?,
		},
		DamageNumber3d
	))
	& BaseFeature.BaseFeature

return DamageNumber3d
