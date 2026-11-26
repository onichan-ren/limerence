local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")

local FileController = require("@src/feature/file/FileController")
local themeState = require("@src/feature/ui/theme/themeState")
local uiState = require("@src/feature/ui/uiState")
local hudState = require("@src/feature/ui/hud/hudState")
local elementBindController = require("@ui/bind/elementBindController")
local OptionsElement = require("@ui/window/element/options/Options")
local cursor = require("@ui/util/cursor")
local useDraggable = require("@ui/hook/useDraggable")
local useHudHover = require("@ui/hook/useHudHover")
local useShadow = require("@ui/hook/useShadow")
local SPRING = require("@ui/util/spring")

local Charm = require("@pkg/Charm")

local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useMemo = React.useMemo
local useState = React.useState
local useRef = React.useRef
local useCallback = React.useCallback
local peek = Charm.peek
local subAt = Charm.subscribe
local memo = React.memo
local e = React.createElement

local SORT_LABELS = { "Activated Time", "Longest Frame", "Keybind Type" }
local LABEL_TO_MODE: { [string]: string } = {
	["Activated Time"] = "activated",
	["Longest Frame"] = "longestFrame",
	["Keybind Type"] = "type",
}
local MODE_TO_LABEL: { [string]: string } = {
	activated = "Activated Time",
	longestFrame = "Longest Frame",
	type = "Keybind Type",
}

local function kindRank(value: any): number
	local t = type(value)
	if t == "boolean" then
		return 0
	elseif t == "number" then
		return 1
	elseif t == "string" then
		return 2
	end
	return 3
end

local colors = themeState.colors.hud
local elColors = themeState.colors.window.element

local HEADER_W = 94
local HEADER_H = 30
local ROW_H = 20
local ROW_GAP = 4
local SHARED_CORNER = 6
local SLIDE_OFFSET = 6
local ROW_SLIDE = 11
local ROW_SHOW_SPRING = { tension = 900, friction = 64, precision = 0.06 }
local NAME_X_OFFSET = 28
local TOGGLE_W = 18
local TOGGLE_H = 10
local TOGGLE_KNOB = 6
local VALUE_MAX_W = 60
local NAME_MAX_W = 180

local ANCHOR_LEFT_CENTER = Vector2.new(0, 0.5)
local ANCHOR_RIGHT_CENTER = Vector2.new(1, 0.5)
local UDIM_CORNER = UDim.new(0, SHARED_CORNER)
local UDIM_FULL_CIRCLE = UDim.new(1, 0)
local UDIM_2 = UDim.new(0, 2)
local UDIM_5 = UDim.new(0, 5)
local UDIM_6 = UDim.new(0, 6)
local UDIM_8 = UDim.new(0, 8)
local UDIM_3 = UDim.new(0, 3)
local UDIM_ROW_GAP = UDim.new(0, ROW_GAP)
local TOGGLE_SIZE = UDim2.fromOffset(TOGGLE_W, TOGGLE_H)
local TOGGLE_POSITION = UDim2.new(0, 5, 0.5, 0)
local NAME_POSITION = UDim2.new(0, NAME_X_OFFSET, 0.5, 0)
local NAME_SIZE = UDim2.fromOffset(0, 14)
local VALUE_SIZE = UDim2.fromOffset(0, 11)
local TOGGLE_KNOB_SIZE = UDim2.fromOffset(TOGGLE_KNOB, TOGGLE_KNOB)
local TOGGLE_KNOB_POSITION = UDim2.new(1, 0, 0.5, 0)
local ROW_SIZE = UDim2.fromOffset(0, ROW_H)
local CHIP_SIZE = UDim2.fromOffset(0, 14)
local CHIP_ICON_PX = 14
local CHIP_ICON_SIZE = UDim2.fromOffset(CHIP_ICON_PX, CHIP_ICON_PX)
local CHIP_LABEL_SIZE = UDim2.new(1, 0, 1, 0)
local CHIP_LABEL_ANCHOR = Vector2.new(0.5, 0.5)
local CHIP_LABEL_POSITION = UDim2.fromScale(0.5, 0.5)
local NAME_MAX_CONSTRAINT = Vector2.new(NAME_MAX_W, math.huge)
local VALUE_MAX_CONSTRAINT = Vector2.new(VALUE_MAX_W, math.huge)
local HEADER_SIZE = UDim2.fromOffset(HEADER_W, HEADER_H)
local HEADER_SHADOW_MULT = Vector2.new(1.3, 1.47)
local ROW_SHADOW_MULT = Vector2.new(1.35, 1.47)

local function shouldDisplay(showInList: boolean, active: boolean): boolean
	return showInList and active
end

local function formatBindStateValue(state: any): string
	local t = type(state)
	if t == "boolean" then
		return state and "On" or "Off"
	elseif t == "number" then
		local r = math.round(state * 1000) / 1000
		local text = string.format("%.3f", r)
		text = text:gsub("0+$", "")
		text = text:gsub("%.$", "")
		return text
	elseif t == "string" then
		return state
	end
	return "—"
end

local function ToggleBind(props: {
	name: string,
	on: boolean,
	bgColor: Color3,
	bgAlpha: number,
	trackColor: Color3,
	trackAlpha: number,
	knobColor: Color3,
	textColor: Color3,
	parentTransparency: any,
}): React.Element<any>
	local fade = props.parentTransparency
	local bgAlpha = props.bgAlpha
	local trackAlpha = props.trackAlpha
	local bgTransparency = useMemo(function()
		return fade:map(function(t: number)
			return 1 - (1 - bgAlpha) * (1 - t)
		end)
	end, { fade, bgAlpha } :: { any })
	local trackTransparency = useMemo(function()
		return fade:map(function(t: number)
			return 1 - (1 - trackAlpha) * (1 - t)
		end)
	end, { fade, trackAlpha } :: { any })

	return e("Frame", {
		BackgroundColor3 = props.bgColor,
		BackgroundTransparency = bgTransparency,
		BorderSizePixel = 0,
		Size = ROW_SIZE,
		AutomaticSize = Enum.AutomaticSize.X,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDIM_CORNER,
		}),
		Toggle = e("Frame", {
			Size = TOGGLE_SIZE,
			BackgroundColor3 = props.trackColor,
			BackgroundTransparency = trackTransparency,
			BorderSizePixel = 0,
			Position = TOGGLE_POSITION,
			AnchorPoint = ANCHOR_LEFT_CENTER,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDIM_FULL_CIRCLE,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDIM_2,
				PaddingRight = UDIM_2,
				PaddingTop = UDIM_2,
				PaddingBottom = UDIM_2,
			}),
			Circle = e("Frame", {
				Size = TOGGLE_KNOB_SIZE,
				BackgroundColor3 = props.knobColor,
				BackgroundTransparency = fade,
				BorderSizePixel = 0,
				Position = TOGGLE_KNOB_POSITION,
				AnchorPoint = ANCHOR_RIGHT_CENTER,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDIM_FULL_CIRCLE,
				}),
			}),
		}),
		Name = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = props.name,
			TextSize = 12,
			TextColor3 = props.textColor,
			TextTransparency = fade,
			FontFace = FileController.Get("font", "semi_bold"),
			Size = NAME_SIZE,
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = NAME_POSITION,
			AnchorPoint = ANCHOR_LEFT_CENTER,
		}, {
			UISizeConstraint = e("UISizeConstraint", {
				MaxSize = NAME_MAX_CONSTRAINT,
			}),
			UIPadding = e("UIPadding", {
				PaddingRight = UDIM_8,
			}),
		}),
	})
end

local function TextBind(props: {
	name: string,
	value: string,
	bgColor: Color3,
	bgAlpha: number,
	valueColor: Color3,
	textColor: Color3,
	parentTransparency: any,
}): React.Element<any>
	local fade = props.parentTransparency
	local bgAlpha = props.bgAlpha
	local bgTransparency = useMemo(function()
		return fade:map(function(t: number)
			return 1 - (1 - bgAlpha) * (1 - t)
		end)
	end, { fade, bgAlpha } :: { any })

	return e("Frame", {
		BackgroundColor3 = props.bgColor,
		BackgroundTransparency = bgTransparency,
		BorderSizePixel = 0,
		Size = ROW_SIZE,
		AutomaticSize = Enum.AutomaticSize.X,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDIM_CORNER,
		}),
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDIM_6,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDIM_8,
			PaddingRight = UDIM_8,
		}),
		Value = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = props.value,
			TextSize = 10,
			TextColor3 = props.valueColor,
			TextTransparency = fade,
			FontFace = FileController.Get("font", "semi_bold"),
			Size = VALUE_SIZE,
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 0,
		}, {
			UISizeConstraint = e("UISizeConstraint", {
				MaxSize = VALUE_MAX_CONSTRAINT,
			}),
		}),
		Name = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = props.name,
			TextSize = 12,
			TextColor3 = props.textColor,
			TextTransparency = fade,
			FontFace = FileController.Get("font", "semi_bold"),
			Size = NAME_SIZE,
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 1,
		}, {
			UISizeConstraint = e("UISizeConstraint", {
				MaxSize = NAME_MAX_CONSTRAINT,
			}),
		}),
	})
end

local function Chip(props: {
	text: string?,
	icon: string?,
	bgColor: Color3,
	bgAlpha: number,
	textColor: Color3,
	parentTransparency: any,
	layoutOrder: number,
	scale: any?,
}): React.Element<any>
	local parentTransparency = props.parentTransparency
	local bgAlpha = props.bgAlpha
	local frameTransparency = useMemo(function()
		return parentTransparency:map(function(t: number)
			return 1 - (1 - bgAlpha) * (1 - t)
		end)
	end, { parentTransparency, bgAlpha } :: { any })

	local children: { [string]: React.Element<any> } = {
		UICorner = e("UICorner", { CornerRadius = UDIM_3 }),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDIM_5,
			PaddingRight = UDIM_5,
		}),
	}

	if props.icon then
		children.Icon = e("ImageLabel", {
			BackgroundTransparency = 1,
			Image = props.icon,
			ImageColor3 = props.textColor,
			ImageTransparency = props.parentTransparency,
			Size = props.scale and props.scale:map(function(s: number)
				return UDim2.fromOffset(CHIP_ICON_PX * s, CHIP_ICON_PX * s)
			end) or CHIP_ICON_SIZE,
			AnchorPoint = CHIP_LABEL_ANCHOR,
			Position = CHIP_LABEL_POSITION,
		})
	else
		children.Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = props.text or "?",
			TextSize = 10,
			TextColor3 = props.textColor,
			TextTransparency = props.parentTransparency,
			FontFace = FileController.Get("font", "semi_bold"),
			Size = CHIP_LABEL_SIZE,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end

	return e("Frame", {
		BackgroundColor3 = props.bgColor,
		BackgroundTransparency = frameTransparency,
		BorderSizePixel = 0,
		Size = CHIP_SIZE,
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = props.layoutOrder,
	}, children)
end

local BindRow = memo(function(props: {
	entry: elementBindController.BindListEntry,
	slotIndex: number?,
	parentTransparency: any,
	onMeasure: (id: number, width: number) -> (),
}): React.Element<any>
	local element = props.entry.element

	local pillRef = useRef(nil :: Frame?)
	local onMeasure = props.onMeasure
	local bindId = props.entry.bind.id

	useEffect(function()
		local pill = pillRef.current
		if not pill then
			return
		end
		local function report(): ()
			local w = pill.AbsoluteSize.X
			if w > 0 then
				onMeasure(bindId, w)
			end
		end
		report()
		local conn = pill:GetPropertyChangedSignal("AbsoluteSize"):Connect(report)
		return function()
			conn:Disconnect()
		end
	end, { bindId, onMeasure } :: { any })

	local stateVal = useAt(element._state, { element })
	local targetVal = useAt(props.entry.bind.targetValue, { props.entry.bind })
	local formattedAtom = element._formattedValue or element._state
	local formattedVal = useAt(formattedAtom, { element })

	local bgPack = useAt(colors.background)
	local bgColor = bgPack[1] :: Color3
	local bgAlpha = bgPack[2] :: number
	local trackPack = useAt(colors.backgroundSecondary)
	local trackColor = trackPack[1] :: Color3
	local trackAlpha = trackPack[2] :: number

	local titleColor = useAt(colors.title)
	local textColor = useAt(colors.text)
	local knobActiveColor = useAt(elColors.thumbActive)
	local knobRestColor = useAt(elColors.thumb)

	local visible = props.slotIndex ~= nil
	local lastSlotRef = useRef(props.slotIndex or 0)
	if props.slotIndex ~= nil then
		lastSlotRef.current = props.slotIndex
	end

	local frozenRef = useRef({ state = stateVal, target = targetVal, formatted = formattedVal })
	local frozen = frozenRef.current
	if visible then
		frozen.state = stateVal
		frozen.target = targetVal
		frozen.formatted = formattedVal
	else
		stateVal = frozen.state
		targetVal = frozen.target
		formattedVal = frozen.formatted
	end
	local effectiveSlot = lastSlotRef.current
	local targetY = effectiveSlot * (ROW_H + ROW_GAP)

	local yBind, ySpring = useSpring(targetY, ROW_SHOW_SPRING)

	useEffect(function()
		ySpring:setGoal(targetY)
	end, { targetY })

	local visBind, visSpring = useSpring(0, ROW_SHOW_SPRING)

	useEffect(function()
		visSpring:setGoal(visible and 1 or 0)
	end, { visible })

	local finalPosition = React.joinBindings({ yBind, visBind }):map(function(values)
		local y = values[1]
		local v = values[2]
		return UDim2.new(0, 0, 0, y - (1 - v) * ROW_SLIDE)
	end)

	local layerFade = React.joinBindings({ props.parentTransparency, visBind }):map(function(values)
		local wt = values[1]
		local v = values[2]
		return 1 - (1 - wt) * v
	end)

	-- Value binds (yaw left/right, etc.) show their OWN target, not the element's
	-- live state, so co-targeted binds don't all read the same value.
	local isValueBind = targetVal ~= nil
	local displayVal
	if isValueBind then
		displayVal = targetVal
	else
		displayVal = stateVal
	end
	local valueLabel = isValueBind
		and formatBindStateValue(targetVal)
		or (element._formattedValue ~= nil and formattedVal ~= nil and formattedVal ~= "" and tostring(
			formattedVal
		) or formatBindStateValue(stateVal))
	local stateKind = type(displayVal)

	local outerVisible = visBind:map(function(v: number)
		return v > 0.001
	end)

	local shadowPack = useAt(colors.shadow)
	local shadowColor = shadowPack[1] :: Color3
	local shadowAlpha = shadowPack[2] :: number

	local shadowTransparency = layerFade:map(function(lf: number)
		return 1 - (1 - lf) * (1 - shadowAlpha)
	end)

	local content = stateKind == "boolean"
			and e(ToggleBind, {
				name = props.entry.label,
				on = stateVal :: boolean,
				bgColor = bgColor,
				bgAlpha = bgAlpha,
				trackColor = trackColor,
				trackAlpha = trackAlpha,
				knobColor = stateVal and knobActiveColor or knobRestColor,
				textColor = textColor,
				parentTransparency = layerFade,
			})
		or e(TextBind, {
			name = props.entry.label,
			value = valueLabel,
			bgColor = bgColor,
			bgAlpha = bgAlpha,
			valueColor = titleColor,
			textColor = textColor,
			parentTransparency = layerFade,
		})

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = finalPosition,
		Size = ROW_SIZE,
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = outerVisible,
	}, {
		Shadow = useShadow({
			color = shadowColor,
			transparency = shadowTransparency,
			multiplier = ROW_SHADOW_MULT,
			zIndex = 0,
		}),
		Pill = e("Frame", {
			ref = pillRef,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = ROW_SIZE,
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 1,
		}, {
			Content = content,
		}),
	})
end)

local HeaderBlock = memo(function(props: {
	parentTransparency: any,
	widgetBind: any,
	hoverGlow: any,
	onHoverEnter: () -> (),
	onHoverLeave: () -> (),
}): React.Element<any>
	local bgPack = useAt(colors.background)
	local bgColor = bgPack[1] :: Color3
	local bgAlpha = bgPack[2] :: number
	local strokePack = useAt(colors.stroke)
	local strokeColor = strokePack[1] :: Color3
	local strokeAlpha = strokePack[2] :: number
	local imageColor = useAt(colors.image)
	local titleColor = useAt(colors.title)

	local shadowPack = useAt(colors.shadow)
	local shadowColor = shadowPack[1] :: Color3
	local shadowAlpha = shadowPack[2] :: number

	local shadowTransparency = props.widgetBind:map(function(v: number)
		local t = 1 - v * 0.7
		return 1 - (1 - t) * (1 - shadowAlpha)
	end)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = HEADER_SIZE,
		LayoutOrder = 0,
	}, {
		Glow = props.hoverGlow,
		Shadow = useShadow({
			color = shadowColor,
			transparency = shadowTransparency,
			multiplier = HEADER_SHADOW_MULT,
			zIndex = 0,
		}),
		Bar = e("Frame", {
			BackgroundColor3 = bgColor,
			BackgroundTransparency = props.parentTransparency:map(function(t: number)
				return 1 - (1 - bgAlpha) * (1 - t)
			end),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			ZIndex = 1,
			[React.Event.MouseEnter] = props.onHoverEnter,
			[React.Event.MouseLeave] = props.onHoverLeave,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDIM_CORNER,
			}),
			UIStroke = e("UIStroke", {
				Color = strokeColor,
				Thickness = 1,
				Transparency = props.parentTransparency:map(function(t: number)
					return 1 - (1 - strokeAlpha) * (1 - t)
				end),
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDIM_8,
				PaddingRight = UDIM_8,
			}),
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDIM_6,
			}),
			IconChip = e(Chip, {
				icon = FileController.Get("image", "keybinds"),
				textColor = imageColor,
				bgAlpha = 1,
				parentTransparency = props.parentTransparency,
				layoutOrder = 0,
			}),
			Title = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = "Keybinds",
				TextSize = 14,
				TextColor3 = titleColor,
				TextTransparency = props.parentTransparency,
				FontFace = FileController.Get("font", "semi_bold"),
				Size = NAME_SIZE,
				AutomaticSize = Enum.AutomaticSize.X,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),
		}),
	})
end)

return function(): React.Element<any>
	local allBinds = useAt(elementBindController.allBinds)
	local showBindList = useAt(hudState.showBindList)
	local menuOpen = useAt(uiState.isOpen)
	local sortMode = useAt(hudState.bindSortMode)

	local onInputBegan, positionBind = useDraggable(hudState.position)
	local onHoverEnter, onHoverLeave, hoverGlow = useHudHover(menuOpen and showBindList)

	local widgetBind, widgetSpring = useSpring(0, SPRING.smoothPreciser)

	useEffect(function()
		widgetSpring:setGoal(showBindList and 1 or 0)
	end, { showBindList })

	local widgetTransparency = useMemo(function()
		return widgetBind:map(function(v: number)
			return 1 - v
		end)
	end, { widgetBind })

	local activationRef = useRef({ seq = {} :: { [number]: number }, counter = 0 })
	local widthsRef = useRef({} :: { [number]: number })
	local widthVersion, bumpWidth = useState(0)

	local onMeasure = useCallback(function(id: number, width: number): ()
		local current = widthsRef.current[id]
		if not current or math.abs(current - width) > 0.5 then
			widthsRef.current[id] = width
			bumpWidth(function(v: number): number
				return v + 1
			end)
		end
	end, {})

	local version, bumpVersion = useState(0)
	useEffect(function()
		local subs: { () -> () } = {}
		for _, entry in next, allBinds do
			local id = entry.bind.id
			if peek(entry.bind.active) and not activationRef.current.seq[id] then
				activationRef.current.counter += 1
				activationRef.current.seq[id] = activationRef.current.counter
			end
			table.insert(
				subs,
				subAt(entry.bind.active, function()
					if peek(entry.bind.active) then
						activationRef.current.counter += 1
						activationRef.current.seq[id] = activationRef.current.counter
					end
					if peek(entry.bind.showInList) then
						bumpVersion(function(v: number): number
							return v + 1
						end)
					end
				end)
			)
			table.insert(
				subs,
				subAt(entry.bind.showInList, function()
					bumpVersion(function(v: number): number
						return v + 1
					end)
				end)
			)
		end
		return function()
			for _, s in next, subs do
				s()
			end
		end
	end, { allBinds })

	local slotOf, visibleCount = useMemo(function(): ({ [number]: number }, number)
		local visible: { elementBindController.BindListEntry } = {}
		for _, entry in next, allBinds do
			if shouldDisplay(peek(entry.bind.showInList), peek(entry.bind.active)) then
				visible[#visible + 1] = entry
			end
		end

		local function widthOf(entry: elementBindController.BindListEntry): number
			return widthsRef.current[entry.bind.id] or 0
		end
		local function kindOf(entry: elementBindController.BindListEntry): number
			local tv = peek(entry.bind.targetValue)
			local val
			if tv ~= nil then
				val = tv
			else
				val = peek(entry.element._state)
			end
			return kindRank(val)
		end
		local function seqOf(entry: elementBindController.BindListEntry): number
			return activationRef.current.seq[entry.bind.id] or math.huge
		end

		table.sort(visible, function(a, b): boolean
			if sortMode == "longestFrame" then
				local wa, wb = widthOf(a), widthOf(b)
				if wa ~= wb then
					return wa > wb
				end
				return a.bind.id < b.bind.id
			elseif sortMode == "type" then
				local ka, kb = kindOf(a), kindOf(b)
				if ka ~= kb then
					return ka < kb
				end
				local wa, wb = widthOf(a), widthOf(b)
				if wa ~= wb then
					return wa > wb
				end
				return a.bind.id < b.bind.id
			end
			local sa, sb = seqOf(a), seqOf(b)
			if sa ~= sb then
				return sa < sb
			end
			return a.bind.id < b.bind.id
		end)

		local slots: { [number]: number } = {}
		for index, entry in next, visible do
			slots[entry.bind.id] = index - 1
		end
		return slots, #visible
	end, { allBinds, version, widthVersion, sortMode } :: { any })

	local sortOptions = useMemo(function()
		local opt: any = OptionsElement("Keybind List")
		local dd: any = opt:AddElement("Dropdown", "Sort By", SORT_LABELS, MODE_TO_LABEL[peek(hudState.bindSortMode)])
		return { opt = opt, dd = dd }
	end, {})

	useEffect(function()
		local dd = sortOptions.dd
		local u1 = subAt(dd._state, function()
			local label = peek(dd._state)
			local mode = LABEL_TO_MODE[label]
			if mode and peek(hudState.bindSortMode) ~= mode then
				hudState.bindSortMode(mode :: any)
			end
		end)
		local u2 = subAt(hudState.bindSortMode, function()
			local label = MODE_TO_LABEL[peek(hudState.bindSortMode)]
			if label and peek(dd._state) ~= label then
				dd:SetSelected(label)
			end
		end)
		return function()
			u1()
			u2()
		end
	end, { sortOptions } :: { any })

	local openSortMenu = useCallback(function(input: InputObject): ()
		sortOptions.opt:Open(cursor.getPosition(input))
	end, { sortOptions } :: { any })

	local renderedRows = useMemo(function()
		local result: { [string]: React.Element<any> } = {}
		for _, entry in next, allBinds do
			result[`Row_{entry.bind.id}`] = e(BindRow, {
				entry = entry,
				slotIndex = slotOf[entry.bind.id],
				parentTransparency = widgetTransparency,
				onMeasure = onMeasure,
			})
		end
		return result
	end, { allBinds, slotOf, widgetTransparency, onMeasure } :: { any })

	local rowsContainerHeight = visibleCount * ROW_H + math.max(0, visibleCount - 1) * ROW_GAP

	local rootPosition = useMemo(function()
		return React.joinBindings({ widgetBind, positionBind }):map(function(values)
			local v: number = values[1]
			local pos: UDim2 = values[2]
			local offset = (1 - v) * SLIDE_OFFSET
			return UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, (pos.Y.Offset :: number) - offset)
		end)
	end, { widgetBind, positionBind } :: { any })

	local rootVisible = useMemo(function()
		return widgetBind:map(function(v: number)
			return v > 0.01
		end)
	end, { widgetBind })

	local onMainInputBegan = useCallback(function(_: Instance, input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			openSortMenu(input)
		else
			onInputBegan(input)
		end
	end, { openSortMenu, onInputBegan } :: { any })

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = rootPosition,
		Visible = rootVisible,
	}, {
		Main = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			ZIndex = 1,
			[React.Event.InputBegan] = menuOpen and onMainInputBegan or nil,
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDIM_ROW_GAP,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			Header = e(HeaderBlock, {
				parentTransparency = widgetTransparency,
				widgetBind = widgetBind,
				hoverGlow = hoverGlow,
				onHoverEnter = onHoverEnter,
				onHoverLeave = onHoverLeave,
			}),
			Rows = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 0, rowsContainerHeight),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 1,
			}, renderedRows),
		}),
	})
end
