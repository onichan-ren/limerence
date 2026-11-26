local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local themeState = require("@ui/theme/themeState")
local FileController = require("@src/feature/file/FileController")
local SPRING = require("@ui/util/spring")
local useScrollFade = require("@ui/hook/useScrollFade")

local MapProfiles = require("@ui/scope/MapProfiles")

local useAt = ReactCharm.useAtom
local useState = React.useState
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local e = React.createElement

local subwindowColors = themeState.colors.subwindow
local elementColors = themeState.colors.window.element

local GLOBAL_ID = MapProfiles.GLOBAL_ID
local ROW_HEIGHT = 28
local SPACE = 8
local COMPACT_SPACE = 4
local MAX_LIST_HEIGHT = 335

type CardProps = {
	Name: string,
	LayoutOrder: number,
	Selected: boolean,
	OnSelect: () -> (),
	Enabled: boolean?,
	OnToggle: (() -> ())?,
	Current: boolean?,
}

local function Toggle(props: { Enabled: boolean, OnToggle: (() -> ())? }): React.Element<any>
	local surface = useAt(elementColors.surface)
	local accent = useAt(elementColors.accent)
	local surfaceStroke = useAt(elementColors.surfaceStroke)
	local accentStrong = useAt(elementColors.accentStrong)
	local thumb = useAt(elementColors.thumb)
	local thumbActive = useAt(elementColors.thumbActive)

	local enabledBind, enabledSpring = useSpring(props.Enabled and 1 or 0, SPRING.quick)

	useEffect(function()
		enabledSpring:setGoal(props.Enabled and 1 or 0)
	end, { props.Enabled })

	return e("TextButton", {
		BackgroundColor3 = enabledBind:map(function(value: number)
			return surface:Lerp(accent, value)
		end),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(24, 12),
		Text = "",
		Active = false,
		AutoButtonColor = false,
		LayoutOrder = 3,
		[React.Event.MouseButton1Click] = props.OnToggle,
	}, {
		UIStroke = e("UIStroke", {
			Color = enabledBind:map(function(value: number)
				return surfaceStroke:Lerp(accentStrong, value)
			end),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}),
		Knob = e("Frame", {
			BackgroundColor3 = enabledBind:map(function(value: number)
				return thumb:Lerp(thumbActive, value)
			end),
			Position = enabledBind:map(function(value: number)
				return UDim2.fromScale(value, 0)
			end),
			AnchorPoint = enabledBind:map(function(value: number)
				return Vector2.new(value, 0)
			end),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(8, 8),
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
	})
end

local function Card(props: CardProps): React.Element<any>
	local hovered, setHovered = useState(false)

	local panel = useAt(elementColors.panel)
	local surface = useAt(elementColors.surface)
	local surfaceStroke = useAt(elementColors.surfaceStroke)
	local accentSoft = useAt(elementColors.accentSoft)
	local accentStrong = useAt(elementColors.accentStrong)
	local text = useAt(elementColors.text)
	local textActive = useAt(elementColors.textActive)
	local captionActive = useAt(elementColors.captionActive)

	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	local selectedBind, selectedSpring = useSpring(props.Selected and 1 or 0, SPRING.quick)

	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	useEffect(function()
		selectedSpring:setGoal(props.Selected and 1 or 0)
	end, { props.Selected })

	local stateBind = React.joinBindings({ hoverBind, selectedBind })

	return e("TextButton", {
		BackgroundColor3 = stateBind:map(function(values)
			local hoveredValue: number = values[1]
			local selectedValue: number = values[2]
			return panel:Lerp(surface, hoveredValue * 0.7):Lerp(accentSoft, selectedValue)
		end),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		[React.Event.MouseButton1Click] = props.OnSelect,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
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
				return 0.35 * (1 - value)
			end),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, SPACE),
			PaddingRight = UDim.new(0, SPACE),
		}),
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, COMPACT_SPACE),
		}),
		Accent = e("Frame", {
			BackgroundColor3 = accentStrong,
			BackgroundTransparency = selectedBind:map(function(value: number)
				return 1 - value
			end),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(2, 12),
			LayoutOrder = 0,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
		Name = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			Text = props.Name,
			TextColor3 = selectedBind:map(function(value: number)
				return text:Lerp(textActive, value)
			end),
			FontFace = FileController.Get("font", "semi_bold"),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 1,
		}, {
			UIFlexItem = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
			}),
		}),
		Current = props.Current and e("Frame", {
			BackgroundColor3 = captionActive,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(5, 5),
			LayoutOrder = 2,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}) or nil,
		Toggle = props.OnToggle and e(Toggle, {
			Enabled = props.Enabled == true,
			OnToggle = props.OnToggle,
		}) or nil,
	})
end

return function(properties: { Profiles: any }): React.Element<any>
	local profiles = properties.Profiles

	local profileNames = useAt(profiles._profiles)
	local allMaps = useAt(profiles._allMaps)
	local selected = useAt(profiles._selected)
	local enabled = useAt(profiles._enabled)
	local currentMap = useAt(profiles._currentMap)

	local titleColor = useAt(subwindowColors.title)
	local dividerColor = useAt(subwindowColors.divider)
	local captionColor = useAt(elementColors.caption)
	local panelColor = useAt(elementColors.panel)
	local panelStroke = useAt(elementColors.panelStroke)
	local scrollThumbColor = useAt(elementColors.icon)

	local names = table.clone(allMaps)
	for _, name in next, profileNames do
		if not table.find(names, name) then
			table.insert(names, name)
		end
	end

	if currentMap then
		local index = table.find(names, currentMap)
		if index and index > 1 then
			table.remove(names, index)
			table.insert(names, 1, currentMap)
		end
	end

	local cards = {}
	cards.Global = e(Card, {
		Name = "Global",
		LayoutOrder = 1,
		Selected = selected == GLOBAL_ID,
		OnSelect = function()
			profiles:Select(GLOBAL_ID)
		end,
	})

	for index, name in next, names do
		cards["P_" .. name] = e(Card, {
			Name = name,
			LayoutOrder = 1 + index,
			Selected = selected == name,
			OnSelect = function()
				profiles:EnsureProfile(name)
				profiles:Select(name)
			end,
			Enabled = enabled[name] == true,
			OnToggle = function()
				profiles:SetEnabled(name, not profiles:IsEnabled(name))
			end,
			Current = currentMap == name,
		})
	end

	local rowCount = #names + 1
	local contentHeight = COMPACT_SPACE * 2 + 2 + rowCount * ROW_HEIGHT + math.max(0, rowCount - 1) * COMPACT_SPACE
	local listHeight = math.min(contentHeight, MAX_LIST_HEIGHT)
	local hasListOverflow = contentHeight > MAX_LIST_HEIGHT
	local listScrollRef, listContentRef, _listNeedsBar, listGradient = useScrollFade()

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		UIPadding = e("UIPadding", {
			PaddingBottom = UDim.new(0, 1),
		}),
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, SPACE),
		}),
		Header = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 35),
			LayoutOrder = 0,
		}, {
			Title = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 16),
				Text = "Map Ambience",
				TextColor3 = titleColor,
				FontFace = FileController.Get("font", "semi_bold"),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),
			Caption = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 17),
				Size = UDim2.new(1, 0, 0, 12),
				Text = "Choose where changes apply",
				TextColor3 = captionColor,
				FontFace = FileController.Get("font", "semi_bold"),
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			}),
			Divider = e("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = dividerColor,
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.new(0, 0, 1, -1),
				LayoutOrder = 3,
			}),
		}),
		Cards = e("Frame", {
			BackgroundColor3 = panelColor,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -2, 0, listHeight),
			LayoutOrder = 1,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			UIStroke = e("UIStroke", {
				Color = panelStroke,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			Fade = e("CanvasGroup", {
				BackgroundTransparency = 0,
				BackgroundColor3 = panelColor,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(COMPACT_SPACE, COMPACT_SPACE),
				Size = UDim2.new(1, -COMPACT_SPACE * 2, 1, -COMPACT_SPACE * 2),
			}, {
				Gradient = listGradient,
				Scroll = e("ScrollingFrame", {
					ref = listScrollRef,
					Active = false,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					CanvasSize = UDim2.fromOffset(0, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					VerticalScrollBarInset = Enum.ScrollBarInset.Always,
					ScrollBarImageColor3 = scrollThumbColor,
					ScrollBarImageTransparency = hasListOverflow and 0.35 or 1,
					ScrollBarThickness = hasListOverflow and 2 or 0,
					ClipsDescendants = true,
				}, {
					Inner = e("Frame", {
						ref = listContentRef,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
					}, {
						UIListLayout = e("UIListLayout", {
							VerticalAlignment = Enum.VerticalAlignment.Top,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, COMPACT_SPACE),
						}),
						UIPadding = e("UIPadding", {
							PaddingTop = UDim.new(0, 1),
							PaddingBottom = UDim.new(0, 1),
							PaddingLeft = UDim.new(0, 1),
							PaddingRight = UDim.new(0, 1 + (hasListOverflow and SPACE or 0)),
						}),
						List = e(React.Fragment, nil, cards),
					}),
				}),
			}),
		}),
	})
end
