local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local Sift = require("@pkg/Sift")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local SPRING = require("@ui/util/spring")
local cursorUtil = require("@ui/util/cursor")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useRef = React.useRef
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local e = React.createElement

local colors = themeState.colors.window.element
local subwindowColors = themeState.colors.subwindow

local HEADER_HEIGHT = 22
local FOOTER_HEIGHT = 24
local DEFAULT_ROW_HEIGHT = 26
local CANVAS_PADDING = 4
local STATUS_HEIGHT = 32
local MIN_COLUMN_PIXEL = 32

type Column = {
	id: string,
	name: string,
	weight: number?,
	minWidth: number?,
	align: ("left" | "center" | "right")?,
	formatter: ((value: any, row: { [string]: any }) -> string)?,
	renderer: ((row: { [string]: any }, value: any) -> any)?,
	headerRenderer: ((column: Column) -> any)?,
	sortable: boolean?,
	sortKey: ((row: { [string]: any }) -> any)?,
	searchValue: ((row: { [string]: any }) -> string)?,
}

type Row = { [string]: any }

export type TableRendererProperties = {
	Table: any,
	LayoutOrder: number?,
}

local function alignToEnum(align: ("left" | "center" | "right")?): Enum.TextXAlignment
	if align == "center" then
		return Enum.TextXAlignment.Center
	elseif align == "right" then
		return Enum.TextXAlignment.Right
	end
	return Enum.TextXAlignment.Left
end

local function getColumnWeight(column: Column): number
	local weight = column.weight
	if not weight or weight <= 0 then
		return 1
	end
	return weight
end

local function getColumnValue(column: Column, row: Row): any
	return row[column.id]
end

local function formatCellText(column: Column, row: Row, value: any): string
	if column.formatter then
		local ok, result = pcall(column.formatter, value, row)
		if ok and result ~= nil then
			return tostring(result)
		end
	end
	if value == nil then
		return ""
	end
	return tostring(value)
end

type HeaderCellProps = {
	Column: Column,
	Weight: number,
	LayoutOrder: number,
	SortActive: boolean,
	SortDirection: string,
	OnClick: ((column: Column) -> ())?,
}

local ARROW_WIDTH = 10

local HeaderCell = React.memo(function(props: HeaderCellProps): React.Element<any>
	local column = props.Column
	local sortable = column.sortable == true and props.OnClick ~= nil
	local hovered, setHovered = useState(false)

	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		activeAtom(props.SortActive or (sortable and hovered))
	end, { props.SortActive, hovered, sortable } :: { any })

	local labelColor = useAdvColor(colors.caption, colors.textActive, activeAtom)

	local arrowText: string? = nil
	if props.SortActive then
		arrowText = props.SortDirection == "desc" and "↓" or "↑"
	end

	local reserveArrow = arrowText ~= nil
	local labelSize = reserveArrow and UDim2.new(1, -(ARROW_WIDTH + 4), 1, 0) or UDim2.fromScale(1, 1)

	local cellChildren: { [string]: React.Element<any> } = {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
	}

	if column.headerRenderer then
		local ok, custom = pcall(column.headerRenderer, column)
		if ok and custom then
			cellChildren.Custom = custom
		end
	end

	if not cellChildren.Custom then
		cellChildren.Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "bold"),
			TextColor3 = labelColor.binding,
			TextSize = 12,
			Text = string.upper(column.name or column.id),
			TextXAlignment = alignToEnum(column.align),
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(0, 0),
			Size = labelSize,
		})

		if arrowText then
			cellChildren.Arrow = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = FileController.Get("font", "bold"),
				TextColor3 = labelColor.binding,
				TextSize = 11,
				Text = arrowText,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0, ARROW_WIDTH, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Center,
			})
		end
	end

	local inner: React.Element<any>
	if sortable then
		inner = e("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Active = false,
			Size = UDim2.fromScale(1, 1),
			[React.Event.MouseEnter] = function()
				setHovered(true)
				labelColor.onMouseEnter()
			end,
			[React.Event.MouseLeave] = function()
				setHovered(false)
				labelColor.onMouseLeave()
			end,
			[React.Event.MouseButton1Click] = function()
				if props.OnClick then
					props.OnClick(column)
				end
			end,
		}, cellChildren)
	else
		inner = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, cellChildren)
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(props.Weight, 0, 1, 0),
		LayoutOrder = props.LayoutOrder,
		ClipsDescendants = true,
	}, {
		UIFlexItem = e("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Fill,
			ItemLineAlignment = Enum.ItemLineAlignment.Stretch,
		}),
		Inner = inner,
	})
end)

type CellProps = {
	Column: Column,
	Row: Row,
	Weight: number,
	LayoutOrder: number,
	ActiveAtom: Charm.Atom<boolean>,
}

local Cell = React.memo(function(props: CellProps): React.Element<any>
	local column = props.Column
	local row = props.Row

	local textColor = useAdvColor(colors.text, colors.textActive, props.ActiveAtom)
	local value = getColumnValue(column, row)

	local cellContent: any
	if column.renderer then
		local ok, custom = pcall(column.renderer, row, value)
		if ok and custom then
			cellContent = custom
		end
	end

	if not cellContent then
		cellContent = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = textColor.binding,
			TextSize = 12,
			Text = formatCellText(column, row, value),
			TextXAlignment = alignToEnum(column.align),
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.fromScale(1, 1),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(props.Weight, 0, 1, 0),
		LayoutOrder = props.LayoutOrder,
		ClipsDescendants = true,
	}, {
		UIFlexItem = e("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Fill,
			ItemLineAlignment = Enum.ItemLineAlignment.Stretch,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		Content = cellContent,
	})
end)

type RowProps = {
	Row: Row,
	RowIndex: number,
	Columns: { Column },
	IsSelected: boolean,
	IsZebra: boolean,
	Height: number,
	LayoutOrder: number?,
	OnClick: (row: Row, index: number) -> (),
	OnContextMenu: (row: Row, index: number, position: UDim2) -> (),
}

local TableRow = React.memo(function(props: RowProps): React.Element<any>
	local row = props.Row
	local index = props.RowIndex
	local columns = props.Columns
	local isSelected = props.IsSelected

	local hovered, setHovered = useState(false)

	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		activeAtom(isSelected)
	end, { isSelected })

	local hoverBind, hoverSpring = useSpring(0, SPRING.quick)
	local selectedBind, selectedSpring = useSpring(0, SPRING.smoothPreciser)

	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	useEffect(function()
		selectedSpring:setGoal(isSelected and 1 or 0)
	end, { isSelected })

	local accentColor = useAt(colors.accentStrong)
	local panelColor = useAt(colors.panel)
	local fieldColor = useAt(colors.fieldBackground)

	local backgroundColorBind = useMemo(function()
		return React.joinBindings({ hoverBind, selectedBind }):map(function(values): Color3
			local hover: number = values[1]
			local selected: number = values[2]
			local base: Color3 = panelColor
			if props.IsZebra then
				base = base:Lerp(fieldColor, 0.35)
			end
			base = base:Lerp(fieldColor, hover * 0.45)
			base = base:Lerp(accentColor, selected * 0.18)
			return base
		end)
	end, { hoverBind, selectedBind, panelColor, fieldColor, accentColor, props.IsZebra } :: { any })

	local backgroundTransparencyBind = useMemo(function()
		return React.joinBindings({ hoverBind, selectedBind }):map(function(values): number
			local hover: number = values[1]
			local selected: number = values[2]
			if props.IsZebra or hover > 0 or selected > 0 then
				return 0
			end
			return 1
		end)
	end, { hoverBind, selectedBind, props.IsZebra } :: { any })

	local renderedCells: { [string]: React.Element<any> } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
		Indicator = e("Frame", {
			BackgroundColor3 = accentColor,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = selectedBind:map(function(value: number): UDim2
				return UDim2.new(0, 2, 0, math.floor(8 + value * 6))
			end),
			BackgroundTransparency = selectedBind:map(function(value: number): number
				return 1 - value
			end),
			ZIndex = 2,
		}),
	}

	for columnIndex, column in columns do
		renderedCells[`Cell_{column.id}_{columnIndex}`] = e(Cell, {
			Column = column,
			Row = row,
			Weight = getColumnWeight(column),
			LayoutOrder = columnIndex,
			ActiveAtom = activeAtom,
		})
	end

	return e(
		"TextButton",
		{
			BackgroundColor3 = backgroundColorBind,
			BackgroundTransparency = backgroundTransparencyBind,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Active = false,
			Size = UDim2.new(1, 0, 0, props.Height),
			LayoutOrder = props.LayoutOrder or index,
			ClipsDescendants = true,
			[React.Event.MouseEnter] = function()
				setHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				setHovered(false)
			end,
			[React.Event.MouseButton1Click] = function()
				props.OnClick(row, index)
			end,
			[React.Event.InputBegan] = function(_rbx: GuiObject, input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					props.OnContextMenu(row, index, cursorUtil.getPosition(input))
				end
			end :: any,
		},
		Sift.Dictionary.join({
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
		}, renderedCells)
	)
end)

type PageButtonProps = {
	Label: string,
	Icon: string?,
	Enabled: boolean,
	OnClick: () -> (),
	LayoutOrder: number,
}

local PageButton = React.memo(function(props: PageButtonProps): React.Element<any>
	local enabled = props.Enabled

	local hovered, setHovered = useState(false)
	local pressed, setPressed = useState(false)

	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		activeAtom(enabled and (hovered or pressed))
	end, { hovered, pressed, enabled })

	local background = useAdvColor(colors.surface, colors.accentSoft, activeAtom)
	local stroke = useAt(colors.surfaceStroke)
	local textColor = useAdvColor(colors.text, colors.textActive, activeAtom)

	return e("TextButton", {
		BackgroundColor3 = background.binding,
		BackgroundTransparency = enabled and 0 or 0.4,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = false,
		Text = "",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			if enabled then
				setHovered(true)
				background.onMouseEnter()
				textColor.onMouseEnter()
			end
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			setPressed(false)
			background.onMouseLeave()
			textColor.onMouseLeave()
		end,
		[React.Event.MouseButton1Down] = function()
			if enabled then
				setPressed(true)
			end
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
		end,
		[React.Event.MouseButton1Click] = function()
			if enabled then
				props.OnClick()
			end
		end,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIStroke = e("UIStroke", {
			Color = stroke,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = enabled and 0 or 0.5,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = textColor.binding,
			TextTransparency = enabled and 0 or 0.5,
			TextSize = 11,
			Text = props.Label,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
	})
end)

type RowDetailProps = {
	Content: any,
	Height: number,
	FullHeight: number,
	LayoutOrder: number,
	Visible: boolean,
}

local RowDetail = React.memo(function(props: RowDetailProps): React.Element<any>
	local revealBind, revealSpring = useSpring(0, SPRING.smoothPreciser)

	useEffect(function()
		revealSpring:setGoal(props.Visible and 1 or 0)
	end, { props.Visible } :: { any })

	return e("CanvasGroup", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, props.Height),
		LayoutOrder = props.LayoutOrder,
		GroupTransparency = revealBind:map(function(value: number): number
			return 1 - value
		end),
	}, {
		Inner = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, props.FullHeight),
			Position = revealBind:map(function(value: number): UDim2
				return UDim2.new(0, 0, 0, math.floor((1 - value) * -6))
			end),
		}, {
			Content = props.Content,
		}),
	})
end)

return function(properties: TableRendererProperties): React.Element<any>
	local tableElement = properties.Table
	local layoutOrder = properties.LayoutOrder or 1

	local columns = useAt(tableElement._columns) :: { Column }
	local rows = useAt(tableElement._rows) :: { Row }
	local rowKey = useAt(tableElement._rowKey) :: string
	local selectedKey = useAt(tableElement._selectedKey) :: string?
	local loading = useAt(tableElement._loading)
	local emptyText = useAt(tableElement._emptyText)
	local loadingText = useAt(tableElement._loadingText)
	local errorText = useAt(tableElement._errorText) :: string?
	local maxHeight = useAt(tableElement._maxHeight)
	local rowHeight = useAt(tableElement._rowHeight)
	local showPagination = useAt(tableElement._showPagination)
	local nextCursor = useAt(tableElement._nextCursor) :: string?
	local previousCursor = useAt(tableElement._previousCursor) :: string?
	local pageIndex = useAt(tableElement._pageIndex)
	local cooldownUntil = useAt(tableElement._cooldownUntil) :: number
	local search = useAt(tableElement._search) :: string
	local showSearch = useAt(tableElement._showSearch) :: boolean
	local searchPlaceholder = useAt(tableElement._searchPlaceholder) :: string
	local sortColumnId = useAt(tableElement._sortColumnId) :: string?
	local sortDirection = useAt(tableElement._sortDirection) :: string
	local labelText = useAt(tableElement._text)

	local _cooldownTick, setCooldownTick = useState(0)
	useEffect(function()
		local remaining = cooldownUntil - os.clock()
		if remaining <= 0 then
			return nil :: any
		end
		local timer = task.delay(remaining, function()
			setCooldownTick(function(value: number): number
				return value + 1
			end)
		end)
		return function()
			task.cancel(timer)
		end
	end, { cooldownUntil })

	local onCooldown = cooldownUntil > os.clock()

	local backgroundColor = useAt(colors.panel)
	local strokeColor = useAt(colors.panelStroke)
	local dividerColor = useAt(colors.panelStroke)
	local headerBackgroundColor = useAt(colors.surface)
	local mutedColor = useAt(colors.caption)
	local labelColor = useAdvColor(colors.text, colors.textActive, tableElement._active)
	local statusColor = useAt(subwindowColors.text)
	local searchTextColor = useAt(subwindowColors.text)
	local scrollThumbColor = useAt(colors.scrollThumb)

	local query = string.lower(search or "")
	local filteredRows = useMemo(function(): { Row }
		if query == "" then
			return rows
		end
		local result: { Row } = {}
		for _, row in next, rows do
			local matched = false
			for _, column in next, columns do
				local value: string
				if column.searchValue then
					local ok, computed = pcall(column.searchValue, row)
					value = (ok and type(computed) == "string") and computed or ""
				else
					local raw = row[column.id]
					if raw == nil then
						value = ""
					elseif column.formatter then
						local ok, formatted = pcall(column.formatter, raw, row)
						value = (ok and type(formatted) == "string") and formatted or tostring(raw)
					else
						value = tostring(raw)
					end
				end
				if value ~= "" and string.find(string.lower(value), query, 1, true) then
					matched = true
					break
				end
			end
			if matched then
				table.insert(result, row)
			end
		end
		return result
	end, { rows, columns, query } :: { any })

	local visibleRows = useMemo(function(): { Row }
		if not sortColumnId then
			return filteredRows
		end
		local sortColumn: Column? = nil
		for _, column in next, columns do
			if column.id == sortColumnId then
				sortColumn = column
				break
			end
		end
		if not sortColumn then
			return filteredRows
		end
		local copy = table.clone(filteredRows)
		local function getSortValue(row: Row): any
			if sortColumn.sortKey then
				local ok, value = pcall(sortColumn.sortKey, row)
				if ok then
					return value
				end
			end
			return row[sortColumn.id]
		end
		local ascending = sortDirection ~= "desc"
		table.sort(copy, function(a: Row, b: Row): boolean
			local av: any, bv: any = getSortValue(a), getSortValue(b)
			if av == nil and bv == nil then
				return false
			end
			if av == nil then
				return not ascending
			end
			if bv == nil then
				return ascending
			end
			if type(av) == "number" and type(bv) == "number" then
				if ascending then
					return av < bv
				end
				return av > bv
			end
			local as, bs = string.lower(tostring(av)), string.lower(tostring(bv))
			if ascending then
				return as < bs
			end
			return as > bs
		end)
		return copy
	end, { filteredRows, sortColumnId, sortDirection, columns } :: { any })

	local rowDetail = tableElement._rowDetail
	local rowDetailHeightSpec = tableElement._rowDetailHeight
	local selectedKeyStr = selectedKey ~= nil and tostring(selectedKey) or nil

	local detailKey, setDetailKey = useState(nil :: string?)
	local detailAnim, setDetailAnim = useState(0)
	local detailAnimRef = useRef(0)

	useEffect(function()
		if rowDetail ~= nil and selectedKeyStr ~= nil then
			setDetailKey(selectedKeyStr)
		end
	end, { selectedKeyStr } :: { any })

	local detailRow: Row? = nil
	local detailIndex: number? = nil
	if rowDetail ~= nil and detailKey ~= nil then
		for i = 1, #visibleRows do
			local candidate = visibleRows[i]
			local rawKey = candidate[rowKey]
			if rawKey ~= nil and tostring(rawKey) == detailKey then
				detailRow = candidate
				detailIndex = i
				break
			end
		end
	end

	local hasDetailRow = detailRow ~= nil
	useEffect(function()
		if detailKey ~= nil and not hasDetailRow then
			setDetailKey(nil)
		end
	end, { detailKey, hasDetailRow } :: { any })

	local detailOpen = detailKey ~= nil and detailKey == selectedKeyStr

	useEffect(function()
		if detailKey == nil then
			detailAnimRef.current = 0
			return nil :: any
		end
		if detailOpen then
			detailAnimRef.current = 1
			setDetailAnim(1)
			return nil :: any
		end
		local running = true
		task.spawn(function()
			while running and detailAnimRef.current > 0 do
				task.wait()
				if not running then
					return
				end
				local nextValue = detailAnimRef.current + (0 - detailAnimRef.current) * 0.28
				if nextValue < 0.01 then
					nextValue = 0
				end
				detailAnimRef.current = nextValue
				setDetailAnim(nextValue)
				if nextValue == 0 then
					setDetailKey(nil)
					return
				end
			end
		end)
		return function()
			running = false
		end
	end, { detailKey, detailOpen } :: { any })

	local detailHeight = 0
	if detailRow then
		if type(rowDetailHeightSpec) == "function" then
			local ok, value = pcall(rowDetailHeightSpec, detailRow)
			detailHeight = (ok and type(value) == "number") and value or 0
		elseif type(rowDetailHeightSpec) == "number" then
			detailHeight = rowDetailHeightSpec
		end
		if detailHeight < 0 then
			detailHeight = 0
		end
	end

	local detailAnimValue = detailOpen and 1 or detailAnim
	local renderedDetailHeight = math.floor(detailHeight * detailAnimValue + 0.5)

	local effectiveRowHeight = math.max(16, rowHeight or DEFAULT_ROW_HEIGHT)
	local rowCount = #visibleRows
	local hasRows = rowCount > 0
	local hasUnfilteredRows = #rows > 0
	local showStatus = (not hasRows) or errorText ~= nil

	local listContentHeight = rowCount * effectiveRowHeight + CANVAS_PADDING * 2 + renderedDetailHeight
	local statusBlockHeight = showStatus and STATUS_HEIGHT or 0
	local viewportContentHeight = math.max(statusBlockHeight, listContentHeight)
	local footerHeight = showPagination and FOOTER_HEIGHT or 0
	local searchBarHeight = showSearch and (HEADER_HEIGHT + 1) or 0
	local headerBlockHeight = searchBarHeight + HEADER_HEIGHT + 1

	local maxBodyHeight =
		math.max(STATUS_HEIGHT, maxHeight :: number - headerBlockHeight - footerHeight - (showPagination and 1 or 0))
	local bodyHeight = math.min(viewportContentHeight, maxBodyHeight)
	local needsScroll = listContentHeight > bodyHeight

	local totalHeight = headerBlockHeight + bodyHeight + (showPagination and (footerHeight + 1) or 0)

	local heightBind, heightSpring = useSpring(totalHeight, SPRING.snap)
	useEffect(function()
		heightSpring:setGoal(totalHeight)
	end, { totalHeight })

	local headerCells: { [string]: React.Element<any> } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
	}

	local onHeaderClick = useCallback(function(column: Column): ()
		tableElement:ToggleSort(column.id)
	end, { tableElement } :: { any })

	for columnIndex, column in columns do
		local active = sortColumnId == column.id
		headerCells[`Header_{column.id}_{columnIndex}`] = e(HeaderCell, {
			Column = column,
			Weight = getColumnWeight(column),
			LayoutOrder = columnIndex,
			SortActive = active,
			SortDirection = sortDirection,
			OnClick = onHeaderClick,
		})
	end

	local searchBar: React.Element<any>?
	if showSearch then
		searchBar = e("Frame", {
			BackgroundColor3 = headerBackgroundColor,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
			Position = UDim2.fromOffset(0, 0),
			ClipsDescendants = true,
		}, {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			Icon = e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = FileController.Get("image", "search"),
				ImageColor3 = mutedColor,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(10, 10),
			}),
			Input = e("TextBox", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = searchPlaceholder,
				PlaceholderColor3 = mutedColor,
				Text = search,
				TextColor3 = searchTextColor,
				TextSize = 12,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(1, -16, 1, 0),
				[React.Change.Text] = function(rbx: TextBox)
					tableElement._search(rbx.Text)
				end,
			}),
		})
	end

	local searchDivider = showSearch
			and e("Frame", {
				BackgroundColor3 = dividerColor,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, HEADER_HEIGHT),
				Size = UDim2.new(1, 0, 0, 1),
			})
		or nil

	local header = e("Frame", {
		BackgroundColor3 = headerBackgroundColor,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		Position = UDim2.fromOffset(0, searchBarHeight),
		ClipsDescendants = true,
	}, headerCells)

	local headerDivider = e("Frame", {
		BackgroundColor3 = dividerColor,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, searchBarHeight + HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 0, 1),
	})

	local onRowClick = useCallback(function(row: Row, index: number): ()
		tableElement:HandleRowClick(row, index)
	end, { tableElement } :: { any })

	local onRowContextMenu = useCallback(function(row: Row, index: number, position: UDim2): ()
		tableElement:HandleRowContextMenu(row, index, position)
	end, { tableElement } :: { any })

	local rowElements: { [string]: React.Element<any> } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0, CANVAS_PADDING),
			PaddingBottom = UDim.new(0, CANVAS_PADDING),
		}),
	}

	for rowIndex, row in visibleRows do
		local rawKey = row[rowKey]
		local keyString = rawKey ~= nil and tostring(rawKey) or `idx_{rowIndex}`
		local isSelected = selectedKey ~= nil and tostring(selectedKey) == keyString

		rowElements[`Row_{keyString}_{rowIndex}`] = e(TableRow, {
			Row = row,
			RowIndex = rowIndex,
			Columns = columns,
			IsSelected = isSelected,
			IsZebra = rowIndex % 2 == 0,
			Height = effectiveRowHeight,
			LayoutOrder = rowIndex * 2,
			OnClick = onRowClick,
			OnContextMenu = onRowContextMenu,
		})
	end

	if detailRow and detailHeight > 0 and renderedDetailHeight > 0 and rowDetail and detailKey then
		local ok, detailContent = pcall(rowDetail, detailRow)
		if ok and detailContent then
			rowElements[`Detail_{detailKey}`] = e(RowDetail, {
				Content = detailContent,
				Height = renderedDetailHeight,
				FullHeight = detailHeight,
				LayoutOrder = (detailIndex or 0) * 2 + 1,
				Visible = detailOpen,
			})
		end
	end

	local statusMessage: string
	local statusTone: Color3
	if errorText then
		statusMessage = errorText
		statusTone = statusColor
	elseif loading and not hasRows then
		statusMessage = loadingText
		statusTone = mutedColor
	elseif query ~= "" and hasUnfilteredRows then
		statusMessage = "No matches"
		statusTone = mutedColor
	else
		statusMessage = emptyText
		statusTone = mutedColor
	end

	local statusElement = showStatus
			and e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = FileController.Get("font", "semi_bold"),
				TextColor3 = statusTone,
				TextSize = 12,
				Text = statusMessage,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 2,
			})
		or nil

	local scrollBody = e(
		"ScrollingFrame",
		{
			Active = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, headerBlockHeight),
			Size = UDim2.new(1, 0, 0, bodyHeight),
			CanvasSize = UDim2.fromOffset(0, math.max(listContentHeight, bodyHeight)),
			AutomaticCanvasSize = Enum.AutomaticSize.None,
			ScrollingEnabled = needsScroll,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = needsScroll and 3 or 0,
			ScrollBarImageColor3 = scrollThumbColor,
			ScrollBarImageTransparency = needsScroll and 0.1 or 1,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			ClipsDescendants = true,
		},
		Sift.Dictionary.join({
			Status = statusElement,
		}, hasRows and rowElements or {})
	)

	local footer: React.Element<any>?
	if showPagination then
		local pageLabel = `Page {pageIndex}`
		if loading then
			pageLabel = pageLabel .. " · " .. loadingText
		end

		footer = e("Frame", {
			BackgroundColor3 = headerBackgroundColor,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
			Position = UDim2.fromOffset(0, headerBlockHeight + bodyHeight + 1),
		}, {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 3),
				PaddingRight = UDim.new(0, 3),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 3),
			}),
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			Previous = e(PageButton, {
				Label = "Previous",
				Enabled = previousCursor ~= nil and not loading and not onCooldown,
				OnClick = function()
					tableElement:PreviousPage()
				end,
				LayoutOrder = 0,
			}),
			Next = e(PageButton, {
				Label = "Next",
				Enabled = nextCursor ~= nil and not loading and not onCooldown,
				OnClick = function()
					tableElement:NextPage()
				end,
				LayoutOrder = 1,
			}),
			Spacer = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, 0),
				LayoutOrder = 2,
			}, {
				UIFlexItem = e("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Fill,
				}),
				PageLabel = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					FontFace = FileController.Get("font", "semi_bold"),
					TextColor3 = mutedColor,
					TextSize = 11,
					Text = pageLabel,
					Size = UDim2.fromScale(1, 1),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
			}),
			Refresh = e(PageButton, {
				Label = "Refresh",
				Enabled = not loading and not onCooldown,
				OnClick = function()
					tableElement:Refresh()
				end,
				LayoutOrder = 3,
			}),
		})
	end

	local footerDivider = showPagination
			and e("Frame", {
				BackgroundColor3 = dividerColor,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, headerBlockHeight + bodyHeight),
				Size = UDim2.new(1, 0, 0, 1),
			})
		or nil

	local hasLabel = labelText ~= nil and labelText ~= ""

	local labelRow: React.Element<any>?
	if hasLabel then
		labelRow = e("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = labelColor.binding,
			TextSize = 13,
			Text = labelText,
			Size = UDim2.new(1, 0, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
		})
	end

	local canvas = e("Frame", {
		BackgroundColor3 = backgroundColor,
		BorderSizePixel = 0,
		Size = heightBind:map(function(value: number): UDim2
			return UDim2.new(1, 0, 0, math.floor(value))
		end),
		LayoutOrder = 1,
		ClipsDescendants = true,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		SearchBar = searchBar,
		SearchDivider = searchDivider,
		Header = header,
		HeaderDivider = headerDivider,
		Body = scrollBody,
		FooterDivider = footerDivider,
		Footer = footer,
	})

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = layoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = labelRow,
		Canvas = canvas,
	})
end
