local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local FileController = require("@feature/file/FileController")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")

local e = React.createElement
local useAt = ReactCharm.useAtom
local createBindable = EspElement.createBindable
local fadedTransparency = EspElement.fadedTransparency

local NAME_ANCHOR = Vector2.new(0.5, 1)

local DEFAULT_COLOR = ColorSequence.new(Color3.fromRGB(225, 225, 225))
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)
local WHITE = Color3.new(1, 1, 1)
local OFFSET_ABOVE_BOX = 3

type State = {
	visible: EspElement.Bindable<boolean>,
	alpha: EspElement.Bindable<number>,
	text: string,
}

type Settings = {
	enabled: any,
	color: any,
	outline: any,
	outlineColor: any,
	size: any,
}

local function setup(link: gameUi.Linker): Settings
	link:Toggle("name", "Name", false):SetTip({
		title = "Name",
		body = "Player display name above the ESP box.",
	})
	local nameLink = link:OnKey("name")
	nameLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0)
	espStateColors.Register({ id = "name", label = "Name", default = DEFAULT_COLOR, transparency = 0 })
	nameLink:Submenu("opts", "Options")
	local optsLink = nameLink:OnKey("opts")
	optsLink:Toggle("outline", "Outline", true)
	local outlineLink = optsLink:OnKey("outline")
	outlineLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)
	espStateColors.Register({ id = "nameOutline", label = "Name Outline", default = DEFAULT_OUTLINE, transparency = 0 })
	optsLink:Slider("size", "Size", 7, 8, 9, 1, nil, "px"):SetTip({
		title = "Size",
		body = "Text size in pixels.",
	})

	return {
		enabled = link:Get("name"),
		color = link:Get("name.color"),
		outline = link:Get("name.opts.outline"),
		outlineColor = link:Get("name.opts.outline.outlineColor"),
		size = link:Get("name.opts.size"),
	}
end

local function createState(player: Player, _basePlayer: any, _settings: Settings): State
	return {
		visible = createBindable(false),
		alpha = createBindable(1),
		text = player.Name,
	}
end

local update = LPH_NO_VIRTUALIZE(function(state: State, ctx: EspElement.EspCtx, _settings: Settings?): ()
	if not ctx.visible then
		state.visible.set(false)
		return
	end
	state.alpha.set(ctx.alpha)
	state.visible.set(true)
end)

local render = LPH_NO_VIRTUALIZE(function(props: { state: State, settings: Settings, userId: number? }): React.Element<any>?
	local state = props.state
	local settings = props.settings

	local enabled = useAt(settings.enabled._state) :: boolean
	local outline = useAt(settings.outline._state) :: boolean
	local size = useAt(settings.size._state) :: number
	local colorpicker = espStateColors.useResolved("name", settings.color, props.userId)
	local outlinePicker = espStateColors.useResolved("nameOutline", settings.outlineColor, props.userId)

	if not enabled then
		return nil
	end

	local alphaBinding = state.alpha.binding

	return e("TextLabel", {
		AnchorPoint = NAME_ANCHOR,
		Position = UDim2.new(0.5, 0, 0, -OFFSET_ABOVE_BOX),
		Visible = state.visible.binding,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = state.text,
		TextColor3 = WHITE,
		TextTransparency = fadedTransparency(alphaBinding, colorpicker._current),
		AutomaticSize = Enum.AutomaticSize.XY,
		TextSize = size,
		FontFace = FileController.Get("font", "pixel"),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Bottom,
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
	id = "name",
	container = true,
	setup = setup,
	createState = createState,
	update = update,
	render = render,
} :: EspElement.EspElement<State, Settings>
