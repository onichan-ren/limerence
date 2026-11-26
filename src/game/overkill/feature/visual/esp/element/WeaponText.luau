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
	_upperKey: string?,
	_basePlayer: any,
} & EspElement.SwitchFade

type Settings = {
	enabled: any,
	color: any,
	outline: any,
	outlineColor: any,
}

local function setup(link: gameUi.Linker): Settings
	link:Toggle("weaponText", "Weapon Text", false):SetTip({
		title = "Weapon Text",
		body = "Shows the enemy's current weapon name below the ESP box.",
	})
	local weaponTextLink = link:OnKey("weaponText")
	weaponTextLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0)
	espStateColors.Register({ id = "weaponText", label = "Weapon Text", default = DEFAULT_COLOR, transparency = 0 })
	weaponTextLink:Submenu("opts", "Options")
	local optsLink = weaponTextLink:OnKey("opts")
	optsLink:Toggle("outline", "Outline", true)
	local outlineLink = optsLink:OnKey("outline")
	outlineLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)
	espStateColors.Register({ id = "weaponTextOutline", label = "Weapon Text Outline", default = DEFAULT_OUTLINE, transparency = 0 })

	return {
		enabled = link:Get("weaponText"),
		color = link:Get("weaponText.color"),
		outline = link:Get("weaponText.opts.outline"),
		outlineColor = link:Get("weaponText.opts.outline.outlineColor"),
	}
end

local function createState(_player: Player, basePlayer: any, _settings: Settings): State
	return {
		belowOffset = createBindable(GAP_FROM_BOX),
		visible = createBindable(false),
		alpha = createBindable(1),
		text = createBindable(""),
		_upperKey = nil,
		_basePlayer = basePlayer,
		_switchKey = nil,
		_switchAlpha = 1,
	}
end

local update = LPH_NO_VIRTUALIZE(function(state: State, ctx: EspElement.EspCtx, _settings: Settings): ()
	if not ctx.visible then
		state.visible.set(false)
		return
	end

	local basePlayer = state._basePlayer
	local name = basePlayer and peek(basePlayer.weaponName)

	if type(name) ~= "string" or name == "" then
		state.visible.set(false)
		return
	end

	local fade, frozen = stepSwitchFade(state, name, ctx.dt, ctx.elementAnimations)

	if not frozen and name ~= state._upperKey then
		state._upperKey = name
		state.text.set(string.upper(name))
	end

	state.belowOffset.set(GAP_FROM_BOX + (ctx.extra.overkillAmmoBarBelow or 0) + (ctx.extra.overkillAmmoTextBelow or 0))
	state.alpha.set(ctx.alpha * fade)
	state.visible.set(true)
end)

local render = LPH_NO_VIRTUALIZE(function(props: { state: State, settings: Settings, userId: number? }): React.Element<any>?
	local state = props.state
	local settings = props.settings

	local enabled = useAt(settings.enabled._state) :: boolean
	local outline = useAt(settings.outline._state) :: boolean
	local colorpicker = espStateColors.useResolved("weaponText", settings.color, props.userId)
	local outlinePicker = espStateColors.useResolved("weaponTextOutline", settings.outlineColor, props.userId)

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
	id = "weaponText",
	container = true,
	setup = setup,
	createState = createState,
	update = update,
	render = render,
} :: EspElement.EspElement<State, Settings>
