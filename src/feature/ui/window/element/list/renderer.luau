local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local Sift = require("@pkg/Sift")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local useTooltip = require("@ui/hook/useTooltip")
local SPRING = require("@ui/util/spring")
local Charm = require("@pkg/Charm")
local contextApi = require("@ui/subwindow/context/contextApi")
local cursor = require("@ui/util/cursor")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useRef = React.useRef
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local memo = React.memo
local e = React.createElement

local colors = themeState.colors.window.element
local windowColors = themeState.colors.window
local subwindowColors = themeState.colors.subwindow

local ROW_HEIGHT = 22
local ROW_PADDING = 0
local SEARCH_HEIGHT = 22
local CANVAS_PADDING_X = 4
local CANVAS_PADDING_Y = 4
local CANVAS_MIN_HEIGHT = 26
local INDICATOR_WIDTH = 4
local ICON_SIZE = 12
local META_WIDTH = 58
local META_TEXT_SIZE = 10
local LEAVE_DURATION = 0.18

export type ListRendererProperties = {
	List: any,
	LayoutOrder: number?,
}

type Item = {
	id: string,
	name: string?,
	icon: string?,
	trailingIcon: string?,
	meta: string?,
	header: boolean?,
	locked: boolean?,
}

type Filter = {
	id: string,
	name: string,
	sort: ((a: Item, b: Item) -> boolean)?,
}

type DisplayedItem = {
	id: string,
	name: string?,
	icon: string?,
	trailingIcon: string?,
	meta: string?,
	header: boolean?,
	locked: boolean?,
	leaving: boolean,
}

type RowProps = {
	Item: DisplayedItem,
	IsSelected: boolean,
	IsEditing: boolean,
	Renamable: boolean,
	Locked: boolean,
	LayoutOrder: number,
	OnPick: (id: string) -> (),
	OnBeginEdit: (id: string) -> (),
	OnCommitEdit: (newName: string) -> (),
	OnCancelEdit: () -> (),
}

local function Row(props: RowProps): React.Element<any>
	local item = props.Item
	local isSelected = props.IsSelected
	local isEditing = props.IsEditing
	local renamable = props.Renamable
	local locked = props.Locked
	local isLeaving = item.leaving
	local onPick = props.OnPick
	local onBeginEdit = props.OnBeginEdit
	local onCommitEdit = props.OnCommitEdit
	local onCancelEdit = props.OnCancelEdit

	local textBoxRef = useRef(nil :: TextBox?)

	useEffect(function()
		local box = textBoxRef.current
		if isEditing and box then
			box:CaptureFocus()
			box.CursorPosition = #box.Text + 1
			box.SelectionStart = 1
		end
	end, { isEditing })

	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	local hoverActive, setHoverActive = useState(false)
	useEffect(function()
		activeAtom(isSelected)
	end, { isSelected })

	local textColor = useAdvColor(colors.caption, colors.textActive, activeAtom)
	local iconColor = useAdvColor(colors.icon, colors.iconActive, activeAtom)
	local stripeColor = useAt(colors.accentStrong)
	local rowHoverColor = useAt(colors.rowHover)

	local progressBind, progressSpring = useSpring(0, SPRING.smoothPrecise)
	local hoverBind, hoverSpring = useSpring(0, SPRING.snap)
	local selectedBind, selectedSpring = useSpring(0, SPRING.smoothPreciser)

	useEffect(function()
		progressSpring:setGoal(not isLeaving and 1 or 0)
	end, { isLeaving })

	useEffect(function()
		hoverSpring:setGoal((hoverActive and not isLeaving) and 1 or 0)
	end, { hoverActive, isLeaving })

	useEffect(function()
		selectedSpring:setGoal(isSelected and 1 or 0)
	end, { isSelected })

	local hasIcon = item.icon ~= nil and item.icon ~= ""
	local hasTrailing = item.trailingIcon ~= nil and item.trailingIcon ~= ""
	local trailingReserve = hasTrailing and (ICON_SIZE + 6) or 0
	local hasMeta = item.meta ~= nil and item.meta ~= ""
	local metaReserve = hasMeta and (META_WIDTH + 6) or 0
	local metaColor = useAt(colors.caption)

	local iconBind, iconSpring = useSpring(hasIcon and 1 or 0, SPRING.smooth)
	useEffect(function()
		iconSpring:setGoal(hasIcon and 1 or 0)
	end, { hasIcon })

	local lastIcon, setLastIcon = useState(item.icon or "")
	useEffect(function()
		if hasIcon then
			setLastIcon(item.icon :: string)
		end
	end, { hasIcon, item.icon })

	local textOffsetBind = useMemo(function()
		return iconBind:map(function(value: number)
			return INDICATOR_WIDTH + 6 + value * (ICON_SIZE + 6)
		end)
	end, { iconBind } :: { any })

	local textPositionBind = useMemo(function()
		return textOffsetBind:map(function(value: number)
			return UDim2.fromOffset(value, 0)
		end)
	end, { textOffsetBind } :: { any })
	local textSizeBind = useMemo(function()
		return textOffsetBind:map(function(value: number)
			return UDim2.new(1, -(value + trailingReserve + metaReserve), 1, 0)
		end)
	end, { textOffsetBind, trailingReserve, metaReserve } :: { any })

	local indicatorSizeBind = useMemo(function()
		return selectedBind:map(function(value: number)
			return UDim2.new(0, INDICATOR_WIDTH, 0, math.floor(4 + value * 8))
		end)
	end, { selectedBind } :: { any })

	local indicatorTransparencyBind = useMemo(function()
		return selectedBind:map(function(value: number)
			return 1 - value
		end)
	end, { selectedBind } :: { any })

	local textTransparencyBind = useMemo(function()
		return progressBind:map(function(value: number)
			return 1 - value
		end)
	end, { progressBind } :: { any })

	local iconTransparencyBind = useMemo(function()
		return React.joinBindings({ progressBind, iconBind }):map(function(values)
			return 1 - values[1] * values[2]
		end)
	end, { progressBind, iconBind } :: { any })

	local rowTransparencyBind = useMemo(function()
		return React.joinBindings({ progressBind, hoverBind, selectedBind }):map(function(values)
			local strength = (values[2] * 0.10 + values[3] * 0.08) * values[1]
			return 1 - strength
		end)
	end, { progressBind, hoverBind, selectedBind } :: { any })

	local rowSizeBind = useMemo(function()
		return progressBind:map(function(value: number)
			return UDim2.new(1, 0, 0, math.floor(value * ROW_HEIGHT))
		end)
	end, { progressBind } :: { any })

	local onMouseEnter = useMemo(function()
		return function()
			setHoverActive(true)
			textColor.onMouseEnter()
			iconColor.onMouseEnter()
		end
	end, { textColor, iconColor } :: { any })

	local onMouseLeave = useMemo(function()
		return function()
			setHoverActive(false)
			textColor.onMouseLeave()
			iconColor.onMouseLeave()
		end
	end, { textColor, iconColor } :: { any })

	local itemRef = useRef(item)
	itemRef.current = item
	local isLeavingRef = useRef(isLeaving)
	isLeavingRef.current = isLeaving
	local isEditingRef = useRef(isEditing)
	isEditingRef.current = isEditing
	local isSelectedRef = useRef(isSelected)
	isSelectedRef.current = isSelected
	local renamableRef = useRef(renamable)
	renamableRef.current = renamable
	local lockedRef = useRef(locked)
	lockedRef.current = locked

	local onMouseClick = useCallback(function()
		if isLeavingRef.current or isEditingRef.current then
			return
		end
		if isSelectedRef.current and renamableRef.current and not lockedRef.current then
			onBeginEdit(itemRef.current.id)
		else
			onPick(itemRef.current.id)
		end
	end, { onPick, onBeginEdit } :: { any })

	local onFocusLost = useCallback(function(rbx: TextBox, _enterPressed: boolean, input: InputObject?)
		if input and input.KeyCode == Enum.KeyCode.Escape then
			onCancelEdit()
		else
			onCommitEdit(rbx.Text)
		end
	end, { onCommitEdit, onCancelEdit } :: { any })

	local children: { [string]: React.Element<any> } = {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 3),
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
			Size = indicatorSizeBind,
			BackgroundTransparency = indicatorTransparencyBind,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
		Text = isEditing and e("TextBox", {
			ref = textBoxRef,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = textColor.binding,
			TextSize = 12,
			Text = item.name or item.id,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Position = textPositionBind,
			Size = textSizeBind,
			MultiLine = false,
			TextWrapped = false,
			[React.Event.FocusLost] = onFocusLost,
		}) or e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = textColor.binding,
			TextSize = 12,
			Text = item.name or item.id,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = textPositionBind,
			Size = textSizeBind,
			TextTransparency = textTransparencyBind,
		}),
		Icon = e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = lastIcon,
			ImageColor3 = iconColor.binding,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, INDICATOR_WIDTH + 6, 0.5, 0),
			Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
			ImageTransparency = iconTransparencyBind,
		}),
		TrailingIcon = hasTrailing and e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = item.trailingIcon,
			ImageColor3 = iconColor.binding,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
			ImageTransparency = textTransparencyBind,
		}) or nil,
		Meta = hasMeta and e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = metaColor,
			TextSize = META_TEXT_SIZE,
			Text = item.meta,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -trailingReserve, 0.5, 0),
			Size = UDim2.new(0, META_WIDTH, 1, 0),
			TextTransparency = textTransparencyBind,
		}) or nil,
	}

	return e("TextButton", {
		BackgroundColor3 = rowHoverColor,
		BackgroundTransparency = rowTransparencyBind,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = rowSizeBind,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = onMouseEnter,
		[React.Event.MouseLeave] = onMouseLeave,
		[React.Event.MouseButton1Click] = onMouseClick,
	}, children)
end

local MemoRow = memo(Row, function(prev, next)
	if prev.IsSelected ~= next.IsSelected then
		return false
	end
	if prev.IsEditing ~= next.IsEditing then
		return false
	end
	if prev.Renamable ~= next.Renamable then
		return false
	end
	if prev.Locked ~= next.Locked then
		return false
	end
	if prev.LayoutOrder ~= next.LayoutOrder then
		return false
	end
	if prev.OnPick ~= next.OnPick then
		return false
	end
	if prev.OnBeginEdit ~= next.OnBeginEdit then
		return false
	end
	if prev.OnCommitEdit ~= next.OnCommitEdit then
		return false
	end
	if prev.OnCancelEdit ~= next.OnCancelEdit then
		return false
	end
	local pi = prev.Item
	local ni = next.Item
	return pi.id == ni.id
		and pi.name == ni.name
		and pi.icon == ni.icon
		and pi.trailingIcon == ni.trailingIcon
		and pi.meta == ni.meta
		and pi.leaving == ni.leaving
end)

type HeaderRowProps = {
	Item: DisplayedItem,
	LayoutOrder: number,
}

local function HeaderRow(props: HeaderRowProps): React.Element<any>
	local item = props.Item
	local captionColor = useAt(colors.caption)

	return e("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = FileController.Get("font", "semi_bold"),
		TextColor3 = captionColor,
		TextSize = 11,
		Text = item.name or item.id,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = props.LayoutOrder,
	}, {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, INDICATOR_WIDTH + 6),
			PaddingBottom = UDim.new(0, 3),
		}),
	})
end

local MemoHeaderRow = memo(HeaderRow, function(prev, next)
	if prev.LayoutOrder ~= next.LayoutOrder then
		return false
	end
	return prev.Item.id == next.Item.id and prev.Item.name == next.Item.name
end)

type FilterButtonProps = {
	OnOpen: () -> (),
	Tip: (string | { title: string?, body: string })?,
}

local function FilterButton(props: FilterButtonProps): React.Element<any>
	local onOpen = props.OnOpen

	local hovered, setHovered = useState(false)
	local hoverAccentAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		hoverAccentAtom(hovered)
	end, { hovered })

	local iconColor = useAdvColor(colors.filterIcon, colors.accentStrong, hoverAccentAtom)
	local buttonRef = useRef(nil :: GuiObject?)
	local tipHandlers = useTooltip(props.Tip, buttonRef)

	return e("TextButton", {
		ref = buttonRef,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		[React.Event.MouseEnter] = function()
			setHovered(true)
			tipHandlers.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			tipHandlers.onMouseLeave()
		end,
		[React.Event.MouseButton1Click] = function()
			onOpen()
		end,
	}, {
		Icon = e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = FileController.Get("image", "filter"),
			ImageColor3 = iconColor.binding,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
		}),
	})
end

local function buildSelectionLabel(items: { Item }, selectedId: string?): string
	if not selectedId then
		return ""
	end
	for _, it in items do
		if it.id == selectedId then
			return it.name or it.id
		end
	end
	return ""
end

return function(properties: ListRendererProperties): React.Element<any>
	local list = properties.List
	local layoutOrder = properties.LayoutOrder or 2

	local items = useAt(list._items) :: { Item }
	local selectedId = useAt(list._state) :: string?
	local search = useAt(list._search)
	local showSearch = useAt(list._showSearch)
	local maxHeight = useAt(list._maxHeight)
	local emptyText = useAt(list._emptyText)
	local placeholder = useAt(list._placeholder)
	local labelText = useAt(list._text)
	local filters = useAt(list._filters) :: { Filter }
	local filterId = useAt(list._filterId) :: string?
	local renamable = useAt(list._renamable)
	local editingId = useAt(list._editingId) :: string?

	local backgroundColor = useAt(colors.panel)
	local strokeColor = useAt(colors.panelStroke)
	local scrollThumbColor = useAt(colors.scrollThumb)
	local mutedColor = useAt(colors.caption)
	local searchMutedColor = useAt(windowColors.searchMuted)
	local searchActiveColor = useAt(subwindowColors.text)
	local dividerColor = useAt(colors.panelStroke)
	local labelColor = useAdvColor(colors.text, colors.textActive, list._active)

	local prevItemsRef = useRef(items)
	local leavingTimersRef = useRef({} :: { [string]: thread })
	local leavingItems, setLeavingItems = useState({} :: { [string]: Item })

	useEffect(function()
		local prev = prevItemsRef.current
		local nowById: { [string]: Item } = {}
		for _, it in items do
			nowById[it.id] = it
		end

		local newlyLeaving: { [string]: Item } = {}
		for _, it in prev do
			if not nowById[it.id] then
				newlyLeaving[it.id] = it
			end
		end

		setLeavingItems(function(prevLeaving)
			local result: { [string]: Item } = {}
			for id, it in prevLeaving do
				if not nowById[id] then
					result[id] = it
				end
			end
			for id, it in newlyLeaving do
				result[id] = it
			end
			return result
		end)

		prevItemsRef.current = items
	end, { items } :: { any })

	useEffect(function()
		local timers = leavingTimersRef.current
		for id in leavingItems do
			if not timers[id] then
				timers[id] = task.delay(LEAVE_DURATION, function()
					timers[id] = nil
					setLeavingItems(function(prev)
						local copy: { [string]: Item } = {}
						for k, v in prev do
							if k ~= id then
								copy[k] = v
							end
						end
						return copy
					end)
				end)
			end
		end
		for id, timer in timers do
			if not leavingItems[id] then
				task.cancel(timer)
				timers[id] = nil
			end
		end
		return nil :: any
	end, { leavingItems } :: { any })

	useEffect(function()
		return function()
			for _, timer in leavingTimersRef.current do
				task.cancel(timer)
			end
			leavingTimersRef.current = {}
		end
	end, {})

	local query = string.lower(search or "")

	local matchedLive, displayed = useMemo(function()
		local function matches(it: Item): boolean
			if query == "" then
				return true
			end
			local name = string.lower(it.name or it.id)
			return string.find(name, query, 1, true) ~= nil
		end

		local activeFilter: Filter? = nil
		if filterId then
			for _, f in filters do
				if f.id == filterId then
					activeFilter = f
					break
				end
			end
		end

		local live: { Item } = {}
		local liveIds: { [string]: true } = {}
		for _, it in items do
			liveIds[it.id] = true
			if matches(it) then
				table.insert(live, it)
			end
		end

		if activeFilter and activeFilter.sort then
			table.sort(live, activeFilter.sort)
		end

		local result: { DisplayedItem } = {}
		for _, it in live do
			table.insert(result, {
				id = it.id,
				name = it.name,
				icon = it.icon,
				trailingIcon = it.trailingIcon,
				meta = it.meta,
				header = it.header,
				locked = it.locked,
				leaving = false,
			})
		end
		for id, it in leavingItems do
			if not liveIds[id] and matches(it) then
				table.insert(result, {
					id = it.id,
					name = it.name,
					icon = it.icon,
					trailingIcon = it.trailingIcon,
					meta = it.meta,
					header = it.header,
					locked = it.locked,
					leaving = true,
				})
			end
		end

		return live, result
	end, { items, query, filterId, filters, leavingItems } :: { any })

	local hasFilters = #filters > 0
	local showHeader = showSearch or hasFilters

	local emptyListHeight = 32
	local visibleCount = #displayed
	local liveCount = #matchedLive
	local hasLive = liveCount > 0
	local listContentHeight = liveCount * ROW_HEIGHT + math.max(0, liveCount - 1) * ROW_PADDING + CANVAS_PADDING_Y * 2
	local renderedContentHeight = visibleCount * ROW_HEIGHT
		+ math.max(0, visibleCount - 1) * ROW_PADDING
		+ CANVAS_PADDING_Y * 2

	local innerPixelHeight = hasLive and listContentHeight or (math.max(emptyListHeight, listContentHeight))

	local emptyVisible = not hasLive
	local emptyBind, emptySpring = useSpring(emptyVisible and 1 or 0, SPRING.smooth)
	useEffect(function()
		emptySpring:setGoal(emptyVisible and 1 or 0)
	end, { emptyVisible })

	local searchBlockHeight = showHeader and (SEARCH_HEIGHT + 1) or 0
	local rawTarget = math.max(CANVAS_MIN_HEIGHT, searchBlockHeight + innerPixelHeight)
	local targetHeight = math.min(rawTarget, maxHeight)
	local viewportListHeight = math.max(0, targetHeight - searchBlockHeight)
	local needsScroll = innerPixelHeight > viewportListHeight

	local heightBind, heightSpring = useSpring(targetHeight, SPRING.smoothPreciser)
	useEffect(function()
		heightSpring:setGoal(targetHeight)
	end, { targetHeight })

	local listRef = useRef(list)
	listRef.current = list
	local selectedIdRef = useRef(selectedId)
	selectedIdRef.current = selectedId

	local pick = useCallback(function(id: string): ()
		local l = listRef.current
		if selectedIdRef.current == id then
			l._state(nil)
		else
			l._state(id)
		end
	end, {})

	local beginEdit = useCallback(function(id: string): ()
		listRef.current:BeginEdit(id)
	end, {})

	local commitEdit = useCallback(function(newName: string): ()
		listRef.current:CommitEdit(newName)
	end, {})

	local cancelEdit = useCallback(function(): ()
		listRef.current:CancelEdit()
	end, {})

	local renderedRows: { [string]: React.Element<any> } = {}
	for index, displayItem in displayed do
		if displayItem.header then
			renderedRows[`Header_{displayItem.id}`] = e(MemoHeaderRow, {
				Item = displayItem,
				LayoutOrder = index,
			})
		else
			renderedRows[`Row_{displayItem.id}`] = e(MemoRow, {
				Item = displayItem,
				IsSelected = (not displayItem.leaving) and displayItem.id == selectedId,
				IsEditing = (not displayItem.leaving) and displayItem.id == editingId,
				Renamable = renamable,
				Locked = displayItem.locked == true,
				LayoutOrder = index,
				OnPick = pick,
				OnBeginEdit = beginEdit,
				OnCommitEdit = commitEdit,
				OnCancelEdit = cancelEdit,
			})
		end
	end

	local emptyElement = e("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = FileController.Get("font", "semi_bold"),
		TextColor3 = mutedColor,
		TextSize = 12,
		Text = query ~= "" and "No matches" or emptyText,
		Size = UDim2.new(1, 0, 0, emptyListHeight),
		Position = UDim2.fromOffset(0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTransparency = emptyBind:map(function(value: number)
			return 1 - value
		end),
		ZIndex = 0,
	})

	local selectionLabel = buildSelectionLabel(items, selectedId)

	local SELECTION_DIM = 0.45
	local fadeBind, fadeSpring = useSpring(0, SPRING.quick)
	local displayedLabel, setDisplayedLabel = useState(selectionLabel)
	local displayedLabelRef = useRef(displayedLabel)
	displayedLabelRef.current = displayedLabel

	useEffect(function()
		if selectionLabel ~= displayedLabelRef.current then
			setDisplayedLabel(selectionLabel)
			fadeSpring:setPosition(SELECTION_DIM)
			fadeSpring:setGoal(0)
		end
	end, { selectionLabel })

	local searchTextActive = (search ~= nil and search ~= "")
	local searchDisplayColor = searchTextActive and searchActiveColor or searchMutedColor

	local function openFilterMenu()
		local menuItems: { contextApi.ContextItem } = {}
		table.insert(menuItems, {
			Label = "Default",
			Icon = filterId == nil and FileController.Get("image", "checkmark") or nil,
			Callback = function()
				list._filterId(nil)
			end,
		})
		if #filters > 0 then
			table.insert(menuItems, { Divider = true })
		end
		for _, f in filters do
			table.insert(menuItems, {
				Label = f.name,
				Icon = filterId == f.id and FileController.Get("image", "checkmark") or nil,
				Callback = function()
					list._filterId(f.id)
				end,
			})
		end

		contextApi.Open(menuItems, cursor.getPosition())
	end

	local searchBar: React.Element<any>?
	local searchDivider: React.Element<any>?
	if showHeader then
		local headerChildren: { [string]: React.Element<any> } = {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		}

		if showSearch then
			headerChildren.Icon = e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = FileController.Get("image", "search"),
				ImageColor3 = searchMutedColor,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(10, 10),
			})

			local inputRightInset = hasFilters and (16 + 18) or 16
			headerChildren.Input = e("TextBox", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = placeholder,
				PlaceholderColor3 = searchMutedColor,
				Text = search,
				TextColor3 = searchDisplayColor,
				TextSize = 12,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(1, -inputRightInset, 1, 0),
				[React.Change.Text] = function(rbx: TextBox)
					list._search(rbx.Text)
				end,
			})
		end

		if hasFilters then
			headerChildren.Filter = e(FilterButton, {
				OnOpen = openFilterMenu,
				Tip = "Filter",
			})
		end

		searchBar = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, SEARCH_HEIGHT),
			Position = UDim2.fromOffset(0, 0),
		}, headerChildren)

		searchDivider = e("Frame", {
			BackgroundColor3 = dividerColor,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, SEARCH_HEIGHT),
			Size = UDim2.new(1, 0, 0, 1),
		})
	end

	local listContainerChildren = Sift.Dictionary.join({
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, ROW_PADDING),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 0),
			PaddingRight = UDim.new(0, 0),
			PaddingTop = UDim.new(0, CANVAS_PADDING_Y),
			PaddingBottom = UDim.new(0, CANVAS_PADDING_Y),
		}),
	}, renderedRows)

	local listInner: React.Element<any> = e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, listContainerChildren)

	local scrollViewportSize = heightBind:map(function(h: number)
		local hPx = math.max(0, math.floor(h) - searchBlockHeight)
		return UDim2.new(1, 0, 0, hPx)
	end)

	local canvasSize = UDim2.fromOffset(0, math.max(innerPixelHeight, renderedContentHeight))

	local scrollFrame = e("ScrollingFrame", {
		Active = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingEnabled = needsScroll,
		AnchorPoint = Vector2.new(0, 0),
		Size = scrollViewportSize,
		Position = UDim2.fromOffset(0, searchBlockHeight),
		CanvasSize = canvasSize,
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ClipsDescendants = true,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ScrollBarImageColor3 = scrollThumbColor,
		ScrollBarImageTransparency = needsScroll and 0.1 or 1,
		ScrollBarThickness = needsScroll and 3 or 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		LayoutOrder = 1,
	}, {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, CANVAS_PADDING_X),
			PaddingRight = UDim.new(0, CANVAS_PADDING_X),
		}),
		Empty = emptyElement,
		Inner = listInner,
	})

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = layoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = e("TextButton", {
			BackgroundTransparency = 1,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = labelColor.binding,
			TextSize = 13,
			Text = labelText,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = 0,
			AutoButtonColor = false,
			Active = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			[React.Event.MouseEnter] = function()
				labelColor.onMouseEnter()
			end,
			[React.Event.MouseLeave] = function()
				labelColor.onMouseLeave()
			end,
		}, {
			Selection = e("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = FileController.Get("font", "semi_bold"),
				TextColor3 = labelColor.binding,
				TextSize = 13,
				Text = displayedLabel,
				TextTransparency = fadeBind,
				Size = UDim2.new(1, 0, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		}),
		Canvas = e("Frame", {
			BackgroundColor3 = backgroundColor,
			BorderSizePixel = 0,
			Size = heightBind:map(function(value: number)
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
			Search = searchBar,
			Divider = searchDivider,
			Scroll = scrollFrame,
		}),
	})
end
