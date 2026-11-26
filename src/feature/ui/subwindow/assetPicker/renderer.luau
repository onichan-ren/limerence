local Charm = require("@pkg/Charm")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local useSubwindowAnimation = require("@ui/hook/useSubwindowAnimation")
local useShadow = require("@ui/hook/useShadow")
local useScrollFade = require("@ui/hook/useScrollFade")
local useTooltip = require("@ui/hook/useTooltip")
local SPRING = require("@ui/util/spring")
local dpiState = require("@ui/util/dpiState")
local floatingController = require("@ui/floating/floatingController")

local subwindowColors = themeState.colors.subwindow
local elementColors = themeState.colors.window.element

local useEffect = React.useEffect
local useMemo = React.useMemo
local useState = React.useState
local useRef = React.useRef
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local e = React.createElement

local EMPTY_PREVIEW_VERSION = Charm.atom(0)

local WIDTH = 220
local CREATOR_EXTRA = 44
local MAX_LIST_HEIGHT = 180
local PADDING = 8
local TITLE_HEIGHT = 22
local DIVIDER_HEIGHT = 1
local ROW_HEIGHT = 22
local ROW_GAP = 4
local ROW_INSET = 1
local ROW_SLOT_HEIGHT = ROW_HEIGHT + ROW_INSET * 2
local ASSIGN_BUTTON = 14
local ASSIGN_GAP = 4
local THUMB_SIZE = 16
local THUMB_GAP = 6
local SELECTED_INDICATOR_GAP = 4

local EMPTY_ASSIGNMENTS = Charm.atom({} :: { [string]: string? })
local EMPTY_ASSETS = Charm.atom({} :: { string })
local EMPTY_REMOVING = Charm.atom({} :: { [string]: boolean })
local EMPTY_FOCUSED = Charm.atom(nil :: string?)
local EMPTY_TYPES: { AssignmentType } = {}

export type AssignmentType = {
	key: string,
	label: string,
	icon: string?,
	tip: string?,
	extras: { any }?,
}

type AssignButtonProps = {
	Type: AssignmentType,
	IsActive: boolean,
	AssetName: string,
	OnClick: () -> (),
	LayoutOrder: number,
}

local function AssignButton(props: AssignButtonProps): React.Element<any>
	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		activeAtom(props.IsActive)
	end, { props.IsActive })

	local backgroundColor = useAdvColor(elementColors.surface, elementColors.accent, activeAtom, true)
	local strokeColor = useAdvColor(elementColors.surfaceStroke, elementColors.accentStrong, activeAtom)

	local idleIcon = useAt(elementColors.icon)
	local activeIcon = useAt(elementColors.thumbActive)

	local activeBind, activeSpring = useSpring(0, SPRING.smoothPrecise)
	useEffect(function()
		activeSpring:setGoal(props.IsActive and 1 or 0)
	end, { props.IsActive })

	local iconColorBind = activeBind:map(function(value: number)
		return idleIcon:Lerp(activeIcon, value)
	end)

	local resolvedIcon = props.Type.icon and (FileController.Get("image", props.Type.icon)) or nil

	local btnRef = useRef(nil :: GuiObject?)
	local tipBody: string
	if props.IsActive then
		tipBody = `Unassign {props.Type.label}`
	elseif props.Type.tip and props.Type.tip ~= "" then
		tipBody = props.Type.tip
	else
		tipBody = `Assign {props.Type.label}`
	end
	local tipHandlers = useTooltip(tipBody, btnRef)

	return e("TextButton", {
		ref = btnRef,
		BackgroundColor3 = backgroundColor.binding,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.fromOffset(ASSIGN_BUTTON, ASSIGN_BUTTON),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			backgroundColor.onMouseEnter()
			strokeColor.onMouseEnter()
			tipHandlers.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			backgroundColor.onMouseLeave()
			strokeColor.onMouseLeave()
			tipHandlers.onMouseLeave()
		end,
		[React.Event.MouseButton1Click] = function()
			props.OnClick()
		end,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		Icon = resolvedIcon and e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = resolvedIcon,
			ImageColor3 = iconColorBind,
			Size = UDim2.fromOffset(8, 8),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		}) or e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = string.upper(string.sub(props.Type.label, 1, 1)),
			TextColor3 = iconColorBind,
			TextSize = 10,
			FontFace = FileController.Get("font", "semi_bold"),
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

type AssetRowProps = {
	Name: string,
	Source: any,
	AssignmentTypes: { AssignmentType },
	Assignments: { [string]: string? },
	Selected: boolean?,
	SingleSelect: boolean?,
	Removing: boolean?,
	SlotGap: number,
	LayoutOrder: number,
}

local function assetRowsEqual(a: AssetRowProps, b: AssetRowProps): boolean
	if
		a.Name ~= b.Name
		or a.Selected ~= b.Selected
		or a.SingleSelect ~= b.SingleSelect
		or a.Removing ~= b.Removing
		or a.SlotGap ~= b.SlotGap
		or a.LayoutOrder ~= b.LayoutOrder
		or a.Source ~= b.Source
		or a.AssignmentTypes ~= b.AssignmentTypes
	then
		return false
	end
	for _, assignType in next, b.AssignmentTypes do
		if (a.Assignments[assignType.key] == a.Name) ~= (b.Assignments[assignType.key] == b.Name) then
			return false
		end
	end
	return true
end

local AssetRow = React.memo(function(props: AssetRowProps): React.Element<any>
	local hovering, setHovering = useState(false)

	local hoverBind, hoverSpring = useSpring(0, SPRING.snap)
	useEffect(function()
		hoverSpring:setGoal(hovering and 1 or 0)
	end, { hovering })

	local panelColor = useAt(elementColors.panel)
	local surfaceColor = useAt(elementColors.surface)
	local surfaceStroke = useAt(elementColors.surfaceStroke)
	local accentSoft = useAt(elementColors.accentSoft)
	local accentStrong = useAt(elementColors.accentStrong)
	local textColor = useAt(elementColors.text)
	local textActive = useAt(elementColors.textActive)

	local selected = props.Selected or false
	local singleSelect = props.SingleSelect or false

	local selectedBind, selectedSpring = useSpring(selected and 1 or 0, SPRING.smoothPrecise)
	useEffect(function()
		selectedSpring:setGoal(selected and 1 or 0)
	end, { selected })

	useAt(props.Source and props.Source._previewVersion or EMPTY_PREVIEW_VERSION)
	local previewImage: string? = nil
	if props.Source and type(props.Source.GetPreviewImage) == "function" then
		previewImage = props.Source:GetPreviewImage(props.Name)
	end
	local hasThumb = previewImage ~= nil and previewImage ~= ""
	local thumbInset = hasThumb and (THUMB_SIZE + THUMB_GAP) or 0

	local hasAssigns = #props.AssignmentTypes > 0
	local contentInset = hasAssigns and 0 or SELECTED_INDICATOR_GAP
	local assignCount = #props.AssignmentTypes
	local assignsWidth = hasAssigns and (assignCount * ASSIGN_BUTTON + math.max(0, assignCount - 1) * ASSIGN_GAP) or 0
	local labelRightInset = (hasAssigns and (assignsWidth + 6) or 0) + thumbInset + contentInset

	local renderedAssigns: { [string]: React.Element<any> } = {}
	if hasAssigns then
		for index, assignType in next, props.AssignmentTypes do
			local isActive = props.Assignments[assignType.key] == props.Name
			renderedAssigns[`Assign_{assignType.key}`] = e(AssignButton, {
				Type = assignType,
				IsActive = isActive,
				AssetName = props.Name,
				LayoutOrder = index,
				OnClick = function()
					props.Source:Assign(assignType.key, not isActive and props.Name or nil)
				end,
			})
		end
	end

	local rowStateBind = React.joinBindings({ hoverBind, selectedBind })
	local rowBgColor = rowStateBind:map(function(values)
		return panelColor:Lerp(surfaceColor, values[1] * 0.75):Lerp(accentSoft, values[2])
	end)
	local rowBgTransparency = rowStateBind:map(function(values)
		return 1 - math.max(values[2], values[1] * 0.65)
	end)
	local rowTextColor = selectedBind:map(function(value: number)
		return textColor:Lerp(textActive, value)
	end)
	local removeBind, removeSpring = useSpring(props.Removing and 0 or 1, SPRING.smoothPrecise)
	useEffect(function()
		removeSpring:setGoal(props.Removing and 0 or 1)
	end, { props.Removing })

	return e("CanvasGroup", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = removeBind:map(function(value: number)
			return UDim2.new(1, 0, 0, math.floor((ROW_SLOT_HEIGHT + props.SlotGap) * value + 0.5))
		end),
		GroupTransparency = removeBind:map(function(value: number)
			return 1 - value
		end),
		-- ClipsDescendants is always true on canvasgroups
		-- ClipsDescendants = props.Removing == true,
		LayoutOrder = props.LayoutOrder,
	}, {
		Button = e("TextButton", {
			BackgroundColor3 = rowBgColor,
			BackgroundTransparency = rowBgTransparency,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Active = false,
			Position = UDim2.fromOffset(ROW_INSET, ROW_INSET),
			Size = UDim2.new(1, -ROW_INSET * 2, 0, ROW_HEIGHT),
			[React.Event.MouseEnter] = function()
				setHovering(true)
			end,
			[React.Event.MouseLeave] = function()
				setHovering(false)
			end,
			[React.Event.MouseButton1Click] = function()
				props.Source:FocusAsset(props.Name)
				props.Source:Preview(props.Name)
				if singleSelect then
					props.Source:Select(props.Name)
				end
			end,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			UIStroke = e("UIStroke", {
				Color = selectedBind:map(function(value: number)
					return surfaceStroke:Lerp(accentStrong, value)
				end),
				Transparency = selectedBind:map(function(value: number)
					return 1 - value
				end),
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, hasAssigns and 6 or 12),
			}),
			Accent = not hasAssigns and e("Frame", {
				BackgroundColor3 = accentStrong,
				BackgroundTransparency = selectedBind:map(function(value: number)
					return 1 - value
				end),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, -2, 0.5, 0),
				Size = UDim2.fromOffset(2, 12),
				ZIndex = 3,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}) or nil,
			Thumb = hasThumb and e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = previewImage,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, contentInset, 0.5, 0),
				Size = UDim2.fromOffset(THUMB_SIZE, THUMB_SIZE),
				ZIndex = 2,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, 2),
				}),
			}) or nil,
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				Text = props.Name,
				TextColor3 = rowTextColor,
				TextSize = 12,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.new(1, -labelRightInset, 1, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, thumbInset + contentInset, 0.5, 0),
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Assigns = hasAssigns and e(
				"Frame",
				{
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.new(0, assignsWidth, 0, ASSIGN_BUTTON),
				},
				Sift.Dictionary.join({
					UIListLayout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, ASSIGN_GAP),
					}),
				}, renderedAssigns)
			) or nil,
		}),
	})
end, assetRowsEqual)

type ExtrasGroupProps = {
	GroupKey: string,
	Label: string,
	Extras: { any },
	LayoutOrder: number,
	MutedColor: Color3,
	Visible: boolean,
}

local ExtrasGroup = React.memo(function(props: ExtrasGroupProps): React.Element<any>
	local fadeBind, fadeSpring = useSpring(0, SPRING.smoothPrecise)
	local hidden, setHidden = useState(not props.Visible)

	useEffect(function()
		if props.Visible then
			setHidden(false)
			fadeSpring:setGoal(1)
			return
		end
		fadeSpring:setGoal(0)
		local handle = task.delay(0.5, function()
			setHidden(true)
		end)
		return function()
			task.cancel(handle)
		end
	end, { props.Visible })

	local naturalHeight, setNaturalHeight = useState(0)
	local innerRef = useRef(nil :: GuiObject?)

	useEffect(function()
		local inner = innerRef.current
		if not inner then
			return
		end
		local function update(): ()
			local h = inner.AbsoluteSize.Y
			if h > 0 then
				setNaturalHeight(h)
			end
		end
		update()
		local conn = inner:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
		return function()
			conn:Disconnect()
		end
	end, {})

	local groupTransparency = fadeBind:map(function(v: number)
		return 1 - v
	end)

	local groupPosition = fadeBind:map(function(v: number)
		return UDim2.new(0, 0, 0, math.floor((1 - v) * -6))
	end)

	local outerSize = fadeBind:map(function(v: number)
		return UDim2.new(1, 0, 0, math.max(0, math.floor(v * naturalHeight)))
	end)

	local rendered: { [string]: React.Element<any> } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 2),
		}),
		Heading = e("TextLabel", {
			BackgroundTransparency = 1,
			Text = string.upper(props.Label),
			TextColor3 = props.MutedColor,
			TextSize = 10,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 11),
			LayoutOrder = 0,
		}),
	}
	for index, element in next, props.Extras do
		rendered[`E_{index}`] = element:Render(index, { textOffsetY = -1 })
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = not hidden,
		Size = outerSize,
		LayoutOrder = props.LayoutOrder,
	}, {
		Inner = e("CanvasGroup", {
			ref = innerRef,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = groupPosition,
			GroupTransparency = groupTransparency,
		}, rendered),
	})
end)

type FormFieldProps = {
	Field: any,
	Value: string,
	OnChange: (string) -> (),
	LayoutOrder: number,
}

local function SelectOption(props: {
	Text: string,
	Selected: boolean,
	OnClick: () -> (),
	LayoutOrder: number,
	WidthScale: number,
}): React.Element<any>
	local hovering, setHovering = useState(false)
	local fieldBackground = useAt(elementColors.fieldBackground)
	local fieldBackgroundActive = useAt(elementColors.fieldBackgroundActive)
	local fieldStroke = useAt(elementColors.fieldStroke)
	local fieldStrokeActive = useAt(elementColors.fieldStrokeActive)
	local captionColor = useAt(elementColors.caption)
	local textActive = useAt(elementColors.textActive)
	local accentSoft = useAt(elementColors.accentSoft)
	local accentStrong = useAt(elementColors.accentStrong)

	local hoverBind, hoverSpring = useSpring(hovering and 1 or 0, SPRING.subtle)
	local selectedBind, selectedSpring = useSpring(props.Selected and 1 or 0, SPRING.quick)
	useEffect(function()
		hoverSpring:setGoal(hovering and 1 or 0)
	end, { hovering })
	useEffect(function()
		selectedSpring:setGoal(props.Selected and 1 or 0)
	end, { props.Selected })

	local stateBind = React.joinBindings({ hoverBind, selectedBind })

	return e("TextButton", {
		BackgroundColor3 = stateBind:map(function(values)
			return fieldBackground:Lerp(fieldBackgroundActive, values[1]):Lerp(accentSoft, values[2])
		end),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Size = UDim2.new(props.WidthScale, -3, 1, 0),
		Text = props.Text,
		TextColor3 = selectedBind:map(function(value: number)
			return captionColor:Lerp(textActive, value):Lerp(accentStrong, value)
		end),
		TextSize = 10,
		FontFace = FileController.Get("font", "semi_bold"),
		AutoButtonColor = false,
		Active = false,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
		[React.Event.MouseButton1Click] = props.OnClick,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIStroke = e("UIStroke", {
			Color = selectedBind:map(function(value: number)
				return fieldStroke:Lerp(fieldStrokeActive, value)
			end),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

local function FormField(props: FormFieldProps): React.Element<any>
	local field = props.Field
	local focused, setFocused = useState(false)
	local fieldBackground = useAt(elementColors.fieldBackground)
	local fieldBackgroundActive = useAt(elementColors.fieldBackgroundActive)
	local fieldStroke = useAt(elementColors.fieldStroke)
	local fieldStrokeActive = useAt(elementColors.fieldStrokeActive)
	local textColor = useAt(elementColors.textActive)
	local captionColor = useAt(elementColors.caption)
	local focusBind, focusSpring = useSpring(focused and 1 or 0, SPRING.quick)
	useEffect(function()
		focusSpring:setGoal(focused and 1 or 0)
	end, { focused })

	local control: React.Element<any>
	if field.kind == "select" then
		local options = {}
		local fieldOptions = field.options or {}
		for index, option in next, fieldOptions do
			options[`Option_{option}`] = e(SelectOption, {
				Text = option,
				Selected = props.Value == option,
				WidthScale = 1 / #fieldOptions,
				OnClick = function()
					props.OnChange(option)
				end,
				LayoutOrder = index,
			})
		end
		control = e(
			"Frame",
			{
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -92, 0, 16),
				LayoutOrder = 2,
			},
			Sift.Dictionary.join({
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
			}, options)
		)
	else
		control = e("TextBox", {
			BackgroundColor3 = focusBind:map(function(value: number)
				return fieldBackground:Lerp(fieldBackgroundActive, value)
			end),
			BorderSizePixel = 0,
			BackgroundTransparency = focusBind:map(function(value: number)
				return 0.18 * (1 - value)
			end),
			Size = UDim2.new(1, -92, 0, 16),
			Text = props.Value,
			PlaceholderText = field.placeholder or "",
			PlaceholderColor3 = captionColor,
			TextColor3 = textColor,
			TextSize = 10,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			LayoutOrder = 2,
			[React.Change.Text] = function(rbx: TextBox)
				props.OnChange(rbx.Text)
			end,
			[React.Event.Focused] = function()
				setFocused(true)
			end,
			[React.Event.FocusLost] = function()
				setFocused(false)
			end,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 3),
			}),
			UIStroke = e("UIStroke", {
				Color = focusBind:map(function(value: number)
					return fieldStroke:Lerp(fieldStrokeActive, value)
				end),
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
			}),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = props.LayoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(84, 16),
			Text = field.label,
			TextColor3 = captionColor,
			TextSize = 13,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 1,
		}),
		Control = control,
	})
end

type ActionButtonProps = {
	Text: string,
	Primary: boolean?,
	OnClick: () -> (),
	LayoutOrder: number,
	Width: number?,
	Height: number?,
	TextSize: number?,
	TextOffsetY: number?,
	Radius: number?,
	Subtle: boolean?,
	Danger: boolean?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

local function ActionButton(props: ActionButtonProps): React.Element<any>
	local hovering, setHovering = useState(false)
	local surface = useAt(elementColors.surface)
	local fieldBackgroundActive = useAt(elementColors.fieldBackgroundActive)
	local surfaceStroke = useAt(elementColors.surfaceStroke)
	local accent = useAt(elementColors.accent)
	local accentStrong = useAt(elementColors.accentStrong)
	local text = useAt(elementColors.text)
	local textActive = useAt(elementColors.textActive)
	local danger = useAt(themeState.colors.status.danger)
	local hoverBind, hoverSpring = useSpring(hovering and 1 or 0, SPRING.subtle)
	useEffect(function()
		hoverSpring:setGoal(hovering and 1 or 0)
	end, { hovering })
	local buttonTextColor = hoverBind:map(function(value: number)
		if props.Danger then
			return text:Lerp(danger, 0.55 + value * 0.45)
		end
		return props.Primary and textActive or text:Lerp(textActive, value)
	end)

	return e("TextButton", {
		BackgroundColor3 = hoverBind:map(function(value: number)
			if props.Danger then
				return surface:Lerp(danger, value * 0.16)
			end
			if props.Primary then
				return accent:Lerp(accentStrong, value * 0.18)
			end
			return surface:Lerp(fieldBackgroundActive, value)
		end),
		BackgroundTransparency = hoverBind:map(function(value: number)
			return props.Subtle and (0.35 - value * 0.2) or 0
		end),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(props.Width or 68, props.Height or 24),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Text = props.TextOffsetY and "" or props.Text,
		TextColor3 = buttonTextColor,
		TextSize = props.TextSize or 12,
		FontFace = FileController.Get("font", "semi_bold"),
		AutoButtonColor = false,
		Active = false,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
		[React.Event.MouseButton1Click] = props.OnClick,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, props.Radius or 4),
		}),
		UIStroke = e("UIStroke", {
			Color = hoverBind:map(function(value: number)
				if props.Danger then
					return surfaceStroke:Lerp(danger, 0.35 + value * 0.65)
				end
				return props.Primary and accentStrong or surfaceStroke:Lerp(accentStrong, value * 0.45)
			end),
			Thickness = 1,
			Transparency = props.Subtle and 0.25 or 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Label = props.TextOffsetY and e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, props.TextOffsetY),
			Size = UDim2.fromScale(1, 1),
			Text = props.Text,
			TextColor3 = buttonTextColor,
			TextSize = props.TextSize or 12,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}) or nil,
	})
end

local function DeleteButton(props: { Show: boolean, OnClick: () -> () }): React.Element<any>?
	local hidden, setHidden = useState(not props.Show)
	local confirming, setConfirming = useState(false)
	local showBind, showSpring = useSpring(props.Show and 1 or 0, SPRING.smooth)

	useEffect(function()
		if props.Show then
			setHidden(false)
			showSpring:setGoal(1)
			return
		end
		setConfirming(false)
		showSpring:setGoal(0)
		local handle = task.delay(0.2, function()
			setHidden(true)
		end)
		return function()
			task.cancel(handle)
		end
	end, { props.Show })

	useEffect(function()
		if not confirming then
			return
		end
		local handle = task.delay(2.5, function()
			setConfirming(false)
		end)
		return function()
			task.cancel(handle)
		end
	end, { confirming })

	if hidden then
		return nil
	end

	return e("CanvasGroup", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -42, 0.5, 0),
		Size = UDim2.fromOffset(50, 20),
		GroupTransparency = showBind:map(function(value: number)
			return 1 - value
		end),
	}, {
		Action = e(ActionButton, {
			Text = confirming and "Confirm" or "Delete",
			Width = 48,
			Height = 18,
			TextSize = 12,
			TextOffsetY = 0,
			Radius = 3,
			Subtle = not confirming,
			Danger = true,
			Position = UDim2.fromOffset(1, 1),
			OnClick = function()
				if confirming then
					props.OnClick()
				else
					setConfirming(true)
				end
			end,
			LayoutOrder = 1,
		}),
	})
end

local function FormButton(props: { Field: any, LayoutOrder: number, OnClick: () -> () }): React.Element<any>
	local captionColor = useAt(elementColors.caption)
	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = props.LayoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(84, 16),
			Text = props.Field.label,
			TextColor3 = captionColor,
			TextSize = 13,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 1,
		}),
		Button = e(ActionButton, {
			Text = props.Field.buttonText or "Open",
			Width = 110,
			Height = 20,
			TextSize = 12,
			Primary = props.Field.primary == true,
			OnClick = props.OnClick,
			LayoutOrder = 2,
		}),
	})
end

local function CreatorPanel(props: {
	Source: any,
	EditName: string?,
	OnCancel: () -> (),
	OnCreated: () -> (),
	CollapsedHeight: number,
}): React.Element<any>
	local creator = props.Source:GetCreator()
	local editName = props.EditName
	local initial: { [string]: string }
	if editName and type(props.Source.GetEditValues) == "function" then
		initial = props.Source:GetEditValues(editName) or { name = editName }
		for _, field in next, creator.fields do
			if initial[field.key] == nil then
				initial[field.key] = field.default or ""
			end
		end
	else
		initial = { name = "" }
		for _, field in next, creator.fields do
			initial[field.key] = field.default or ""
		end
	end
	local values, setValues = useState(initial)
	local errorText, setErrorText = useState(nil :: string?)
	local closing, setClosing = useState(false)
	local closingRef = useRef(false)
	local contentRef = useRef(nil :: GuiObject?)

	local captionColor = useAt(elementColors.caption)
	local panelColor = useAt(elementColors.panel)
	local panelStroke = useAt(elementColors.panelStroke)
	local dangerColor = useAt(themeState.colors.status.danger)
	local titleColor = useAt(subwindowColors.title)
	local enterBind, enterSpring = useSpring(0, SPRING.smooth)
	local heightBind, heightSpring = useSpring(props.CollapsedHeight, SPRING.smooth)
	useEffect(function()
		enterSpring:setGoal(1)
	end, {})
	useEffect(function()
		local content = contentRef.current
		if not content then
			return
		end
		local function update(): ()
			if not closingRef.current and content.AbsoluteSize.Y > 0 then
				local scale = Charm.peek(dpiState.scale)
				heightSpring:setGoal(content.AbsoluteSize.Y / math.max(scale, 0.01))
			end
		end
		update()
		local connection = content:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
		return function()
			connection:Disconnect()
		end
	end, {})

	local function close(callback: () -> ()): ()
		if closing then
			return
		end
		closingRef.current = true
		setClosing(true)
		enterSpring:setGoal(0)
		heightSpring:setGoal(props.CollapsedHeight)
		callback()
	end

	local function setValue(key: string, value: string): ()
		local nextValues = table.clone(values)
		nextValues[key] = value
		setValues(nextValues)
		if errorText then
			setErrorText(nil)
		end
	end

	local fields: { [string]: React.Element<any> } = {}
	fields.Name = e(FormField, {
		Field = { label = "Name", placeholder = "My custom asset" },
		Value = values.name,
		OnChange = function(value: string)
			setValue("name", value)
		end,
		LayoutOrder = 1,
	})
	for index, field in next, creator.fields do
		if field.visibleWhen and not field.visibleWhen(values) then
			continue
		end
		if field.kind == "button" then
			fields[`Field_{field.key}`] = e(FormButton, {
				Field = field,
				LayoutOrder = index + 1,
				OnClick = function()
					if field.onClick then
						field.onClick(props.Source, values)
					end
				end,
			})
		else
			fields[`Field_{field.key}`] = e(FormField, {
				Field = field,
				Value = values[field.key] or "",
				OnChange = function(value: string)
					setValue(field.key, value)
				end,
				LayoutOrder = index + 1,
			})
		end
	end

	return e("CanvasGroup", {
		BackgroundColor3 = panelColor,
		BorderSizePixel = 0,
		Size = heightBind:map(function(value: number)
			return UDim2.new(1, 0, 0, math.floor(value + 0.5))
		end),
		AutomaticSize = Enum.AutomaticSize.None,
		LayoutOrder = 2,
		GroupTransparency = enterBind:map(function(value: number)
			return 1 - value
		end),
		Position = enterBind:map(function(value: number)
			return UDim2.fromOffset(0, math.floor((1 - value) * -6))
		end),
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 5),
		}),
		UIStroke = e("UIStroke", {
			Color = panelStroke,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Content = e("Frame", {
			ref = contentRef,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			}),
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			Header = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 0,
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				Heading = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 17),
					Text = editName and "Edit asset" or (creator.title or "New asset"),
					TextColor3 = titleColor,
					TextSize = 15,
					FontFace = FileController.Get("font", "semi_bold"),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					LayoutOrder = 0,
				}),
				Description = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Text = creator.description or "",
					TextColor3 = captionColor,
					TextSize = 12,
					FontFace = FileController.Get("font", "semi_bold"),
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					LayoutOrder = 1,
				}),
			}),
			Fields = e(
				"Frame",
				{
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 1,
				},
				Sift.Dictionary.join({
					UIListLayout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Top,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 5),
					}),
				}, fields)
			),
			Error = errorText and e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 14),
				Text = errorText,
				TextColor3 = dangerColor,
				TextSize = 12,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = 2,
			}) or nil,
			Footer = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 25),
				LayoutOrder = 3,
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				Cancel = e(ActionButton, {
					Text = "Cancel",
					Width = 64,
					Height = 22,
					TextSize = 12,
					OnClick = function()
						close(props.OnCancel)
					end,
					LayoutOrder = 1,
				}),
				Create = e(ActionButton, {
					Text = editName and "Save" or "Create",
					Width = 64,
					Height = 22,
					TextSize = 12,
					Primary = true,
					OnClick = function()
						local ok, message = props.Source:CreateAsset(values.name, values, editName)
						if ok then
							close(props.OnCreated)
						else
							setErrorText(message)
						end
					end,
					LayoutOrder = 2,
				}),
			}),
		}),
	})
end

return function(properties: { AssetPicker: any }): React.Element<any>
	local picker = properties.AssetPicker

	local source = useAt(picker._source)
	local title = useAt(picker._title)
	local creating, setCreating = useState(false)
	local editingName, setEditingName = useState(nil :: string?)
	local opening, setOpening = useState(false)
	local creatorExpanded, setCreatorExpanded = useState(false)
	local titleWidth, setTitleWidth = useState(0)
	local baseWidth = source and source._config.width or WIDTH
	local widthBind, widthSpring = useSpring(baseWidth, SPRING.smooth)
	local libraryBind, librarySpring = useSpring(1, SPRING.smooth)

	local backgroundColor = useAt(subwindowColors.background)
	local dividerColor = useAt(subwindowColors.divider)
	local strokeColor = useAt(subwindowColors.stroke)
	local titleColor = useAt(subwindowColors.title)
	local mutedColor = useAt(themeState.colors.hud.textMuted)
	local scrollThumbColor = useAt(elementColors.icon)

	local sourceDeps = { source :: any }
	local assets = useAt(source and source._assetNames or EMPTY_ASSETS, sourceDeps)
	local assignments = useAt(source and source._state or EMPTY_ASSIGNMENTS, sourceDeps)
	local removingAssets = useAt(source and source._removingAssets or EMPTY_REMOVING, sourceDeps)
	local focusedAsset = useAt(source and source._focusedAsset or EMPTY_FOCUSED, sourceDeps)

	local anim = useSubwindowAnimation(picker, {
		slideOffset = 14,
		floatingId = "subwindow.assetPicker",
		floatingPriority = floatingController.PRIORITY.MENU,
		onClickOutside = function()
			picker:Close()
		end,
	})

	local assignmentTypes: { AssignmentType } = source and source._assignmentTypes or EMPTY_TYPES
	local creator = source and source:GetCreator() or nil

	useEffect(function()
		setCreating(false)
		setEditingName(nil)
		setOpening(false)
		setCreatorExpanded(false)
		librarySpring:setGoal(1)
	end, { source })
	useEffect(function()
		if anim.isOpen then
			return
		end
		local handle = task.delay(0.35, function()
			setCreating(false)
			setEditingName(nil)
			setOpening(false)
			setCreatorExpanded(false)
			widthSpring:setPosition(baseWidth)
			widthSpring:setGoal(baseWidth)
			librarySpring:setPosition(1)
			librarySpring:setGoal(1)
		end)
		return function()
			task.cancel(handle)
		end
	end, { anim.isOpen, baseWidth } :: { any })

	local function closeCreator(): ()
		setCreatorExpanded(false)
		task.delay(0.28, function()
			setCreating(false)
			setEditingName(nil)
			librarySpring:setGoal(1)
		end)
	end
	local function openCreator(edit: string?): ()
		setEditingName(edit)
		setOpening(true)
		librarySpring:setGoal(0)
		task.delay(0.14, function()
			setCreating(true)
			setCreatorExpanded(true)
			setOpening(false)
		end)
	end
	local isSingleSelect = false
	if source and type(source.IsSingleSelect) == "function" then
		isSingleSelect = source:IsSingleSelect()
	end
	local selectedName: string? = nil
	if isSingleSelect and source then
		selectedName = source:GetSelected()
	end
	local deleteCandidate = selectedName or focusedAsset
	local canDeleteSelected = creator ~= nil
		and deleteCandidate ~= nil
		and source ~= nil
		and source:IsCustomAsset(deleteCandidate)

	local canEditSelected = source ~= nil
		and type(source.CanEditAsset) == "function"
		and deleteCandidate ~= nil
		and source:CanEditAsset(deleteCandidate)

	local buttonReserve = 0
	if creator then
		if canEditSelected then
			buttonReserve = 150
		elseif canDeleteSelected then
			buttonReserve = 104
		else
			buttonReserve = 50
		end
	end
	local contentWidth = math.max(baseWidth, PADDING * 2 + titleWidth + buttonReserve)
	local creatorGoalWidth = contentWidth + CREATOR_EXTRA
	useEffect(function()
		widthSpring:setGoal(creatorExpanded and creatorGoalWidth or contentWidth)
	end, { creatorExpanded, contentWidth, creatorGoalWidth } :: { any })

	local configuredGroups: { { layoutOrder: number, key: string, label: string, extras: { any } } } = {}
	if source then
		for index, assignType in next, assignmentTypes do
			local extras = source:GetExtras(assignType.key)
			if not extras or #extras == 0 then
				continue
			end
			table.insert(configuredGroups, {
				layoutOrder = index,
				key = assignType.key,
				label = assignType.label,
				extras = extras,
			})
		end
	end

	local liveHasAssignment = false
	for _, group in next, configuredGroups do
		if assignments[group.key] then
			liveHasAssignment = true
			break
		end
	end

	local retainExtras, setRetainExtras = useState(liveHasAssignment)

	useEffect(function()
		if liveHasAssignment then
			setRetainExtras(true)
			return
		end
		local handle = task.delay(0.5, function()
			setRetainExtras(false)
		end)
		return function()
			task.cancel(handle)
		end
	end, { liveHasAssignment })

	local dividerBind, dividerSpring = useSpring(liveHasAssignment and 1 or 0, SPRING.smoothPrecise)
	useEffect(function()
		dividerSpring:setGoal(liveHasAssignment and 1 or 0)
	end, { liveHasAssignment })

	local sectionVisible = retainExtras or liveHasAssignment

	local renderedRows = useMemo(function(): { [string]: React.Element<any> }
		local sorted = table.clone(assets)
		table.sort(sorted, function(a: string, b: string): boolean
			if #a ~= #b then
				return #a > #b
			end
			return a < b
		end)

		local rows: { [string]: React.Element<any> } = {}
		for index, name in next, sorted do
			rows[`Row_{index}_{name}`] = e(AssetRow, {
				Name = name,
				Source = source,
				AssignmentTypes = assignmentTypes,
				Assignments = assignments,
				Selected = isSingleSelect and selectedName == name,
				SingleSelect = isSingleSelect,
				Removing = removingAssets[name] == true,
				SlotGap = index < #sorted and ROW_GAP or 0,
				LayoutOrder = index,
			})
		end
		return rows
	end, { assets, source, assignmentTypes, assignments, removingAssets, isSingleSelect, selectedName } :: { any })

	local listScrollRef, listContentRef, _listNeedsBar, listGradient = useScrollFade()

	local listContentHeight = 2 + #assets * ROW_SLOT_HEIGHT + math.max(0, #assets - 1) * ROW_GAP
	local listHeight = math.min(MAX_LIST_HEIGHT, math.max(ROW_SLOT_HEIGHT, listContentHeight))
	local removingCount = 0
	for name, isRemoving in next, removingAssets do
		if isRemoving and table.find(assets, name) then
			removingCount += 1
		end
	end
	local remainingCount = math.max(0, #assets - removingCount)
	local targetContentHeight = 2 + remainingCount * ROW_SLOT_HEIGHT + math.max(0, remainingCount - 1) * ROW_GAP
	local targetListHeight = math.min(MAX_LIST_HEIGHT, math.max(ROW_SLOT_HEIGHT, targetContentHeight))
	local listHeightBind, listHeightSpring = useSpring(listHeight, SPRING.smooth)
	useEffect(function()
		listHeightSpring:setGoal(targetListHeight)
	end, { targetListHeight })
	useEffect(function()
		listHeightSpring:setPosition(targetListHeight)
		listHeightSpring:setGoal(targetListHeight)
	end, { source })
	local hasListOverflow = targetContentHeight > MAX_LIST_HEIGHT
	if #assets == 0 then
		listHeight = 28
	end

	local renderedExtras: { [string]: React.Element<any> } = {}
	for _, group in next, configuredGroups do
		renderedExtras[`Group_{group.key}`] = e(ExtrasGroup, {
			GroupKey = group.key,
			Label = group.label,
			Extras = group.extras,
			LayoutOrder = group.layoutOrder,
			MutedColor = mutedColor,
			Visible = assignments[group.key] ~= nil,
		})
	end

	return e("Frame", {
		ref = anim.frameRef,
		BackgroundTransparency = 1,
		Size = widthBind:map(function(value: number)
			return UDim2.new(0, math.floor(value + 0.5), 0, 0)
		end),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = anim.position,
		Visible = anim.visible,
		ZIndex = anim.zIndex,
	}, {
		Shadow = useShadow({
			transparency = anim.transparency,
			zIndex = 0,
		}),
		Body = e("CanvasGroup", {
			BackgroundTransparency = 0,
			BackgroundColor3 = backgroundColor,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			GroupTransparency = anim.transparency,
			ZIndex = 1,
		}, {
			UIStroke = e("UIStroke", {
				Color = strokeColor,
				Transparency = anim.strokeTransparency,
				Thickness = 1,
			}),
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 5),
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, PADDING),
				PaddingRight = UDim.new(0, PADDING),
				PaddingTop = UDim.new(0, PADDING),
				PaddingBottom = UDim.new(0, PADDING),
			}),
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),
			Main = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 0,
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				Title = e("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
					LayoutOrder = 0,
				}, {
					Label = e("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Text = title,
						TextColor3 = titleColor,
						TextSize = 15,
						FontFace = FileController.Get("font", "semi_bold"),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Size = UDim2.new(1, creator and -buttonReserve or 0, 1, 0),
					}),
					Measure = e("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Visible = false,
						AutomaticSize = Enum.AutomaticSize.XY,
						Size = UDim2.fromOffset(0, 0),
						Text = title,
						TextSize = 15,
						FontFace = FileController.Get("font", "semi_bold"),
						TextXAlignment = Enum.TextXAlignment.Left,
						[React.Change.AbsoluteSize] = function(rbx: TextLabel)
							local scale = Charm.peek(dpiState.scale)
							setTitleWidth(rbx.AbsoluteSize.X / math.max(scale, 0.01))
						end,
					}),
					Delete = creator and e(DeleteButton, {
						Show = not creating and not opening and canDeleteSelected,
						OnClick = function()
							if source and deleteCandidate then
								source:DeleteAsset(deleteCandidate)
							end
						end,
					}) or nil,
					Edit = not creating and not opening and canEditSelected and e(ActionButton, {
						Text = source._config.editLabel or "Edit",
						Width = 40,
						Height = 18,
						TextSize = 12,
						TextOffsetY = 0,
						Radius = 3,
						Subtle = true,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -98, 0.5, 0),
						OnClick = function()
							if not (source and deleteCandidate) then
								return
							end
							if type(source.HasCustomEditor) == "function" and source:HasCustomEditor() then
								source:EditAsset(deleteCandidate)
							else
								openCreator(deleteCandidate)
							end
						end,
						LayoutOrder = 2,
					}) or nil,
					New = creator and not creating and not opening and e(ActionButton, {
						Text = "New",
						Width = 38,
						Height = 18,
						TextSize = 12,
						TextOffsetY = 0,
						Radius = 3,
						Subtle = true,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						OnClick = function()
							openCreator(nil)
						end,
						LayoutOrder = 1,
					}) or nil,
				}),
				TitleDivider = e("Frame", {
					BackgroundColor3 = dividerColor,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, DIVIDER_HEIGHT),
					LayoutOrder = 1,
				}),
				Creator = creating and source and e(CreatorPanel, {
					Source = source,
					EditName = editingName,
					CollapsedHeight = #assets > 0 and targetListHeight or 28,
					OnCancel = closeCreator,
					OnCreated = closeCreator,
				}) or nil,
				Empty = not creating and #assets == 0 and e("TextLabel", {
					BackgroundTransparency = 1,
					TextTransparency = libraryBind:map(function(value: number)
						return 1 - value
					end),
					Text = "No assets found",
					TextColor3 = mutedColor,
					TextSize = 12,
					FontFace = FileController.Get("font", "semi_bold"),
					Size = UDim2.new(1, 0, 0, 28),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
					LayoutOrder = 2,
				}) or nil,
				List = not creating and #assets > 0 and e("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = removingCount > 0 and listHeightBind:map(function(value: number)
						return UDim2.new(1, 0, 0, math.floor(value + 0.5))
					end) or UDim2.new(1, 0, 0, targetListHeight),
					LayoutOrder = 2,
					ZIndex = 1,
				}, {
					Fade = e("CanvasGroup", {
						BackgroundTransparency = 0,
						BackgroundColor3 = backgroundColor,
						BorderSizePixel = 0,
						Size = UDim2.fromScale(1, 1),
						GroupTransparency = libraryBind:map(function(value: number)
							return 1 - value
						end),
					}, {
						Gradient = listGradient,
						Scroll = e("ScrollingFrame", {
							ref = listScrollRef,
							Active = false,
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							Size = UDim2.fromScale(1, 1),
							ClipsDescendants = true,
							CanvasSize = UDim2.fromOffset(0, 0),
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
							ScrollingDirection = Enum.ScrollingDirection.Y,
							VerticalScrollBarInset = Enum.ScrollBarInset.Always,
							ScrollBarImageColor3 = scrollThumbColor,
							ScrollBarImageTransparency = hasListOverflow and 0.35 or 1,
							ScrollBarThickness = hasListOverflow and 2 or 0,
						}, {
							Inner = e(
								"Frame",
								{
									ref = listContentRef,
									BackgroundTransparency = 1,
									BorderSizePixel = 0,
									Position = UDim2.fromOffset(1, 0),
									Size = UDim2.new(1, -(hasListOverflow and 10 or 2), 0, 0),
									AutomaticSize = Enum.AutomaticSize.Y,
								},
								Sift.Dictionary.join({
									UIListLayout = e("UIListLayout", {
										FillDirection = Enum.FillDirection.Vertical,
										HorizontalAlignment = Enum.HorizontalAlignment.Left,
										VerticalAlignment = Enum.VerticalAlignment.Top,
										SortOrder = Enum.SortOrder.LayoutOrder,
										Padding = UDim.new(0, 0),
									}),
									UIPadding = e("UIPadding", {
										PaddingTop = UDim.new(0, 1),
										PaddingBottom = UDim.new(0, 1),
									}),
								}, renderedRows)
							),
						}),
					}),
				}) or nil,
			}),
			ExtrasDivider = not creating and sectionVisible and e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = dividerBind:map(function(v: number)
					return UDim2.new(1, 0, 0, math.floor(13 * v + 0.5))
				end),
				ClipsDescendants = true,
				LayoutOrder = 1,
			}, {
				Line = e("Frame", {
					BackgroundColor3 = dividerColor,
					BackgroundTransparency = dividerBind:map(function(v: number)
						return 1 - v
					end),
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, 6),
					Size = UDim2.new(1, 0, 0, DIVIDER_HEIGHT),
				}),
			}) or nil,
			Extras = not creating and sectionVisible and e(
				"Frame",
				{
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 2,
				},
				Sift.Dictionary.join({
					UIListLayout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Top,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
				}, renderedExtras)
			) or nil,
		}),
	})
end
