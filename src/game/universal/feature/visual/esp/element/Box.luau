local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")
local cornerImage = require("@game/universal/feature/visual/esp/cornerImage")

local e = React.createElement
local useAt = ReactCharm.useAtom
local peek = Charm.peek
local sub = Charm.subscribe
local joinBindings = React.joinBindings
local createBindable = EspElement.createBindable
local fadedTransparency = EspElement.fadedTransparency

local FILL_POS = UDim2.new()
local FILL_SIZE = UDim2.fromScale(1, 1)

local CORNER_SUPPORTED = identifyexecutor() ~= "Volt"
local BOX_MODES = CORNER_SUPPORTED and { "Normal", "Corner" } or { "Normal" }
local CORNER_OUTLINE_THICKNESS = 1
local CORNER_THICKNESS = 1
local CORNER_LEVEL_FACTOR = 0.92
local CORNER_LEVEL_MIN = 1
local CORNER_LEVEL_MAX = 256
local CORNER_MAX_LENGTH = 500
local CORNER_LINEAR_MAX = 64
local CORNER_MIN_ARM_PX = 4
local WARM_SIZE = UDim2.fromOffset(2, 2)
local WARM_RECT = Vector2.new(2, 2)
local ZERO_OFFSET = Vector2.zero

type CornerLevel = {
	content: any,
	cell: number,
	len: number,
	rect: Rect,
	offset: Vector2,
}

local LEVEL_LENGTHS: { number } = {}
do
	local length = CORNER_MAX_LENGTH
	for _ = 1, CORNER_LEVEL_MAX do
		LEVEL_LENGTHS[#LEVEL_LENGTHS + 1] = length
		if length <= CORNER_LEVEL_MIN then
			break
		end
		local nextLength
		if length <= CORNER_LINEAR_MAX then
			nextLength = length - 1
		else
			nextLength = math.floor(length * CORNER_LEVEL_FACTOR)
			if nextLength < CORNER_LINEAR_MAX then
				nextLength = CORNER_LINEAR_MAX
			end
		end
		if nextLength < CORNER_LEVEL_MIN then
			nextLength = CORNER_LEVEL_MIN
		end
		if nextLength >= length then
			break
		end
		length = nextLength
	end
end
local LEVEL_COUNT = #LEVEL_LENGTHS

local DEFAULT_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(225, 225, 225)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
})
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)
local DEFAULT_FILL = Color3.fromRGB(42, 42, 42)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

type State = {
	visible: EspElement.Bindable<boolean>,
	alpha: EspElement.Bindable<number>,
	boxSize: EspElement.Bindable<Vector2>,
}

type Settings = {
	enabled: any,
	mode: any,
	color: any,
	outline: any,
	outlineColor: any,
	fill: any,
	fillColor: any,
	cornerLength: any,
	cornerGen: EspElement.Bindable<number>,
	getLevel: (index: number) -> CornerLevel,
}

local function setup(link: gameUi.Linker): Settings
	link:Toggle("box", "Box", false):SetTip({
		title = "Box",
		body = "2D bounding box around each enemy on screen.",
	})
	local boxLink = link:OnKey("box")
	boxLink:Submenu("opts", "Box Settings")
	local optsLink = boxLink:OnKey("opts")
	optsLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0):SetTip({
		title = "Color",
		body = "Box border color or gradient.",
	})
	espStateColors.Register({ id = "box", label = "Box", default = DEFAULT_COLOR, transparency = 0 })
	optsLink:Dropdown("mode", "Mode", BOX_MODES, "Normal"):SetTip({
		title = "Mode",
		body = "Full box or only the corners.",
	})
	optsLink:Toggle("outline", "Outline", true):SetTip({
		title = "Outline",
		body = "Draws a separate outline around the box edges.",
	})
	local outlineLink = optsLink:OnKey("outline")
	outlineLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)
	espStateColors.Register({ id = "boxOutline", label = "Box Outline", default = DEFAULT_OUTLINE, transparency = 0 })
	optsLink:Toggle("fill", "Fill", false):SetTip({
		title = "Fill",
		body = "Fills the inside of the box with a semi-transparent color.",
	})
	local fillLink = optsLink:OnKey("fill")
	fillLink:Colorpicker("fillColor", "Fill Color", DEFAULT_FILL, 0.5)
	if CORNER_SUPPORTED then
		optsLink:Submenu("corner", "Corner Settings")
		local cornerLink = optsLink:OnKey("corner")
		cornerLink:Slider("length", "Length", 25, 0, 50, 1, nil, "%"):SetTip({
			title = "Length",
			body = "Corner length as a share of the box. Stays this share at any distance.",
		})
	end

	local modeEl = link:Get("box.opts.mode")
	local colorEl = link:Get("box.opts.color")
	local outlineToggleEl = link:Get("box.opts.outline")
	local outlineColorEl = link:Get("box.opts.outline.outlineColor")
	local lengthEl = CORNER_SUPPORTED and link:Get("box.opts.corner.length") or { _state = Charm.atom(25) }

	local function buildOpts(): cornerImage.CornerOpts
		return {
			length = CORNER_MAX_LENGTH,
			thickness = CORNER_THICKNESS,
			gap = 0,
			gradient = colorEl:GetGradient(),
			rotation = colorEl:GetRotation(),
			lineTransparency = colorEl:GetTransparency(),
			outline = peek(outlineToggleEl._state) == true,
			outlineThickness = CORNER_OUTLINE_THICKNESS,
			outlineColor = outlineColorEl:GetColor(),
			outlineTransparency = outlineColorEl:GetTransparency(),
		}
	end

	local levelCache: { [number]: CornerLevel } = {}
	local cacheImages: { any } = {}
	local currentOpts = buildOpts()

	local function getLevel(index: number): CornerLevel
		local cached = levelCache[index]
		if cached then
			return cached
		end
		currentOpts.length = LEVEL_LENGTHS[index]
		local result = cornerImage.generate(currentOpts)
		local cell = result.cell
		local level: CornerLevel = {
			content = result.content,
			cell = cell,
			len = result.len,
			rect = Rect.new(cell, cell, cell + 2, cell + 2),
			offset = Vector2.new(cell, cell),
		}
		levelCache[index] = level
		cacheImages[#cacheImages + 1] = result.image
		return level
	end

	local settings: Settings = {
		enabled = link:Get("box"),
		mode = modeEl,
		color = colorEl,
		outline = outlineToggleEl,
		outlineColor = outlineColorEl,
		fill = link:Get("box.opts.fill"),
		fillColor = link:Get("box.opts.fill.fillColor"),
		cornerLength = lengthEl,
		cornerGen = createBindable(0),
		getLevel = getLevel,
	}

	local generation = 0
	local function regenerate(): ()
		local old = cacheImages
		table.clear(levelCache)
		cacheImages = {}
		currentOpts = buildOpts()
		generation += 1
		settings.cornerGen.set(generation)
		if #old > 0 then
			task.delay(0.2, function(): ()
				for _, img in next, old do
					img:Destroy()
				end
			end)
		end
	end

	local regenScheduled = false
	local function scheduleRegenerate(): ()
		if regenScheduled then
			return
		end
		regenScheduled = true
		task.defer(function()
			regenScheduled = false
			regenerate()
		end)
	end

	if CORNER_SUPPORTED then
		sub(modeEl._state, scheduleRegenerate)
		sub(outlineToggleEl._state, scheduleRegenerate)
		sub((colorEl :: any)._rotation, scheduleRegenerate)
		colorEl:OnColorChange(scheduleRegenerate)
		colorEl:OnTransparencyChange(scheduleRegenerate)
		outlineColorEl:OnColorChange(scheduleRegenerate)
		outlineColorEl:OnTransparencyChange(scheduleRegenerate)
	end

	return settings
end

local function createState(_player: Player, _basePlayer: any, _settings: Settings): State
	return {
		visible = createBindable(false),
		alpha = createBindable(1),
		boxSize = createBindable(Vector2.zero),
	}
end

local update = LPH_NO_VIRTUALIZE(function(state: State, ctx: EspElement.EspCtx, _settings: Settings?): ()
	if not ctx.visible then
		state.visible.set(false)
		return
	end
	state.boxSize.set(ctx.boxSize)
	state.alpha.set(ctx.alpha)
	state.visible.set(true)
end)

local render = LPH_NO_VIRTUALIZE(function(props: { state: State, settings: Settings, userId: number? }): React.Element<any>?
	local state = props.state
	local settings = props.settings

	local enabled = useAt(settings.enabled._state) :: boolean
	local mode = useAt(settings.mode._state) :: string
	local outline = useAt(settings.outline._state) :: boolean
	local fill = useAt(settings.fill._state) :: boolean
	local cornerPct = useAt(settings.cornerLength._state) :: number
	local colorpicker = espStateColors.useResolved("box", settings.color, props.userId)
	local outlinePicker = espStateColors.useResolved("boxOutline", settings.outlineColor, props.userId)

	if not enabled then
		return nil
	end

	local fillPicker = settings.fillColor
	local alphaBinding = state.alpha.binding

	if CORNER_SUPPORTED and mode == "Corner" then
		local o = outline and CORNER_OUTLINE_THICKNESS or 0
		local bleed = o
		local pad = o + 1
		local frac = math.clamp(cornerPct, 0, 100) / 100
		local picked = joinBindings({ state.boxSize.binding, settings.cornerGen.binding }):map(
			function(v: { any }): { [string]: any }
				local sz = v[1] :: Vector2
				local m = sz.X < sz.Y and sz.X or sz.Y
				local maxLen = m * 0.5 - pad
				if maxLen < 1 then
					maxLen = 1
				end
				local target = m * frac
				if target > maxLen then
					target = maxLen
				end
				local minArm = CORNER_MIN_ARM_PX
				if minArm > maxLen then
					minArm = maxLen
				end
				if target < minArm then
					target = minArm
				end
				local chosenIndex = LEVEL_COUNT
				local lo = 1
				local hi = LEVEL_COUNT
				while lo <= hi do
					local mid = math.floor((lo + hi) / 2)
					if LEVEL_LENGTHS[mid] <= target then
						chosenIndex = mid
						hi = mid - 1
					else
						lo = mid + 1
					end
				end
				local chosen = settings.getLevel(chosenIndex)
				local scale = 1
				if chosen.len > CORNER_LINEAR_MAX then
					scale = target / chosen.len
				end
				local prev = chosenIndex > 1 and settings.getLevel(chosenIndex - 1) or nil
				local nxt = chosenIndex < LEVEL_COUNT and settings.getLevel(chosenIndex + 1) or nil
				return {
					content = chosen.content,
					rect = chosen.rect,
					scale = scale,
					warmAContent = prev and prev.content or nil,
					warmAOffset = prev and prev.offset or ZERO_OFFSET,
					warmBContent = nxt and nxt.content or nil,
					warmBOffset = nxt and nxt.offset or ZERO_OFFSET,
				}
			end
		)

		return e("ImageLabel", {
			Position = UDim2.new(0, -bleed, 0, -bleed),
			Size = UDim2.new(1, bleed * 2, 1, bleed * 2),
			Visible = state.visible.binding,
			BackgroundColor3 = fillPicker._currentColor,
			BackgroundTransparency = fill and fadedTransparency(alphaBinding, fillPicker._current) or 1,
			BorderSizePixel = 0,
			ImageContent = picked:map(function(p): any
				return p.content
			end),
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = picked:map(function(p): Rect
				return p.rect
			end),
			SliceScale = picked:map(function(p): number
				return p.scale
			end),
			ResampleMode = Enum.ResamplerMode.Pixelated,
			ImageTransparency = fadedTransparency(alphaBinding),
		}, {
			WarmA = e("ImageLabel", {
				Size = WARM_SIZE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 0,
				ImageTransparency = 0.99,
				ImageRectSize = WARM_RECT,
				ImageContent = picked:map(function(p): any
					return p.warmAContent
				end),
				ImageRectOffset = picked:map(function(p): Vector2
					return p.warmAOffset
				end),
			}),
			WarmB = e("ImageLabel", {
				Size = WARM_SIZE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 0,
				ImageTransparency = 0.99,
				ImageRectSize = WARM_RECT,
				ImageContent = picked:map(function(p): any
					return p.warmBContent
				end),
				ImageRectOffset = picked:map(function(p): Vector2
					return p.warmBOffset
				end),
			}),
		})
	end

	local colorTransparency = fadedTransparency(alphaBinding, colorpicker._current)
	local outlineTransparency = fadedTransparency(alphaBinding, outlinePicker._current)

	return e("Frame", {
		Position = FILL_POS,
		Size = FILL_SIZE,
		Visible = state.visible.binding,
		BackgroundColor3 = fillPicker._currentColor,
		BackgroundTransparency = fill and fadedTransparency(alphaBinding, fillPicker._current) or 1,
		BorderSizePixel = 0,
	}, {
		Stroke = e("UIStroke", {
			Color = WHITE,
			Transparency = colorTransparency,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			LineJoinMode = Enum.LineJoinMode.Miter,
			ZIndex = 2,
		}, {
			Gradient = e("UIGradient", {
				Color = colorpicker._currentGradient,
				Rotation = colorpicker._currentRotation,
			}),
		}),
		Outline = outline and e("UIStroke", {
			Color = outlinePicker._currentColor,
			Transparency = outlineTransparency,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			LineJoinMode = Enum.LineJoinMode.Miter,
		}) or nil,
		Outline2 = outline and e("UIStroke", {
			Color = BLACK,
			Transparency = outlineTransparency,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Miter,
			BorderStrokePosition = Enum.BorderStrokePosition.Center,
		}) or nil,
	})
end)

return {
	id = "box",
	container = true,
	setup = setup,
	createState = createState,
	update = update,
	render = render,
} :: EspElement.EspElement<State, Settings>
