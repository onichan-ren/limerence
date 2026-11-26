local RunService = cloneref(game:GetService("RunService")) :: RunService

local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local Sift = require("@pkg/Sift")

local FileController = require("@src/feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local windowState = require("@ui/window/windowState")
local SPRING = require("@ui/util/spring")
local searchUtil = require("@ui/window/search/searchUtil")
local tooltipController = require("@ui/tooltip/tooltipController")
local useScrollFade = require("@ui/hook/useScrollFade")

local useAt = ReactCharm.useAtom
local useSpring = ReactRipple.useSpring
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useState = React.useState
local useRef = React.useRef
local memo = React.memo
local e = React.createElement

local windowColors = themeState.colors.window
local sectionColors = windowColors.section
local elementColors = windowColors.element

type ResultPanelProps = {
	Result: searchUtil.Result,
	LayoutOrder: number,
}

local ResultPanel = memo(function(props: ResultPanelProps): React.Element<any>
	local result = props.Result

	local backgroundColor = useAt(sectionColors.background)
	local strokeColor = useAt(sectionColors.stroke)
	local titleColor = useAt(sectionColors.text)
	local captionColor = useAt(elementColors.caption)

	local renderedElements = useMemo(function()
		local rendered: { [string]: React.Element<any> } = {}
		for index, element in next, result.elements do
			rendered[tostring(element)] = element:Render(index)
		end
		return rendered
	end, { result.elements })

	local onHeaderClick = useCallback(function()
		windowState.openTab(result.tab)
		windowState.searchQuery("")
	end, { result.tab } :: { any })

	local crumb = result.tabGroup.title .. "  /  " .. result.tab.title
	if result.submenuTitle then
		crumb = crumb .. "  /  " .. result.submenuTitle
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.LayoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Header = e("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 14),
			Text = "",
			AutoButtonColor = false,
			Active = false,
			LayoutOrder = 0,
			[React.Event.MouseButton1Click] = onHeaderClick,
		}, {
			UIListLayout = e("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			Title = e("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = FileController.Get("font", "semi_bold"),
				TextColor3 = titleColor,
				TextSize = 11,
				Text = result.section._title,
				Size = UDim2.fromOffset(0, 14),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 0,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Caption = e("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = FileController.Get("font", "light"),
				TextColor3 = captionColor,
				TextSize = 11,
				Text = crumb,
				Size = UDim2.fromOffset(0, 14),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),
		Panel = e(
			"Frame",
			{
				BackgroundColor3 = backgroundColor,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 34),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
			},
			Sift.Dictionary.join({
				UIStroke = e("UIStroke", {
					Color = strokeColor,
					Thickness = 1,
				}),
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
				}),
				UIListLayout = e("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Top,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10),
				}),
			}, renderedElements)
		),
	})
end)

return function(properties: { Window: any }): React.Element<any>
	local window = properties.Window

	local query = useAt(windowState.searchQuery)
	useAt(window._tabGroups)

	local active = #query >= 2

	local openBind, openSpring = useSpring(0, SPRING.smooth)
	local contentBind, contentSpring = useSpring(0, SPRING.smooth)

	local results, setResults = useState({} :: { searchUtil.Result })
	local pendingRef = useRef(nil :: { searchUtil.Result }?)
	local shownRef = useRef(false)
	local closingRef = useRef(false)
	local fadeInRef = useRef(false)

	local showPending = useCallback(function()
		local pending = pendingRef.current
		if pending then
			setResults(pending)
			pendingRef.current = nil
		end
		contentSpring:setPosition(0)
		fadeInRef.current = true
		shownRef.current = true
	end, {})

	useEffect(function()
		if not fadeInRef.current then
			return
		end
		fadeInRef.current = false
		contentSpring:setPosition(0)
		local connection
		connection = RunService.Heartbeat:Connect(function(deltaTime: number)
			if deltaTime > 0.05 then
				return
			end
			connection:Disconnect()
			contentSpring:setPosition(0)
			contentSpring:setGoal(1)
		end)
		return function()
			connection:Disconnect()
		end
	end, { results } :: { any })

	useEffect(function()
		local disconnect = contentSpring:onComplete(function(value: number)
			if value > 0.001 then
				return
			end
			if closingRef.current then
				closingRef.current = false
				openSpring:setGoal(0)
			elseif pendingRef.current ~= nil then
				showPending()
			end
		end)
		return disconnect
	end, { showPending } :: { any })

	useEffect(function()
		if not active then
			pendingRef.current = nil
			if shownRef.current then
				closingRef.current = true
				contentSpring:setGoal(0)
				shownRef.current = false
			else
				openSpring:setGoal(0)
			end
			return
		end
		closingRef.current = false
		openSpring:setGoal(1)
		tooltipController.Hide()
		pendingRef.current = searchUtil.walk(window, query)
		if shownRef.current then
			contentSpring:setGoal(0)
		else
			showPending()
		end
	end, { active, query } :: { any })

	local mutedColor = useAt(windowColors.searchMuted)
	local scrollThumbColor = useAt(elementColors.scrollThumb)
	local backgroundColor = useAt(windowColors.background)

	local scrollRef, contentRef, needsBar, scrollGradient = useScrollFade()

	local renderedPanels = useMemo(function()
		local panels: { [string]: React.Element<any> } = {}
		for index, result in next, results do
			local key = tostring(result.section)
			if result.submenu then
				key = key .. "_" .. tostring(result.submenu)
			end
			panels[key] = e(ResultPanel, {
				Result = result,
				LayoutOrder = index,
			})
		end
		return panels
	end, { results } :: { any })

	local hasResults = #results > 0

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 1, -71),
		Position = openBind:map(function(value: number)
			return UDim2.fromOffset(8, 59 + (1 - value) * 10)
		end),
		Visible = openBind:map(function(value: number)
			return value > 0.01
		end),
		ZIndex = 5,
	}, {
		Background = e("Frame", {
			BackgroundColor3 = backgroundColor,
			BackgroundTransparency = openBind:map(function(value: number)
				return 1 - value
			end),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			ZIndex = 0,
		}),
		Blocker = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			Active = true,
			ZIndex = 0,
		}),
		Content = e("CanvasGroup", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			GroupTransparency = contentBind:map(function(value: number)
				return 1 - value
			end),
			ZIndex = 1,
		}, {
		Gradient = scrollGradient,
		Scroll = e("ScrollingFrame", {
			ref = scrollRef,
			Active = false,
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			ClipsDescendants = true,
			ScrollingEnabled = needsBar,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			ScrollBarImageColor3 = scrollThumbColor,
			ScrollBarThickness = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			Visible = hasResults,
			ZIndex = 1,
		}, {
			Content = e(
				"Frame",
				{
					ref = contentRef,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				},
				Sift.Dictionary.join({
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 1),
						PaddingRight = UDim.new(0, 1),
						PaddingTop = UDim.new(0, 0),
						PaddingBottom = UDim.new(0, 1),
					}),
					UIListLayout = e("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Top,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 12),
					}),
				}, renderedPanels)
			),
		}),
		Empty = not hasResults and e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			Text = "No results found",
			TextColor3 = mutedColor,
			TextSize = 13,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 2,
		}) or nil,
		}),
	})
end
