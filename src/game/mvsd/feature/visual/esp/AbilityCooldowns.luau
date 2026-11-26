local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local FileController = require("@feature/file/FileController")

local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement
local useAt = ReactCharm.useAtom
local createBindable = EspElement.createBindable
local fadedTransparency = EspElement.fadedTransparency

local GAP_FROM_BOX = 3
local BAR_HEIGHT = 8
local BAR_GAP = 2
local MIN_WIDTH = 46
local TEXT_SIZE = 8

local BELOW_POSITION = UDim2.new(0, 0, 1, GAP_FROM_BOX)
local FULL_WIDTH = UDim2.new(1, 0, 0, 0)
local MIN_SIZE = Vector2.new(MIN_WIDTH, 0)

local WHITE = Color3.new(1, 1, 1)
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)
local TRACK = Color3.fromRGB(24, 24, 24)

type Ability = { id: string, label: string, color: Color3 }

local ABILITIES: { Ability } = {
	{ id = "Sprint", label = "SPRINT", color = Color3.fromRGB(150, 205, 150) },
	{ id = "SoulReap", label = "SOUL", color = Color3.fromRGB(70, 220, 176) },
	{ id = "Shroud", label = "SHROUD", color = Color3.fromRGB(120, 200, 235) },
}

type Slot = {
	ratio: EspElement.Bindable<number>,
	visible: EspElement.Bindable<boolean>,
	text: EspElement.Bindable<string>,
}

type State = {
	visible: EspElement.Bindable<boolean>,
	alpha: EspElement.Bindable<number>,
	slots: { [string]: Slot },
	_cooldowns: { [string]: { started: number, duration: number } },
	_playerUnsub: () -> (),
}

type Settings = {
	enabled: any,
	outline: any,
	outlineColor: any,
	showText: any,
	cache: { showText: boolean },
}

local function setup(link: gameUi.Linker): Settings
	link:Toggle("abilityCooldowns", "Ability Cooldowns", false):SetTip({
		title = "Ability Cooldowns",
		body = "Bars under the box estimating how long until a player can reuse an ability.",
	})
	local cdLink = link:OnKey("abilityCooldowns")
	cdLink:Submenu("opts", "Ability Cooldowns")
	local optsLink = cdLink:OnKey("opts")

	optsLink:Toggle("text", "Show Timer", true):SetTip({
		title = "Show Timer",
		body = "Draws the remaining seconds on each bar.",
	})
	optsLink:Toggle("outline", "Outline", true)
	local outlineLink = optsLink:OnKey("outline")
	outlineLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)

	local showTextLink = link:Get("abilityCooldowns.opts.text")
	local cache = { showText = peek(showTextLink._state) :: boolean }
	sub(showTextLink._state, function(v: boolean): ()
		cache.showText = v
	end)

	return {
		enabled = link:Get("abilityCooldowns"),
		outline = link:Get("abilityCooldowns.opts.outline"),
		outlineColor = link:Get("abilityCooldowns.opts.outline.outlineColor"),
		showText = showTextLink,
		cache = cache,
	}
end

local function createState(_player: Player, basePlayer: any, _settings: Settings): State
	local slots: { [string]: Slot } = {}
	for _, ability in next, ABILITIES do
		slots[ability.id] = {
			ratio = createBindable(0),
			visible = createBindable(false),
			text = createBindable(ability.label),
		}
	end

	local state: State = {
		visible = createBindable(false),
		alpha = createBindable(1),
		slots = slots,
		_cooldowns = (basePlayer and basePlayer.cooldowns and peek(basePlayer.cooldowns)) or {},
		_playerUnsub = function() end,
	}

	if basePlayer and basePlayer.cooldowns then
		state._playerUnsub = sub(basePlayer.cooldowns, function(v: any): ()
			state._cooldowns = v or {}
		end)
	end

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

	state.alpha.set(ctx.alpha)

	local now = os.clock()
	local cooldowns = state._cooldowns
	local showText = settings.cache.showText

	for _, ability in next, ABILITIES do
		local slot = state.slots[ability.id]
		local entry = cooldowns[ability.id]
		if entry then
			local remaining = entry.duration - (now - entry.started)
			if remaining > 0 then
				slot.ratio.set(math.clamp(remaining / entry.duration, 0, 1))
				slot.text.set(showText and `{ability.label} {math.ceil(remaining)}` or ability.label)
				slot.visible.set(true)
			else
				slot.visible.set(false)
			end
		else
			slot.visible.set(false)
		end
	end

	state.visible.set(true)
end)

local function ratioToSize(r: number): UDim2
	return UDim2.new(math.max(r, 0), 0, 1, 0)
end

type BarProps = {
	ability: Ability,
	slot: Slot,
	outline: boolean,
	outlineColor: any,
	showText: boolean,
	alpha: any,
	font: Font,
	layoutOrder: number,
}

local Bar = LPH_NO_VIRTUALIZE(function(props: BarProps): React.Element<any>
	local slot = props.slot
	local fade = fadedTransparency(props.alpha)
	local outlinePicker = props.outlineColor

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
		BackgroundColor3 = TRACK,
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Visible = slot.visible.binding,
	}, {
		Fill = e("Frame", {
			Size = slot.ratio.binding:map(ratioToSize),
			BackgroundColor3 = props.ability.color,
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
			ZIndex = 1,
		}),
		Label = props.showText and e("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = slot.text.binding,
			TextColor3 = WHITE,
			TextTransparency = fade,
			TextSize = TEXT_SIZE,
			FontFace = props.font,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 2,
		}, {
			Outline = e("UIStroke", {
				Color = DEFAULT_OUTLINE,
				Transparency = fade,
				Thickness = 1,
				LineJoinMode = Enum.LineJoinMode.Miter,
			}),
		}) or nil,
		Outline = props.outline and e("UIStroke", {
			Color = outlinePicker._currentColor,
			Transparency = fade,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Outer,
			LineJoinMode = Enum.LineJoinMode.Miter,
			ZIndex = 1,
		}) or nil,
	})
end)

local render = LPH_NO_VIRTUALIZE(function(props: { state: State, settings: Settings }): React.Element<any>?
	local state = props.state
	local settings = props.settings

	local enabled = useAt(settings.enabled._state) :: boolean
	local outline = useAt(settings.outline._state) :: boolean
	local showText = useAt(settings.showText._state) :: boolean

	if not enabled then
		return nil
	end

	local font = FileController.Get("font", "pixel2") :: Font

	local children: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, BAR_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
		MinWidth = e("UISizeConstraint", {
			MinSize = MIN_SIZE,
		}),
	}

	for i, ability in next, ABILITIES do
		children[ability.id] = e(Bar, {
			ability = ability,
			slot = state.slots[ability.id],
			outline = outline,
			outlineColor = settings.outlineColor,
			showText = showText,
			alpha = state.alpha.binding,
			font = font,
			layoutOrder = i,
		})
	end

	return e("Frame", {
		Position = BELOW_POSITION,
		Size = FULL_WIDTH,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = state.visible.binding,
	}, children)
end)

return {
	id = "abilityCooldowns",
	container = true,
	setup = setup,
	createState = createState,
	update = update,
	render = render,
	destroyState = destroyState,
} :: EspElement.EspElement<State, Settings>
