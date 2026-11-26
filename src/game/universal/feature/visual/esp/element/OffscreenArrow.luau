local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local FileController = require("@feature/file/FileController")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement
local useAt = ReactCharm.useAtom
local createBindable = EspElement.createBindable
local fadedTransparency = EspElement.fadedTransparency
local vector2ToUDim2Offset = EspElement.vector2ToUDim2Offset
local v2 = Vector2.new
local atan2 = math.atan2
local deg = math.deg
local sqrt = math.sqrt
local floor = math.floor
local exp = math.exp

local ARROW_FADE_RATE = 20
local ARROW_EPSILON = 0.004

local _fadeLastDt = -1
local _fadeBlend = 0

local DEFAULT_COLOR = Color3.fromRGB(220, 90, 90)
local DEFAULT_FILL = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 200, 130)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 95, 95)),
})
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)
local DEFAULT_BACKGROUND = Color3.fromRGB(18, 18, 18)
local DEFAULT_NAME = Color3.fromRGB(225, 225, 225)
local DEFAULT_NAME_OUTLINE = Color3.fromRGB(18, 18, 18)
local DEFAULT_DISTANCE = Color3.fromRGB(200, 200, 200)
local WHITE = Color3.new(1, 1, 1)

local _distanceSuffix = "m"

local HEALTH_GAP = 4
local NAME_GAP = 4
local DISTANCE_GAP = 4
local CENTER = Vector2.new(0.5, 0.5)
local HEALTH_ANCHOR = Vector2.new(1, 0.5)
local NAME_ANCHOR = Vector2.new(0.5, 1)
local DISTANCE_ANCHOR = Vector2.new(0.5, 0)
local GRADIENT_ROTATION = 90
local FILL_ANCHOR = Vector2.new(0.5, 1)
local FILL_POSITION = UDim2.fromScale(0.5, 1)
local ZERO_UDIM = UDim2.fromOffset(0, 0)

type State = {
	center: EspElement.Bindable<Vector2>,
	rotation: EspElement.Bindable<number>,
	distanceText: EspElement.Bindable<string>,
	healthRatio: EspElement.Bindable<number>,
	visible: EspElement.Bindable<boolean>,
	alpha: EspElement.Bindable<number>,
	text: string,
	_lastDistInt: number,
	_arrowFade: number,
} & EspElement.HealthCache

type Settings = {
	enabled: any,
	color: any,
	radius: any,
	size: any,
	health: any,
	healthColor: any,
	healthOutline: any,
	healthOutlineColor: any,
	healthBackground: any,
	healthThickness: any,
	name: any,
	nameColor: any,
	nameOutline: any,
	nameOutlineColor: any,
	nameSize: any,
	distanceEnabled: any,
	distanceColor: any,
	cache: { radius: number, size: number, thickness: number, maxDistance: number },
}

local function setup(link: gameUi.Linker, opts: { health: boolean?, distanceSuffix: string? }?): Settings
	local withHealth = not opts or opts.health ~= false
	if opts and opts.distanceSuffix then
		_distanceSuffix = opts.distanceSuffix
	end

	link:Toggle("offscreenArrow", "Offscreen Arrows", false):SetTip({
		title = "Offscreen Arrows",
		body = "Arrows around your crosshair pointing toward players who are off screen.",
	})
	local arrowLink = link:OnKey("offscreenArrow")
	arrowLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0)
	espStateColors.Register({ id = "offscreenArrow", label = "Offscreen Arrow", default = DEFAULT_COLOR, transparency = 0 })
	arrowLink:Submenu("opts", "Offscreen Options")

	local optsLink = arrowLink:OnKey("opts")
	optsLink:Slider("radius", "Radius", 150, 50, 400, 5, nil, "px"):SetTip({
		title = "Radius",
		body = "Distance of the arrows from the center of your screen.",
	})
	optsLink:Slider("size", "Size", 10, 10, 24, 1, nil, "px"):SetTip({
		title = "Size",
		body = "Arrow size in pixels.",
	})
	optsLink
		:Slider("maxDistance", "Max Distance", 0, 0, 2000, 50, nil, "st")
		:SetTip({
			title = "Max Distance",
			body = "Hides arrows for players farther than this. Zero means no limit.",
		})
		:SetValueTextOverrides({
			[0] = "Off",
		})

	if withHealth then
		optsLink:Toggle("health", "Health Bar", false):SetTip({
			title = "Health Bar",
			body = "Small health bar next to the arrow.",
		})
		local healthLink = optsLink:OnKey("health")
		healthLink:Colorpicker("healthColor", "Fill", DEFAULT_FILL, 0):SetTip({
			title = "Fill",
			body = "Health gradient (left = high HP, right = low).",
		})
		healthLink:Submenu("healthOpts", "Health Bar Options")
		local healthOptsLink = healthLink:OnKey("healthOpts")
		healthOptsLink:Slider("healthThickness", "Thickness", 3, 2, 6, 1, nil, "px"):SetTip({
			title = "Thickness",
			body = "Bar thickness in pixels.",
		})
		healthOptsLink:Toggle("healthOutline", "Outline", true)
		local healthOutlineLink = healthOptsLink:OnKey("healthOutline")
		healthOutlineLink:Colorpicker("healthOutlineColor", "Outline Color", DEFAULT_OUTLINE, 0)
		healthOptsLink:Colorpicker("healthBackground", "Background", DEFAULT_BACKGROUND, 0):SetTip({
			title = "Background",
			body = "Color behind the health fill.",
		})
	end

	optsLink:Toggle("name", "Name", false):SetTip({
		title = "Name",
		body = "Player's name next to the arrow.",
	})
	local nameLink = optsLink:OnKey("name")
	nameLink:Colorpicker("nameColor", "Color", DEFAULT_NAME, 0)
	nameLink:Submenu("nameOpts", "Name Options")
	local nameOptsLink = nameLink:OnKey("nameOpts")
	nameOptsLink:Toggle("nameOutline", "Outline", true)
	local nameOutlineLink = nameOptsLink:OnKey("nameOutline")
	nameOutlineLink:Colorpicker("nameOutlineColor", "Outline Color", DEFAULT_NAME_OUTLINE, 0)
	nameOptsLink:Slider("nameSize", "Size", 8, 7, 14, 1, nil, "px"):SetTip({
		title = "Size",
		body = "Text size in pixels.",
	})

	optsLink:Toggle("distance", "Distance", false):SetTip({
		title = "Distance",
		body = "How far away the player is, shown beneath the arrow.",
	})
	local distanceLink = optsLink:OnKey("distance")
	distanceLink:Colorpicker("distanceColor", "Color", DEFAULT_DISTANCE, 0)

	local radiusLink = link:Get("offscreenArrow.opts.radius")
	local sizeLink = link:Get("offscreenArrow.opts.size")
	local maxDistanceLink = link:Get("offscreenArrow.opts.maxDistance")
	local thicknessLink = (not withHealth) and ({ _state = at(3) } :: any)
		or link:Get("offscreenArrow.opts.health.healthOpts.healthThickness")
	local cache = {
		radius = peek(radiusLink._state) :: number,
		size = peek(sizeLink._state) :: number,
		thickness = peek(thicknessLink._state) :: number,
		maxDistance = peek(maxDistanceLink._state) :: number,
	}
	sub(radiusLink._state, function(v: number): ()
		cache.radius = v
	end)
	sub(sizeLink._state, function(v: number): ()
		cache.size = v
	end)
	sub(thicknessLink._state, function(v: number): ()
		cache.thickness = v
	end)
	sub(maxDistanceLink._state, function(v: number): ()
		cache.maxDistance = v
	end)

	local disabledStub = { _state = at(false) } :: any

	return {
		enabled = link:Get("offscreenArrow"),
		color = link:Get("offscreenArrow.color"),
		radius = radiusLink,
		size = sizeLink,
		health = (not withHealth) and disabledStub or link:Get("offscreenArrow.opts.health"),
		healthColor = withHealth and link:Get("offscreenArrow.opts.health.healthColor") or nil,
		healthOutline = (not withHealth) and disabledStub
			or link:Get("offscreenArrow.opts.health.healthOpts.healthOutline"),
		healthOutlineColor = withHealth and link:Get(
			"offscreenArrow.opts.health.healthOpts.healthOutline.healthOutlineColor"
		) or nil,
		healthBackground = withHealth and link:Get("offscreenArrow.opts.health.healthOpts.healthBackground") or nil,
		healthThickness = thicknessLink,
		name = link:Get("offscreenArrow.opts.name"),
		nameColor = link:Get("offscreenArrow.opts.name.nameColor"),
		nameOutline = link:Get("offscreenArrow.opts.name.nameOpts.nameOutline"),
		nameOutlineColor = link:Get("offscreenArrow.opts.name.nameOpts.nameOutline.nameOutlineColor"),
		nameSize = link:Get("offscreenArrow.opts.name.nameOpts.nameSize"),
		distanceEnabled = link:Get("offscreenArrow.opts.distance"),
		distanceColor = link:Get("offscreenArrow.opts.distance.distanceColor"),
		cache = cache,
	}
end

local function createState(player: Player, basePlayer: any, _settings: Settings): State
	local state: State = {
		center = createBindable(Vector2.zero),
		rotation = createBindable(0),
		distanceText = createBindable(""),
		healthRatio = createBindable(1),
		visible = createBindable(false),
		alpha = createBindable(1),
		text = player.Name,
		_lastDistInt = -1,
		_arrowFade = 0,
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
	if not ctx.offscreenReady then
		state._arrowFade = 0
		state.visible.set(false)
		return
	end

	local dist = ctx.dist
	if dist < 0 then
		dist = (ctx.hrp.Position - ctx.camPos).Magnitude
		ctx.dist = dist
	end
	local maxDistance = settings.cache.maxDistance

	local show = not ctx.onScreen and not (maxDistance > 0 and dist > maxDistance)
	local target = show and 1 or 0
	local fade = state._arrowFade
	if target ~= fade then
		if ctx.dt ~= _fadeLastDt then
			_fadeLastDt = ctx.dt
			_fadeBlend = 1 - exp(-ctx.dt * ARROW_FADE_RATE)
		end
		fade += (target - fade) * _fadeBlend
		if fade > 1 - ARROW_EPSILON then
			fade = 1
		elseif fade < ARROW_EPSILON then
			fade = 0
		end
		state._arrowFade = fade
	end

	local combined = ctx.alpha * fade
	if combined <= ARROW_EPSILON then
		state.visible.set(false)
		return
	end

	local viewport = ctx.viewport
	local screen = ctx.screen
	local cx = viewport.X * 0.5
	local cy = viewport.Y * 0.5
	local dx = screen.X - cx
	local dy = screen.Y - cy
	if ctx.depth <= 0 then
		dx = -dx
		dy = -dy
	end

	local mag = sqrt(dx * dx + dy * dy)
	if mag < 1e-4 then
		mag = 1e-4
	end
	local nx = dx / mag
	local ny = dy / mag

	local radius = settings.cache.radius
	local px = cx + nx * radius
	local py = cy + ny * radius

	state.center.set(v2(px, py))
	state.rotation.set(deg(atan2(nx, -ny)) + 180)

	local distInt = floor(dist)
	if distInt ~= state._lastDistInt then
		state._lastDistInt = distInt
		state.distanceText.set(`{distInt}{_distanceSuffix}`)
	end

	local maxH = math.max(state._maxHealth, 1e-4)
	state.healthRatio.set(math.clamp(state._health / maxH, 0, 1))
	state.alpha.set(combined)
	state.visible.set(true)
end)

local healthRatioToSize = LPH_NO_VIRTUALIZE(function(r: number): UDim2
	return UDim2.new(1, 0, math.max(r, 0), 0)
end)

local toNumberSequence = LPH_NO_VIRTUALIZE(function(t: number): NumberSequence
	return NumberSequence.new(t)
end)

local render = LPH_NO_VIRTUALIZE(function(props: { state: State, settings: Settings, userId: number? }): React.Element<any>?
	local state = props.state
	local settings = props.settings

	local enabled = useAt(settings.enabled._state) :: boolean
	local showHealth = useAt(settings.health._state) :: boolean
	local healthOutline = useAt(settings.healthOutline._state) :: boolean
	local showName = useAt(settings.name._state) :: boolean
	local nameOutline = useAt(settings.nameOutline._state) :: boolean
	local showDistance = useAt(settings.distanceEnabled._state) :: boolean
	local size = useAt(settings.size._state) :: number
	local thickness = useAt(settings.healthThickness._state) :: number
	local nameSize = useAt(settings.nameSize._state) :: number
	local colorpicker = espStateColors.useResolved("offscreenArrow", settings.color, props.userId)

	if not enabled then
		return nil
	end

	local fillPicker = settings.healthColor
	local healthOutlinePicker = settings.healthOutlineColor
	local backgroundPicker = settings.healthBackground
	local namePicker = settings.nameColor
	local nameOutlinePicker = settings.nameOutlineColor
	local distancePicker = settings.distanceColor
	local alphaBinding = state.alpha.binding
	local fade = fadedTransparency(alphaBinding)
	local half = size * 0.5

	return e("Frame", {
		AnchorPoint = CENTER,
		Position = state.center.binding:map(vector2ToUDim2Offset),
		Size = ZERO_UDIM,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = state.visible.binding,
	}, {
		Arrow = e("ImageLabel", {
			AnchorPoint = CENTER,
			Position = ZERO_UDIM,
			Size = UDim2.fromOffset(size, size),
			Rotation = state.rotation.binding,
			Image = FileController.Get("image", "glow_arrow"),
			ImageColor3 = colorpicker._currentColor,
			ImageTransparency = fadedTransparency(alphaBinding, colorpicker._current),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}),
		Health = showHealth and e("Frame", {
			AnchorPoint = HEALTH_ANCHOR,
			Position = UDim2.fromOffset(-half - HEALTH_GAP, 0),
			Size = UDim2.fromOffset(thickness, size),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
		}, {
			Fill = e("Frame", {
				AnchorPoint = FILL_ANCHOR,
				Position = FILL_POSITION,
				Size = state.healthRatio.binding:map(healthRatioToSize),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = fade,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, {
				UIGradient = e("UIGradient", {
					Color = fillPicker._currentGradient,
					Rotation = GRADIENT_ROTATION,
					Transparency = fillPicker._currentTransparency:map(toNumberSequence),
				}),
			}),
			Outline = healthOutline and e("UIStroke", {
				Color = WHITE,
				Transparency = fade,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Outer,
				LineJoinMode = Enum.LineJoinMode.Miter,
				ZIndex = 1,
			}, {
				Gradient = e("UIGradient", {
					Color = healthOutlinePicker._currentGradient,
					Rotation = GRADIENT_ROTATION,
					Transparency = healthOutlinePicker._currentTransparency:map(toNumberSequence),
				}),
			}) or nil,
			UIGradient = e("UIGradient", {
				Color = backgroundPicker._currentGradient,
				Rotation = GRADIENT_ROTATION,
				Transparency = backgroundPicker._currentTransparency:map(toNumberSequence),
			}),
		}) or nil,
		Name = showName and e("TextLabel", {
			AnchorPoint = NAME_ANCHOR,
			Position = UDim2.fromOffset(0, -half - NAME_GAP),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = state.text,
			TextColor3 = namePicker._currentColor,
			TextTransparency = fadedTransparency(alphaBinding, namePicker._current),
			TextSize = nameSize,
			FontFace = FileController.Get("font", "pixel"),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Bottom,
		}, {
			Stroke = nameOutline and e("UIStroke", {
				Color = nameOutlinePicker._currentColor,
				Transparency = fadedTransparency(alphaBinding, nameOutlinePicker._current),
				Thickness = 1,
				LineJoinMode = Enum.LineJoinMode.Miter,
			}) or nil,
		}) or nil,
		Distance = showDistance and e("TextLabel", {
			AnchorPoint = DISTANCE_ANCHOR,
			Position = UDim2.fromOffset(0, half + DISTANCE_GAP),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = state.distanceText.binding,
			TextColor3 = distancePicker._currentColor,
			TextTransparency = fadedTransparency(alphaBinding, distancePicker._current),
			TextSize = nameSize,
			FontFace = FileController.Get("font", "pixel"),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, {
			Stroke = nameOutline and e("UIStroke", {
				Color = nameOutlinePicker._currentColor,
				Transparency = fadedTransparency(alphaBinding, nameOutlinePicker._current),
				Thickness = 1,
				LineJoinMode = Enum.LineJoinMode.Miter,
			}) or nil,
		}) or nil,
	})
end)

return {
	id = "offscreenArrow",
	setup = setup,
	createState = createState,
	update = update,
	render = render,
	destroyState = destroyState,
} :: EspElement.EspElement<State, Settings>
