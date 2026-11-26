local Workspace = cloneref(game:GetService("Workspace"))
local RunService = cloneref(game:GetService("RunService")) :: RunService

local Ripple = require("@pkg/Ripple")
local Janitor = require("@pkg/Janitor")
local Signal = require("@pkg/Signal")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")

local Impact = {}
Impact.__index = Impact

setmetatable(Impact, { __index = BaseFeature })

type ImpactSettings = {
	Color: Color3,
	Transparency: number,
	Lifetime: number,
	Size: number,
}

export type ImpactCtx = {
	spawn: (positions: { Vector3 }) -> (),
	janitor: Janitor.Janitor,
}

export type ImpactSource = {
	key: string,
	label: string,
	defaultColor: Color3,
	body: string?,
	connect: (ctx: ImpactCtx) -> Signal.Connection,
}

export type ImpactOpts = {
	rootKey: string?,
	rootLabel: string?,
	getIgnoreFolder: (() -> Instance)?,
	sources: { ImpactSource },
}

local SHADING = Enum.AdornShading.XRay

local POP_SPRING = {
	dampingRatio = 0.6,
	frequency = 6,
	precision = 0.01,
}

local IMPACT_FADE_DURATION = 0.9

type Adornment = {
	adornment: BoxHandleAdornment,
	part: Part,
	baseSize: Vector3,
	baseTransparency: number,
}

type Effect = {
	adornment: Adornment,
	spring: any,
	baseTransparency: number,
	unsubChange: () -> (),
	unsubColor: () -> (),
	decayThread: thread?,
	dying: boolean,
}

local function addImpactControls(optionsLink: gameUi.Linker, source: ImpactSource): ()
	local toggle = optionsLink:Toggle(source.key, source.label, false):SetTip({
		title = source.label,
		body = source.body or "Draws impacts.",
	})
	local submenuKey = `{source.key}Options`
	optionsLink:Extra(toggle, submenuKey, "Submenu", `{source.label} Options`)
	local optsLink = optionsLink:OnKey(submenuKey)
	optsLink:Colorpicker("color", "Color", source.defaultColor, 0):SetTip({
		title = "Color",
		body = "Impact color or gradient.",
	})
	optsLink:Slider("size", "Size", 0.3, 0.3, 3, 0.1, nil, "st"):SetTip({
		title = "Size",
		body = "Size of the Impact square.",
	})
	optsLink:Slider("lifetime", "Lifetime", 2, 0.5, 5, 0.1, nil, "s"):SetTip({
		title = "Lifetime",
		body = "Seconds before the impact starts fading out.",
	})
end

function Impact.new(link: gameUi.Linker, opts: ImpactOpts): Impact
	local self = BaseFeature.new() :: any
	setmetatable(self, Impact)

	self._effects = {}
	self._link = link
	self._janitor = Janitor.new()
	self._sourceJanitors = {} :: { [string]: Janitor.Janitor }

	local rootKey = opts.rootKey or "bulletImpacts"
	self._ignoreFolder = opts.getIgnoreFolder and opts.getIgnoreFolder() or Workspace
	self._rootKey = rootKey
	link:Options(rootKey, opts.rootLabel or "Bullet Impacts")
	local optionsLink = link:OnKey(rootKey)

	for _, source in next, opts.sources do
		addImpactControls(optionsLink, source)
		local sourceLink = optionsLink:Get(source.key)
		self:Track(sourceLink:OnChange(function(value: boolean): ()
			if value then
				self:_enableSource(source)
			else
				self:_disableSource(source)
			end
		end))
	end

	return self
end

Impact.spawnSegment = LPH_NO_VIRTUALIZE(function(self: Impact, target: Vector3, settings: ImpactSettings): ()
	local size = settings.Size
	local vectorSize = Vector3.new(size, size, size)
	local transparency = settings.Transparency

	local part = Instance.new("Part")
	part.Parent = self._ignoreFolder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = target
	part.Size = vectorSize
	part.Transparency = 1

	local boxHandleAdorment = Instance.new("BoxHandleAdornment")
	boxHandleAdorment.Parent = part
	boxHandleAdorment.Adornee = part
	boxHandleAdorment.Shading = SHADING
	boxHandleAdorment.AlwaysOnTop = true
	boxHandleAdorment.Color3 = settings.Color
	boxHandleAdorment.Transparency = transparency
	boxHandleAdorment.Size = vectorSize

	self:_spawnEffect(settings, {
		part = part,
		adornment = boxHandleAdorment,
		baseSize = vectorSize,
		baseTransparency = transparency,
	})
end)

Impact._destroyEffect = LPH_NO_VIRTUALIZE(function(self: Impact, settings: ImpactSettings, effect: Effect): ()
	if effect.dying then
		return
	end
	effect.dying = true

	local thread = effect.decayThread
	if thread then
		effect.decayThread = nil
		task.cancel(thread)
	end

	local spring = effect.spring
	spring:stop()

	local fadeStart = os.clock()
	local disconnect: RBXScriptConnection? = nil
	disconnect = RunService.PreRender:Connect(function(): ()
		local t = math.min((os.clock() - fadeStart) / IMPACT_FADE_DURATION, 1)
		local eased = t * t * (3 - 2 * t)
		local alpha = 1 - eased
		local boxHandleAdornment = effect.adornment.adornment
		boxHandleAdornment.Transparency = effect.baseTransparency + (1 - alpha) * (1 - effect.baseTransparency)

		if t < 1 then
			return
		end

		if disconnect then
			disconnect:Disconnect()
			disconnect = nil
		end
		effect.unsubChange()
		effect.unsubColor()
		spring:destroy()
		effect.adornment.part:Destroy()
		self._effects[effect] = nil
	end)
end)

Impact._spawnEffect = LPH_NO_VIRTUALIZE(function(self: Impact, settings: ImpactSettings, adornment: Adornment): ()
	local baseTransparency = adornment.baseTransparency
	local boxHandleAdornment = adornment.adornment

	local spring = Ripple.createSpring(0, POP_SPRING)
	local effect: Effect = {
		adornment = adornment,
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
		boxHandleAdornment.Size = adornment.baseSize * sizeScale
		boxHandleAdornment.Transparency = transparency
	end)

	self._effects[effect] = true

	spring:start()
	spring:setGoal(1)

	effect.decayThread = task.delay(settings.Lifetime, function(): ()
		effect.decayThread = nil
		self:_destroyEffect(settings, effect)
	end)
end)

function Impact.peekSettings(self: Impact, submenuKey: string, fallbackColor: Color3): ImpactSettings
	local optsLink = self._link:OnKey(self._rootKey):OnKey(submenuKey)
	local colorEl: any = optsLink:Get("color")
	local color: Color3 = fallbackColor
	local transparency = 0
	if colorEl then
		color = (colorEl._currentColor :: any):getValue() :: Color3
		transparency = (colorEl._currentTransparency :: any):getValue() :: number
	end
	return {
		Color = color,
		Transparency = transparency,
		Lifetime = optsLink:Peek("lifetime") or 2,
		Size = optsLink:Peek("size") or 1,
	}
end

function Impact._enableSource(self: Impact, source: ImpactSource): ()
	if self._sourceJanitors[source.key] then
		return
	end

	local sourceJanitor = Janitor.new()
	self._sourceJanitors[source.key] = sourceJanitor

	local submenuKey = `{source.key}Options`
	local ctx: ImpactCtx = {
		janitor = sourceJanitor,
		spawn = function(positions: { Vector3 }): ()
			local data = self:peekSettings(submenuKey, source.defaultColor)
			for _, position in next, positions do
				self:spawnSegment(position, data)
			end
		end,
	}

	sourceJanitor:Add(source.connect(ctx), "Disconnect")
end

function Impact._disableSource(self: Impact, source: ImpactSource): ()
	local sourceJanitor = self._sourceJanitors[source.key]
	if not sourceJanitor then
		return
	end
	self._sourceJanitors[source.key] = nil
	sourceJanitor:Destroy()
end

function Impact.Destroy(self: Impact): ()
	for key, janitor in next, self._sourceJanitors do
		self._sourceJanitors[key] = nil
		janitor:Destroy()
	end
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type Impact =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_rootKey: string,
			_janitor: Janitor.Janitor,
			_sourceJanitors: { [string]: Janitor.Janitor },
			_effects: { Effect },
		},
		Impact
	))
	& BaseFeature.BaseFeature

return Impact
