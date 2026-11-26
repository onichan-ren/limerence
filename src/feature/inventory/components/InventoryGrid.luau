local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local themeState = require("@ui/theme/themeState")
local InventoryCard = require("@feature/inventory/components/InventoryCard")
local inventoryAdapter = require("@feature/inventory/inventoryAdapter")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useAt = ReactCharm.useAtom
local e = React.createElement

local colors = themeState.colors.window.element
local gridLayout = require("@feature/inventory/gridLayout")
local Charm = require("@pkg/Charm")
local dpiState = require("@ui/util/dpiState")

local function localSize(absolute: Vector2): Vector2
	local scale = Charm.peek(dpiState.scale)
	if scale <= 0 then
		scale = 1
	end
	return absolute / scale
end

local CARD_MIN_WIDTH = 118
local CARD_HEIGHT = 178

export type InventoryGridProps = {
	Items: { inventoryAdapter.UIItem },
	OnDelete: ((id: string) -> ())?,
	GetMenuItems: ((item: inventoryAdapter.UIItem) -> { any })?,
}

return function(props: InventoryGridProps): React.Element<any>
	local items = props.Items

	local scrollThumb = useAt(colors.scrollThumb)

	local scrollRef = useRef(nil :: ScrollingFrame?)
	local containerSize, setContainerSize = useState(Vector2.new(0, 0))

	useEffect(function()
		local scroll = scrollRef.current
		if not scroll then
			return
		end
		setContainerSize(localSize(scroll.AbsoluteSize))
		local conn = scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			setContainerSize(localSize(scroll.AbsoluteSize))
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	local layoutProbe = gridLayout.compute(containerSize.X, CARD_MIN_WIDTH, CARD_HEIGHT, #items, nil, false)
	local needsScroll = layoutProbe.contentHeight > containerSize.Y
	local layout = (needsScroll and gridLayout.compute(containerSize.X, CARD_MIN_WIDTH, CARD_HEIGHT, #items, nil, true) or layoutProbe)
	local columns = layout.columns
	local cellWidth = layout.cellWidth
	local contentHeight = layout.contentHeight

	local onDelete = props.OnDelete
	local getMenuItems = props.GetMenuItems
	local rendered = useMemo(function()
		local children: { [string]: React.Element<any> } = {}
		for index, uiItem in next, items do
			children[`Card_{uiItem.id}`] = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, math.floor(cellWidth), 0, CARD_HEIGHT),
				LayoutOrder = index,
			}, {
				Card = e(InventoryCard, {
					Item = uiItem,
					LayoutOrder = index,
					OnDelete = onDelete,
					GetMenuItems = getMenuItems,
				}),
			})
		end
		return children
	end, { items, cellWidth, onDelete, getMenuItems } :: { any })

	return e("ScrollingFrame", {
		ref = scrollRef,
		Active = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, contentHeight),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollingEnabled = needsScroll,
		ScrollBarThickness = needsScroll and 3 or 0,
		ScrollBarImageColor3 = scrollThumb,
		ScrollBarImageTransparency = needsScroll and 0.1 or 1,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
	}, {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, gridLayout.PADDING_X),
			PaddingRight = UDim.new(0, gridLayout.PADDING_X),
			PaddingTop = UDim.new(0, gridLayout.PADDING_Y),
			PaddingBottom = UDim.new(0, gridLayout.PADDING_Y),
		}),
		UIGridLayout = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(gridLayout.GAP_X, gridLayout.GAP_Y),
			CellSize = UDim2.new(0, math.floor(cellWidth), 0, CARD_HEIGHT),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = columns,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			StartCorner = Enum.StartCorner.TopLeft,
		}),
		Content = e(React.Fragment, nil, rendered),
	})
end
