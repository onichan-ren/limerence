local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local Charm = require("@pkg/Charm")
local FileController = require("@feature/file/FileController")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")

local e = React.createElement
local useAt = ReactCharm.useAtom
local peek = Charm.peek
local createBindable = EspElement.createBindable
local fadedTransparency = EspElement.fadedTransparency
local stepSwitchFade = EspElement.stepSwitchFade

local DEFAULT_COLOR = ColorSequence.new(Color3.fromRGB(200, 200, 200))
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)
local WHITE = Color3.new(1, 1, 1)
local GAP_FROM_BOX = 3

local BELOW_ANCHOR = Vector2.new(0.5, 0)

local function belowToUDim2(o: number): UDim2
	return UDim2.new(0.5, 0, 1, o)
end

type State = {
	belowOffset: EspElement.Bindable<number>,
	visible: EspElement.Bindable<boolean>,
	alpha: EspElement.Bindable<number>,
	text: EspElement.Bindable<string>,
	_lastMag: number,
	_lastReserve: number,
	_basePlayer: any,
} & EspElement.SwitchFade

type Settings = {
	enabled: any,
	color: any,
	outline: any,
	outlineColor: any,
}

local function setup(link: gameUi.Linker): Settings
	link:Toggle("ammoText", "Ammo Text", false):SetTip({
		title = "Ammo Text",
		body = "Shows magazine and reserve ammo below the ESP box.",
	})
	local ammoTextLink = link:OnKey("ammoText")
	ammoTextLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0)
	espStateColors.Register({ id = "ammoText", label = "Ammo Text", default = DEFAULT_COLOR, transparency = 0 })
	ammoTextLink:Submenu("opts", "Options")
	local optsLink = ammoTextLink:OnKey("opts")
	optsLink:Toggle("outline", "Outline", true)
	local outlineLink = optsLink:OnKey("outline")
	outlineLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)
	espStateColors.Register({ id = "ammoTextOutline", label = "Ammo Text Outline", default = DEFAULT_OUTLINE, transparency = 0 })

	return {
		enabled = link:Get("ammoText"),
		color = link:Get("ammoText.color"),
		outline = link:Get("ammoText.opts.outline"),
		outlineColor = link:Get("ammoText.opts.outline.outlineColor"),
	}
end

local function createState(_player: Player, basePlayer: any, _settings: Settings): State
	return {
		belowOffset = createBindable(GAP_FROM_BOX),
		visible = createBindable(false),
		alpha = createBindable(1),
		text = createBindable(""),
		_lastMag = -1,
		_lastReserve = -1,
		_basePlayer = basePlayer,
		_switchKey = nil,
		_switchAlpha = 1,
	}
end

local update = LPH_NO_VIRTUALIZE(function(state: State, ctx: EspElement.EspCtx, _settings: Settings): ()
	local basePlayer = state._basePlayer
	local object = basePlayer and peek(basePlayer.object)
	local equipped = object and object.values and object.values.equipped
	local states = equipped and equipped.states
	local magState = states and states.mag
	local magSizeState = states and states.mag_size

	if not ctx.visible or not magState or not magSizeState then
		ctx.extra.op1AmmoTextBelow = 0
		state.visible.set(false)
		return
	end

	local fade, frozen = stepSwitchFade(state, equipped and equipped.display_name, ctx.dt, ctx.elementAnimations)

	if not frozen then
		local mag = magState:get() or 0
		local reserveState = states.bullets
		local reserve = (reserveState and reserveState:get()) or 0

		if mag ~= state._lastMag or reserve ~= state._lastReserve then
			state._lastMag = mag
			state._lastReserve = reserve
			state.text.set(`{mag}/{reserve}`)
		end
	end

	state.belowOffset.set(GAP_FROM_BOX + (ctx.extra.op1AmmoBarBelow or 0))
	ctx.extra.op1AmmoTextBelow = 10
	state.alpha.set(ctx.alpha * fade)
	state.visible.set(true)
end)

local render = LPH_NO_VIRTUALIZE(function(props: { state: State, settings: Settings, userId: number? }): React.Element<any>?
	local state = props.state
	local settings = props.settings

	local enabled = useAt(settings.enabled._state) :: boolean
	local outline = useAt(settings.outline._state) :: boolean
	local colorpicker = espStateColors.useResolved("ammoText", settings.color, props.userId)
	local outlinePicker = espStateColors.useResolved("ammoTextOutline", settings.outlineColor, props.userId)

	if not enabled then
		return nil
	end

	local alphaBinding = state.alpha.binding

	return e("TextLabel", {
		AnchorPoint = BELOW_ANCHOR,
		Position = state.belowOffset.binding:map(belowToUDim2),
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
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
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
	id = "ammoText",
	container = true,
	setup = setup,
	createState = createState,
	update = update,
	render = render,
} :: EspElement.EspElement<State, Settings>
