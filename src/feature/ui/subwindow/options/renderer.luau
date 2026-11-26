local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local themeState = require("@ui/theme/themeState")
local FileController = require("@src/feature/file/FileController")
local useSubwindowAnimation = require("@ui/hook/useSubwindowAnimation")
local useShadow = require("@ui/hook/useShadow")
local useScrollFade = require("@ui/hook/useScrollFade")
local dpiState = require("@ui/util/dpiState")

local colors = themeState.colors.subwindow
local elementColors = themeState.colors.window.element
local SUBWINDOW_ELEMENT_RENDER = { textOffsetY = -1 }

local PANE_WIDTH = 175
local MAIN_WIDTH = 229
local PANE_GAP = 12
local MAX_PANE_HEIGHT = 380

local useMemo = React.useMemo
local useEffect = React.useEffect
local useRef = React.useRef
local useBinding = React.useBinding
local useAt = ReactCharm.useAtom
local peek = Charm.peek
local e = React.createElement

local function useMeasuredHeight(active: any, externalRef: any?): ({ current: GuiObject? }, React.Binding<number>)
	local ownRef = useRef(nil :: GuiObject?)
	local ref = externalRef or ownRef
	local height, setHeight = useBinding(0)

	useEffect(function()
		local instance = ref.current
		if not instance then
			setHeight(0)
			return
		end
		local function update(): ()
			local scale = peek(dpiState.scale)
			if scale <= 0 then
				scale = 1
			end
			setHeight(instance.AbsoluteSize.Y / scale)
		end
		update()
		local connection = instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
		return function()
			connection:Disconnect()
		end
	end, { active })

	return ref, height
end

local function titleFrame(
	title: string,
	titleColor: Color3,
	dividerColor: Color3,
	caption: string?,
	captionColor: Color3?
): React.Element<any>
	local hasCaption = caption ~= nil
	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, hasCaption and 35 or 14),
		LayoutOrder = 0,
	}, {
		Title = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = 0,
			Text = title,
			TextColor3 = titleColor,
			FontFace = FileController.Get("font", "semi_bold"),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Caption = hasCaption and e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 17),
			Size = UDim2.new(1, 0, 0, 12),
			Text = caption,
			TextColor3 = captionColor,
			FontFace = FileController.Get("font", "semi_bold"),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
		}) or nil,
		Divider = e("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = dividerColor,
			Size = UDim2.new(1, 0, 0, hasCaption and 1 or 2),
			Position = hasCaption and UDim2.new(0, 0, 1, -1) or UDim2.fromOffset(0, 18),
			LayoutOrder = 1,
		}),
	})
end

return function(properties: { Options: any }): React.Element<any>
	local optionsWindow = properties.Options

	local title = useAt(optionsWindow._title)
	local showTitle = useAt(optionsWindow._showTitle)
	local elements = useAt(optionsWindow._elements)
	local sidePane = useAt(optionsWindow._sidePane)

	local backgroundColor = useAt(colors.background)
	local dividerColor = useAt(colors.divider)
	local strokeColor = useAt(colors.stroke)
	local titleColor = useAt(colors.title)
	local scrollThumbColor = useAt(elementColors.icon)
	local captionColor = useAt(elementColors.caption)
	local panelColor = useAt(elementColors.panel)
	local panelStroke = useAt(elementColors.panelStroke)

	local renderedElements = useMemo(function()
		local rendered = {}
		for index, element in elements do
			rendered["E_" .. index .. "_" .. tostring(element)] = element:Render(index, SUBWINDOW_ELEMENT_RENDER)
		end
		return rendered
	end, { elements })

	local anim = useSubwindowAnimation(optionsWindow, {
		slideOffset = 15,
		floatingId = "subwindow.options",
		onClickOutside = function()
			optionsWindow:Close()
		end,
	})

	local elementsList = Sift.Dictionary.join({
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, sidePane and 8 or 10),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, sidePane and 8 or 3),
			PaddingRight = UDim.new(0, sidePane and 8 or 3),
			PaddingTop = UDim.new(0, sidePane and 8 or 7),
			PaddingBottom = UDim.new(0, sidePane and 8 or 3),
		}),
	}, renderedElements)

	local mainScrollRef, mainContentRef, _mainNeedsBar, mainGradient = useScrollFade()
	local paneRef, paneHeight = useMeasuredHeight(sidePane)
	local mainRef, mainHeight = useMeasuredHeight(sidePane, mainContentRef)

	local titleOffset = showTitle and (sidePane and 43 or 26) or 0
	local maxMainHeight = MAX_PANE_HEIGHT - titleOffset

	local paneScrollSize = useMemo(function()
		return paneHeight:map(function(value: number)
			return UDim2.new(0, PANE_WIDTH, 0, math.min(value, MAX_PANE_HEIGHT))
		end)
	end, { paneHeight })

	local mainScrollSize = useMemo(function()
		return mainHeight:map(function(value: number)
			return UDim2.new(1, 0, 0, math.min(value, maxMainHeight))
		end)
	end, { mainHeight, maxMainHeight } :: { any })

	local dividerSize = useMemo(function()
		return React.joinBindings({ paneHeight, mainHeight }):map(function(values)
			local pane = math.min(values[1], MAX_PANE_HEIGHT)
			local main = titleOffset + math.min(values[2], maxMainHeight)
			return UDim2.new(0, 2, 0, math.max(pane, main))
		end)
	end, { paneHeight, mainHeight, titleOffset, maxMainHeight } :: { any })

	local bodyChildren
	if sidePane then
		bodyChildren = {
			UIListLayout = e("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, PANE_GAP),
			}),
			SidePane = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = paneScrollSize,
				LayoutOrder = 0,
				ClipsDescendants = true,
			}, {
				Inner = e("Frame", {
					ref = paneRef,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				}, {
					Pane = e(sidePane.component),
				}),
			}),
			PaneDivider = e("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = dividerColor,
				Size = dividerSize,
				LayoutOrder = 1,
			}),
			Main = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, MAIN_WIDTH, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
			}, {
				UIListLayout = e("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Top,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				TitleFrame = showTitle
						and titleFrame(title, titleColor, dividerColor, "Configure the selected profile", captionColor)
					or nil,
				ScrollFade = e("CanvasGroup", {
					BackgroundTransparency = 0,
					BackgroundColor3 = panelColor,
					BorderSizePixel = 0,
					Size = mainScrollSize,
					LayoutOrder = 1,
					ZIndex = 1,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),
					UIStroke = e("UIStroke", {
						Color = panelStroke,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = 1,
					}),
					Gradient = mainGradient,
					Scroll = e("ScrollingFrame", {
						ref = mainScrollRef,
						Active = false,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.fromScale(1, 1),
						ClipsDescendants = true,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.fromOffset(0, 0),
						VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
						ScrollBarImageColor3 = scrollThumbColor,
						ScrollBarImageTransparency = 0.35,
						ScrollBarThickness = 2,
					}, {
						Inner = e("Frame", {
							ref = mainRef,
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							Size = UDim2.new(1, 0, 0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
						}, elementsList),
					}),
				}),
			}),
		}
	else
		bodyChildren = {
			UIListLayout = e("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			TitleFrame = showTitle and titleFrame(title, titleColor, dividerColor) or nil,
			Elements = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
			}, elementsList),
		}
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = sidePane and UDim2.new(0, PANE_WIDTH + PANE_GAP * 2 + 2 + MAIN_WIDTH + 20, 0, 0)
			or UDim2.new(0, 250, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = anim.position,
		Visible = anim.visible,
		ZIndex = anim.zIndex,
	}, {
		Shadow = useShadow({
			transparency = anim.transparency,
			zIndex = 0,
		}),
		Body = e(
			"CanvasGroup",
			{
				ref = anim.frameRef,
				BackgroundTransparency = 0,
				BackgroundColor3 = backgroundColor,
				Size = UDim2.fromScale(1, 1),
				AutomaticSize = Enum.AutomaticSize.Y,
				GroupTransparency = anim.transparency,
				ZIndex = 1,
			},
			Sift.Dictionary.join({
				UIStroke = e("UIStroke", {
					Color = strokeColor,
					Transparency = anim.strokeTransparency,
					Thickness = 1,
				}),
				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
				}),
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
			}, bodyChildren)
		),
	})
end
