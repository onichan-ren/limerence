local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local Charm = require("@pkg/Charm")

local themeState = require("@ui/theme/themeState")
local dpiState = require("@ui/util/dpiState")
local FileController = require("@feature/file/FileController")
local useSubwindowAnimation = require("@ui/hook/useSubwindowAnimation")
local useShadow = require("@ui/hook/useShadow")
local useAdvColor = require("@ui/hook/useAdvColor")
local elementBindController = require("@ui/bind/elementBindController")
local SPRING = require("@ui/util/spring")

local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useState = React.useState
local peek = Charm.peek
local subAt = Charm.subscribe
local e = React.createElement

local colors = themeState.colors.subwindow
local elColors = themeState.colors.window.element

local PANEL_WIDTH = 230
local OUTER_PAD_X = 10
local OUTER_PAD_X_RIGHT = 11
local OUTER_PAD_Y = 10
local CONTENT_INSET_X = 4
local CONTENT_INSET_TOP = 4
local SECTION_GAP = 8
local ROW_GAP = 10
local ROW_HEIGHT = 18
local TITLE_HEIGHT = 14
local DIVIDER_HEIGHT = 2
local DIVIDER_OFFSET_Y = 18

local SEGMENT_W = 44
local SEGMENT_H = 18
local SEGMENT_COUNT = 3
local SEGMENTED_TOTAL_W = SEGMENT_W * SEGMENT_COUNT
local KEY_CHIP_W = 56
local KEY_CHIP_H = 18
local ICON_BTN_SIZE = 18
local TOGGLE_W = 30
local TOGGLE_H = 14
local TOGGLE_KNOB = 10

local LABEL_TEXT_SIZE = 12
local CONTROL_TEXT_SIZE = 11
local SUBWINDOW_TEXT_OFFSET_Y = -1

local MODES: { { mode: string, label: string } } = {
	{ mode = "toggle", label = "Toggle" },
	{ mode = "onHold", label = "Hold" },
	{ mode = "offHold", label = "Off" },
}

local function modeIndex(mode: string): number
	for i, item in next, MODES do
		if item.mode == mode then
			return i - 1
		end
	end
	return 0
end

local function useBoolAtom(value: boolean): any
	local atom = useMemo(function()
		return Charm.atom(false)
	end, {})
	useEffect(function()
		atom(value)
	end, { value })
	return atom
end

local function trim(s: string): string
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function formatTargetDraft(value: any): string
	local t = type(value)
	if t == "number" then
		local r = math.round(value * 1000) / 1000
		local text = string.format("%.3f", r)
		text = text:gsub("0+$", "")
		text = text:gsub("%.$", "")
		return text
	elseif t == "string" then
		return value
	end
	return ""
end

local function Row(props: {
	label: string,
	control: React.Element<any>,
	layoutOrder: number,
}): React.Element<any>
	local labelColor = useAt(elColors.text)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = props.layoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = props.label,
			TextSize = LABEL_TEXT_SIZE,
			TextColor3 = labelColor,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 0,
		}, {
			UIFlexItem = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
			}),
		}),
		Control = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 1,
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Item = props.control,
		}),
	})
end

local function KeyChip(props: {
	label: string,
	isListening: boolean,
	hasInput: boolean,
	onClick: () -> (),
	layoutOrder: number,
}): React.Element<any>
	local listeningAtom = useBoolAtom(props.isListening)
	local restTextAtom = props.hasInput and elColors.text or elColors.caption

	local bgColor = useAdvColor(elColors.fieldBackground, elColors.fieldBackgroundActive, listeningAtom)
	local strokeColor = useAdvColor(elColors.fieldStroke, elColors.fieldStrokeActive, listeningAtom)
	local textColor = useAdvColor(restTextAtom, elColors.textActive, listeningAtom)

	return e("TextButton", {
		BackgroundColor3 = bgColor.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(KEY_CHIP_W, KEY_CHIP_H),
		Text = props.label,
		TextSize = CONTROL_TEXT_SIZE,
		TextColor3 = textColor.binding,
		FontFace = FileController.Get("font", "semi_bold"),
		AutoButtonColor = false,
		Active = false,
		LayoutOrder = props.layoutOrder,
		[React.Event.MouseEnter] = function()
			bgColor.onMouseEnter()
			strokeColor.onMouseEnter()
			textColor.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			bgColor.onMouseLeave()
			strokeColor.onMouseLeave()
			textColor.onMouseLeave()
		end,
		[React.Event.MouseButton1Click] = props.onClick,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = e("UIStroke", {
			Color = strokeColor.binding,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

local function IconButton(props: {
	image: string,
	onPress: () -> (),
	layoutOrder: number,
}): React.Element<any>
	local bgColor = useAdvColor(elColors.surface)
	local strokeColor = useAdvColor(elColors.surfaceStroke)
	local iconColor = useAdvColor(elColors.icon, elColors.iconActive)

	return e("TextButton", {
		BackgroundColor3 = bgColor.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(ICON_BTN_SIZE, ICON_BTN_SIZE),
		Text = "",
		Active = false,
		AutoButtonColor = false,
		LayoutOrder = props.layoutOrder,
		[React.Event.MouseEnter] = function()
			bgColor.onMouseEnter()
			strokeColor.onMouseEnter()
			iconColor.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			bgColor.onMouseLeave()
			strokeColor.onMouseLeave()
			iconColor.onMouseLeave()
		end,
		[React.Event.MouseButton1Click] = props.onPress,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = e("UIStroke", {
			Color = strokeColor.binding,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Image = e("ImageLabel", {
			BackgroundTransparency = 1,
			Image = props.image,
			ImageColor3 = iconColor.binding,
			Size = UDim2.fromOffset(12, 12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		}),
	})
end

local function Switch(props: {
	on: boolean,
	onClick: () -> (),
	layoutOrder: number,
}): React.Element<any>
	local onAtom = useBoolAtom(props.on)
	local trackColor = useAdvColor(elColors.surface, elColors.accent, onAtom, true)
	local strokeColor = useAdvColor(elColors.surfaceStroke, elColors.accentStrong, onAtom)
	local knobColor = useAdvColor(elColors.thumb, elColors.thumbActive, onAtom, true)

	local bind, spring = useSpring(props.on and 1 or 0, SPRING.quick)

	useEffect(function()
		spring:setGoal(props.on and 1 or 0)
	end, { props.on })

	return e("TextButton", {
		BackgroundColor3 = trackColor.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(TOGGLE_W, TOGGLE_H),
		Text = "",
		Active = false,
		AutoButtonColor = false,
		LayoutOrder = props.layoutOrder,
		[React.Event.MouseEnter] = function()
			trackColor.onMouseEnter()
			strokeColor.onMouseEnter()
			knobColor.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			trackColor.onMouseLeave()
			strokeColor.onMouseLeave()
			knobColor.onMouseLeave()
		end,
		[React.Event.MouseButton1Click] = props.onClick,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		UIStroke = e("UIStroke", {
			Color = strokeColor.binding,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}),
		Knob = e("Frame", {
			Size = UDim2.fromOffset(TOGGLE_KNOB, TOGGLE_KNOB),
			Position = bind:map(function(v: number)
				return UDim2.fromScale(v, 0)
			end),
			AnchorPoint = bind:map(function(v: number)
				return Vector2.new(v, 0)
			end),
			BackgroundColor3 = knobColor.binding,
			BorderSizePixel = 0,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
	})
end

local function SegmentButton(props: {
	label: string,
	selected: boolean,
	xOffset: number,
	onPress: () -> (),
}): React.Element<any>
	local selectedAtom = useBoolAtom(props.selected)
	local textColor = useAdvColor(elColors.text, elColors.textActive, selectedAtom)
	local hoverBg = useAt(elColors.accentSoft)

	local isHovered, setHovered = useState(false)
	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)

	useEffect(function()
		local target = (isHovered and not props.selected) and 1 or 0
		hoverSpring:setGoal(target)
	end, { isHovered, props.selected })

	return e("TextButton", {
		BackgroundColor3 = hoverBg,
		BackgroundTransparency = hoverBind:map(function(v: number)
			return 1 - v * 0.6
		end),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(props.xOffset, 0),
		Size = UDim2.fromOffset(SEGMENT_W, SEGMENT_H),
		Text = props.label,
		TextSize = CONTROL_TEXT_SIZE,
		TextColor3 = textColor.binding,
		FontFace = FileController.Get("font", "semi_bold"),
		AutoButtonColor = false,
		Active = false,
		ZIndex = 2,
		[React.Event.MouseEnter] = function()
			setHovered(true)
			textColor.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			textColor.onMouseLeave()
		end,
		[React.Event.MouseButton1Click] = props.onPress,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
	})
end

local function ModeSegmented(props: {
	selected: string,
	onSelect: (string) -> (),
	layoutOrder: number,
}): React.Element<any>
	local trackBg = useAt(elColors.surface)
	local highlightBg = useAt(elColors.accentStrong)
	local strokeColor = useAt(elColors.surfaceStroke)

	local activeIdx = modeIndex(props.selected)
	local idxBind, idxSpring = useSpring(activeIdx, SPRING.smoothPrecise)

	useEffect(function()
		idxSpring:setGoal(activeIdx)
	end, { activeIdx })

	local children: { [string]: React.Element<any> } = {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = e("UIStroke", {
			Color = strokeColor,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Highlight = e("Frame", {
			BackgroundColor3 = highlightBg,
			BorderSizePixel = 0,
			Position = idxBind:map(function(v: number)
				return UDim2.fromOffset(v * SEGMENT_W, 0)
			end),
			Size = UDim2.fromOffset(SEGMENT_W, SEGMENT_H),
			ZIndex = 1,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		}),
	}

	for i, item in next, MODES do
		children[item.mode] = e(SegmentButton, {
			label = item.label,
			selected = props.selected == item.mode,
			xOffset = (i - 1) * SEGMENT_W,
			onPress = function()
				props.onSelect(item.mode)
			end,
		})
	end

	return e("Frame", {
		BackgroundColor3 = trackBg,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(SEGMENTED_TOTAL_W, SEGMENT_H),
		LayoutOrder = props.layoutOrder,
	}, children)
end

local function TargetEntry(props: {
	value: any,
	placeholder: string,
	onCommit: (string) -> (),
}): React.Element<any>
	local bg = useAt(elColors.fieldBackground)
	local stroke = useAt(elColors.fieldStroke)
	local mutedColor = useAt(elColors.caption)
	local textColor = useAt(elColors.text)

	local draft, setDraft = useState(formatTargetDraft(props.value))

	useEffect(function()
		setDraft(formatTargetDraft(props.value))
	end, { props.value })

	return e("TextBox", {
		BackgroundColor3 = bg,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(80, ROW_HEIGHT),
		Text = draft,
		TextSize = CONTROL_TEXT_SIZE,
		TextColor3 = textColor,
		PlaceholderText = props.placeholder,
		PlaceholderColor3 = mutedColor,
		FontFace = FileController.Get("font", "semi_bold"),
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		[React.Change.Text] = function(rbx: TextBox)
			setDraft(rbx.Text)
		end,
		[React.Event.FocusLost] = function(rbx: TextBox)
			props.onCommit(rbx.Text)
		end,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = e("UIStroke", {
			Color = stroke,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
	})
end

local function BindEditorBindRows(props: {
	element: any,
	bind: any,
	index: number,
	totalBinds: number,
	listeningId: number?,
	setListeningId: (number?) -> (),
	onRemoveBind: () -> (),
	isInitial: boolean,
	isRemoving: boolean,
	layoutOrder: number,
}): React.Element<any>
	local element = props.element
	local bind = props.bind
	local listeningId = props.listeningId
	local setListeningId = props.setListeningId

	local mode = useAt(bind.mode)
	local inputs = useAt(bind.inputs)
	local showInList = useAt(bind.showInList)
	local stateSnapshot = useAt(element._state, { element })
	local valueKind = type(stateSnapshot)

	local isListeningHere = listeningId == bind.id
	local hasInput = #inputs > 0
	local keyLabel = isListeningHere and "..."
		or not hasInput and "—"
		or elementBindController.GetInputLabel(inputs[1])

	local proxy = useMemo(function(): any?
		if type(element.CreateTargetProxy) == "function" then
			return element:CreateTargetProxy(peek(bind.targetValue))
		end
		return nil
	end, { element, bind.id })

	useEffect(function()
		if not proxy then
			return
		end
		local s1 = subAt(proxy._state, function(v: any)
			bind.targetValue(v)
		end)
		local s2 = subAt(bind.targetValue, function(v: any)
			if v ~= nil then
				proxy._state(v)
			end
		end)
		return function()
			s1()
			s2()
		end
	end, { proxy })

	local showFallbackEditor = (proxy == nil) and (valueKind == "number" or valueKind == "string")

	local function commitFallback(text: string): ()
		if not showFallbackEditor then
			return
		end
		local vk = type(peek(element._state))
		if vk == "number" then
			local n = tonumber(trim(text))
			if n ~= nil then
				bind.targetValue(n)
			end
		elseif vk == "string" then
			bind.targetValue(text)
		end
	end

	local rows: { [string]: React.Element<any> } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, ROW_GAP),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, CONTENT_INSET_X),
			PaddingRight = UDim.new(0, CONTENT_INSET_X),
			PaddingTop = UDim.new(0, CONTENT_INSET_TOP),
		}),
	}

	if props.totalBinds > 1 then
		rows.Header = e(Row, {
			label = `Bind {props.index}`,
			layoutOrder = 0,
			control = e(IconButton, {
				image = FileController.Get("image", "trash"),
				onPress = props.onRemoveBind,
				layoutOrder = 0,
			}),
		})
	end

	rows.Key = e(Row, {
		label = "Key",
		layoutOrder = 1,
		control = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(KEY_CHIP_W + ICON_BTN_SIZE + 6, KEY_CHIP_H),
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Chip = e(KeyChip, {
				label = keyLabel,
				isListening = isListeningHere,
				hasInput = hasInput,
				onClick = function()
					setListeningId(bind.id)
				end,
				layoutOrder = 0,
			}),
			Clear = e(IconButton, {
				image = FileController.Get("image", "clear"),
				onPress = function()
					bind.inputs({})
					if isListeningHere then
						setListeningId(nil)
					end
				end,
				layoutOrder = 1,
			}),
		}),
	})

	rows.Mode = e(Row, {
		label = "Mode",
		layoutOrder = 2,
		control = e(ModeSegmented, {
			selected = mode,
			onSelect = function(m: string)
				bind.mode(m :: any)
			end,
			layoutOrder = 0,
		}),
	})

	if proxy then
		rows.Target = e(Row, {
			label = "Set to",
			layoutOrder = 3,
			control = proxy:RenderInternal({
				layoutOrder = 0,
				textOffsetY = SUBWINDOW_TEXT_OFFSET_Y,
			}),
		})
	elseif showFallbackEditor then
		local currentTarget: any = peek(bind.targetValue)
		if currentTarget == nil then
			currentTarget = stateSnapshot
		end
		rows.Target = e(Row, {
			label = "Set to",
			layoutOrder = 3,
			control = e(TargetEntry, {
				value = currentTarget,
				placeholder = valueKind == "number" and "Number" or "Value",
				onCommit = commitFallback,
			}),
		})
	end

	rows.ShowInList = e(Row, {
		label = "Show in list",
		layoutOrder = 4,
		control = e(Switch, {
			on = showInList,
			onClick = function()
				bind.showInList(not peek(bind.showInList))
			end,
			layoutOrder = 0,
		}),
	})

	local alphaBind, alphaSpring = useSpring(props.isInitial and 1 or 0, SPRING.smoothPrecise)

	useEffect(function()
		alphaSpring:setGoal(props.isRemoving and 0 or 1)
	end, { props.isRemoving })

	return e("CanvasGroup", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.layoutOrder,
		GroupTransparency = alphaBind:map(function(v: number)
			return 1 - v
		end),
	}, rows)
end

local REMOVE_ANIM_TIME = 0.25

local function BindEditorBody(props: { element: any }): React.Element<any>
	local element = props.element

	local listeningId, setListeningId = useState(nil :: number?)
	local removingIds, setRemovingIds = useState({} :: { [number]: boolean })
	local binds = useAt(element._binds, { element })

	local initialBindsRef = useRef(nil :: { [number]: boolean }?)
	if initialBindsRef.current == nil then
		local initial: { [number]: boolean } = {}
		for _, b in next, binds do
			initial[b.id] = true
		end
		initialBindsRef.current = initial
	end

	useEffect(function()
		setListeningId(nil)
		if #peek(element._binds) == 0 and element.AddBind then
			element:AddBind()
		end
	end, { element })

	useEffect(function()
		if not listeningId then
			return
		end

		local conn = UserInputService.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					setListeningId(nil)
					return
				end
				for _, eb in next, peek(element._binds) do
					if eb.id == listeningId then
						eb.inputs({ input.KeyCode })
						break
					end
				end
				setListeningId(nil)
			elseif
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2
				or input.UserInputType == Enum.UserInputType.MouseButton3
			then
				for _, eb in next, peek(element._binds) do
					if eb.id == listeningId then
						eb.inputs({ input.UserInputType })
						break
					end
				end
				setListeningId(nil)
			end
		end)

		return function()
			conn:Disconnect()
		end
	end, { listeningId, element })

	local addBtnBg = useAdvColor(elColors.surface)
	local addBtnStroke = useAdvColor(elColors.surfaceStroke)
	local addBtnText = useAdvColor(elColors.text, elColors.textActive)
	local dividerColor = useAt(colors.divider)

	local function startRemove(bindId: number): ()
		if removingIds[bindId] then
			return
		end
		setRemovingIds(function(prev: { [number]: boolean })
			local next_ = table.clone(prev)
			next_[bindId] = true
			return next_
		end)
		if listeningId == bindId then
			setListeningId(nil)
		end
		task.delay(REMOVE_ANIM_TIME, function(): ()
			element:RemoveBind(bindId)
			setRemovingIds(function(prev: { [number]: boolean })
				if not prev[bindId] then
					return prev
				end
				local next_ = table.clone(prev)
				next_[bindId] = nil
				return next_
			end)
		end)
	end

	local children: { [string]: React.Element<any> } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, SECTION_GAP),
		}),
	}

	local order = 0
	for i, bind in next, binds do
		if i > 1 then
			children[`Divider_{i}`] = e("Frame", {
				BackgroundColor3 = dividerColor,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 1),
				LayoutOrder = order,
			})
			order += 1
		end
		local isInitial = (initialBindsRef.current :: { [number]: boolean })[bind.id] == true
		children[`Bind_{bind.id}`] = e(BindEditorBindRows, {
			element = element,
			bind = bind,
			index = i,
			totalBinds = #binds,
			listeningId = listeningId,
			setListeningId = setListeningId,
			onRemoveBind = function()
				startRemove(bind.id)
			end,
			isInitial = isInitial,
			isRemoving = removingIds[bind.id] == true,
			layoutOrder = order,
		})
		order += 1
	end

	if #binds < elementBindController.MAX_BINDS then
		children.AddBind = e("TextButton", {
			BackgroundColor3 = addBtnBg.binding,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -CONTENT_INSET_X * 2, 0, ROW_HEIGHT),
			Position = UDim2.new(0.5, 0, 0, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			Text = "+ Add bind",
			TextSize = CONTROL_TEXT_SIZE,
			TextColor3 = addBtnText.binding,
			FontFace = FileController.Get("font", "semi_bold"),
			AutoButtonColor = false,
			Active = false,
			LayoutOrder = order,
			[React.Event.MouseEnter] = function()
				addBtnBg.onMouseEnter()
				addBtnStroke.onMouseEnter()
				addBtnText.onMouseEnter()
			end,
			[React.Event.MouseLeave] = function()
				addBtnBg.onMouseLeave()
				addBtnStroke.onMouseLeave()
				addBtnText.onMouseLeave()
			end,
			[React.Event.MouseButton1Click] = function()
				if element.AddBind then
					element:AddBind()
				end
			end,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			UIStroke = e("UIStroke", {
				Color = addBtnStroke.binding,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, children)
end

return function(properties: { BindEditor: any }): React.Element<any>
	local editor = properties.BindEditor

	local element = useAt(editor._element)
	local backgroundColor = useAt(colors.background)
	local strokeColor = useAt(colors.stroke)
	local titleColor = useAt(colors.title)
	local dividerColor = useAt(colors.divider)

	local anim = useSubwindowAnimation(editor, {
		preset = SPRING.snap,
		slideOffset = 8,
		floatingId = "subwindow.bindEditor",
		onClickOutside = function()
			editor:Close()
		end,
	})

	local layoutRef = useRef(nil :: UIListLayout?)
	local heightBind, heightSpring = useSpring(0, SPRING.smoothPrecise)
	local heightSeededRef = useRef(false)

	useEffect(function()
		local layout = layoutRef.current
		if not layout then
			return
		end
		local function update(): ()
			local scale = peek(dpiState.scale)
			if scale <= 0 then
				scale = 1
			end
			local layoutY = layout.AbsoluteContentSize.Y / scale
			if layoutY <= 0 then
				return
			end
			local target = layoutY + OUTER_PAD_Y * 2
			if not heightSeededRef.current then
				heightSeededRef.current = true
				heightSpring:setPosition(target)
			end
			heightSpring:setGoal(target)
		end
		update()
		local conn = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
		return function()
			conn:Disconnect()
		end
	end, { element })

	local wrapperSize = heightBind:map(function(h: number)
		return UDim2.fromOffset(PANEL_WIDTH, math.max(h, 0))
	end)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = wrapperSize,
		Position = anim.position,
		Visible = anim.visible,
		ZIndex = anim.zIndex,
	}, {
		Shadow = useShadow({
			transparency = anim.transparency,
			zIndex = 0,
		}),
		Body = e("CanvasGroup", {
			ref = anim.frameRef,
			BackgroundColor3 = backgroundColor,
			BackgroundTransparency = 0,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = anim.transparency,
			ZIndex = 1,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			UIStroke = e("UIStroke", {
				Color = strokeColor,
				Transparency = anim.strokeTransparency,
				Thickness = 1,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, OUTER_PAD_X),
				PaddingRight = UDim.new(0, OUTER_PAD_X_RIGHT),
				PaddingTop = UDim.new(0, OUTER_PAD_Y),
				PaddingBottom = UDim.new(0, OUTER_PAD_Y),
			}),
			UIListLayout = e("UIListLayout", {
				ref = layoutRef,
				FillDirection = Enum.FillDirection.Vertical,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, SECTION_GAP),
			}),
			TitleFrame = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, TITLE_HEIGHT + DIVIDER_HEIGHT + 2),
				LayoutOrder = 0,
			}, {
				Title = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
					Text = "Bind Settings",
					TextColor3 = titleColor,
					FontFace = FileController.Get("font", "semi_bold"),
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Divider = e("Frame", {
					BorderSizePixel = 0,
					BackgroundColor3 = dividerColor,
					Size = UDim2.new(1, 0, 0, DIVIDER_HEIGHT),
					Position = UDim2.fromOffset(0, DIVIDER_OFFSET_Y),
				}),
			}),
			Content = element and e(BindEditorBody, {
				element = element,
				key = tostring(element),
			}) or nil,
		}),
	})
end
