local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local at = Charm.atom
local peek = Charm.peek

type Entry = {
	id: number,
	priority: number,
	fn: any,
}

type ForcedEntry = {
	id: number,
	name: string,
	expiry: number?,
}

local enabled = at(false)
local active = at(false)

local signals = {
	onAction = Signal.new(),
}

local itemFilters: { Entry } = {}
local actionFilters: { Entry } = {}
local forcedItems: { ForcedEntry } = {}
local nextId = 0

local waker: (() -> ())? = nil

local function byPriorityDesc(a: Entry, b: Entry): boolean
	return a.priority > b.priority
end

local function insertEntry(list: { Entry }, fn: any, priority: number): number
	nextId += 1
	local id = nextId
	list[#list + 1] = { id = id, priority = priority, fn = fn }
	table.sort(list, byPriorityDesc)
	return id
end

local function removeEntry(list: { Entry }, id: number): ()
	for i, entry in next, list do
		if entry.id == id then
			table.remove(list, i)
			return
		end
	end
end

local autoLootApi = {
	signals = signals,
}

function autoLootApi.IsEnabled(): boolean
	return peek(enabled)
end

function autoLootApi.IsActive(): boolean
	return peek(active)
end

function autoLootApi.SetEnabled(value: boolean): ()
	if peek(enabled) ~= value then
		enabled(value)
	end
end

function autoLootApi.SetActive(value: boolean): ()
	if peek(active) ~= value then
		active(value)
	end
end

function autoLootApi.SetWaker(fn: (() -> ())?): ()
	waker = fn
end

function autoLootApi.Scan(): ()
	if waker then
		waker()
	end
end

function autoLootApi.NotifyAction(action: any): ()
	local item = action.item
	signals.onAction:Fire({
		type = action.act,
		kind = action.pickKind,
		name = action.name or (item and (item.DisplayName or item.Name)) or nil,
		caliber = action.caliber,
		slot = action.slot,
	})
end

local function itemInfo(item: any): any
	return {
		name = item.DisplayName or item.Name,
		rawName = item.Name,
		type = item.Type,
		caliber = item.Caliber,
		slot = item.EquipSlot,
	}
end

function autoLootApi.AddItemFilter(fn: any, priority: number?): number
	return insertEntry(itemFilters, fn, priority or 0)
end

function autoLootApi.RemoveItemFilter(id: number): ()
	removeEntry(itemFilters, id)
end

function autoLootApi.AddActionFilter(fn: any, priority: number?): number
	return insertEntry(actionFilters, fn, priority or 0)
end

function autoLootApi.RemoveActionFilter(id: number): ()
	removeEntry(actionFilters, id)
end

function autoLootApi.AddForcedItem(name: string, durationSec: number?): number
	nextId += 1
	local id = nextId
	forcedItems[#forcedItems + 1] = {
		id = id,
		name = name,
		expiry = durationSec and os.clock() + durationSec or nil,
	}
	return id
end

function autoLootApi.RemoveForcedItem(id: number): ()
	for i, entry in next, forcedItems do
		if entry.id == id then
			table.remove(forcedItems, i)
			return
		end
	end
end

function autoLootApi.GetForcedItemSet(): { [string]: boolean }?
	if #forcedItems == 0 then
		return nil
	end
	local now = os.clock()
	local set: { [string]: boolean } = {}
	local any = false
	for i = #forcedItems, 1, -1 do
		local entry = forcedItems[i]
		if entry.expiry and now >= entry.expiry then
			table.remove(forcedItems, i)
		else
			set[entry.name] = true
			any = true
		end
	end
	return any and set or nil
end

function autoLootApi.RunFilters(action: any): boolean
	if #actionFilters > 0 then
		local info = {
			type = action.act,
			kind = action.pickKind,
			name = action.name,
			caliber = action.caliber,
			slot = action.slot,
		}
		for _, entry in next, actionFilters do
			local ok, result = pcall(entry.fn, info)
			if ok and result == false then
				return false
			end
		end
	end

	local item = action.item
	if item and #itemFilters > 0 then
		local info = itemInfo(item)
		for _, entry in next, itemFilters do
			local ok, result = pcall(entry.fn, info)
			if ok and result == false then
				return false
			end
		end
	end

	return true
end

luauApiRegistry.RegisterAlias("autoloot", "feature.autoloot")

luauApiRegistry.RegisterFeature("autoloot", function(ctx)
	local onUnload = ctx.onUnload
	local wrap = luauApiRegistry.WrapSignal
	local registry = luauApiRegistry.CreateRegistry(onUnload)

	local function trackFilter(kind: "item" | "action", fn: any, priority: number?): any
		local p = priority or 0
		local addFn: any = autoLootApi.AddItemFilter
		local removeFn: any = autoLootApi.RemoveItemFilter
		if kind == "action" then
			addFn, removeFn = autoLootApi.AddActionFilter, autoLootApi.RemoveActionFilter
		end
		return registry.Add({
			id = addFn(fn, p),
			fn = fn,
			priority = p,
			remove = removeFn,
			reAdd = addFn,
		})
	end

	local api = {}

	api.isEnabled = autoLootApi.IsEnabled
	api.isActive = autoLootApi.IsActive
	api.onAction = wrap(signals.onAction, onUnload)

	function api.scan(): ()
		autoLootApi.Scan()
	end

	function api.addItemFilter(fn: any, priority: number?): any
		if type(fn) ~= "function" then
			error("api.feature.autoloot.addItemFilter: callback must be a function", 2)
		end
		return trackFilter("item", fn, priority)
	end

	function api.addActionFilter(fn: any, priority: number?): any
		if type(fn) ~= "function" then
			error("api.feature.autoloot.addActionFilter: callback must be a function", 2)
		end
		return trackFilter("action", fn, priority)
	end

	function api.blockItem(names: any): any
		local set: { [string]: boolean } = {}
		if type(names) == "string" then
			set[names] = true
		elseif type(names) == "table" then
			for _, name in next, names do
				if type(name) == "string" then
					set[name] = true
				end
			end
		else
			error("api.feature.autoloot.blockItem: expected a name or list of names", 2)
		end
		return trackFilter("item", function(item: any): boolean
			return not (item.name ~= nil and set[item.name]) and not (item.rawName ~= nil and set[item.rawName])
		end, 0)
	end

	function api.blockAction(types: any): any
		local set: { [string]: boolean } = {}
		if type(types) == "string" then
			set[types] = true
		elseif type(types) == "table" then
			for _, kind in next, types do
				if type(kind) == "string" then
					set[kind] = true
				end
			end
		else
			error("api.feature.autoloot.blockAction: expected an action type or list of types", 2)
		end
		return trackFilter("action", function(action: any): boolean
			return not set[action.type]
		end, 0)
	end

	function api.forceItem(name: any, durationSec: number?): any
		if type(name) ~= "string" then
			error("api.feature.autoloot.forceItem: name must be a string", 2)
		end
		return registry.Add({
			id = autoLootApi.AddForcedItem(name, durationSec),
			remove = autoLootApi.RemoveForcedItem,
		})
	end

	return api
end)

return autoLootApi
