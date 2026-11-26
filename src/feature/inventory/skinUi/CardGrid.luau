local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local Charm = require("@pkg/Charm")

local themeState = require("@ui/theme/themeState")
local dpiState = require("@ui/util/dpiState")
local layout = require("@feature/inventory/skinUi/layout")
local gridLayout = require("@feature/inventory/gridLayout")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useAt = ReactCharm.useAtom
local e = React.createElement

local colors = themeState.colors.window.element

local CARD_MIN_WIDTH = layout.CARD_MIN_WIDTH
local CARD_HEIGHT = layout.CARD_HEIGHT
local GRID_PADDING_X = layout.CONTENT_PAD_X
local OVERSCAN_ROWS = 2
local ROW_STRIDE = CARD_HEIGHT + gridLayout.GAP_Y

local function firstRowOf(scrollY: number): number
	return math.max(0, math.floor((scrollY - gridLayout.PADDING_Y) / ROW_STRIDE) - OVERSCAN_ROWS)
end

export type CardGridProps = {
	Entries: { any },
	RenderCard: (entry: any, index: number) -> React.Element<any>?,
	LeadingCard: ((layoutOrder: number) -> React.Element<any>)?,
}

local function localSize(absolute: Vector2): Vector2
	local scale = Charm.peek(dpiState.scale)
	if scale <= 0 then
		scale = 1
	end
	return absolute / scale
end

return function(props: CardGridProps): React.Element<any>
	local entries = props.Entries
	local renderCard = props.RenderCard
	local leadingCard = props.LeadingCard
	local leadingOffset = leadingCard and 1 or 0
	local totalCount = #entries + leadingOffset

	local scrollThumb = useAt(colors.scrollThumb)

	local scrollRef = useRef(nil :: ScrollingFrame?)
	local containerSize, setContainerSize = useState(Vector2.new(0, 0))
	local firstRow, setFirstRow = useState(0)

	useEffect(function()
		local scroll = scrollRef.current
		if not scroll then
			return
		end
		setContainerSize(localSize(scroll.AbsoluteSize))
		local lastRow = firstRowOf(scroll.CanvasPosition.Y)
		setFirstRow(lastRow)
		local sizeConn = scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			setContainerSize(localSize(scroll.AbsoluteSize))
		end)
		local posConn = scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			local row = firstRowOf(scroll.CanvasPosition.Y)
			if row ~= lastRow then
				lastRow = row
				setFirstRow(row)
			end
		end)
		return function()
			sizeConn:Disconnect()
			posConn:Disconnect()
		end
	end, {})

	useEffect(function()
		local scroll = scrollRef.current
		if scroll then
			scroll.CanvasPosition = Vector2.new(0, 0)
		end
		setFirstRow(0)
	end, { entries } :: { any })

	local computed = useMemo(function()
		local probe = gridLayout.compute(containerSize.X, CARD_MIN_WIDTH, CARD_HEIGHT, totalCount, GRID_PADDING_X, false)
		if probe.contentHeight > containerSize.Y then
			return gridLayout.compute(containerSize.X, CARD_MIN_WIDTH, CARD_HEIGHT, totalCount, GRID_PADDING_X, true)
		end
		return probe
	end, { containerSize, totalCount } :: { any })
	local needsScroll = computed.contentHeight > containerSize.Y
	local columns = computed.columns
	local cellWidth = computed.cellWidth
	local contentHeight = computed.contentHeight

	local rowsInView = math.ceil((containerSize.Y + ROW_STRIDE) / ROW_STRIDE) + OVERSCAN_ROWS * 2
	local startIndex = firstRow * columns + 1
	local endIndex = math.min(totalCount, (firstRow + rowsInView) * columns)

	local rendered = useMemo(
		function()
			local children: { [string]: React.Element<any> } = {}
			for index = startIndex, endIndex do
				local col = (index - 1) % columns
				local row = math.floor((index - 1) / columns)
				local position = UDim2.fromOffset(math.floor(col * (cellWidth + gridLayout.GAP_X)), row * ROW_STRIDE)
				local cellSize = UDim2.new(0, math.floor(cellWidth), 0, CARD_HEIGHT)

				if leadingCard and index == 1 then
					children.Card_leading = e("Frame", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Position = position,
						Size = cellSize,
						LayoutOrder = index,
					}, {
						Card = leadingCard(index),
					})
					continue
				end

				local entry = entries[index - leadingOffset]
				if not entry then
					continue
				end
				local card = renderCard(entry, index)
				if not card then
					continue
				end
				children[`Card_{entry.name}`] = e("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = position,
					Size = cellSize,
					LayoutOrder = index,
				}, {
					Card = card,
				})
			end
			return children
		end,
		{
			entries,
			cellWidth,
			columns,
			startIndex,
			endIndex,
			renderCard,
			leadingCard,
		} :: { any }
	)

	return e("ScrollingFrame", {
		ref = scrollRef,
		Active = false,
		Selectable = false,
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
			PaddingLeft = UDim.new(0, GRID_PADDING_X),
			PaddingRight = UDim.new(0, GRID_PADDING_X),
			PaddingTop = UDim.new(0, gridLayout.PADDING_Y),
			PaddingBottom = UDim.new(0, gridLayout.PADDING_Y),
		}),
		Content = e(React.Fragment, nil, rendered),
	})
end
