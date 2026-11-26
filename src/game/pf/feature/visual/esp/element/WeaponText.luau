local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local FileController = require("@feature/file/FileController")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")
local Charm = require("@pkg/Charm")

local e = React.createElement
local useAt = ReactCharm.useAtom
local peek = Charm.peek
local sub = Charm.subscribe
local createBindable = EspElement.createBindable
local fadedTransparency = EspElement.fadedTransparency
local stepSwitchFade = EspElement.stepSwitchFade

local DEFAULT_COLOR = ColorSequence.new(Color3.fromRGB(200, 200, 200))
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)
local WHITE = Color3.new(1, 1, 1)
local GAP_FROM_BOX = 3

local BELOW_ANCHOR = Vector2.new(0.5, 0)

type State = {
	visible: EspElement.Bindable<boolean>,
	alpha: EspElement.Bindable<number>,
	text: EspElement.Bindable<string>,
	belowOffset: EspElement.Bindable<number>,
	_weapon: string,
	_upper: string,
	_playerUnsub: () -> (),
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
	local state: State = {
		visible = createBindable(false),
		alpha = createBindable(1),
		text = createBindable(""),
		belowOffset = createBindable(GAP_FROM_BOX),
		_weapon = "",
		_upper = "",
		_playerUnsub = function() end,
		_switchKey = nil,
		_switchAlpha = 1,
	}

	if basePlayer and basePlayer.weapon then
		state._weapon = peek(basePlayer.weapon)
		state._upper = string.upper(state._weapon)
		state._playerUnsub = sub(basePlayer.weapon, function(weapon: string): ()
			state._weapon = weapon
			state._upper = string.upper(weapon)
		end)
	end

	return state
end

local function destroyState(state: State, _settings: Settings): ()
	state._playerUnsub()
end

local update = LPH_NO_VIRTUALIZE(function(state: State, ctx: EspElement.EspCtx, _settings: Settings): ()
	if not ctx.visible or state._weapon == "" then
		state.visible.set(false)
		return
	end

	local fade, frozen = stepSwitchFade(state, state._weapon, ctx.dt, ctx.elementAnimations)

	if not frozen then
		state.text.set(state._upper)
	end

	state.belowOffset.set(GAP_FROM_BOX + (ctx.extra.ammoBarExtraBelow or 0) + (ctx.extra.ammoTextExtraBelow or 0))
	state.alpha.set(ctx.alpha * fade)
	state.visible.set(true)
end)

local function belowToUDim2(offset: number): UDim2
	return UDim2.new(0.5, 0, 1, offset)
end

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
	destroyState = destroyState,
} :: EspElement.EspElement<State, Settings>
