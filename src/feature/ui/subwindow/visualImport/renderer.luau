local Charm = require("@pkg/Charm")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local themeState = require("@ui/theme/themeState")
local FileController = require("@src/feature/file/FileController")
local useAdvColor = require("@ui/hook/useAdvColor")
local useSubwindowAnimation = require("@ui/hook/useSubwindowAnimation")
local useShadow = require("@ui/hook/useShadow")
local useDraggable = require("@ui/hook/useDraggable")
local SPRING = require("@ui/util/spring")
local floatingController = require("@ui/floating/floatingController")

local subwindowColors = themeState.colors.subwindow
local elementColors = themeState.colors.window.element

local useEffect = React.useEffect
local useMemo = React.useMemo
local useState = React.useState
local useCallback = React.useCallback
local useBinding = React.useBinding
local useRef = React.useRef
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local e = React.createElement
local memo = React.memo

local WIDTH = 360
local PADDING_X = 15
local PADDING_TOP = 11
local PADDING_BOTTOM = 13
local SECTION_GAP = 12
local DIVIDER_GAP = 9
local CAPTION_GAP = 6
local TITLE_HEIGHT = 15
local SUBTITLE_HEIGHT = 12
local CAPTION_HEIGHT = 13
local TAB_HEIGHT = 24
local PILL_HEIGHT = 24
local ROW_HEIGHT = 22
local INDICATOR_WIDTH = 4
local FOOTER_HEIGHT = 26
local MIN_ROWS = 2
local MAX_ROWS = 5

type GameTabProps = {
	Label: string,
	Id: string,
	IsActive: boolean,
	OnClick: (id: string) -> (),
	LayoutOrder: number,
}

local GameTab = memo(function(props: GameTabProps): React.Element<any>
	local isHovering, setHovering = useState(false)
	local surfaceColor = useAt(elementColors.surface)
	local accentSoftColor = useAt(elementColors.accentSoft)
	local surfaceStrokeColor = useAt(elementColors.surfaceStroke)
	local accentStrokeColor = useAt(elementColors.fieldStrokeActive)
	local textColor = useAt(elementColors.text)
	local activeTextColor = useAt(elementColors.captionActive)
	local rowHoverColor = useAt(elementColors.rowHover)

	local activeBind, activeSpring = useSpring(props.IsActive and 1 or 0, SPRING.smooth)
	local hoverBind, hoverSpring = useSpring(0, SPRING.snap)

	useEffect(function()
		activeSpring:setGoal(props.IsActive and 1 or 0)
	end, { props.IsActive })

	useEffect(function()
		hoverSpring:setGoal(isHovering and 1 or 0)
	end, { isHovering })

	return e("TextButton", {
		BackgroundColor3 = React.joinBindings({ activeBind, hoverBind }):map(function(values: { number })
			return surfaceColor:Lerp(accentSoftColor, values[1]):Lerp(rowHoverColor, values[2] * 0.03)
		end),
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, TAB_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
		[React.Event.MouseButton1Click] = function()
			props.OnClick(props.Id)
		end,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIStroke = e("UIStroke", {
			Color = activeBind:map(function(value: number)
				return surfaceStrokeColor:Lerp(accentStrokeColor, value)
			end),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Text = props.Label,
			TextColor3 = activeBind:map(function(value: number)
				return textColor:Lerp(activeTextColor, value)
			end),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			FontFace = FileController.Get("font", "semi_bold"),
		}),
	})
end)

type TogglePillProps = {
	Label: string,
	Id: string,
	IsActive: boolean,
	OnClick: (id: string) -> (),
	LayoutOrder: number,
}

local TogglePill = memo(function(props: TogglePillProps): React.Element<any>
	local isHovering, setHovering = useState(false)
	local surfaceColor = useAt(elementColors.surface)
	local accentSoftColor = useAt(elementColors.accentSoft)
	local surfaceStrokeColor = useAt(elementColors.surfaceStroke)
	local accentStrokeColor = useAt(elementColors.fieldStrokeActive)
	local textColor = useAt(elementColors.caption)
	local activeTextColor = useAt(elementColors.captionActive)
	local accentColor = useAt(elementColors.accent)
	local rowHoverColor = useAt(elementColors.rowHover)

	local activeBind, activeSpring = useSpring(props.IsActive and 1 or 0, SPRING.smooth)
	local hoverBind, hoverSpring = useSpring(0, SPRING.snap)

	useEffect(function()
		activeSpring:setGoal(props.IsActive and 1 or 0)
	end, { props.IsActive })

	useEffect(function()
		hoverSpring:setGoal(isHovering and 1 or 0)
	end, { isHovering })

	return e("TextButton", {
		BackgroundColor3 = React.joinBindings({ activeBind, hoverBind }):map(function(values: { number })
			return surfaceColor:Lerp(accentSoftColor, values[1]):Lerp(rowHoverColor, values[2] * 0.03)
		end),
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, PILL_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
		[React.Event.MouseButton1Click] = function()
			props.OnClick(props.Id)
		end,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		UIStroke = e("UIStroke", {
			Color = activeBind:map(function(value: number)
				return surfaceStrokeColor:Lerp(accentStrokeColor, value)
			end),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 9),
			PaddingRight = UDim.new(0, 9),
		}),
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 5),
		}),
		Check = e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = FileController.Get("image", "checkmark"),
			ImageColor3 = accentColor,
			ImageTransparency = activeBind:map(function(value: number)
				return 1 - value
			end),
			Size = activeBind:map(function(value: number)
				local size = math.floor(8 * value + 0.5)
				return UDim2.fromOffset(size, 8)
			end),
			LayoutOrder = 1,
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Text = props.Label,
			TextColor3 = activeBind:map(function(value: number)
				return textColor:Lerp(activeTextColor, value)
			end),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			FontFace = FileController.Get("font", "semi_bold"),
			LayoutOrder = 2,
		}),
	})
end)

type ConfigRowProps = {
	Label: string,
	Id: string,
	IsActive: boolean,
	OnSelect: (id: string) -> (),
	LayoutOrder: number,
}

local ConfigRow = memo(function(props: ConfigRowProps): React.Element<any>
	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		activeAtom(props.IsActive)
	end, { props.IsActive })

	local textColor = useAdvColor(elementColors.caption, elementColors.textActive, activeAtom)
	local stripeColor = useAt(elementColors.accentStrong)
	local rowHoverColor = useAt(elementColors.rowHover)

	local isHovering, setHovering = useState(false)
	local hoverBind, hoverSpring = useSpring(0, SPRING.snap)
	local selectedBind, selectedSpring = useSpring(0, SPRING.smoothPreciser)

	useEffect(function()
		hoverSpring:setGoal(isHovering and 1 or 0)
	end, { isHovering })

	useEffect(function()
		selectedSpring:setGoal(props.IsActive and 1 or 0)
	end, { props.IsActive })

	return e("TextButton", {
		BackgroundColor3 = rowHoverColor,
		BackgroundTransparency = React.joinBindings({ hoverBind, selectedBind }):map(function(values: { number })
			return 1 - (values[1] * 0.10 + values[2] * 0.08)
		end),
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
			textColor.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
			textColor.onMouseLeave()
		end,
		[React.Event.MouseButton1Click] = function()
			props.OnSelect(props.Id)
		end,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 6),
		}),
		Indicator = e("Frame", {
			BackgroundColor3 = stripeColor,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = selectedBind:map(function(value: number)
				return UDim2.new(0, INDICATOR_WIDTH, 0, math.floor(4 + value * 8))
			end),
			BackgroundTransparency = selectedBind:map(function(value: number)
				return 1 - value
			end),
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
		Text = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = textColor.binding,
			TextSize = 12,
			Text = props.Label,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(INDICATOR_WIDTH + 6, 0),
			Size = UDim2.new(1, -(INDICATOR_WIDTH + 6), 1, 0),
		}),
	})
end)

type FooterButtonProps = {
	Text: string,
	Variant: "primary" | "secondary",
	Disabled: boolean?,
	LayoutOrder: number,
	OnClick: () -> (),
}

local function FooterButton(props: FooterButtonProps): React.Element<any>
	local activeAtom = useMemo(function()
		return Charm.atom(props.Variant == "primary")
	end, {})

	useEffect(function()
		activeAtom(props.Variant == "primary" and not props.Disabled)
	end, { props.Disabled })

	local backgroundColor = useAdvColor(elementColors.surface, elementColors.accentStrong, activeAtom, true)
	local strokeColor = useAt(elementColors.surfaceStroke)
	local textColor = useAdvColor(elementColors.text, elementColors.textActive, activeAtom)

	local disabledBind, disabledSpring = useSpring(props.Disabled and 1 or 0, SPRING.smooth)
	useEffect(function()
		disabledSpring:setGoal(props.Disabled and 1 or 0)
	end, { props.Disabled })

	return e("TextButton", {
		BackgroundColor3 = backgroundColor.binding,
		BackgroundTransparency = disabledBind:map(function(value: number)
			return value * 0.4
		end),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.new(0, 78, 0, FOOTER_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			if props.Disabled then
				return
			end
			backgroundColor.onMouseEnter()
			textColor.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			backgroundColor.onMouseLeave()
			textColor.onMouseLeave()
		end,
		[React.Event.MouseButton1Click] = function()
			if props.Disabled then
				return
			end
			props.OnClick()
		end,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 5),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = props.Text,
			TextColor3 = textColor.binding,
			TextTransparency = disabledBind:map(function(value: number)
				return value * 0.35
			end),
			TextSize = 13,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

type SectionProps = {
	Caption: string,
	LayoutOrder: number,
	ContentSize: any?,
	children: any,
}

local function Section(props: SectionProps): React.Element<any>
	local captionColor = useAt(elementColors.caption)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = props.LayoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, CAPTION_GAP),
		}),
		Caption = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, CAPTION_HEIGHT),
			Text = props.Caption,
			TextColor3 = captionColor,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			FontFace = FileController.Get("font", "semi_bold"),
			LayoutOrder = 1,
		}),
		Content = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = props.ContentSize == nil and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
			Size = props.ContentSize or UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
		}, props.children),
	})
end

return function(properties: { Importer: any }): React.Element<any>
	local importer = properties.Importer

	local games = useAt(importer._games)
	local categories = useAt(importer._categories)
	local selectedGame = useAt(importer._selectedGame)
	local selectedConfig = useAt(importer._selectedConfig)
	local selectedCategories = useAt(importer._selectedCategories)

	local backgroundColor = useAt(subwindowColors.background)
	local dividerColor = useAt(subwindowColors.divider)
	local strokeColor = useAt(subwindowColors.stroke)
	local titleColor = useAt(subwindowColors.title)
	local captionColor = useAt(elementColors.caption)
	local panelColor = useAt(elementColors.panel)
	local panelStrokeColor = useAt(elementColors.panelStroke)
	local scrollThumbColor = useAt(elementColors.scrollThumb)

	local anim = useSubwindowAnimation(importer, {
		slideOffset = 18,
		floatingId = "subwindow.visualImport",
		floatingPriority = floatingController.PRIORITY.MODAL,
		onClickOutside = function()
			importer:Close()
		end,
	})

	local onDragStart = useDraggable(importer._position)

	local onSelectGame = useCallback(function(id: string): ()
		importer:SelectGame(id)
	end, { importer } :: { any })

	local onSelectConfig = useCallback(function(id: string): ()
		importer:SelectConfig(id)
	end, { importer } :: { any })

	local onTogglePill = useCallback(function(id: string): ()
		importer:ToggleCategory(id)
	end, { importer } :: { any })

	local configs: { string } = useMemo(function(): { string }
		for _, entry in next, games do
			if entry.id == selectedGame then
				return entry.configs
			end
		end
		return {}
	end, { games, selectedGame } :: { any })

	local chips: { [string]: React.Element<any> } = {}
	for index, entry in next, games do
		chips[`Chip_{entry.id}`] = e(GameTab, {
			Label = entry.label,
			Id = entry.id,
			IsActive = selectedGame == entry.id,
			OnClick = onSelectGame,
			LayoutOrder = index,
		})
	end

	local configRows: { [string]: React.Element<any> } = {}
	for index, name in next, configs do
		configRows[`Row_{name}`] = e(ConfigRow, {
			Label = name,
			Id = name,
			IsActive = selectedConfig == name,
			OnSelect = onSelectConfig,
			LayoutOrder = index,
		})
	end

	local pills: { [string]: React.Element<any> } = {}
	for index, category in next, categories do
		pills[`Pill_{category.id}`] = e(TogglePill, {
			Label = category.label,
			Id = category.id,
			IsActive = selectedCategories[category.id] == true,
			OnClick = onTogglePill,
			LayoutOrder = index,
		})
	end

	local canImport = selectedGame ~= nil and selectedConfig ~= nil

	local visibleRows = math.clamp(#configs, MIN_ROWS, MAX_ROWS)
	local panelHeight = visibleRows * ROW_HEIGHT + 8
	local needsScroll = #configs > MAX_ROWS

	local panelBind, panelSpring = useSpring(panelHeight, SPRING.smooth)
	local wasOpen = useRef(false)
	useEffect(function()
		if anim.isOpen and not wasOpen.current then
			panelSpring:setPosition(panelHeight)
		end
		wasOpen.current = anim.isOpen
		panelSpring:setGoal(panelHeight)
	end, { panelHeight, anim.isOpen } :: { any })

	local panelSize = useMemo(function()
		return panelBind:map(function(value: number)
			return UDim2.new(1, 0, 0, math.floor(value + 0.5))
		end)
	end, { panelBind })

	local contentBind, setContentBind = useBinding(0)
	local onContentSize = useCallback(function(rbx: UIListLayout): ()
		setContentBind(math.ceil(rbx.AbsoluteContentSize.Y))
	end, {})

	local rootSize = useMemo(function()
		return contentBind:map(function(value: number)
			return UDim2.fromOffset(WIDTH, value + PADDING_TOP + PADDING_BOTTOM)
		end)
	end, { contentBind })

	return e("Frame", {
		ref = anim.frameRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Size = rootSize,
		Position = anim.position,
		Visible = anim.visible,
		ZIndex = anim.zIndex,
	}, {
		Shadow = useShadow({
			transparency = anim.transparency,
			zIndex = 0,
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor,
			Transparency = anim.strokeTransparency,
			Thickness = 1,
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		Inner = e("CanvasGroup", {
			BackgroundTransparency = 0,
			BackgroundColor3 = backgroundColor,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = anim.transparency,
			ZIndex = 1,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, PADDING_X),
				PaddingRight = UDim.new(0, PADDING_X),
				PaddingTop = UDim.new(0, PADDING_TOP),
				PaddingBottom = UDim.new(0, PADDING_BOTTOM),
			}),
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, SECTION_GAP),
				[React.Change.AbsoluteContentSize] = onContentSize,
			}),
			Header = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, TITLE_HEIGHT + SUBTITLE_HEIGHT + DIVIDER_GAP - 3),
				LayoutOrder = 1,
			}, {
				Divider = e("Frame", {
					BackgroundColor3 = dividerColor,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, -1, 1, 5),
					Size = UDim2.new(1, 2, 0, 1),
				}),
				Title = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
					Text = "Import Visuals",
					TextColor3 = titleColor,
					TextSize = 15,
					FontFace = FileController.Get("font", "semi_bold"),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
				Subtitle = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, TITLE_HEIGHT),
					Size = UDim2.new(1, 0, 0, SUBTITLE_HEIGHT),
					Text = "Import visual settings from one of your other games",
					TextColor3 = captionColor,
					TextSize = 12,
					FontFace = FileController.Get("font", "semi_bold"),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				DragStrip = e("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 5,
					Active = true,
					[React.Event.InputBegan] = function(_: any, input: InputObject)
						onDragStart(input)
					end,
				}),
			}),
			GameSection = e(Section, {
				Caption = "GAME",
				LayoutOrder = 3,
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
					Wraps = true,
				}),
				Empty = #games == 0 and e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
					Text = "No other games have saved configs yet",
					TextColor3 = captionColor,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					FontFace = FileController.Get("font", "semi_bold"),
				}) or nil,
				Chips = React.createElement(React.Fragment, nil, chips),
			}),
			ConfigSection = e(Section, {
				Caption = "CONFIG",
				LayoutOrder = 4,
				ContentSize = panelSize,
			}, {
				Panel = e("Frame", {
					BackgroundColor3 = panelColor,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, 0),
					ClipsDescendants = true,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),
					UIStroke = e("UIStroke", {
						Color = panelStrokeColor,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = 1,
					}),
					Empty = #configs == 0 and e("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.fromScale(1, 1),
						Text = selectedGame and "This game has no saved configs" or "Pick a game above",
						TextColor3 = captionColor,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						FontFace = FileController.Get("font", "semi_bold"),
					}) or nil,
					Items = #configs > 0 and e(
						"ScrollingFrame",
						{
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							Size = UDim2.fromScale(1, 1),
							CanvasSize = UDim2.new(),
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
							ScrollingEnabled = needsScroll,
							ScrollingDirection = Enum.ScrollingDirection.Y,
							VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
							ScrollBarThickness = needsScroll and 3 or 0,
							ScrollBarImageColor3 = scrollThumbColor,
							ScrollBarImageTransparency = needsScroll and 0.1 or 1,
							Active = false,
						},
						Sift.Dictionary.join({
							UIPadding = e("UIPadding", {
								PaddingTop = UDim.new(0, 4),
								PaddingBottom = UDim.new(0, 4),
								PaddingLeft = UDim.new(0, 4),
								PaddingRight = UDim.new(0, 4),
							}),
							UIListLayout = e("UIListLayout", {
								VerticalAlignment = Enum.VerticalAlignment.Top,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
								FillDirection = Enum.FillDirection.Vertical,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 0),
							}),
						}, configRows)
					) or nil,
				}),
			}),
			IncludeSection = e(Section, {
				Caption = "INCLUDE",
				LayoutOrder = 5,
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
					Wraps = true,
				}),
				Pills = React.createElement(React.Fragment, nil, pills),
			}),
			Footer = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT + DIVIDER_GAP + 4),
				LayoutOrder = 6,
			}, {
				Divider = e("Frame", {
					BackgroundColor3 = dividerColor,
					BorderSizePixel = 0,
					Position = UDim2.new(0, -1, 0, -1),
					Size = UDim2.new(1, 2, 0, 1),
				}),
				Buttons = e("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
				}, {
					UIListLayout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					Cancel = e(FooterButton, {
						Text = "Cancel",
						Variant = "secondary",
						LayoutOrder = 1,
						OnClick = function()
							importer:Close()
						end,
					}),
					Import = e(FooterButton, {
						Text = "Import",
						Variant = "primary",
						Disabled = not canImport,
						LayoutOrder = 2,
						OnClick = function()
							importer:Import()
						end,
					}),
				}),
			}),
		}),
	})
end
