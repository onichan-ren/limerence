local TextService = cloneref(game:GetService("TextService")) :: TextService

local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useSubwindowAnimation = require("@ui/hook/useSubwindowAnimation")
local useShadow = require("@ui/hook/useShadow")
local SPRING = require("@ui/util/spring")
local floatingController = require("@ui/floating/floatingController")

local useSpring = ReactRipple.useSpring
local useEffect = React.useEffect
local useState = React.useState
local useRef = React.useRef
local useCallback = React.useCallback
local useMemo = React.useMemo
local useAt = ReactCharm.useAtom
local e = React.createElement
local memo = React.memo

local subwindowColors = themeState.colors.subwindow
local elementColors = themeState.colors.window.element

local ROW_HEIGHT = 22
local INDICATOR_WIDTH = 14
local MAX_VISIBLE_ROWS = 10

local ROW_TEXT_SIZE = 13
local ROW_PAD_LEFT = 8
local ROW_PAD_RIGHT = 8
local MAX_WIDTH = 240

local SEARCH_FIELD_HEIGHT = 26
local SEARCH_FIELD_MARGIN = 6
local SEARCH_FIELD_PAD = 8
local SEARCH_ICON_GAP = 6
local SEARCH_ICON_SIZE = 12

local textBoundsParams = Instance.new("GetTextBoundsParams") :: any

local function measuredLabelWidth(label: string): number
	local ok, bounds = pcall(function(): Vector2
		textBoundsParams.Text = label
		textBoundsParams.FontFace = FileController.Get("font", "semi_bold")
		textBoundsParams.Size = ROW_TEXT_SIZE
		return TextService:GetTextBoundsAsync(textBoundsParams)
	end)
	if ok and typeof(bounds) == "Vector2" then
		return bounds.X
	end
	local chars = utf8.len(label)
	return (chars or #label) * ROW_TEXT_SIZE * 0.53
end

local function computeContentWidth(options: { string }): number
	local width = 0
	for _, option in next, options do
		width = math.max(width, ROW_PAD_LEFT + INDICATOR_WIDTH + 4 + measuredLabelWidth(option) + ROW_PAD_RIGHT)
	end
	return math.clamp(math.ceil(width), 2, MAX_WIDTH)
end

local EMPTY_OPTIONS = Charm.atom({} :: { string })
local EMPTY_SELECTION = Charm.atom(nil :: any)
local EMPTY_MODE = Charm.atom("single")

type RowProps = {
	Option: string,
	Mode: string,
	IsSelected: boolean,
	OnPick: (option: string) -> (),
	LayoutOrder: number,
	FillWidth: boolean,
}

local Row = memo(function(props: RowProps): React.Element<any>
	local option = props.Option
	local mode = props.Mode
	local isSelected = props.IsSelected
	local onPick = props.OnPick

	local isHovering, setHovering = useState(false)
	local rowRef = useRef(nil :: GuiObject?)

	local textColor = useAt(subwindowColors.text)
	local rowHoverColor = useAt(elementColors.rowHover)
	local stripeColor = useAt(elementColors.accentStrong)
	local checkOnColor = useAt(elementColors.accent)
	local checkStrokeColor = useAt(elementColors.surfaceStroke)
	local checkSurfaceIdle = useAt(elementColors.panel)
	local checkKnob = useAt(elementColors.thumbHighlight)

	local hoverBind, hoverSpring = useSpring(0, SPRING.snap)
	local selectedBind, selectedSpring = useSpring(0, SPRING.smooth)

	useEffect(function()
		hoverSpring:setGoal(isHovering and 1 or 0)
	end, { isHovering })

	useEffect(function()
		selectedSpring:setGoal(isSelected and 1 or 0)
	end, { isSelected })

	local indicator: React.Element<any>?
	if mode == "multi" then
		local BOX = 12
		indicator = e("Frame", {
			BackgroundColor3 = selectedBind:map(function(value: number)
				return checkSurfaceIdle:Lerp(checkOnColor, value)
			end),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(BOX, BOX),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 3),
			}),
			UIStroke = e("UIStroke", {
				Color = selectedBind:map(function(value: number)
					return checkStrokeColor:Lerp(stripeColor, value)
				end),
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			UIScale = e("UIScale", {
				Scale = 1,
			}),
			Mark = e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = FileController.Get("image", "checkmark"),
				ImageColor3 = checkKnob,
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset(8, 8),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ImageTransparency = selectedBind:map(function(value: number)
					return 1 - value * value
				end),
			}),
		})
	elseif isSelected then
		indicator = e("Frame", {
			BackgroundColor3 = stripeColor,
			BorderSizePixel = 0,
			BackgroundTransparency = selectedBind:map(function(value: number)
				return 1 - value
			end),
			Size = UDim2.new(0, 2, 1, -8),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		})
	end

	return e("TextButton", {
		ref = rowRef,
		BackgroundColor3 = rowHoverColor,
		BackgroundTransparency = hoverBind:map(function(value: number)
			return 1 - (value * 0.04)
		end),
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		AutomaticSize = props.FillWidth and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		Size = props.FillWidth and UDim2.new(1, 0, 0, ROW_HEIGHT) or UDim2.new(0, 0, 0, ROW_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
		[React.Event.MouseButton1Click] = function()
			onPick(option)
		end,
	}, {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, ROW_PAD_LEFT),
			PaddingRight = UDim.new(0, ROW_PAD_RIGHT),
			PaddingTop = UDim.new(0, 0),
			PaddingBottom = UDim.new(0, 0),
		}),
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		UIFlexItem = e("UIFlexItem", {
			ItemLineAlignment = Enum.ItemLineAlignment.Stretch,
		}),
		Indicator = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, INDICATOR_WIDTH, 1, 0),
			LayoutOrder = 0,
		}, {
			Inner = indicator,
		}),
		Text = e("TextLabel", {
			BackgroundTransparency = 1,
			TextColor3 = textColor,
			TextSize = 13,
			Text = option,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			FontFace = FileController.Get("font", "semi_bold"),
			LayoutOrder = 1,
		}),
	})
end)

type SearchBarProps = {
	Query: string,
	OnChange: (query: string) -> (),
}

local SearchBar = memo(function(props: SearchBarProps): React.Element<any>
	local query = props.Query
	local onChange = props.OnChange

	local focused, setFocused = useState(false)

	local fieldColor = useAt(elementColors.panel)
	local idleStroke = useAt(elementColors.surfaceStroke)
	local accentColor = useAt(elementColors.accent)
	local textColor = useAt(subwindowColors.text)
	local imageColor = useAt(subwindowColors.image)

	local focusBind, focusSpring = useSpring(0, SPRING.snap)

	useEffect(function()
		focusSpring:setGoal(focused and 1 or 0)
	end, { focused })

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, SEARCH_FIELD_HEIGHT),
		LayoutOrder = 0,
	}, {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, SEARCH_FIELD_MARGIN),
			PaddingRight = UDim.new(0, SEARCH_FIELD_MARGIN),
		}),
		Field = e("Frame", {
			BackgroundColor3 = fieldColor,
			BackgroundTransparency = focusBind:map(function(value: number): number
				return 0.55 - value * 0.2
			end),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
				Color = focusBind:map(function(value: number): Color3
					return idleStroke:Lerp(accentColor, value)
				end),
				Transparency = focusBind:map(function(value: number): number
					return 0.5 - value * 0.5
				end),
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, SEARCH_FIELD_PAD),
				PaddingRight = UDim.new(0, SEARCH_FIELD_PAD),
			}),
			UIListLayout = e("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, SEARCH_ICON_GAP),
			}),
			SearchIcon = e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(SEARCH_ICON_SIZE, SEARCH_ICON_SIZE),
				Image = FileController.Get("image", "search"),
				ImageColor3 = focusBind:map(function(value: number): Color3
					return imageColor:Lerp(accentColor, value)
				end),
				LayoutOrder = 1,
			}),
			SearchInput = e("TextBox", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = "Search...",
				PlaceholderColor3 = imageColor,
				TextColor3 = textColor,
				TextSize = ROW_TEXT_SIZE,
				Text = query,
				FontFace = FileController.Get("font", "light"),
				AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.new(1, -(SEARCH_ICON_SIZE + SEARCH_ICON_GAP), 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 2,
				[React.Event.Focused] = function(): ()
					setFocused(true)
				end,
				[React.Event.FocusLost] = function(): ()
					setFocused(false)
				end,
				[React.Change.Text] = function(rbx: TextBox): ()
					onChange(rbx.Text)
				end,
			}),
		}),
	})
end)

type NoResultsProps = {
	Visible: boolean,
}

local NoResults = memo(function(props: NoResultsProps): React.Element<any>
	local visible = props.Visible

	local textColor = useAt(subwindowColors.image)
	local fadeBind, fadeSpring = useSpring(0, SPRING.snap)

	useEffect(function()
		fadeSpring:setGoal(visible and 1 or 0)
	end, { visible })

	return e("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, -16, 0, 16),
		Text = "No search results",
		TextColor3 = textColor,
		TextSize = ROW_TEXT_SIZE,
		FontFace = FileController.Get("font", "light"),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTransparency = fadeBind:map(function(value: number): number
			return 1 - value
		end),
		ZIndex = 5,
	})
end)

return function(properties: { Dropdown: any }): React.Element<any>
	local dropdownWindow = properties.Dropdown

	local source = useAt(dropdownWindow._source)

	local backgroundColor = useAt(subwindowColors.background)
	local strokeColor = useAt(subwindowColors.stroke)

	local sourceDeps = { source :: any }
	local options = useAt(source and source._options or EMPTY_OPTIONS, sourceDeps)
	local selection = useAt(source and source._state or EMPTY_SELECTION, sourceDeps)
	local mode = useAt(source and source._mode or EMPTY_MODE, sourceDeps)

	local searchable = #options > MAX_VISIBLE_ROWS
	local query, setQuery = useState("")

	useEffect(function()
		setQuery("")
	end, { source, options } :: { any })

	local contentWidth = useMemo(function(): number
		return computeContentWidth(options)
	end, { options } :: { any })

	local anim = useSubwindowAnimation(dropdownWindow, {
		preset = SPRING.snap,
		slideOffset = 0,
		strokeIntensity = 0.6,
		floatingId = "subwindow.dropdown",
		floatingPriority = floatingController.PRIORITY.DROPDOWN,
		onClickOutside = function()
			dropdownWindow:Close()
		end,
	})

	local function isOptionSelected(option: string): boolean
		if mode == "multi" then
			if type(selection) ~= "table" then
				return false
			end
			for _, v in selection :: { string } do
				if v == option then
					return true
				end
			end
			return false
		end
		return selection == option
	end

	local pickOption = useCallback(function(option: string): ()
		if not source then
			return
		end
		source:Toggle(option)
	end, { source } :: { any })

	local selectionKey = type(selection) == "table" and table.concat(selection :: { string }, "\0") or tostring(selection)

	local loweredQuery = string.lower(query)

	local renderedRows = useMemo(function(): { [string]: React.Element<any> }
		local built: { [string]: React.Element<any> } = {}
		for index, option in options do
			if loweredQuery ~= "" and not string.find(string.lower(option), loweredQuery, 1, true) then
				continue
			end
			built[`Row_{index}_{option}`] = e(Row, {
				Option = option,
				Mode = mode,
				IsSelected = isOptionSelected(option),
				OnPick = pickOption,
				LayoutOrder = index,
				FillWidth = searchable,
			})
		end
		return built
	end, { options, mode, selectionKey, pickOption, loweredQuery, searchable } :: { any })

	local showNoResults = searchable and next(renderedRows) == nil

	local listChildren = Sift.Dictionary.join({
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		}),
	}, renderedRows)

	local rowsContainer: React.Element<any>
	if searchable then
		rowsContainer = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, MAX_VISIBLE_ROWS * ROW_HEIGHT),
			LayoutOrder = 2,
		}, {
			Scroll = e("ScrollingFrame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, 0),
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = strokeColor,
				ScrollBarImageTransparency = 0.2,
				ZIndex = 1,
			}, {
				List = e("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 0),
				}, listChildren),
			}),
			NoResults = e(NoResults, {
				Visible = showNoResults,
			}),
		})
	else
		rowsContainer = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
		}, listChildren)
	end

	local searchBar = searchable and e(SearchBar, {
		Query = query,
		OnChange = setQuery,
	}) or nil

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
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
			BackgroundTransparency = 0,
			BackgroundColor3 = backgroundColor,
			Size = searchable and UDim2.fromOffset(contentWidth, 0) or UDim2.new(0, 0, 0, 0),
			AutomaticSize = searchable and Enum.AutomaticSize.Y or Enum.AutomaticSize.XY,
			GroupTransparency = anim.transparency,
			ZIndex = 1,
		}, {
			UIStroke = e("UIStroke", {
				Color = strokeColor,
				Transparency = anim.strokeTransparency,
				Thickness = 1,
			}),
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 0),
				PaddingRight = UDim.new(0, 0),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}),
			UIListLayout = e("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			UISizeConstraint = e("UISizeConstraint", {
				MinSize = searchable and Vector2.new(contentWidth, 0) or Vector2.new(0, 0),
				MaxSize = searchable and Vector2.new(contentWidth, math.huge) or Vector2.new(MAX_WIDTH, math.huge),
			}),
			SearchBar = searchBar,
			Rows = rowsContainer,
		}),
	})
end
