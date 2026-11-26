local TextService = cloneref(game:GetService("TextService")) :: TextService

local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local themeState = require("@ui/theme/themeState")
local FileController = require("@feature/file/FileController")
local sharedRefs = require("@ui/subwindow/sharedRefs")
local contextApi = require("@ui/subwindow/context/contextApi")
local useSubwindowAnimation = require("@ui/hook/useSubwindowAnimation")
local SPRING = require("@ui/util/spring")

local useSpring = ReactRipple.useSpring
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useState = React.useState
local useRef = React.useRef
local useAt = ReactCharm.useAtom
local e = React.createElement
local memo = React.memo

local DEFAULT_HOVER_DELAY = 0.15
local SCROLL_THRESHOLD = 5
local SCROLL_VISIBLE = 5
local ITEM_HEIGHT = 22
local DIVIDER_HEIGHT = 7
local PADDING_Y = 6
local MAX_WIDTH = 220
local ROW_TEXT_SIZE = 13
local ROW_PAD_LEFT = 8
local ROW_PAD_RIGHT = 10
local ICON_SIZE = 13
local ICON_TEXT_GAP = 6

local colors = themeState.colors.subwindow
local elementColors = themeState.colors.window.element

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
	if chars then
		return chars * ROW_TEXT_SIZE * 0.53
	end
	return #label * ROW_TEXT_SIZE * 0.53
end

local function computeMenuWidth(itemsList: { any }): number
	local maxPx = ROW_PAD_LEFT + ROW_PAD_RIGHT
	for _, entry in itemsList do
		if entry.Divider then
			continue
		end
		local txt = measuredLabelWidth(entry.Label or "")
		local row = ROW_PAD_LEFT + ROW_PAD_RIGHT + txt
		if entry.Icon then
			row += ICON_SIZE + ICON_TEXT_GAP
		end
		if row > maxPx then
			maxPx = row
		end
	end
	return math.min(MAX_WIDTH, math.max(2, math.ceil(maxPx)))
end

local ContextButton = memo(function(props: {
	Label: string,
	Icon: string?,
	Callback: (() -> ())?,
	OnHoverEnter: (() -> ())?,
	OnHoverLeave: (() -> ())?,
	HoverDelay: number?,
	OnClose: () -> (),
	IsContextOpen: boolean,
	Items: { any },
	LayoutOrder: number,
	FillWidth: boolean,
}): React.Element<any>
	local label = props.Label
	local icon = props.Icon
	local callback = props.Callback
	local onClose = props.OnClose
	local fillWidth = props.FillWidth

	local isHovering, setHovering = useState(false)
	local imageColor = useAt(colors.image)
	local textColor = useAt(colors.text)
	local rowHoverColor = useAt(elementColors.rowHover)

	local bind, spring = useSpring(0, SPRING.snap)

	local lastIcon = useRef(props.Icon)
	local lastItems = useRef(props.Items)
	if props.Icon then
		lastIcon.current = props.Icon
	elseif props.Items ~= lastItems.current then
		lastIcon.current = nil
	end
	lastItems.current = props.Items
	local iconAlpha, iconSpring = useSpring(props.Icon and 0 or 1, SPRING.quick)
	useEffect(function()
		iconSpring:setGoal(props.Icon and 0 or 1)
	end, { props.Icon })

	local hoverTimerRef = useRef(nil :: thread?)
	local hoverFiredRef = useRef(false)
	local onHoverEnterRef = useRef(props.OnHoverEnter)
	local onHoverLeaveRef = useRef(props.OnHoverLeave)
	onHoverEnterRef.current = props.OnHoverEnter
	onHoverLeaveRef.current = props.OnHoverLeave

	local function clearHover(): ()
		if hoverTimerRef.current then
			task.cancel(hoverTimerRef.current)
			hoverTimerRef.current = nil
		end
		if hoverFiredRef.current then
			hoverFiredRef.current = false
			local leave = onHoverLeaveRef.current
			if leave then
				leave()
			end
		end
	end

	useEffect(function()
		spring:setGoal(isHovering and 1 or 0)
	end, { isHovering })

	useEffect(function()
		if not props.IsContextOpen then
			clearHover()
		end
	end, { props.IsContextOpen })

	useEffect(function()
		return function()
			clearHover()
		end
	end, {})

	local children: { [string]: React.Element<any>? } = {
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, ICON_TEXT_GAP),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, ROW_PAD_LEFT),
			PaddingRight = UDim.new(0, ROW_PAD_RIGHT),
			PaddingTop = UDim.new(0, 0),
			PaddingBottom = UDim.new(0, 0),
		}),
	}

	if lastIcon.current then
		children.Image = e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
			Image = lastIcon.current,
			ImageColor3 = imageColor,
			ImageTransparency = iconAlpha,
		})
		children.TextHold = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 2,
		}, {
			UIFlexItem = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
				ItemLineAlignment = Enum.ItemLineAlignment.Stretch,
			}),
			Text = e("TextLabel", {
				TextSize = ROW_TEXT_SIZE,
				TextColor3 = textColor,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = label,
				BorderSizePixel = 0,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				FontFace = FileController.Get("font", "semi_bold"),
			}),
		})
	else
		children.Text = e("TextLabel", {
			TextSize = ROW_TEXT_SIZE,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.X,
			Text = label,
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, ROW_TEXT_SIZE),
			LayoutOrder = 2,
			FontFace = FileController.Get("font", "semi_bold"),
		})
	end

	return e("TextButton", {
		BackgroundColor3 = rowHoverColor,
		BackgroundTransparency = bind:map(function(value: number)
			return 1 - (value * 0.03)
		end),
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutomaticSize = fillWidth and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		Size = fillWidth and UDim2.new(1, 0, 0, ITEM_HEIGHT) or UDim2.new(0, 0, 0, ITEM_HEIGHT),
		AutoButtonColor = false,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseButton1Click] = function()
			clearHover()
			onClose()
			if callback then
				callback()
			end
		end,
		[React.Event.MouseEnter] = function()
			setHovering(true)
			local enter = onHoverEnterRef.current
			if enter then
				if hoverTimerRef.current then
					task.cancel(hoverTimerRef.current)
				end
				local delay = props.HoverDelay or DEFAULT_HOVER_DELAY
				hoverTimerRef.current = task.delay(delay, function()
					hoverTimerRef.current = nil
					hoverFiredRef.current = true
					local fn = onHoverEnterRef.current
					if fn then
						fn()
					end
				end)
			end
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
			clearHover()
		end,
	}, children)
end)

local Divider = memo(function(props: { LayoutOrder: number }): React.Element<any>
	local dividerColor = useAt(colors.divider)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, DIVIDER_HEIGHT),
		LayoutOrder = props.LayoutOrder,
	}, {
		Line = e("Frame", {
			BackgroundColor3 = dividerColor,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
		}),
	})
end)

return function(properties: { Context: any }): React.Element<any>
	local context = properties.Context

	local backgroundColor = useAt(colors.background)
	local strokeColor = useAt(colors.stroke)
	local scrollThumbColor = useAt(elementColors.scrollThumb)

	local items = useAt(context._items)
	local isContextOpen = useAt(context._isOpen)

	local anim = useSubwindowAnimation(context, {
		preset = SPRING.snap,
		slideOffset = 6,
		strokeIntensity = 0.6,
		floatingId = "subwindow.context",
		onClickOutside = function()
			if contextApi.WasJustOpened() then
				return
			end
			context:Close()
		end,
	})

	useEffect(function()
		sharedRefs.context = anim.frameRef
		return function()
			sharedRefs.context = nil
		end
	end, {})

	local close = useCallback(function(): ()
		context:Close()
	end, { context } :: { any })

	local nonDividerCount = 0
	local dividerCount = 0
	for _, item in items do
		if item.Divider then
			dividerCount += 1
		else
			nonDividerCount += 1
		end
	end
	local needsScroll = nonDividerCount > SCROLL_THRESHOLD
	local naturalHeight = nonDividerCount * ITEM_HEIGHT + dividerCount * DIVIDER_HEIGHT + PADDING_Y * 2

	local menuWidth = useMemo(function(): number
		return computeMenuWidth(items)
	end, { items })

	local renderedChildren = useMemo(function(): { [string]: React.Element<any> }
		local built: { [string]: React.Element<any> } = {}
		for index, item in items do
			if item.Divider then
				built[`Divider_{index}`] = e(Divider, { LayoutOrder = index })
			else
				built[`Item_{index}_{item.Label or ""}`] = e(ContextButton, {
					Label = item.Label or "",
					Icon = item.Icon,
					Callback = item.Callback,
					OnHoverEnter = item.OnHoverEnter,
					OnHoverLeave = item.OnHoverLeave,
					HoverDelay = item.HoverDelay,
					OnClose = close,
					IsContextOpen = isContextOpen,
					Items = items,
					LayoutOrder = index,
					FillWidth = true,
				})
			end
		end
		return built
	end, { items, isContextOpen, close } :: { any })

	local body: React.Element<any>
	if needsScroll then
		local scrollHeight = SCROLL_VISIBLE * ITEM_HEIGHT + PADDING_Y * 2

		body = e("CanvasGroup", {
			ref = anim.frameRef,
			BackgroundTransparency = 0,
			BackgroundColor3 = backgroundColor,
			Size = UDim2.fromOffset(menuWidth, scrollHeight),
			AutomaticSize = Enum.AutomaticSize.None,
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
			Scroll = e(
				"ScrollingFrame",
				{
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, 0),
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollBarThickness = 3,
					ScrollBarImageColor3 = scrollThumbColor,
					ScrollBarImageTransparency = 0.2,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					VerticalScrollBarInset = Enum.ScrollBarInset.None,
					ZIndex = 1,
				},
				Sift.Dictionary.join({
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 0),
						PaddingRight = UDim.new(0, 0),
						PaddingTop = UDim.new(0, PADDING_Y),
						PaddingBottom = UDim.new(0, PADDING_Y),
					}),
					UIListLayout = e("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Top,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 0),
					}),
				}, renderedChildren)
			),
		})
	else
		body = e("CanvasGroup", {
			ref = anim.frameRef,
			BackgroundTransparency = 0,
			BackgroundColor3 = backgroundColor,
			Size = UDim2.fromOffset(menuWidth, naturalHeight),
			AutomaticSize = Enum.AutomaticSize.None,
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
			Items = e(
				"Frame",
				{
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, 0),
					ZIndex = 1,
				},
				Sift.Dictionary.join({
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 0),
						PaddingRight = UDim.new(0, 0),
						PaddingTop = UDim.new(0, PADDING_Y),
						PaddingBottom = UDim.new(0, PADDING_Y),
					}),
					UIListLayout = e("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Top,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 0),
					}),
				}, renderedChildren)
			),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = anim.position,
		Visible = anim.visible,
		ZIndex = anim.zIndex,
	}, {
		Body = body,
	})
end
