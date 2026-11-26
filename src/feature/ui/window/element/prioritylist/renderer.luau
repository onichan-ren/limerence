local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local Charm = require("@pkg/Charm")
local themeState = require("@ui/theme/themeState")
local FileController = require("@feature/file/FileController")
local useAdvColor = require("@ui/hook/useAdvColor")
local cursor = require("@ui/util/cursor")
local SPRING = require("@ui/util/spring")

local useAt = ReactCharm.useAtom
local useSpring = ReactRipple.useSpring
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useState = React.useState
local useBinding = React.useBinding
local useRef = React.useRef
local memo = React.memo
local e = React.createElement

local colors = themeState.colors.window.element

local ROW_HEIGHT = 22
local CANVAS_PADDING_X = 4
local CANVAS_PADDING_Y = 4
local INDICATOR_WIDTH = 4
local RANK_WIDTH = 14
local GRIP_WIDTH = 6
local GRIP_HEIGHT = 10
local GRIP_DOT = 2

type RowProps = {
	Id: string,
	Index: number,
	Dragging: boolean,
	DragY: any,
	OnDragStart: (id: string) -> (),
}

local Row = memo(function(props: RowProps): React.Element<any>
	local id = props.Id
	local index = props.Index
	local dragging = props.Dragging
	local onDragStart = props.OnDragStart

	local isTop = index == 0

	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	local hovered, setHovered = useState(false)
	useEffect(function()
		activeAtom(isTop or dragging)
	end, { isTop, dragging })

	local textColor = useAdvColor(colors.caption, colors.textActive, activeAtom)
	local stripeColor = useAt(colors.accentStrong)
	local rowHoverColor = useAt(colors.rowHover)
	local surface = useAt(colors.surface)
	local captionColor = useAt(colors.caption)
	local rankColor = isTop and stripeColor or captionColor

	local posBind, posSpring = useSpring(index, SPRING.snap)
	useEffect(function()
		posSpring:setGoal(index)
	end, { index })

	local hoverBind, hoverSpring = useSpring(0, SPRING.snap)
	useEffect(function()
		hoverSpring:setGoal((hovered or dragging) and 1 or 0)
	end, { hovered, dragging })

	local stripeBind, stripeSpring = useSpring((isTop or dragging) and 1 or 0, SPRING.smoothPreciser)
	useEffect(function()
		stripeSpring:setGoal((isTop or dragging) and 1 or 0)
	end, { isTop, dragging })

	local slotPosition = useMemo(function()
		return posBind:map(function(i: number): UDim2
			return UDim2.new(0, 0, 0, CANVAS_PADDING_Y + i * ROW_HEIGHT)
		end)
	end, { posBind } :: { any })

	local dragPosition = useMemo(function()
		return props.DragY:map(function(y: number): UDim2
			return UDim2.new(0, 0, 0, y)
		end)
	end, { props.DragY } :: { any })

	local rowTransparencyBind = useMemo(function()
		return hoverBind:map(function(value: number): number
			return 1 - value * 0.10
		end)
	end, { hoverBind } :: { any })

	local stripeSizeBind = useMemo(function()
		return stripeBind:map(function(value: number): UDim2
			return UDim2.new(0, INDICATOR_WIDTH, 0, math.floor(4 + value * 8))
		end)
	end, { stripeBind } :: { any })

	local stripeTransparencyBind = useMemo(function()
		return stripeBind:map(function(value: number): number
			return 1 - value
		end)
	end, { stripeBind } :: { any })

	local gripTransparencyBind = useMemo(function()
		return hoverBind:map(function(value: number): number
			return 1 - value * 0.75
		end)
	end, { hoverBind } :: { any })

	local onMouseDown = useCallback(function(): ()
		onDragStart(id)
	end, { onDragStart, id } :: { any })

	local onMouseEnter = useMemo(function()
		return function(): ()
			setHovered(true)
			textColor.onMouseEnter()
		end
	end, { textColor } :: { any })

	local onMouseLeave = useMemo(function()
		return function(): ()
			setHovered(false)
			textColor.onMouseLeave()
		end
	end, { textColor } :: { any })

	local gripDots: { [string]: React.Element<any> } = {}
	for column = 0, 1 do
		for dotRow = 0, 2 do
			gripDots[`Dot_{column}_{dotRow}`] = e("Frame", {
				BackgroundColor3 = captionColor,
				BackgroundTransparency = gripTransparencyBind,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(column * (GRIP_DOT + 2), dotRow * (GRIP_DOT + 2)),
				Size = UDim2.fromOffset(GRIP_DOT, GRIP_DOT),
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			})
		end
	end

	return e("TextButton", {
		BackgroundColor3 = dragging and surface or rowHoverColor,
		BackgroundTransparency = dragging and 0 or rowTransparencyBind,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = false,
		Text = "",
		ZIndex = dragging and 5 or 1,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Position = dragging and dragPosition or slotPosition,
		[React.Event.MouseEnter] = onMouseEnter,
		[React.Event.MouseLeave] = onMouseLeave,
		[React.Event.MouseButton1Down] = onMouseDown,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIStroke = e("UIStroke", {
			Color = stripeColor,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
			Transparency = dragging and 0.5 or 1,
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
			Size = stripeSizeBind,
			BackgroundTransparency = stripeTransparencyBind,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
		Rank = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = tostring(index + 1),
			TextColor3 = rankColor,
			TextSize = 12,
			Position = UDim2.fromOffset(INDICATOR_WIDTH + 6, 0),
			Size = UDim2.new(0, RANK_WIDTH, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = id,
			TextColor3 = textColor.binding,
			TextSize = 12,
			Position = UDim2.fromOffset(INDICATOR_WIDTH + 6 + RANK_WIDTH, 0),
			Size = UDim2.new(1, -(INDICATOR_WIDTH + 6 + RANK_WIDTH + GRIP_WIDTH + 6), 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Grip = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(GRIP_WIDTH, GRIP_HEIGHT),
		}, gripDots),
	})
end)

export type PriorityListRendererProperties = {
	List: any,
	LayoutOrder: number?,
}

return function(properties: PriorityListRendererProperties): React.Element<any>
	local list = properties.List

	useAt(list._state)
	local order = list:GetOrder()
	local text = useAt(list._text)
	local panel = useAt(colors.panel)
	local panelStroke = useAt(colors.panelStroke)
	local labelColor = useAdvColor(colors.text, colors.textActive, list._active)

	local count = #order
	local orderKey = table.concat(order, "\0")

	local draggingId, setDraggingId = useState(nil :: string?)
	local dragY, setDragY = useBinding(0)
	local dragRef = useRef({ startCursorY = 0, startIndex = 0, count = 0 })

	local indexById = useMemo(function(): { [string]: number }
		local map: { [string]: number } = {}
		for i, id in order do
			map[id] = i - 1
		end
		return map
	end, { orderKey } :: { any })

	local onDragStart = useMemo(function()
		return function(id: string): ()
			local startIndex = indexById[id]
			if startIndex == nil then
				return
			end
			dragRef.current = {
				startCursorY = cursor.getPosition().Y.Offset,
				startIndex = startIndex,
				count = count,
			}
			setDragY(CANVAS_PADDING_Y + startIndex * ROW_HEIGHT)
			setDraggingId(id)
		end
	end, { indexById, count } :: { any })

	useEffect(function()
		if not draggingId then
			return
		end

		local moveConn = UserInputService.InputChanged:Connect(function(input: InputObject): ()
			if
				input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local data = dragRef.current
			local delta = cursor.getPosition().Y.Offset - data.startCursorY
			setDragY(CANVAS_PADDING_Y + data.startIndex * ROW_HEIGHT + delta)
			local newIndex = math.clamp(data.startIndex + math.floor(delta / ROW_HEIGHT + 0.5), 0, data.count - 1)
			list:MoveTo(draggingId, newIndex + 1)
		end)

		local endConn = UserInputService.InputEnded:Connect(function(input: InputObject): ()
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				setDraggingId(nil)
			end
		end)

		return function(): ()
			moveConn:Disconnect()
			endConn:Disconnect()
		end
	end, { draggingId } :: { any })

	local rows = useMemo(function(): { [string]: any }
		local built: { [string]: any } = {}
		for id, index in indexById do
			built["Row_" .. id] = e(Row, {
				Id = id,
				Index = index,
				Dragging = draggingId == id,
				DragY = dragY,
				OnDragStart = onDragStart,
			})
		end
		return built
	end, { indexById, draggingId, dragY, onDragStart } :: { any })

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = properties.LayoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = e("TextButton", {
			LayoutOrder = 0,
			BackgroundTransparency = 1,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = labelColor.binding,
			TextSize = 13,
			Text = text,
			Size = UDim2.new(1, 0, 0, 14),
			AutoButtonColor = false,
			Active = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			[React.Event.MouseEnter] = labelColor.onMouseEnter,
			[React.Event.MouseLeave] = labelColor.onMouseLeave,
		}),
		Canvas = e("Frame", {
			LayoutOrder = 1,
			BackgroundColor3 = panel,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, count * ROW_HEIGHT + CANVAS_PADDING_Y * 2),
			ClipsDescendants = true,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			UIStroke = e("UIStroke", {
				Color = panelStroke,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, CANVAS_PADDING_X),
				PaddingRight = UDim.new(0, CANVAS_PADDING_X),
			}),
			Rows = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, 0),
			}, rows),
		}),
	})
end
