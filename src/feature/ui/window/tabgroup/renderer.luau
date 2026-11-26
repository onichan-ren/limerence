local Charm = require("@pkg/Charm")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local ThemeState = require("@ui/theme/themeState")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")
local FileController = require("@src/feature/file/FileController")
local windowState = require("@ui/window/windowState")
local SPRING = require("@ui/util/spring")

local useAdvColor = require("@ui/hook/useAdvColor")
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local useMemo = React.useMemo
local useCallback = React.useCallback
local useRef = React.useRef
local useState = React.useState
local useAt = ReactCharm.useAtom
local peek = Charm.peek
local e = React.createElement

local openTab = windowState.openTab
local colors = ThemeState.colors.window

local STROKE_PAD = 2
local TITLE_HEIGHT = 14
local TAB_BUTTON_HEIGHT = 28
local SUBTAB_BUTTON_HEIGHT = 24
local SUBTAB_INDENT = 12
local LIST_GAP = 6

type TabGroupRendererProps = {
	TabGroup: any,
}
type TabButtonProps = {
	tab: any,
	sub: boolean?,
}

local function isExpanded(tab: any, openNow: any): boolean
	if not openNow then
		return false
	end
	return openNow == tab or openNow._parent == tab
end

local function TabButton(props: TabButtonProps): React.Element<any>
	local tab = props.tab
	local sub = props.sub

	local tabStrokeColor = useAt(colors.tabStroke)
	local tabIconColor = useAt(colors.tabIcon)

	local setIsOpen = tab._isOpen
	local isOpen = useAt(setIsOpen)

	local backgroundColor = useAdvColor(colors.sidebar, colors.tabSurface, setIsOpen)
	local textColor = useAdvColor(colors.tabLabel, colors.tabLabelSelected, setIsOpen)

	local subtabs = useAt(tab._subtabs)
	local openNow = useAt(openTab)
	local expanded = not sub and #subtabs > 0 and isExpanded(tab, openNow)

	local strokeBind, strokeSpring = ReactRipple.useSpring(0, {
		tension = 700,
		friction = 50,
	})
	local expandBind, expandSpring = ReactRipple.useSpring(0, {
		tension = 700,
		friction = 50,
	})

	useEffect(function()
		strokeSpring:setGoal(isOpen and 1 or 0)
		if isOpen then
			backgroundColor.onMouseLeave()
		end
	end, { isOpen })

	useEffect(function()
		expandSpring:setGoal(expanded and 1 or 0)
	end, { expanded })

	local isOpenRef = useRef(isOpen)
	isOpenRef.current = isOpen
	local tabRef = useRef(tab)
	tabRef.current = tab

	local onMouseEnter = useMemo(function()
		return function()
			if isOpenRef.current then
				return
			end
			backgroundColor.onMouseEnter()
		end
	end, { backgroundColor } :: { any })

	local onMouseLeave = useMemo(function()
		return function()
			backgroundColor.onMouseLeave()
		end
	end, { backgroundColor } :: { any })

	local onClick = useCallback(function()
		local current = tabRef.current
		local subs = peek(current._subtabs)
		if #subs > 0 then
			openTab(peek(current._activeSubtab) or subs[1])
		else
			openTab(current)
		end
		windowState.searchQuery("")
	end, {})

	local strokeTransparencyBind = useMemo(function()
		return strokeBind:map(function(value: number)
			return 1 - value
		end)
	end, { strokeBind } :: { any })

	local renderedSubtabs = useMemo(function()
		if sub or #subtabs == 0 then
			return {}
		end
		return Sift.Array.map(subtabs, function(subtab)
			return e(TabButton, {
				tab = subtab,
				sub = true,
			})
		end)
	end, { subtabs, sub } :: { any })

	local subBlockHeight = #subtabs * (SUBTAB_BUTTON_HEIGHT + LIST_GAP)

	local containerSizeBind = useMemo(function()
		return expandBind:map(function(value: number)
			return UDim2.new(1, 0, 0, TAB_BUTTON_HEIGHT + math.floor(value * (subBlockHeight + 1) + 0.5))
		end)
	end, { expandBind, subBlockHeight } :: { any })

	local buttonHeight = sub and SUBTAB_BUTTON_HEIGHT or TAB_BUTTON_HEIGHT
	local iconSize = sub and 12 or 14
	local textOffset = sub and 28 or 31
	local textSize = sub and 12 or 13

	local button = e("TextButton", {
		BackgroundColor3 = backgroundColor.binding,
		LayoutOrder = 0,
		[React.Event.MouseEnter] = onMouseEnter,
		[React.Event.MouseLeave] = onMouseLeave,
		[React.Event.MouseButton1Click] = onClick,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Position = sub and UDim2.fromOffset(SUBTAB_INDENT, 0) or nil,
		Size = sub and UDim2.new(1, -SUBTAB_INDENT, 1, 0) or UDim2.new(1, 0, 0, buttonHeight),
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		UIStroke = e("UIStroke", {
			Color = tabStrokeColor,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = strokeTransparencyBind,
			Thickness = 1,
		}),
		TabIcon = e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 8, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.fromOffset(iconSize, iconSize),
			Image = tab.icon,
			ImageColor3 = tabIconColor,
		}),
		TabText = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, textOffset, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Text = tab.title,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = textColor.binding,
			TextSize = textSize,
			Size = UDim2.fromOffset(0, 14),
			AutomaticSize = Enum.AutomaticSize.X,
		}),
	})

	if sub then
		return e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = tab.layoutOrder or 2,
			Size = UDim2.new(1, 0, 0, SUBTAB_BUTTON_HEIGHT),
		}, {
			Button = button,
		})
	end

	if #subtabs == 0 then
		return e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = tab.layoutOrder or 2,
			Size = UDim2.new(1, 0, 0, TAB_BUTTON_HEIGHT),
		}, {
			Button = button,
		})
	end

	return e(
		"Frame",
		{
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = tab.layoutOrder or 2,
			Size = containerSizeBind,
			ClipsDescendants = true,
		},
		Sift.Dictionary.join({
			UIPadding = e("UIPadding", {
				PaddingRight = UDim.new(0, 1),
			}),
			UIListLayout = e("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, LIST_GAP),
			}),
			Button = button,
		}, renderedSubtabs)
	)
end

return function(props: TabGroupRendererProps): React.Element<any>
	local tabGroup = props.TabGroup
	local layoutOrder = tabGroup.layoutOrder or 1

	local tabHeadingColor = useAt(colors.tabHeading)
	local tabs = useAt(tabGroup.tabs)
	local visible = useAt(tabGroup._visible)
	local openNow = useAt(openTab)

	local renderedTabButtons = useMemo(function()
		return Sift.Array.map(tabs, function(tab)
			return e(TabButton, {
				tab = tab,
			})
		end)
	end, { tabs })

	local heldPaddedRef = useRef(0)
	local _, bumpLayout = useState(0)

	local tabCount = #tabs
	local contentHeight = tabCount == 0 and 0 or (TITLE_HEIGHT + tabCount * (TAB_BUTTON_HEIGHT + LIST_GAP))
	local paddedFull = contentHeight == 0 and 0 or (contentHeight + STROKE_PAD * 2)

	local expandedExtra = 0
	for _, tab in next, tabs do
		local subs = peek(tab._subtabs)
		if #subs > 0 and isExpanded(tab, openNow) then
			expandedExtra += #subs * (SUBTAB_BUTTON_HEIGHT + LIST_GAP) + 1
		end
	end

	local extraBind, extraSpring = useSpring(0, {
		tension = 700,
		friction = 50,
	})

	useEffect(function()
		extraSpring:setGoal(expandedExtra)
	end, { expandedExtra })

	useEffect(function()
		if paddedFull > 0 then
			heldPaddedRef.current = paddedFull
		end
	end, { paddedFull })

	local fadeGoal = visible and paddedFull > 0 and 0 or 1
	local groupTransparencyBind, groupTransparencySpring = useSpring(fadeGoal, SPRING.smooth)

	useEffect(function()
		groupTransparencySpring:setGoal(fadeGoal)
	end, { fadeGoal })

	useEffect(function()
		local disconnect = groupTransparencySpring:onComplete(function(value: number)
			if value < 0.99 then
				return
			end
			if peek(tabGroup._visible) then
				return
			end
			if #peek(tabGroup.tabs) > 0 then
				return
			end
			if heldPaddedRef.current <= 0 then
				return
			end
			heldPaddedRef.current = 0
			bumpLayout(function(n)
				return n + 1
			end)
		end)
		return disconnect
	end, { tabGroup, groupTransparencySpring })

	local layoutPadded = paddedFull > 0 and paddedFull or heldPaddedRef.current
	local sizeBind = useMemo(function()
		return extraBind:map(function(extra: number)
			return UDim2.new(1, 0, 0, math.max(0, layoutPadded + math.floor(extra + 0.5)))
		end)
	end, { extraBind, layoutPadded } :: { any })
	local outerSize = sizeBind
	local innerSize = sizeBind

	return e("CanvasGroup", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = outerSize,
		GroupTransparency = groupTransparencyBind,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, {
		Inner = e(
			"Frame",
			{
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 0),
				Size = innerSize,
				BorderSizePixel = 0,
			},
			Sift.Dictionary.join({
				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, STROKE_PAD),
					PaddingRight = UDim.new(0, STROKE_PAD),
					PaddingTop = UDim.new(0, STROKE_PAD),
					PaddingBottom = UDim.new(0, STROKE_PAD),
				}),
				UIListLayout = e("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Top,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, LIST_GAP),
				}),
				Title = e("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(0, 14),
					AutomaticSize = Enum.AutomaticSize.X,
					BorderSizePixel = 0,
					FontFace = FileController.Get("font", "semi_bold"),
					TextColor3 = tabHeadingColor,
					TextSize = 10,
					LayoutOrder = 0,
					Text = tabGroup.title,
				}),
			}, renderedTabButtons)
		),
	})
end
