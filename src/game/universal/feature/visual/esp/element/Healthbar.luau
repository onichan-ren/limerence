local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")

local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement
local useAt = ReactCharm.useAtom
local createBindable = EspElement.createBindable
local fadedTransparency = EspElement.fadedTransparency

local HEALTH_LERP_RATE = 10
local exp = math.exp

local _lerpLastDt = -1
local _lerpBlend = 0

local DEFAULT_FILL = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 153)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(66, 149, 149)),
})
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)
local WHITE = Color3.new(1, 1, 1)
local GAP_FROM_BOX = 3

type State = {
	visible: EspElement.Bindable<boolean>,
	healthRatio: EspElement.Bindable<number>,
	alpha: EspElement.Bindable<number>,
	_displayedRatio: number,
} & EspElement.HealthCache

type Settings = {
	enabled: any,
	color: any,
	outline: any,
	outlineColor: any,
	width: any,
	backgroundColor: any,
	cache: { width: number },
}

local function setup(link: gameUi.Linker): Settings
	link:Toggle("healthbar", "Health Bar", false):SetTip({
		title = "Health Bar",
		body = "Vertical bar beside the box showing remaining health.",
	})
	local hbLink = link:OnKey("healthbar")
	hbLink:Colorpicker("color", "Fill", DEFAULT_FILL, 0):SetTip({
		title = "Fill",
		body = "Health gradient (top = high HP, bottom = low).",
	})
	espStateColors.Register({ id = "healthbar", label = "Health Bar", default = DEFAULT_FILL, transparency = 0 })
	hbLink:Submenu("opts", "Health Bar Options")

	local optsLink = hbLink:OnKey("opts")
	optsLink:Slider("width", "Width", 2, 1, 3, 1, nil, "px"):SetTip({
		title = "Width",
		body = "Bar thickness in pixels.",
	})
	optsLink:Toggle("outline", "Outline", true)
	local outlineLink = optsLink:OnKey("outline")
	outlineLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)
	espStateColors.Register({
		id = "healthbarOutline",
		label = "Health Bar Outline",
		default = DEFAULT_OUTLINE,
		transparency = 0,
	})
	optsLink:Colorpicker("backgroundColor", "Background", DEFAULT_OUTLINE, 0):SetTip({
		title = "Background",
		body = "Color behind the health fill.",
	})

	local widthLink = link:Get("healthbar.opts.width")
	local cache = { width = peek(widthLink._state) :: number }
	sub(widthLink._state, function(v: number): ()
		cache.width = v
	end)

	return {
		enabled = link:Get("healthbar"),
		color = link:Get("healthbar.color"),
		outline = link:Get("healthbar.opts.outline"),
		outlineColor = link:Get("healthbar.opts.outline.outlineColor"),
		backgroundColor = link:Get("healthbar.opts.backgroundColor"),
		width = widthLink,
		cache = cache,
	}
end

local function createState(_player: Player, basePlayer: any, _settings: Settings): State
	local state: State = {
		visible = createBindable(false),
		healthRatio = createBindable(1),
		alpha = createBindable(1),
		_displayedRatio = 1,
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
	local target = math.clamp(state._health / maxH, 0, 1)

	local displayed
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
	state.healthRatio.set(displayed)
	state.alpha.set(ctx.alpha)
	state.visible.set(true)
end)

local GRADIENT_ROTATION = 90
local FILL_ANCHOR = Vector2.new(0, 1)
local FILL_POSITION = UDim2.fromScale(0, 1)

local healthRatioToSize = LPH_NO_VIRTUALIZE(function(r: number): UDim2
	return UDim2.new(1, 0, math.max(r, 0), 0)
end)

local toNumberSequence = LPH_NO_VIRTUALIZE(function(t: number): NumberSequence
	return NumberSequence.new(t)
end)

local render = LPH_NO_VIRTUALIZE(
	function(props: { state: State, settings: Settings, userId: number? }): React.Element<any>?
		local state = props.state
		local settings = props.settings

		local enabled = useAt(settings.enabled._state) :: boolean
		local outline = useAt(settings.outline._state) :: boolean
		local width = useAt(settings.width._state) :: number
		local colorpicker = espStateColors.useResolved("healthbar", settings.color, props.userId)
		local outlinePicker = espStateColors.useResolved("healthbarOutline", settings.outlineColor, props.userId)

		if not enabled then
			return nil
		end

		local backgroundPicker = settings.backgroundColor
		local fadeTransparency = fadedTransparency(state.alpha.binding)

		return e("Frame", {
			Position = UDim2.new(0, -GAP_FROM_BOX - width, 0, 0),
			Size = UDim2.new(0, width, 1, 0),
			Visible = state.visible.binding,
			BorderSizePixel = 0,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = fadeTransparency,
		}, {
			Fill = e("Frame", {
				AnchorPoint = FILL_ANCHOR,
				Position = FILL_POSITION,
				Size = state.healthRatio.binding:map(healthRatioToSize),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = fadeTransparency,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, {
				UIGradient = e("UIGradient", {
					Color = colorpicker._currentGradient,
					Rotation = GRADIENT_ROTATION,
					Transparency = colorpicker._currentTransparency:map(toNumberSequence),
				}),
			}),
			Outline = outline and e("UIStroke", {
				Color = WHITE,
				Transparency = fadeTransparency,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Outer,
				LineJoinMode = Enum.LineJoinMode.Miter,
				ZIndex = 1,
			}, {
				Gradient = e("UIGradient", {
					Color = outlinePicker._currentGradient,
					Rotation = GRADIENT_ROTATION,
					Transparency = outlinePicker._currentTransparency:map(toNumberSequence),
				}),
			}) or nil,
			UIGradient = e("UIGradient", {
				Color = backgroundPicker._currentGradient,
				Rotation = GRADIENT_ROTATION,
				Transparency = backgroundPicker._currentTransparency:map(toNumberSequence),
			}),
		})
	end
)

return {
	id = "healthbar",
	container = true,
	setup = setup,
	createState = createState,
	update = update,
	render = render,
	destroyState = destroyState,
} :: EspElement.EspElement<State, Settings>
