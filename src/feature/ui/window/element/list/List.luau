local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/list/renderer")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement

local List = {}
List.__index = List

setmetatable(List, { __index = Element })

export type Item = {
	id: string,
	name: string?,
	icon: string?,
	trailingIcon: string?,
	meta: string?,
	header: boolean?,
	locked: boolean?,
}

export type FilterComparator = (a: Item, b: Item) -> boolean

export type Filter = {
	id: string,
	name: string,
	sort: FilterComparator?,
}

local Sort = {
	Alphabetical = function(a: Item, b: Item): boolean
		return string.lower(a.name or a.id) < string.lower(b.name or b.id)
	end,
	AlphabeticalDesc = function(a: Item, b: Item): boolean
		return string.lower(a.name or a.id) > string.lower(b.name or b.id)
	end,
}

local function normalizeOne(raw: any): Item?
	if type(raw) == "string" then
		return { id = raw, name = raw }
	end
	if type(raw) == "table" and type(raw.id) == "string" then
		return {
			id = raw.id,
			name = type(raw.name) == "string" and raw.name or raw.id,
			icon = type(raw.icon) == "string" and raw.icon or nil,
			trailingIcon = type(raw.trailingIcon) == "string" and raw.trailingIcon or nil,
			meta = type(raw.meta) == "string" and raw.meta or nil,
			header = raw.header == true or nil,
			locked = raw.locked == true or nil,
		}
	end
	return nil
end

local function normalize(items: { any }?): { Item }
	if not items then
		return {}
	end
	local out: { Item } = {}
	local seen: { [string]: true } = {}
	for _, raw in items do
		local item = normalizeOne(raw)
		if item and not seen[item.id] then
			seen[item.id] = true
			table.insert(out, item)
		end
	end
	return out
end

local function indexOf(items: { Item }, id: string): number?
	for i, it in items do
		if it.id == id then
			return i
		end
	end
	return nil
end

local function isSelectable(items: { Item }, id: string): boolean
	for _, it in items do
		if it.id == id then
			return not it.header
		end
	end
	return false
end

local function isLocked(items: { Item }, id: string): boolean
	for _, it in items do
		if it.id == id then
			return it.locked == true
		end
	end
	return false
end

local function constructor(text: string, items: { any }?, default: string?): List
	local self = Element.new(text) :: any

	setmetatable(self, List)

	self._items = at(normalize(items))
	self._search = at("")
	self._showSearch = at(false)
	self._maxHeight = at(120)
	self._emptyText = at("No items")
	self._placeholder = at("Search...")
	self._filters = at({} :: { Filter })
	self._filterId = at(nil :: string?)
	self._renamable = at(false)
	self._editingId = at(nil :: string?)
	self._renameCallbacks = {} :: { (oldId: string, newName: string) -> () }

	sub(self._state, function(state: string?)
		self._active(state ~= nil and state ~= "")
	end)

	if default ~= nil and isSelectable(peek(self._items), default) then
		self._state(default)
	end

	return self
end

function List.SetItems(self: List, items: { any }): List
	self._items(normalize(items))

	local current = peek(self._state)
	if current and not indexOf(peek(self._items), current) then
		self._state(nil)
	end

	return self
end

function List.AddItem(self: List, item: any): List
	local normalized = normalizeOne(item)
	if not normalized then
		return self
	end

	local current = peek(self._items)
	if indexOf(current, normalized.id) then
		return self
	end

	local copy = table.clone(current)
	table.insert(copy, normalized)
	self._items(copy)

	return self
end

function List.RemoveItem(self: List, id: string): List
	local current = peek(self._items)
	local idx = indexOf(current, id)
	if not idx then
		return self
	end

	local copy = table.clone(current)
	table.remove(copy, idx)
	self._items(copy)

	if peek(self._state) == id then
		self._state(nil)
	end

	return self
end

function List.SetSelected(self: List, id: string?): List
	if id == nil then
		self._state(nil)
		return self
	end
	if isSelectable(peek(self._items), id) then
		self._state(id)
	end
	return self
end

function List.GetSelected(self: List): string?
	return peek(self._state)
end

function List.GetSelectedItem(self: List): Item?
	local id = peek(self._state)
	if not id then
		return nil
	end
	for _, it in peek(self._items) do
		if it.id == id then
			return it
		end
	end
	return nil
end

function List.SetShowSearch(self: List, show: boolean): List
	self._showSearch(show)
	return self
end

function List.SetMaxHeight(self: List, height: number): List
	self._maxHeight(math.max(40, height))
	return self
end

function List.SetEmptyText(self: List, text: string): List
	self._emptyText(text)
	return self
end

function List.SetPlaceholder(self: List, text: string): List
	self._placeholder(text)
	return self
end

local function findFilter(filters: { Filter }, id: string): number?
	for i, f in filters do
		if f.id == id then
			return i
		end
	end
	return nil
end

function List.AddFilter(self: List, name: string, comparator: FilterComparator?): List
	local current = peek(self._filters)
	local copy = table.clone(current)
	local existing = findFilter(copy, name)
	local filter: Filter = { id = name, name = name, sort = comparator }
	if existing then
		copy[existing] = filter
	else
		table.insert(copy, filter)
	end
	self._filters(copy)

	if peek(self._filterId) == nil and not existing then
		self._filterId(name)
	end

	return self
end

function List.RemoveFilter(self: List, name: string): List
	local current = peek(self._filters)
	local idx = findFilter(current, name)
	if not idx then
		return self
	end

	local copy = table.clone(current)
	table.remove(copy, idx)
	self._filters(copy)

	if peek(self._filterId) == name then
		self._filterId(copy[1] and copy[1].id or nil)
	end

	return self
end

function List.SetFilter(self: List, name: string?): List
	if name == nil then
		self._filterId(nil)
		return self
	end
	if findFilter(peek(self._filters), name) then
		self._filterId(name)
	end
	return self
end

function List.GetFilter(self: List): string?
	return peek(self._filterId)
end

function List.SetRenamable(self: List, renamable: boolean): List
	self._renamable(renamable)
	return self
end

function List.IsRenamable(self: List): boolean
	return peek(self._renamable)
end

function List.OnRename(self: List, callback: (oldId: string, newName: string) -> ()): () -> ()
	table.insert(self._renameCallbacks, callback)
	return function()
		local index = table.find(self._renameCallbacks, callback)
		if index then
			table.remove(self._renameCallbacks, index)
		end
	end
end

function List.BeginEdit(self: List, id: string): ()
	if not peek(self._renamable) then
		return
	end
	if not isSelectable(peek(self._items), id) then
		return
	end
	if isLocked(peek(self._items), id) then
		return
	end
	self._editingId(id)
end

function List.CancelEdit(self: List): ()
	self._editingId(nil)
end

function List.CommitEdit(self: List, newName: string): ()
	local oldId = peek(self._editingId)
	if not oldId then
		return
	end

	self._editingId(nil)

	if not newName or newName == "" or newName == oldId then
		return
	end

	local items = peek(self._items)
	if indexOf(items, newName) then
		return
	end

	local newItems = table.clone(items)
	for i, it in newItems do
		if it.id == oldId then
			newItems[i] =
				{ id = newName, name = newName, icon = it.icon, trailingIcon = it.trailingIcon, meta = it.meta }
			break
		end
	end
	self._items(newItems)

	if peek(self._state) == oldId then
		self._state(newName)
	end

	for _, callback in self._renameCallbacks do
		task.spawn(callback, oldId, newName)
	end
end

function List.Render(self: List, layoutOrder: number?): React.Element<any>
	return e(renderer, {
		List = self,
		LayoutOrder = layoutOrder,
	})
end

function List.RenderInternal(self: List, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		List = self,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type List = typeof(setmetatable(
	{} :: {
		_items: Charm.Atom<{ Item }>,
		_search: Charm.Atom<string>,
		_showSearch: Charm.Atom<boolean>,
		_maxHeight: Charm.Atom<number>,
		_emptyText: Charm.Atom<string>,
		_placeholder: Charm.Atom<string>,
		_filters: Charm.Atom<{ Filter }>,
		_filterId: Charm.Atom<string?>,
		_renamable: Charm.Atom<boolean>,
		_editingId: Charm.Atom<string?>,
		_renameCallbacks: { (oldId: string, newName: string) -> () },
	},
	List
)) & Element.Element

return {
	__call = constructor,
	Sort = Sort,
}
