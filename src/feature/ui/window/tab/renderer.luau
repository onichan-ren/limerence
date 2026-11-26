local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")
local windowState = require("@ui/window/windowState")
local themeState = require("@ui/theme/themeState")
local ScopeOverrideBar = require("@ui/scope/components/ScopeOverrideBar")
local scopeState = require("@ui/scope/scopeState")
local ScopeController = require("@ui/scope/ScopeController")

local useEffect = React.useEffect
local useState = React.useState
local useRef = React.useRef
local useSpring = ReactRipple.useSpring
local useMemo = React.useMemo
local useAt = ReactCharm.useAtom
local e = React.createElement

local SCROLLBAR_EPS = 1
local FADE_HEIGHT = 20

local elementColors = themeState.colors.window.element

local openTab = windowState.openTab

export type TabRendererProps = {
	Tab: any,
}
type ContainerProps = {
	Container: any,
}

local Container = React.memo(function(props: ContainerProps): React.Element<any>
	local container = props.Container

	local sections = useAt(container._sections)

	local renderedSections = useMemo(function()
		return Sift.Array.map(sections, function(section)
			return section:Render()
		end)
	end, { sections })

	return e(
		"Frame",
		{
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0.5, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		},
		Sift.Dictionary.join({
			UIFlexItem = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
				ItemLineAlignment = Enum.ItemLineAlignment.Automatic,
			}),
			UIListLayout = e("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 9),
			}),
		}, renderedSections)
	)
end)

return function(props: TabRendererProps): React.Element<any>
	local tab = props.Tab

	local scrollThumbColor = useAt(elementColors.scrollThumb)

	local isOpen = useAt(openTab) == tab

	local customRenderer = useAt(tab._customRenderer)
	local headerAccessory = useAt(tab._headerAccessory)
	local useScope = useAt(tab._useScope)
	local currentScopeId = useAt(scopeState.currentScope)
	local showOverrideBar = useScope and currentScopeId ~= ScopeController.GLOBAL_ID

	local barProgressBind, barProgressSpring = useSpring(0, {
		tension = 700,
		friction = 50,
		precision = 0.01,
	})

	local lastNonGlobalScope, setLastNonGlobalScope = useState(nil :: string?)

	useEffect(function()
		if useScope and currentScopeId ~= ScopeController.GLOBAL_ID then
			setLastNonGlobalScope(currentScopeId)
		end
	end, { useScope, currentScopeId } :: { any })

	useEffect(function()
		barProgressSpring:setGoal(showOverrideBar and 1 or 0)
	end, { showOverrideBar })

	local mountBar = useScope and lastNonGlobalScope ~= nil
	local barScopeId = showOverrideBar and currentScopeId or lastNonGlobalScope

	local containers = useAt(tab._containers)
	local renderedContainers = useMemo(function()
		if customRenderer then
			return {}
		end
		return Sift.Array.map(containers, function(container)
			return e(Container, {
				Container = container,
			})
		end)
	end, { containers, customRenderer } :: { any })

	local customContent = useMemo(function()
		if not customRenderer then
			return nil
		end
		return customRenderer.render(tab)
	end, { customRenderer, tab } :: { any })

	local renderedAccessory = useMemo(function(): React.Element<any>?
		if not headerAccessory then
			return nil
		end
		return headerAccessory.render(tab)
	end, { headerAccessory, tab } :: { any })

	local bind, spring = useSpring(1, {
		friction = 52,
		tension = 950,
		precision = 0.01,
	})

	local scrollRef = useRef(nil :: ScrollingFrame?)
	local contentRef = useRef(nil :: Frame?)
	local needsBar, setNeedsBar = useState(false)
	local viewHeight, setViewHeight = useState(0)

	local topFadeBind, topFadeSpring = useSpring(0, {
		tension = 1050,
		friction = 59,
		precision = 0.04,
	})
	local bottomFadeBind, bottomFadeSpring = useSpring(0, {
		tension = 1050,
		friction = 59,
		precision = 0.04,
	})

	useEffect(function()
		spring:setGoal(isOpen and 0 or 1)
	end, { isOpen })

	useEffect(function()
		local conns: { RBXScriptConnection } = {}
		local hookIteration = 0
		local cancelled = false

		local function recompute()
			if cancelled then
				return
			end
			local sc = scrollRef.current
			local cf = contentRef.current
			if not sc or not cf then
				return
			end
			if sc.AbsoluteSize.Y < 1 then
				return
			end
			local maxScroll = cf.AbsoluteSize.Y - sc.AbsoluteSize.Y
			local need = maxScroll > SCROLLBAR_EPS
			setNeedsBar(need)
			setViewHeight(sc.AbsoluteSize.Y)
			local pos = sc.CanvasPosition.Y
			topFadeSpring:setGoal((need and pos > 2) and 1 or 0)
			bottomFadeSpring:setGoal((need and pos < maxScroll - 2) and 1 or 0)
		end

		local function tryConnect()
			if cancelled then
				return
			end
			for _, c in conns do
				c:Disconnect()
			end
			while conns[1] do
				table.remove(conns, 1)
			end

			local sc = scrollRef.current
			local cf = contentRef.current
			if not sc or not cf then
				hookIteration = hookIteration + 1
				if hookIteration < 8 then
					task.defer(tryConnect)
				end
				return
			end

			table.insert(conns, sc:GetPropertyChangedSignal("AbsoluteSize"):Connect(recompute))
			table.insert(conns, cf:GetPropertyChangedSignal("AbsoluteSize"):Connect(recompute))
			table.insert(conns, sc:GetPropertyChangedSignal("CanvasSize"):Connect(recompute))
			table.insert(conns, sc:GetPropertyChangedSignal("CanvasPosition"):Connect(recompute))
			task.defer(recompute)
			task.defer(recompute)
		end

		tryConnect()

		return function()
			cancelled = true
			for _, c in conns do
				c:Disconnect()
			end
		end
	end, { isOpen, containers } :: { any })

	local groupTransparencyBind = useMemo(function()
		return bind:map(function(value: number)
			return value
		end)
	end, { bind } :: { any })

	local groupVisibleBind = useMemo(function()
		return bind:map(function(value: number)
			return value < 0.99
		end)
	end, { bind } :: { any })

	local groupPositionBind = useMemo(function()
		return bind:map(function(value: number)
			local offset = value * 15
			return UDim2.fromOffset(8, 59 - offset)
		end)
	end, { bind } :: { any })

	local wrapperProps = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 1, -71),
		GroupTransparency = groupTransparencyBind,
		Visible = groupVisibleBind,
		Position = groupPositionBind,
	}

	local accessoryHeight = renderedAccessory and 28 or 0
	local BAR_RESERVED = 34

	local scrollPosition = useMemo(function()
		return barProgressBind:map(function(value: number)
			return UDim2.fromOffset(0, math.floor(accessoryHeight + value * BAR_RESERVED))
		end)
	end, { barProgressBind, accessoryHeight } :: { any })
	local scrollSize = useMemo(function()
		return barProgressBind:map(function(value: number)
			return UDim2.new(1, 0, 1, -math.floor(accessoryHeight + value * BAR_RESERVED))
		end)
	end, { barProgressBind, accessoryHeight } :: { any })

	local overrideBarElement = mountBar
			and e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 26),
				Position = UDim2.fromOffset(0, 0),
				ZIndex = 4,
			}, {
				Bar = e(ScopeOverrideBar, {
					ScopeId = barScopeId,
					Progress = barProgressBind,
				}),
			})
		or nil

	local fadeSequence = useMemo(function()
		return React.joinBindings({ topFadeBind, bottomFadeBind }):map(function(values)
			local top: number = values[1]
			local bottom: number = values[2]
			local h = math.max(viewHeight, 1)
			local f = math.clamp(FADE_HEIGHT / h, 0.001, 0.45)
			return NumberSequence.new({
				NumberSequenceKeypoint.new(0, top),
				NumberSequenceKeypoint.new(f, 0),
				NumberSequenceKeypoint.new(1 - f, 0),
				NumberSequenceKeypoint.new(1, bottom),
			})
		end)
	end, { topFadeBind, bottomFadeBind, viewHeight } :: { any })

	local scrollFade = e("CanvasGroup", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = scrollPosition,
		Size = scrollSize,
		ZIndex = 1,
	}, {
		UIGradient = e("UIGradient", {
			Rotation = 90,
			Transparency = fadeSequence,
		}),
		Scroll = e("ScrollingFrame", {
			ref = scrollRef,
			Active = false,
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 1),
			ClipsDescendants = true,
			ScrollingEnabled = needsBar,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			ScrollBarImageColor3 = scrollThumbColor,
			ScrollBarThickness = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
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
					UIListLayout = e("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Top,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 12),
					}),
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 1),
						PaddingRight = UDim.new(0, 1),
						PaddingTop = UDim.new(0, 1),
						PaddingBottom = UDim.new(0, 1),
					}),
				}, renderedContainers)
			),
		}),
	})

	if customRenderer and customContent then
		return e("CanvasGroup", wrapperProps, {
			Custom = customContent,
			Accessory = renderedAccessory and e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.new(1, 0, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				ZIndex = 5,
			}, {
				Accessory = renderedAccessory,
			}) or nil,
			OverrideBar = overrideBarElement,
		})
	end

	return e("CanvasGroup", wrapperProps, {
		Accessory = renderedAccessory and e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.new(1, 0, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			ZIndex = 5,
		}, {
			Accessory = renderedAccessory,
		}) or nil,
		OverrideBar = overrideBarElement,
		ScrollFade = scrollFade,
	})
end
