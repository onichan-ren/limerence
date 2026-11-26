local Charm = require("@pkg/Charm")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")

local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement
local useAt = ReactCharm.useAtom
local createBindable = EspElement.createBindable
local fadedTransparency = EspElement.fadedTransparency
local stepSwitchFade = EspElement.stepSwitchFade

local AMMO_LERP_RATE = 10
local GAP_FROM_BOX = 3
local AMMO_POSITION = UDim2.new(0, 0, 1, GAP_FROM_BOX)

local DEFAULT_FILL = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 153)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(66, 149, 149)),
})
local DEFAULT_BACKGROUND = Color3.fromRGB(42, 42, 42)
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)
local WHITE = Color3.new(1, 1, 1)

type State = {
	visible: EspElement.Bindable<boolean>,
	ammoRatio: EspElement.Bindable<number>,
	alpha: EspElement.Bindable<number>,
	basePlayer: any,
	_displayedRatio: number,
} & EspElement.SwitchFade

type Settings = {
	enabled: any,
	color: any,
	backgroundColor: any,
	outline: any,
	outlineColor: any,
	thickness: any,
	cache: { thickness: number },
}

local function setup(link: gameUi.Linker): Settings
	link:Toggle("ammoBar", "Ammo Bar", false):SetTip({
		title = "Ammo Bar",
		body = "Horizontal estimated magazine bar along the bottom of the ESP box.",
	})
	local barLink = link:OnKey("ammoBar")
	barLink:Colorpicker("color", "Fill", DEFAULT_FILL, 0)
	espStateColors.Register({ id = "ammoBar", label = "Ammo Bar", default = DEFAULT_FILL, transparency = 0 })
	barLink:Submenu("opts", "Ammo Bar Options")
	local optsLink = barLink:OnKey("opts")
	optsLink:Slider("thickness", "Thickness", 2, 1, 4, 1, nil, "px")
	optsLink:Toggle("outline", "Outline", true)
	optsLink:OnKey("outline"):Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)
	espStateColors.Register({ id = "ammoBarOutline", label = "Ammo Bar Outline", default = DEFAULT_OUTLINE, transparency = 0 })
	optsLink:Colorpicker("backgroundColor", "Background", DEFAULT_BACKGROUND, 0)

	local thicknessLink = link:Get("ammoBar.opts.thickness")
	local cache = { thickness = peek(thicknessLink._state) :: number }
	sub(thicknessLink._state, function(v: number): ()
		cache.thickness = v
	end)

	return {
		enabled = link:Get("ammoBar"),
		color = link:Get("ammoBar.color"),
		backgroundColor = link:Get("ammoBar.opts.backgroundColor"),
		outline = link:Get("ammoBar.opts.outline"),
		outlineColor = link:Get("ammoBar.opts.outline.outlineColor"),
		thickness = thicknessLink,
		cache = cache,
	}
end

local function createState(_player: Player, basePlayer: any, _settings: Settings): State
	return {
		visible = createBindable(false),
		ammoRatio = createBindable(1),
		alpha = createBindable(1),
		basePlayer = basePlayer,
		_displayedRatio = 1,
		_switchKey = nil,
		_switchAlpha = 1,
	}
end

local update = LPH_NO_VIRTUALIZE(function(state: State, ctx: EspElement.EspCtx, _settings: Settings): ()
	local ammoAtom = state.basePlayer and state.basePlayer.ammo
	local capacityAtom = state.basePlayer and state.basePlayer.ammoCapacity
	local ammo = ammoAtom and tonumber(peek(ammoAtom))
	local capacity = capacityAtom and tonumber(peek(capacityAtom))
	if not ctx.visible or ammo == nil or capacity == nil or capacity <= 0 then
		state.visible.set(false)
		return
	end

	local fade, frozen = stepSwitchFade(state, state.basePlayer and peek(state.basePlayer.weapon), ctx.dt, ctx.elementAnimations)

	local displayed
	if frozen then
		displayed = state._displayedRatio
	else
		local target = math.clamp(ammo / capacity, 0, 1)
		if ctx.elementAnimations and ctx.dt > 0 then
			displayed = state._displayedRatio + (target - state._displayedRatio) * (1 - math.exp(-ctx.dt * AMMO_LERP_RATE))
		else
			displayed = target
		end
	end
	state._displayedRatio = displayed
	state.ammoRatio.set(displayed)
	state.alpha.set(ctx.alpha * fade)
	state.visible.set(true)
end)

local function ammoRatioToSize(r: number): UDim2
	return UDim2.new(math.max(r, 0), 0, 1, 0)
end

local function toNumberSequence(t: number): NumberSequence
	return NumberSequence.new(t)
end

local render = LPH_NO_VIRTUALIZE(function(props: { state: State, settings: Settings, userId: number? }): React.Element<any>?
	local state = props.state
	local settings = props.settings

	local fillPicker = espStateColors.useResolved("ammoBar", settings.color, props.userId)
	local outlinePicker = espStateColors.useResolved("ammoBarOutline", settings.outlineColor, props.userId)

	if not useAt(settings.enabled._state) :: boolean then
		return nil
	end

	local outline = useAt(settings.outline._state) :: boolean
	local thickness = useAt(settings.thickness._state) :: number
	local backgroundPicker = settings.backgroundColor
	local alphaBinding = state.alpha.binding

	return e("Frame", {
		Position = AMMO_POSITION,
		Size = UDim2.new(1, 0, 0, thickness),
		Visible = state.visible.binding,
		BackgroundColor3 = backgroundPicker._currentColor,
		BackgroundTransparency = fadedTransparency(alphaBinding, backgroundPicker._current),
		BorderSizePixel = 0,
	}, {
		Fill = e("Frame", {
			Size = state.ammoRatio.binding:map(ammoRatioToSize),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = fadedTransparency(alphaBinding),
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			UIGradient = e("UIGradient", {
				Color = fillPicker._currentGradient,
				Rotation = 0,
				Transparency = fillPicker._currentTransparency:map(toNumberSequence),
			}),
		}),
		Outline = outline and e("UIStroke", {
			Color = outlinePicker._currentColor,
			Transparency = fadedTransparency(alphaBinding, outlinePicker._current),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Miter,
		}) or nil,
	})
end)

return {
	id = "ammoBar",
	container = true,
	setup = setup,
	createState = createState,
	update = update,
	render = render,
} :: EspElement.EspElement<State, Settings>
