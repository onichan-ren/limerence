local Charm = require("@pkg/Charm")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/bloxstrike/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")

local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement
local useAt = ReactCharm.useAtom
local createBindable = EspElement.createBindable
local fadedTransparency = EspElement.fadedTransparency
local vector2ToUDim2Offset = EspElement.vector2ToUDim2Offset
local stepSwitchFade = EspElement.stepSwitchFade
local v2 = Vector2.new

local GAP_FROM_BOX = 3
local ICON_ASPECT = 2
local DEFAULT_COLOR = Color3.new(1, 1, 1)

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
} & EspElement.WeaponIconCache & EspElement.SwitchFade

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
	optsLink:Slider("size", "Size", 12, 6, 32, 1, nil, "px"):SetTip({
		title = "Size",
		body = "Icon height in pixels.",
	})

	local sizeLink = link:Get("weaponIcon.opts.size")
	local cache = { size = peek(sizeLink._state) :: number }
	sub(sizeLink._state, function(v: number): ()
		cache.size = v
	end)

	return {
		enabled = link:Get("weaponIcon"),
		color = link:Get("weaponIcon.color"),
		size = sizeLink,
		cache = cache,
	}
end

local function createState(_player: Player, basePlayer: any, _settings: Settings): State
	local state: State = {
		belowOffset = createBindable(0),
		size = createBindable(Vector2.zero),
		visible = createBindable(false),
		alpha = createBindable(1),
		image = createBindable(""),
		_weaponName = nil,
		_icon = nil,
		_switchKey = nil,
		_switchAlpha = 1,
		_playerUnsub = function() end,
	}
	EspElement.attachWeaponIconCache(basePlayer, state)
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

	local icon = state._icon
	if not icon then
		state.visible.set(false)
		return
	end

	local fade, frozen = stepSwitchFade(state, state._weaponName, ctx.dt, ctx.elementAnimations)
	if not frozen then
		state.image.set(icon)
	end

	local height = settings.cache.size
	state.belowOffset.set(GAP_FROM_BOX + (ctx.extra.ammoBarExtraBelow or 0) + (ctx.extra.ammoTextExtraBelow or 0))
	state.size.set(v2(height * ICON_ASPECT, height))
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
	destroyState = destroyState,
} :: EspElement.EspElement<State, Settings>
