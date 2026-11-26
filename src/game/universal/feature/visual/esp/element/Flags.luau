local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")
local ReactCharm = require("@pkg/ReactCharm")
local FileController = require("@feature/file/FileController")
local gameUi = require("@game/gameUi")
local SPRING = require("@ui/util/spring")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local playerState = require("@feature/record/module/playerState")

local e = React.createElement
local useAt = ReactCharm.useAtom
local useSpring = ReactRipple.useSpring
local useEffect = React.useEffect
local useMemo = React.useMemo
local joinBindings = React.joinBindings
local createBindable = EspElement.createBindable
local floor = math.floor

local GAP_FROM_BOX = 1
local BADGE_HEIGHT = 8
local BADGE_PAD_X = 3
local FLAG_GAP = 2
local TEXT_SIZE = 8

local DEFAULT_DISTANCE = Color3.fromRGB(200, 200, 200)
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)
local DEFAULT_STATE = Color3.fromRGB(225, 205, 150)

export type FlagDef = {
	id: string,
	menuLabel: string,
	badgeLabel: string,
	default: boolean,
	color: Color3,
	icon: string?,
	priority: number?,
	atomKeys: { string },
	compute: (values: { any }) -> (boolean, string?),
}

local _gameFlags: { FlagDef } = {}
local _distanceSuffix = "m"
local NIL_ATOM = Charm.atom(nil)

local function Configure(flags: { FlagDef }): ()
	local sorted = table.clone(flags)
	table.sort(sorted, function(a: FlagDef, b: FlagDef): boolean
		local ap = a.priority or 0
		local bp = b.priority or 0
		if ap ~= bp then
			return ap > bp
		end
		return #a.menuLabel > #b.menuLabel
	end)
	_gameFlags = sorted
end

type FlagSettings = {
	enabled: any,
	color: any,
}

type State = {
	position: EspElement.Bindable<Vector2>,
	visible: EspElement.Bindable<boolean>,
	alpha: EspElement.Bindable<number>,
	distanceText: EspElement.Bindable<string>,
	basePlayer: any,
	userId: number,
	_frame: number,
	_hasText: boolean,
}

type Settings = {
	enabled: any,
	outline: any,
	outlineColor: any,
	distanceEnabled: any,
	distanceColor: any,
	stateEnabled: any,
	stateColor: any,
	flags: { [string]: FlagSettings },
}

local function setup(link: gameUi.Linker, opts: { distanceSuffix: string? }?): Settings
	if opts and opts.distanceSuffix then
		_distanceSuffix = opts.distanceSuffix
	end
	link:Toggle("flags", "Flags", false):SetTip({
		title = "Flags",
		body = "Text labels for player status and info, stacked beside the ESP box.",
	})
	local flagsLink = link:OnKey("flags")
	flagsLink:Submenu("opts", "Flag Options")
	local optsLink = flagsLink:OnKey("opts")

	optsLink:Toggle("outline", "Outline", true)
	local outlineLink = optsLink:OnKey("outline")
	outlineLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)

	optsLink:Toggle("distance", "Distance", false)
	local distanceLink = optsLink:OnKey("distance")
	distanceLink:Colorpicker("color", "Color", DEFAULT_DISTANCE, 0)

	local flagSettings: { [string]: FlagSettings } = {}
	for _, def in next, _gameFlags do
		optsLink:Toggle(def.id, def.menuLabel, def.default)
		local subLink = optsLink:OnKey(def.id)
		subLink:Colorpicker("color", "Color", def.color, 0)
		flagSettings[def.id] = {
			enabled = link:Get(`flags.opts.{def.id}`),
			color = link:Get(`flags.opts.{def.id}.color`),
		}
	end

	optsLink:Toggle("state", "Player State", false):SetTip({
		title = "Player State",
		body = "Shows the state you assigned the player in the record menu (Friendly, Priority, etc.).",
	})
	optsLink:OnKey("state"):Colorpicker("color", "Color", DEFAULT_STATE, 0)

	return {
		enabled = link:Get("flags"),
		outline = link:Get("flags.opts.outline"),
		outlineColor = link:Get("flags.opts.outline.outlineColor"),
		distanceEnabled = link:Get("flags.opts.distance"),
		distanceColor = link:Get("flags.opts.distance.color"),
		stateEnabled = link:Get("flags.opts.state"),
		stateColor = link:Get("flags.opts.state.color"),
		flags = flagSettings,
	}
end

local function createState(_player: Player, basePlayer: any, _settings: Settings): State
	return {
		position = createBindable(Vector2.zero),
		visible = createBindable(false),
		alpha = createBindable(1),
		distanceText = createBindable(""),
		basePlayer = basePlayer,
		userId = _player and _player.UserId or 0,
		_frame = 0,
		_hasText = false,
	}
end

local update = LPH_NO_VIRTUALIZE(function(state: State, ctx: EspElement.EspCtx, _settings: Settings?): ()
	if not ctx.visible then
		state.visible.set(false)
		return
	end
	local frame = state._frame + 1
	state._frame = frame
	if frame % 2 == 0 or not state._hasText then
		local dist = ctx.dist
		if dist < 0 then
			dist = (ctx.hrp.Position - ctx.camPos).Magnitude
			ctx.dist = dist
		end
		state.distanceText.set(`{floor(dist)}{_distanceSuffix}`)
		state._hasText = true
	end
	state.alpha.set(ctx.alpha)
	state.visible.set(true)
end)

type BadgeProps = {
	visible: boolean,
	label: string?,
	labelBinding: any?,
	icon: string?,
	color: any,
	outline: boolean,
	outlineColor: any,
	parentAlpha: any,
	font: Font,
	layoutOrder: number,
}

local FlagBadge = LPH_NO_VIRTUALIZE(function(props: BadgeProps): React.Element<any>?
	local bind, spring = useSpring(0, SPRING.quick)

	useEffect(function()
		spring:setGoal(props.visible and 1 or 0)
	end, { props.visible })

	local combinedAlpha = useMemo(function()
		return joinBindings({ self = bind, parent = props.parentAlpha }):map(
			function(values: { self: number, parent: number }): number
				return values.self * values.parent
			end
		)
	end, { bind, props.parentAlpha })

	local fadeTransparency = useMemo(function()
		return combinedAlpha:map(function(v: number): number
			return 1 - v
		end)
	end, { combinedAlpha })

	local visibleBind = useMemo(function()
		return bind:map(function(v: number): boolean
			return v > 0.01
		end)
	end, { bind })

	local sizeBind = useMemo(function()
		local height = props.icon and BADGE_HEIGHT + 2 or BADGE_HEIGHT
		return bind:map(function(v: number): UDim2
			local scale = 0.85 + v * 0.15
			return UDim2.new(0, 0, 0, height * scale)
		end)
	end, { bind, props.icon } :: { any })

	local colorpicker = props.color
	local outlinePicker = props.outlineColor

	return e("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = sizeBind,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Visible = visibleBind,
		AnchorPoint = Vector2.new(0, 0),
	}, {
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, BADGE_PAD_X),
			PaddingRight = UDim.new(0, BADGE_PAD_X),
		}),
		Label = props.icon
			and e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = props.icon,
				ImageColor3 = colorpicker._currentColor,
				ImageTransparency = fadeTransparency,
				Size = UDim2.new(0, BADGE_HEIGHT + 2, 1, 0),
				ScaleType = Enum.ScaleType.Stretch,
			})
			or e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = props.labelBinding or props.label,
				TextColor3 = colorpicker._currentColor,
				TextTransparency = fadeTransparency,
				TextSize = TEXT_SIZE,
				FontFace = props.font,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Top,
			}, {
				Outline = props.outline and e("UIStroke", {
					Color = outlinePicker._currentColor,
					Transparency = fadeTransparency,
					Thickness = 1,
					LineJoinMode = Enum.LineJoinMode.Miter,
				}) or nil,
			}),
	})
end)

type StatusBadgeProps = {
	spec: FlagDef,
	basePlayer: any,
	settings: FlagSettings,
	outline: boolean,
	outlineColor: any,
	parentAlpha: any,
	font: Font,
	layoutOrder: number,
}

local StatusFlagBadge = LPH_NO_VIRTUALIZE(function(props: StatusBadgeProps): React.Element<any>?
	local spec = props.spec
	local basePlayer = props.basePlayer
	local enabled = useAt(props.settings.enabled._state) :: boolean
	local values: { any } = {}
	for i, key in next, spec.atomKeys do
		values[i] = useAt(basePlayer[key] or NIL_ATOM)
	end
	local visible, label = spec.compute(values)
	return e(FlagBadge, {
		visible = enabled and visible,
		label = label or spec.badgeLabel,
		icon = spec.icon,
		color = props.settings.color,
		outline = props.outline,
		outlineColor = props.outlineColor,
		parentAlpha = props.parentAlpha,
		font = props.font,
		layoutOrder = props.layoutOrder,
	})
end)

local FLAGS_POSITION = UDim2.new(1, GAP_FROM_BOX, 0, -2)

type RenderProps = { state: State, settings: Settings }

local render = LPH_NO_VIRTUALIZE(function(props: RenderProps): React.Element<any>?
	local state = props.state
	local settings = props.settings
	local basePlayer = state.basePlayer

	local masterEnabled = useAt(settings.enabled._state) :: boolean
	local outline = useAt(settings.outline._state) :: boolean
	local distanceEnabled = useAt(settings.distanceEnabled._state) :: boolean
	local stateEnabled = useAt(settings.stateEnabled._state) :: boolean
	local assignments = useAt(playerState._assignments) :: { [number]: string }

	local font = FileController.Get("font", "pixel2") :: Font

	if not masterEnabled then
		return nil
	end

	local stateId = assignments[state.userId]
	local stateDef = stateId and playerState.Get(stateId) or nil
	local stateLabel = stateDef and string.upper(stateDef.label) or ""

	local children: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, FLAG_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
		distance = e(FlagBadge, {
			visible = distanceEnabled,
			labelBinding = state.distanceText.binding,
			color = settings.distanceColor,
			outline = outline,
			outlineColor = settings.outlineColor,
			parentAlpha = state.alpha.binding,
			font = font,
			layoutOrder = 1,
		}),
	}

	for i, spec in next, _gameFlags do
		children[spec.id] = e(StatusFlagBadge, {
			spec = spec,
			basePlayer = basePlayer,
			settings = settings.flags[spec.id],
			outline = outline,
			outlineColor = settings.outlineColor,
			parentAlpha = state.alpha.binding,
			font = font,
			layoutOrder = i + 1,
		})
	end

	children.state = e(FlagBadge, {
		visible = stateEnabled and stateDef ~= nil,
		label = stateLabel,
		color = settings.stateColor,
		outline = outline,
		outlineColor = settings.outlineColor,
		parentAlpha = state.alpha.binding,
		font = font,
		layoutOrder = #_gameFlags + 2,
	})

	return e("Frame", {
		Position = FLAGS_POSITION,
		Size = UDim2.new(0, 0, 0, BADGE_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = state.visible.binding,
		AnchorPoint = Vector2.new(0, 0),
	}, children)
end)

local Flags = {
	id = "flags",
	container = true,
	setup = setup,
	createState = createState,
	update = update,
	render = render,
	Configure = Configure,
} :: EspElement.EspElement<State, Settings> & { Configure: (flags: { FlagDef }) -> () }

return Flags
