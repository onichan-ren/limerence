local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")
local Charm = require("@pkg/Charm")
local FileController = require("@src/feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local windowState = require("@ui/window/windowState")
local searchRenderer = require("@ui/window/search/renderer")

local useDraggable = require("@ui/hook/useDraggable")
local useShadow = require("@ui/hook/useShadow")
local ScopeSelector = require("@ui/scope/components/ScopeSelector")
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useRef = React.useRef
local useState = React.useState
local e = React.createElement

export type WindowRendererProperties = {
	Window: any,
}
export type TopBarProperties = {
	Window: any,
}
export type TabButtonProps = {
	tab: any,
}

local colors = themeState.colors.window

local function tabGroupFrames(properties: { TabGroup: any }): React.Element<any>
	local tabGroup = properties.TabGroup
	local tabs = useAt(tabGroup.tabs)

	local rendered = useMemo(function()
		local frames = {}
		for _, tab in next, tabs do
			table.insert(frames, tab:Render())
			for _, subtab in next, Charm.peek(tab._subtabs) do
				table.insert(frames, subtab:Render())
			end
		end
		return frames
	end, { tabs })

	return e(React.Fragment, nil, rendered)
end

local function topBar(properties: TopBarProperties): React.Element<any>
	local backgroundColor = useAt(colors.toolbar)
	local dividerColor = useAt(colors.divider)

	local searchMuted = useAt(colors.searchMuted)
	local activeText = useAt(colors.element.textActive)

	local query = useAt(windowState.searchQuery)
	local openTab = useAt(windowState.openTab)
	local showScopeSelector, setShowScopeSelector = useState(false)
	local textBoxRef = useRef(nil :: TextBox?)

	local onSearchTextChanged = useCallback(function(rbx: TextBox)
		windowState.searchQuery(rbx.Text)
	end, {})

	useEffect(function()
		if not openTab or not openTab._useScope then
			setShowScopeSelector(false)
			return
		end
		setShowScopeSelector(Charm.peek(openTab._useScope))
		local unsub = Charm.subscribe(openTab._useScope, function(value: boolean)
			setShowScopeSelector(value)
		end)
		return unsub
	end, { openTab } :: { any })

	useEffect(function()
		local box = textBoxRef.current
		if not box then
			return
		end
		local current = Charm.peek(windowState.searchQuery)
		if box.Text ~= current then
			box.Text = current
		end
	end, { query })

	return e("Frame", {
		Size = UDim2.new(1, -141, 0, 50),
		Position = UDim2.fromOffset(141, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = backgroundColor,
		ZIndex = 2,
	}, {
		Cover = e("Frame", {
			BackgroundColor3 = backgroundColor,
			Size = UDim2.new(1, 0, 0.25, 0),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			BorderSizePixel = 0,
			ZIndex = 2,
		}),
		Divider = e("Frame", {
			BackgroundColor3 = dividerColor,
			Size = UDim2.new(1, 0, 0, 1),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 2,
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		ScopeSelector = showScopeSelector and e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 2,
		}, {
			Selector = e(ScopeSelector, {}),
		}) or nil,
		SearchBar = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -250, 1, -26),
			Position = UDim2.fromOffset(15, 13),
			ZIndex = 2,
		}, {
			UIListLayout = e("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
			}),
			SearchIcon = e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(12, 12),
				Image = FileController.Get("image", "search"),
				ImageColor3 = searchMuted,
				LayoutOrder = 1,
				ZIndex = 2,
			}),
			SearchInput = e("TextBox", {
				ref = textBoxRef,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = "Search...",
				PlaceholderColor3 = searchMuted,
				TextColor3 = activeText,
				TextSize = 14,
				FontFace = FileController.Get("font", "light"),
				AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.new(1, -20, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
				[React.Change.Text] = onSearchTextChanged,
				ZIndex = 2,
			}),
		}),
	})
end

return function(properties: WindowRendererProperties): React.Element<any>
	local window = properties.Window

	local backgroundColor = useAt(colors.background)
	local dividerColor = useAt(colors.divider)
	local strokeColor = useAt(colors.stroke)
	local shadowPack = useAt(colors.shadow)
	local shadowColor = shadowPack[1] :: Color3
	local shadowAlpha = shadowPack[2] :: number
	local titleColor = useAt(colors.title)
	local sideColor = useAt(colors.sidebar)
	local logoColor = useAt(colors.logo)

	local tabGroups = useAt(window._tabGroups)
	local open = useAt(window._isOpen)
	local size = useAt(window._size)

	local renderedTabGroups = useMemo(function()
		return Sift.Array.map(tabGroups, function(tabGroup: any, index: number)
			return tabGroup:Render(window._openTab)
		end)
	end, { tabGroups })

	local renderedTabFrames = useMemo(function()
		return Sift.Array.map(tabGroups, function(tabGroup: any)
			return e(tabGroupFrames, { TabGroup = tabGroup })
		end)
	end, { tabGroups })

	local bind, spring = useSpring(0, {
		tension = 700,
		friction = 50,
	})

	useEffect(function()
		spring:setGoal(open and 1 or 0)
	end, { open })

	local onDragStart, positionBind = useDraggable(window._position)

	local onBodyInputBegan = useCallback(function(_: any, input: InputObject)
		onDragStart(input)
	end, { onDragStart } :: { any })

	local visibleBind = useMemo(function()
		return bind:map(function(value: number)
			return value > 0.01
		end)
	end, { bind } :: { any })

	local shadowTransparencyBind = useMemo(function()
		return bind:map(function(value: number)
			local t = 1 - value
			return 1 - (1 - t) * (1 - shadowAlpha)
		end)
	end, { bind, shadowAlpha } :: { any })

	local bodyTransparencyBind = useMemo(function()
		return bind:map(function(value: number)
			return 1 - value
		end)
	end, { bind } :: { any })

	local strokeTransparencyBind = useMemo(function()
		return bind:map(function(value: number)
			return 1 - value
		end)
	end, { bind } :: { any })

	return e("Frame", {
		Size = size,
		Position = positionBind,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = visibleBind,
	}, {
		Shadow = useShadow({
			color = shadowColor,
			transparency = shadowTransparencyBind,
			zIndex = 0,
		}),
		Body = e("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = sideColor,
			BorderSizePixel = 0,
			ZIndex = 1,
			[React.Event.InputBegan] = onBodyInputBegan,
			BackgroundTransparency = 0,
			GroupTransparency = bodyTransparencyBind,
		}, {
			Background = e(
				"Frame",
				{
					BackgroundColor3 = backgroundColor,
					Position = UDim2.fromOffset(141, 0),
					Size = UDim2.new(1, -141, 1, 0),
					BorderSizePixel = 0,
				},
				Sift.Dictionary.join({
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),
					SearchView = e(searchRenderer, {
						Window = window,
					}),
				}, renderedTabFrames)
			),
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			UIStroke = e("UIStroke", {
				Color = strokeColor,
				Transparency = strokeTransparencyBind,
				Thickness = 1,
			}),
			SideDivider = e("Frame", {
				BackgroundColor3 = dividerColor,
				Size = UDim2.new(0, 1, 1, 0),
				Position = UDim2.fromOffset(140, 0),
				BorderSizePixel = 0,
			}),
			TopBar = e(topBar, {
				Window = window,
			}),
			TopLeft = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(140, 31),
			}, {
				UIListLayout = e("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 6),
				}),
				Logo = e("ImageLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = 1,
					Size = UDim2.fromOffset(14, 14),
					Image = FileController.Get("image", "logov2"),
					ImageColor3 = logoColor,
				}),
				Title = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = 2,
					Text = "Limerence",
					TextColor3 = titleColor,
					TextSize = 18,
					Size = UDim2.fromOffset(0, 14),
					FontFace = FileController.Get("font", "semi_bold"),
					AutomaticSize = Enum.AutomaticSize.X,
				}),
			}),
			TabButtons = e(
				"Frame",
				{
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 50),
					Size = UDim2.new(0, 140, 1, -60),
					BorderSizePixel = 0,
				},
				Sift.Dictionary.join({
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 10),
						PaddingTop = UDim.new(0, 0),
						PaddingBottom = UDim.new(0, 0),
					}),
					UIListLayout = e("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Top,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
				}, renderedTabGroups)
			),
		}),
	})
end
