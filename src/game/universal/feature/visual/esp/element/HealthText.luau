local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local FileController = require("@feature/file/FileController")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")

local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement
local useAt = ReactCharm.useAtom
local createBindable = EspElement.createBindable
local fadedTransparency = EspElement.fadedTransparency
local joinBindings = React.joinBindings
local floor = math.floor

local TEXT_ANCHOR = Vector2.new(1, 0)

local DEFAULT_COLOR = ColorSequence.new(Color3.fromRGB(200, 200, 200))
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)
local WHITE = Color3.new(1, 1, 1)
local GAP_FROM_BOX = 5
local HEALTH_LERP_RATE = 8
local exp = math.exp

local _lerpLastDt = -1
local _lerpBlend = 0

type State = {
	fillScale: EspElement.Bindable<number>,
	leftOffset: EspElement.Bindable<number>,
	visible: EspElement.Bindable<boolean>,
	alpha: EspElement.Bindable<number>,
	text: EspElement.Bindable<string>,
	_displayedRatio: number,
	_lastHpInt: number,
} & EspElement.HealthCache

type Settings = {
	enabled: any,
	color: any,
	outline: any,
	outlineColor: any,
	followBar: any,
	cache: { followBar: boolean, hideAbove: number },
}

local function setup(link: gameUi.Linker): Settings
	link:Toggle("healthText", "Health Text", false):SetTip({
		title = "Health Text",
		body = "Numeric HP next to the player. Can track the health bar position.",
	})
	local healthTextLink = link:OnKey("healthText")
	healthTextLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0)
	espStateColors.Register({ id = "healthText", label = "Health Text", default = DEFAULT_COLOR, transparency = 0 })
	healthTextLink:Submenu("opts", "Options")
	local optsLink = healthTextLink:OnKey("opts")
	optsLink:Toggle("followBar", "Follow Health Bar", true):SetTip({
		title = "Follow Health Bar",
		body = "Places the text beside the health bar instead of a fixed offset.",
	})
	optsLink:Slider("hideAbove", "Hide Above", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Hide Above",
		body = "Hides health text when HP is above this percentage. 100% shows text at all health levels.",
	})
	optsLink:Toggle("outline", "Outline", true)
	local outlineLink = optsLink:OnKey("outline")
	outlineLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)
	espStateColors.Register({ id = "healthTextOutline", label = "Health Text Outline", default = DEFAULT_OUTLINE, transparency = 0 })

	local followBarLink = link:Get("healthText.opts.followBar")
	local hideAboveLink = link:Get("healthText.opts.hideAbove")
	local cache = {
		followBar = peek(followBarLink._state) :: boolean,
		hideAbove = peek(hideAboveLink._state) :: number,
	}
	sub(followBarLink._state, function(v: boolean): ()
		cache.followBar = v
	end)
	sub(hideAboveLink._state, function(v: number): ()
		cache.hideAbove = v
	end)

	return {
		enabled = link:Get("healthText"),
		color = link:Get("healthText.color"),
		outline = link:Get("healthText.opts.outline"),
		outlineColor = link:Get("healthText.opts.outline.outlineColor"),
		followBar = followBarLink,
		cache = cache,
	}
end

local function createState(_player: Player, basePlayer: any, _settings: Settings): State
	local state: State = {
		fillScale = createBindable(0),
		leftOffset = createBindable(0),
		visible = createBindable(false),
		alpha = createBindable(1),
		text = createBindable(""),
		_displayedRatio = 1,
		_lastHpInt = -1,
		_health = 0,
		_maxHealth = 100,
		_playerUnsub = function() end,
	}
	EspElement.attachHealthCache(basePlayer, state)
	return state
end

local function destroyState(state: State, _settings: Settings): ()
	state._playerUnsub()
end

local update = LPH_NO_VIRTUALIZE(function(state: State, ctx: EspElement.EspCtx, settings: Settings): ()
	if not ctx.visible then
		state.visible.set(false)
		return
	end

	local maxH = math.max(state._maxHealth, 1e-4)
	local h = state._health
	local healthPercent = (h / maxH) * 100
	if healthPercent > settings.cache.hideAbove then
		state.visible.set(false)
		return
	end

	local hpInt = floor(healthPercent + 0.5)
	if hpInt ~= state._lastHpInt then
		state._lastHpInt = hpInt
		state.text.set(`{hpInt}%`)
	end

	local target = math.clamp(h / maxH, 0, 1)
	local displayed: number
	if ctx.elementAnimations and ctx.dt > 0 then
		local current = state._displayedRatio
		if ctx.dt ~= _lerpLastDt then
			_lerpLastDt = ctx.dt
			_lerpBlend = 1 - exp(-ctx.dt * HEALTH_LERP_RATE)
		end
		displayed = current + (target - current) * _lerpBlend
	else
		displayed = target
	end
	state._displayedRatio = displayed

	local followBarVert = settings.cache.followBar
	state.fillScale.set(followBarVert and (1 - displayed) or 0)
	state.leftOffset.set(GAP_FROM_BOX + ctx.healthTextExtraLeft)
	state.alpha.set(ctx.alpha)
	state.visible.set(true)
end)

local render = LPH_NO_VIRTUALIZE(function(props: { state: State, settings: Settings, userId: number? }): React.Element<any>?
	local state = props.state
	local settings = props.settings

	local enabled = useAt(settings.enabled._state) :: boolean
	local outline = useAt(settings.outline._state) :: boolean
	local followBarVert = useAt(settings.followBar._state) :: boolean
	local colorpicker = espStateColors.useResolved("healthText", settings.color, props.userId)
	local outlinePicker = espStateColors.useResolved("healthTextOutline", settings.outlineColor, props.userId)

	if not enabled then
		return nil
	end

	local alphaBinding = state.alpha.binding

	return e("TextLabel", {
		AnchorPoint = TEXT_ANCHOR,
		Position = joinBindings({ state.leftOffset.binding, state.fillScale.binding }):map(function(v: { number })
			return UDim2.new(0, -v[1], v[2], 0)
		end),
		Visible = state.visible.binding,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = state.text.binding,
		TextColor3 = WHITE,
		TextTransparency = fadedTransparency(alphaBinding, colorpicker._current),
		AutomaticSize = Enum.AutomaticSize.XY,
		TextSize = 8,
		FontFace = FileController.Get("font", "pixel2"),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = followBarVert and Enum.TextYAlignment.Bottom or Enum.TextYAlignment.Top,
	}, {
		Gradient = e("UIGradient", {
			Color = colorpicker._currentGradient,
			Rotation = colorpicker._currentRotation,
		}),
		Stroke = outline and e("UIStroke", {
			Color = outlinePicker._currentColor,
			Transparency = fadedTransparency(alphaBinding, outlinePicker._current),
			Thickness = 1,
			LineJoinMode = Enum.LineJoinMode.Miter,
		}) or nil,
	})
end)

return {
	id = "healthText",
	container = true,
	setup = setup,
	createState = createState,
	update = update,
	render = render,
	destroyState = destroyState,
} :: EspElement.EspElement<State, Settings>
