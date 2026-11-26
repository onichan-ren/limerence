local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local SPRING = require("@ui/util/spring")
local layout = require("@feature/inventory/skinUi/layout")
local dpiState = require("@ui/util/dpiState")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useRef = React.useRef
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local e = React.createElement

local windowColors = themeState.colors.window
local elementColors = themeState.colors.window.element

local TAB_PADDING_X = layout.TAB_PADDING_X
local CONTENT_PAD_X = layout.CONTENT_PAD_X
local TAB_HEIGHT = layout.TAB_HEIGHT
local INDICATOR_HEIGHT = 2

export type TypeTab = {
	id: string,
	label: string,
}

export type TypeTabsProps = {
	Tabs: { TypeTab },
	SelectedAtom: any,
	OnPicked: ((id: string) -> ())?,
}

type TabSlot = {
	id: string,
	x: number,
	width: number,
}

type TabButtonProps = {
	Id: string,
	Label: string,
	Selected: boolean,
	LayoutOrder: number,
	OnPick: (id: string) -> (),
	OnMeasure: (id: string, x: number, width: number) -> (),
}

local function TabButton(props: TabButtonProps): React.Element<any>
	local hoveredRef = useRef(false)

	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		activeAtom(props.Selected or hoveredRef.current)
	end, { props.Selected })

	local textColor = useAdvColor(windowColors.tabLabel, windowColors.tabLabelSelected, activeAtom)

	local buttonRef = useRef(nil :: TextButton?)

	useEffect(function()
		local btn = buttonRef.current
		if not btn then
			return
		end
		local function measure()
			local size = btn.AbsoluteSize
			local pos = btn.AbsolutePosition
			local parent = btn.Parent :: GuiObject?
			if not parent then
				return
			end
			local scale = Charm.peek(dpiState.scale)
			if scale <= 0 then
				scale = 1
			end
			local relX = (pos.X - parent.AbsolutePosition.X) / scale
			props.OnMeasure(props.Id, relX, size.X / scale)
		end
		measure()
		local c1 = btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(measure)
		local c2 = btn:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		return function()
			c1:Disconnect()
			c2:Disconnect()
		end
	end, { props.Id, props.OnMeasure } :: { any })

	local onClick = useCallback(function()
		props.OnPick(props.Id)
	end, { props.OnPick, props.Id } :: { any })

	local onEnter = useCallback(function()
		hoveredRef.current = true
		activeAtom(true)
		textColor.onMouseEnter()
	end, { textColor } :: { any })

	local onLeave = useCallback(function()
		hoveredRef.current = false
		activeAtom(props.Selected)
		textColor.onMouseLeave()
	end, { textColor, props.Selected } :: { any })

	return e("TextButton", {
		ref = buttonRef,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseButton1Click] = onClick,
		[React.Event.MouseEnter] = onEnter,
		[React.Event.MouseLeave] = onLeave,
	}, {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, TAB_PADDING_X),
			PaddingRight = UDim.new(0, TAB_PADDING_X),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = props.Label,
			TextColor3 = textColor.binding,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		}),
	})
end

return function(props: TypeTabsProps): React.Element<any>
	local selectedType = useAt(props.SelectedAtom)
	local dividerColor = useAt(windowColors.divider)
	local accentColor = useAt(elementColors.textActive)

	local slots, setSlots = useState({} :: { [string]: TabSlot })

	local onMeasure = useCallback(function(id: string, x: number, width: number)
		setSlots(function(prev)
			local existing = prev[id]
			if existing and existing.x == x and existing.width == width then
				return prev
			end
			local copy: { [string]: TabSlot } = {}
			for k, v in next, prev do
				copy[k] = v
			end
			copy[id] = { id = id, x = x, width = width }
			return copy
		end)
	end, {})

	local onPick = useCallback(function(id: string)
		props.SelectedAtom(id)
		local picked = props.OnPicked
		if picked then
			picked(id)
		end
	end, { props.SelectedAtom, props.OnPicked } :: { any })

	local indicatorTarget = slots[selectedType]
	local indicatorX = indicatorTarget and indicatorTarget.x or 0
	local indicatorWidth = indicatorTarget and indicatorTarget.width or 0

	local xBind, xSpring = useSpring(indicatorX, SPRING.smoothPreciser)
	local wBind, wSpring = useSpring(indicatorWidth, SPRING.smoothPreciser)
	local visBind, visSpring = useSpring(indicatorTarget and 1 or 0, SPRING.smoothPreciser)

	useEffect(function()
		xSpring:setGoal(indicatorX)
	end, { indicatorX })

	useEffect(function()
		wSpring:setGoal(indicatorWidth)
	end, { indicatorWidth })

	useEffect(function()
		visSpring:setGoal(indicatorTarget and 1 or 0)
	end, { indicatorTarget ~= nil })

	local indicatorPosition = useMemo(function()
		return xBind:map(function(value: number)
			return UDim2.new(0, math.floor(value + TAB_PADDING_X), 1, -INDICATOR_HEIGHT)
		end)
	end, { xBind } :: { any })

	local indicatorSize = useMemo(function()
		return wBind:map(function(value: number)
			return UDim2.new(0, math.max(0, math.floor(value - TAB_PADDING_X * 2)), 0, INDICATOR_HEIGHT)
		end)
	end, { wBind } :: { any })

	local indicatorTransparency = useMemo(function()
		return visBind:map(function(value: number)
			return 1 - value
		end)
	end, { visBind } :: { any })

	local renderedTabs: { [string]: React.Element<any> } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
	}

	for index, tab in next, props.Tabs do
		renderedTabs[`Tab_{tab.id}`] = e(TabButton, {
			Id = tab.id,
			Label = tab.label,
			Selected = tab.id == selectedType,
			LayoutOrder = index,
			OnPick = onPick,
			OnMeasure = onMeasure,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
	}, {
		Content = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, -1),
		}, {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, CONTENT_PAD_X),
				PaddingRight = UDim.new(0, CONTENT_PAD_X),
			}),
			TabRow = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
			}, renderedTabs),
			Indicator = e("Frame", {
				BackgroundColor3 = accentColor,
				BackgroundTransparency = indicatorTransparency,
				BorderSizePixel = 0,
				Position = indicatorPosition,
				Size = indicatorSize,
				ZIndex = 3,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),
		}),
		Divider = e("Frame", {
			BackgroundColor3 = dividerColor,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 1),
		}),
	})
end
