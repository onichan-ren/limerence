local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")

local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement
local useAt = ReactCharm.useAtom
local createBindable = EspElement.createBindable
local fadedTransparency = EspElement.fadedTransparency
local vector2ToUDim2Offset = EspElement.vector2ToUDim2Offset
local stepSwitchFade = EspElement.stepSwitchFade

local DEFAULT_COLOR = Color3.new(1, 1, 1)
local GAP_FROM_BOX = 3
local ICON_ASPECT = 2

local BELOW_ANCHOR = Vector2.new(0.5, 0)

local function belowToUDim2(o: number): UDim2
	return UDim2.new(0.5, 0, 1, o)
end

type State = {
	belowOffset: EspElement.Bindable<number>,
	size: EspElement.Bindable<Vector2>,
	visible: EspElement.Bindable<boolean>,
	alpha: EspElement.Bindable<number>,
	image: EspElement.Bindable<string>,
	_basePlayer: any,
} & EspElement.SwitchFade

type Settings = {
	enabled: any,
	color: any,
	size: any,
	cache: { size: number },
}

local function setup(link: gameUi.Linker): Settings
	link:Toggle("weaponIcon", "Weapon Icon", false):SetTip({
		title = "Weapon Icon",
		body = "Shows the enemy's current weapon icon below the ESP box.",
	})
	local iconLink = link:OnKey("weaponIcon")
	iconLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0)
	espStateColors.Register({ id = "weaponIcon", label = "Weapon Icon", default = DEFAULT_COLOR, transparency = 0 })
	iconLink:Submenu("opts", "Options")
	local optsLink = iconLink:OnKey("opts")
	optsLink:Slider("size", "Size", 14, 6, 32, 1, nil, "px"):SetTip({
		title = "Size",
		body = "Icon height in pixels.",
	})

	local sizeLink = link:Get("weaponIcon.opts.size")
	local cache = { size = peek(sizeLink._state) :: number }
	sub(sizeLink._state, function(value: number): ()
		cache.size = value
	end)

	return {
		enabled = link:Get("weaponIcon"),
		color = link:Get("weaponIcon.color"),
		size = sizeLink,
		cache = cache,
	}
end

local function createState(_player: Player, basePlayer: any, _settings: Settings): State
	return {
		belowOffset = createBindable(GAP_FROM_BOX),
		size = createBindable(Vector2.zero),
		visible = createBindable(false),
		alpha = createBindable(1),
		image = createBindable(""),
		_basePlayer = basePlayer,
		_switchKey = nil,
		_switchAlpha = 1,
	}
end

local update = LPH_NO_VIRTUALIZE(function(state: State, ctx: EspElement.EspCtx, settings: Settings): ()
	if not ctx.visible then
		ctx.extra.op1WeaponIconBelow = 0
		state.visible.set(false)
		return
	end

	local basePlayer = state._basePlayer
	local object = basePlayer and peek(basePlayer.object)
	local equipped = object and object.values and object.values.equipped

	local icon = equipped and equipped.icon
	if type(icon) ~= "string" or icon == "" then
		ctx.extra.op1WeaponIconBelow = 0
		state.visible.set(false)
		return
	end

	local fade, frozen = stepSwitchFade(state, equipped and equipped.display_name, ctx.dt, ctx.elementAnimations)

	if not frozen then
		state.image.set(icon)
	end

	local height = settings.cache.size
	state.size.set(Vector2.new(height * ICON_ASPECT, height))
	state.belowOffset.set(GAP_FROM_BOX + (ctx.extra.op1AmmoBarBelow or 0) + (ctx.extra.op1AmmoTextBelow or 0))
	ctx.extra.op1WeaponIconBelow = height + 2
	state.alpha.set(ctx.alpha * fade)
	state.visible.set(true)
end)

local render = LPH_NO_VIRTUALIZE(function(props: { state: State, settings: Settings, userId: number? }): React.Element<any>?
	local state = props.state
	local settings = props.settings

	local colorpicker = espStateColors.useResolved("weaponIcon", settings.color, props.userId)

	if not useAt(settings.enabled._state) :: boolean then
		return nil
	end

	return e("ImageLabel", {
		AnchorPoint = BELOW_ANCHOR,
		Position = state.belowOffset.binding:map(belowToUDim2),
		Size = state.size.binding:map(vector2ToUDim2Offset),
		Visible = state.visible.binding,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = state.image.binding,
		ImageColor3 = colorpicker._currentColor,
		ImageTransparency = fadedTransparency(state.alpha.binding, colorpicker._current),
		ScaleType = Enum.ScaleType.Fit,
	})
end)

return {
	id = "weaponIcon",
	container = true,
	setup = setup,
	createState = createState,
	update = update,
	render = render,
} :: EspElement.EspElement<State, Settings>
