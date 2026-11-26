local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/table/renderer")

local at = Charm.atom
local peek = Charm.peek
local e = React.createElement

local Table = {}
Table.__index = Table

setmetatable(Table, { __index = Element })

export type Align = "left" | "center" | "right"

export type Column = {
	id: string,
	name: string,
	weight: number?,
	minWidth: number?,
	align: Align?,
	formatter: ((value: any, row: { [string]: any }) -> string)?,
	renderer: ((row: { [string]: any }, value: any) -> any)?,
	headerRenderer: ((column: Column) -> any)?,
	sortable: boolean?,
	sortKey: ((row: { [string]: any }) -> any)?,
	searchValue: ((row: { [string]: any }) -> string)?,
}

export type SortDirection = "asc" | "desc"

export type Row = { [string]: any }

export type PageResult = {
	rows: { Row }?,
	nextCursor: string?,
	previousCursor: string?,
	error: string?,
}

export type DataSource = (cursor: string?) -> PageResult

export type RowDetailRenderer = (row: Row) -> any
export type RowDetailHeight = (row: Row) -> number

export type RowClickCallback = (row: Row, index: number) -> ()
export type RowContextCallback = (row: Row, index: number, position: UDim2) -> ()
export type PageChangeCallback = (cursor: string?, pageIndex: number) -> ()
export type SelectionCallback = (row: Row?) -> ()

local function disconnector(list: { any }, callback: any): () -> ()
	return function()
		local idx = table.find(list, callback)
		if idx then
			table.remove(list, idx)
		end
	end
end

local function constructor(text: string, columns: { Column }?): Table
	local self = Element.new(text) :: any

	setmetatable(self, Table)

	self._columns = at(columns or {} :: { Column })
	self._rows = at({} :: { Row })
	self._rowKey = at("id")
	self._selectedKey = at(nil :: string?)
	self._loading = at(false)
	self._emptyText = at("No items")
	self._loadingText = at("Loading...")
	self._errorText = at(nil :: string?)
	self._maxHeight = at(360)
	self._rowHeight = at(26)
	self._showPagination = at(true)
	self._rowDetail = nil :: RowDetailRenderer?
	self._rowDetailHeight = nil :: (number | RowDetailHeight)?

	self._dataSource = nil :: DataSource?
	self._currentCursor = at(nil :: string?)
	self._nextCursor = at(nil :: string?)
	self._previousCursor = at(nil :: string?)
	self._pageIndex = at(1)
	self._fetchToken = 0
	self._cooldown = at(4)
	self._cooldownUntil = at(0)

	self._search = at("")
	self._showSearch = at(false)
	self._searchPlaceholder = at("Search...")
	self._sortColumnId = at(nil :: string?)
	self._sortDirection = at("asc" :: SortDirection)

	self._rowClickCallbacks = {} :: { RowClickCallback }
	self._rowContextCallbacks = {} :: { RowContextCallback }
	self._pageChangeCallbacks = {} :: { PageChangeCallback }
	self._selectionCallbacks = {} :: { SelectionCallback }

	return self
end

function Table.SetColumns(self: Table, columns: { Column }): Table
	self._columns(columns or {})
	return self
end

function Table.GetColumns(self: Table): { Column }
	return peek(self._columns)
end

function Table.SetRowKey(self: Table, field: string): Table
	self._rowKey(field)
	return self
end

function Table.SetRows(self: Table, rows: { Row }): Table
	self._rows(rows or {})
	self._errorText(nil)
	return self
end

function Table.GetRows(self: Table): { Row }
	return peek(self._rows)
end

function Table.SetEmptyText(self: Table, text: string): Table
	self._emptyText(text or "No items")
	return self
end

function Table.SetLoadingText(self: Table, text: string): Table
	self._loadingText(text or "Loading...")
	return self
end

function Table.SetLoading(self: Table, state: boolean): Table
	self._loading(state and true or false)
	return self
end

function Table.IsLoading(self: Table): boolean
	return peek(self._loading)
end

function Table.SetMaxHeight(self: Table, height: number): Table
	self._maxHeight(math.max(80, height))
	return self
end

function Table.SetRowHeight(self: Table, height: number): Table
	self._rowHeight(math.max(16, height))
	return self
end

function Table.SetShowPagination(self: Table, show: boolean): Table
	self._showPagination(show and true or false)
	return self
end

function Table.SetRowDetail(self: Table, renderer: RowDetailRenderer?): Table
	self._rowDetail = renderer
	return self
end

function Table.SetRowDetailHeight(self: Table, height: (number | RowDetailHeight)?): Table
	self._rowDetailHeight = height
	return self
end

function Table.SetDataSource(self: Table, source: DataSource?): Table
	self._dataSource = source
	return self
end

function Table.SetRefreshCooldown(self: Table, seconds: number): Table
	self._cooldown(math.max(0, seconds))
	return self
end

function Table.GetCooldownRemaining(self: Table): number
	local now = os.clock()
	local until_ = peek(self._cooldownUntil)
	if until_ <= now then
		return 0
	end
	return until_ - now
end

function Table.IsOnCooldown(self: Table): boolean
	return self:GetCooldownRemaining() > 0
end

function Table.SetShowSearch(self: Table, show: boolean): Table
	self._showSearch(show and true or false)
	return self
end

function Table.SetSearchPlaceholder(self: Table, text: string): Table
	self._searchPlaceholder(text or "Search...")
	return self
end

function Table.SetSearch(self: Table, text: string?): Table
	self._search(text or "")
	return self
end

function Table.GetSearch(self: Table): string
	return peek(self._search)
end

function Table.SetSort(self: Table, columnId: string?, direction: SortDirection?): Table
	self._sortColumnId(columnId)
	self._sortDirection(direction or "asc")
	return self
end

function Table.GetSort(self: Table): (string?, SortDirection)
	return peek(self._sortColumnId), peek(self._sortDirection) :: SortDirection
end

function Table.ToggleSort(self: Table, columnId: string): ()
	local current = peek(self._sortColumnId)
	local direction = peek(self._sortDirection)
	if current ~= columnId then
		self._sortColumnId(columnId)
		self._sortDirection("asc")
	elseif direction == "asc" then
		self._sortDirection("desc")
	else
		self._sortColumnId(nil)
		self._sortDirection("asc")
	end
end

local function fireSelection(self: Table): ()
	local row: Row? = self:GetSelectedRow()
	for _, callback in self._selectionCallbacks do
		task.spawn(callback, row)
	end
end

local function findRowByKey(rows: { Row }, keyField: string, key: string?): Row?
	if key == nil then
		return nil
	end
	for _, row in rows do
		if tostring(row[keyField]) == key then
			return row
		end
	end
	return nil
end

function Table.SetSelected(self: Table, key: string?): Table
	if key == nil then
		if peek(self._selectedKey) ~= nil then
			self._selectedKey(nil)
			fireSelection(self)
		end
		return self
	end

	local keyStr = tostring(key)
	if peek(self._selectedKey) == keyStr then
		return self
	end

	self._selectedKey(keyStr)
	fireSelection(self)
	return self
end

function Table.GetSelectedKey(self: Table): string?
	return peek(self._selectedKey)
end

function Table.GetSelectedRow(self: Table): Row?
	return findRowByKey(peek(self._rows), peek(self._rowKey), peek(self._selectedKey))
end

function Table.ClearSelection(self: Table): Table
	return self:SetSelected(nil)
end

function Table.GetPageIndex(self: Table): number
	return peek(self._pageIndex)
end

function Table.HasNextPage(self: Table): boolean
	return peek(self._nextCursor) ~= nil
end

function Table.HasPreviousPage(self: Table): boolean
	return peek(self._previousCursor) ~= nil
end

function Table.OnRowClick(self: Table, callback: RowClickCallback): () -> ()
	table.insert(self._rowClickCallbacks, callback)
	return disconnector(self._rowClickCallbacks, callback)
end

function Table.OnRowContextMenu(self: Table, callback: RowContextCallback): () -> ()
	table.insert(self._rowContextCallbacks, callback)
	return disconnector(self._rowContextCallbacks, callback)
end

function Table.OnPageChange(self: Table, callback: PageChangeCallback): () -> ()
	table.insert(self._pageChangeCallbacks, callback)
	return disconnector(self._pageChangeCallbacks, callback)
end

function Table.OnSelectionChange(self: Table, callback: SelectionCallback): () -> ()
	table.insert(self._selectionCallbacks, callback)
	return disconnector(self._selectionCallbacks, callback)
end

function Table.HandleRowClick(self: Table, row: Row, index: number): ()
	local keyField = peek(self._rowKey)
	local key = row[keyField]
	if key ~= nil then
		local keyStr = tostring(key)
		if self._rowDetail ~= nil and peek(self._selectedKey) == keyStr then
			self:SetSelected(nil)
		else
			self:SetSelected(keyStr)
		end
	end
	for _, callback in self._rowClickCallbacks do
		task.spawn(callback, row, index)
	end
end

function Table.HandleRowContextMenu(self: Table, row: Row, index: number, position: UDim2): ()
	for _, callback in self._rowContextCallbacks do
		task.spawn(callback, row, index, position)
	end
end

local function loadPage(self: Table, cursor: string?, direction: number, bypassCooldown: boolean?): ()
	local source: DataSource? = self._dataSource
	if not source then
		return
	end

	if not bypassCooldown and self:IsOnCooldown() then
		return
	end

	self._fetchToken += 1
	local token = self._fetchToken

	self._loading(true)
	self._errorText(nil)
	self._cooldownUntil(os.clock() + peek(self._cooldown))

	task.spawn(function()
		local ok, result: any = pcall(source, cursor)

		if token ~= self._fetchToken then
			return
		end

		self._loading(false)

		if not ok then
			self._errorText(tostring(result))
			return
		end

		if type(result) ~= "table" then
			self._errorText("Invalid response")
			return
		end

		self._rows(result.rows or {})
		self._nextCursor(result.nextCursor)
		self._previousCursor(result.previousCursor)
		self._currentCursor(cursor)
		if result.error then
			self._errorText(tostring(result.error))
		end

		local previousIndex = peek(self._pageIndex)
		local nextIndex = previousIndex
		if direction == 1 then
			nextIndex = previousIndex + 1
		elseif direction == -1 then
			nextIndex = math.max(1, previousIndex - 1)
		elseif direction == 0 then
			nextIndex = 1
		end

		self._pageIndex(nextIndex)

		local selectedKey = peek(self._selectedKey)
		if selectedKey and not findRowByKey(peek(self._rows), peek(self._rowKey), selectedKey) then
			self._selectedKey(nil)
			fireSelection(self)
		end

		for _, callback in self._pageChangeCallbacks do
			task.spawn(callback, cursor, nextIndex)
		end
	end)
end

function Table.Refresh(self: Table): ()
	loadPage(self, peek(self._currentCursor), 0)
end

function Table.Reload(self: Table): ()
	loadPage(self, nil, 0, true)
end

function Table.NextPage(self: Table): ()
	local cursor = peek(self._nextCursor)
	if cursor then
		loadPage(self, cursor, 1)
	end
end

function Table.PreviousPage(self: Table): ()
	local cursor = peek(self._previousCursor)
	if cursor then
		loadPage(self, cursor, -1)
	end
end

function Table.Render(self: Table, layoutOrder: number?): React.Element<any>
	return e(renderer, {
		Table = self,
		LayoutOrder = layoutOrder,
	})
end

function Table.RenderInternal(self: Table, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		Table = self,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type Table =
	typeof(setmetatable(
		{} :: {
			_columns: Charm.Atom<{ Column }>,
			_rows: Charm.Atom<{ Row }>,
			_rowKey: Charm.Atom<string>,
			_selectedKey: Charm.Atom<string?>,
			_loading: Charm.Atom<boolean>,
			_emptyText: Charm.Atom<string>,
			_loadingText: Charm.Atom<string>,
			_errorText: Charm.Atom<string?>,
			_maxHeight: Charm.Atom<number>,
			_rowHeight: Charm.Atom<number>,
			_showPagination: Charm.Atom<boolean>,
			_rowDetail: RowDetailRenderer?,
			_rowDetailHeight: (number | RowDetailHeight)?,
			_dataSource: DataSource?,
			_currentCursor: Charm.Atom<string?>,
			_nextCursor: Charm.Atom<string?>,
			_previousCursor: Charm.Atom<string?>,
			_pageIndex: Charm.Atom<number>,
			_fetchToken: number,
			_cooldown: Charm.Atom<number>,
			_cooldownUntil: Charm.Atom<number>,
			_search: Charm.Atom<string>,
			_showSearch: Charm.Atom<boolean>,
			_searchPlaceholder: Charm.Atom<string>,
			_sortColumnId: Charm.Atom<string?>,
			_sortDirection: Charm.Atom<SortDirection>,
			_rowClickCallbacks: { RowClickCallback },
			_rowContextCallbacks: { RowContextCallback },
			_pageChangeCallbacks: { PageChangeCallback },
			_selectionCallbacks: { SelectionCallback },
		},
		Table
	))
	& Element.Element

return constructor
