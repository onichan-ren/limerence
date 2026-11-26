local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local RunService = cloneref(game:GetService("RunService")) :: RunService
local PlayerController = require("@feature/player/PlayerController")
local Ripple = require("@pkg/Ripple")
local Signal = require("@pkg/Signal")
local React = require("@pkg/React")
local BaseFeature = require("@game/BaseFeature")
local instances = require("@share/instances")
local gameUi = require("@game/gameUi")

local subscribeToBinding = (React :: any).__subscribeToBinding

local DEFAULT_COLOR = Color3.fromRGB(195, 110, 110)

local POP_SPRING = {
	dampingRatio = 0.45,
	frequency = 3.5,
	precision = 0.01,
}

local FADE_SPRING = {
	tension = 950,
	friction = 55,
}

local HIT_FADE_DURATION = 0.9

export type ConnectHit = (handler: (player: Player) -> ()) -> Signal.Connection

export type HitChamsOpts = {
	connectHit: ConnectHit,
	body: string?,
	lastShotBody: string?,
	colorBody: string?,
	getSizes: ((player: Player) -> { [string]: Vector3 }?)?,
	resolve: ((player: Player) -> any?)?,
}

type Adornment = {
	adornment: HandleAdornment,
	baseSize: Vector3,
	baseRadius: number?,
	baseHeight: number?,
}

type Effect = {
	model: Model,
	adornments: { Adornment },
	spring: any,
	baseTransparency: number,
	unsubChange: () -> (),
	unsubColor: () -> (),
	decayThread: thread?,
	dying: boolean,
}

local DEFAULT_BODY = "Briefly highlights the body parts you hit with a colored box overlay."
local DEFAULT_LAST_SHOT_BODY = "Only show chams for your most recent hit instead of stacking every hit."
local DEFAULT_COLOR_BODY = "Fill color of the hit cham boxes."

local Hitchams = {}
Hitchams.__index = Hitchams

setmetatable(Hitchams, { __index = BaseFeature })

function Hitchams.new(link: gameUi.Linker, opts: HitChamsOpts): Hitchams
	local self = BaseFeature.new() :: any
	setmetatable(self, Hitchams)

	self._effects = {} :: { [Effect]: true }
	self._connection = nil
	self._connectHit = opts.connectHit
	self._getSizes = opts.getSizes
	self._resolve = opts.resolve or PlayerController.Get

	link:Toggle("hitChams", "Hit Chams", false):SetTip({
		title = "Hit Chams",
		body = opts.body or DEFAULT_BODY,
	})
	local hitChamsLink = link:OnKey("hitChams")
	hitChamsLink:Submenu("opts", "Hit Chams Options")
	local optsLink = hitChamsLink:OnKey("opts")
	optsLink:Toggle("lastShotOnly", "Last Shot Only", false):SetTip({
		title = "Last Shot Only",
		body = opts.lastShotBody or DEFAULT_LAST_SHOT_BODY,
	})
	optsLink:Toggle("behindWalls", "Behind Walls", true):SetTip({
		title = "Behind Walls",
		body = "When on, hit boxes stay visible through walls.",
	})
	optsLink:Slider("lifetime", "Lifetime", 1, 0.5, 5, 0.1, nil, "s"):SetTip({
		title = "Lifetime",
		body = "How long each hit cham stays on screen before fading.",
	})
	optsLink:Dropdown("disappearing", "Disappearing", { "Default", "Fade" }, "Default"):SetTip({
		title = "Disappearing",
		body = "Default pops the boxes away. Fade smoothly fades them out.",
	})
	optsLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0):SetTip({
		title = "Color",
		body = opts.colorBody or DEFAULT_COLOR_BODY,
	})

	self:Track(link:Get("hitChams"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self._optsLink = optsLink

	if link:Peek("hitChams") then
		self:Enable()
	end

	return self
end

function Hitchams.Enable(self: Hitchams): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._connection = self._connectHit(LPH_NO_VIRTUALIZE(function(player: Player): ()
		local playerData = self._resolve(player)
		if not playerData or not playerData:IsAlive() then
			return
		end

		local model = playerData:GetCharacter()
		if not model then
			return
		end

		if self._optsLink:Peek("lastShotOnly") then
			self:_clearEffects()
		end

		local sizes = self._getSizes and self._getSizes(player) or nil
		self:_spawnEffect(playerData:GetParts(), sizes)
	end)) :: any
end

function Hitchams.Disable(self: Hitchams): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end

	self:_clearEffects()
end

Hitchams._spawnEffect = LPH_NO_VIRTUALIZE(function(self: Hitchams, parts: { [string]: Instance }, sizes: { [string]: Vector3 }?): ()
	local opts = self._optsLink
	local colorpicker: any = opts:Get("color")
	local colorBinding = colorpicker._currentColor
	local initialColor = (colorBinding :: any):getValue() :: Color3
	local baseTransparency = opts:PeekTransparency("color") or 0
	local lifetime = opts:Peek("lifetime") or 1
	local shading = opts:Peek("behindWalls") and Enum.AdornShading.AlwaysOnTop or Enum.AdornShading.Default

	local model = instances.new("Model", { Secure = true }, Workspace) :: Model
	local adornments: { Adornment } = {}

	for name, part in next, parts do
		if not part:IsA("BasePart") then
			continue
		end

		if part.Transparency == 1 then
			continue
		end

		local size = (sizes and sizes[name]) or part.Size
		if size.X == 0 and size.Y == 0 and size.Z == 0 then
			continue
		end

		local clone = part:Clone()
		for _, child in next, clone:GetChildren() do
			child:Destroy()
		end

		clone.Anchored = true
		clone.CanQuery = false
		clone.CanCollide = false
		clone.CanTouch = false
		clone.Transparency = 1
		clone.Parent = model

		local isHead = name == "Head" or name == "FakeHead"
		if isHead then
			local radius = math.max(size.X, size.Z) * 0.5
			local height = size.Y
			local cyl = instances.new("CylinderHandleAdornment", {
				Adornee = clone,
				Radius = radius,
				Height = height,
				Angle = 360,
				CFrame = CFrame.Angles(math.rad(90), 0, 0),
				Color3 = initialColor,
				Transparency = 1,
				Shading = shading,
				ZIndex = 1,
			}, model) :: CylinderHandleAdornment

			adornments[#adornments + 1] = {
				adornment = cyl,
				baseSize = size,
				baseRadius = radius,
				baseHeight = height,
			}
		else
			local adornment = instances.new("BoxHandleAdornment", {
				Adornee = clone,
				Size = size,
				Color3 = initialColor,
				Transparency = 1,
				Shading = shading,
				ZIndex = 1,
			}, model) :: BoxHandleAdornment

			adornments[#adornments + 1] = {
				adornment = adornment,
				baseSize = size,
			}
		end
	end

	local spring = Ripple.createSpring(0, POP_SPRING)
	local effect: Effect = {
		model = model,
		adornments = adornments,
		spring = spring,
		baseTransparency = baseTransparency,
		unsubChange = function() end,
		unsubColor = function() end,
		decayThread = nil,
		dying = false,
	}

	effect.unsubChange = spring:onChange(function(alpha: number): ()
		local clamped = math.clamp(alpha, 0, 1)
		local transparency = baseTransparency + (1 - clamped) * (1 - baseTransparency)
		local sizeScale = math.max(alpha, 0)
		for _, entry in next, adornments do
			local a = entry.adornment
			if entry.baseRadius then
				local cyl = a :: CylinderHandleAdornment
				cyl.Radius = entry.baseRadius * sizeScale
				cyl.Height = (entry.baseHeight :: number) * sizeScale
			else
				(a :: BoxHandleAdornment).Size = entry.baseSize * sizeScale
			end
			a.Transparency = transparency
		end
	end)

	effect.unsubColor = subscribeToBinding(colorBinding, function(value: Color3): ()
		for _, entry in next, adornments do
			entry.adornment.Color3 = value
		end
	end)

	self._effects[effect] = true

	spring:start()
	spring:setGoal(1)

	effect.decayThread = task.delay(lifetime, function(): ()
		effect.decayThread = nil
		self:_destroyEffect(effect)
	end)
end)

Hitchams._fadeOut = LPH_NO_VIRTUALIZE(function(self: Hitchams, effect: Effect): ()
	local spring = effect.spring
	spring:stop()

	local fadeStart = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.PreRender:Connect(function(): ()
		local t = math.min((os.clock() - fadeStart) / HIT_FADE_DURATION, 1)
		local eased = t * t * (3 - 2 * t)
		local transparency = effect.baseTransparency + (1 - effect.baseTransparency) * eased
		for _, entry in next, effect.adornments do
			entry.adornment.Transparency = transparency
		end

		if t < 1 then
			return
		end

		if conn then
			conn:Disconnect()
			conn = nil
		end
		effect.unsubChange()
		effect.unsubColor()
		spring:destroy()
		effect.model:Destroy()
		self._effects[effect] = nil
	end)
end)

Hitchams._destroyEffect = LPH_NO_VIRTUALIZE(function(self: Hitchams, effect: Effect): ()
	if effect.dying then
		return
	end
	effect.dying = true

	local thread = effect.decayThread
	if thread then
		effect.decayThread = nil
		task.cancel(thread)
	end

	if self._optsLink:Peek("disappearing") == "Fade" then
		self:_fadeOut(effect)
		return
	end

	local spring = effect.spring
	spring:setGoal(0, FADE_SPRING)

	local disconnect: (() -> ())?
	disconnect = spring:onComplete(function(): ()
		if disconnect then
			disconnect()
			disconnect = nil
		end
		effect.unsubChange()
		effect.unsubColor()
		spring:destroy()
		effect.model:Destroy()
		self._effects[effect] = nil
	end)
end)

function Hitchams._clearEffects(self: Hitchams): ()
	for effect in next, self._effects do
		self:_destroyEffect(effect)
	end
end

function Hitchams.Destroy(self: Hitchams): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type Hitchams =
	typeof(setmetatable(
		{} :: {
			_optsLink: gameUi.Linker,
			_connectHit: ConnectHit,
			_getSizes: ((player: Player) -> { [string]: Vector3 }?)?,
			_resolve: (player: Player) -> any?,
			_enabled: boolean,
			_connection: Signal.Connection?,
			_effects: { [Effect]: true },
		},
		Hitchams
	))
	& BaseFeature.BaseFeature

return Hitchams
