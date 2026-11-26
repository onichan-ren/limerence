local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local stateConverter = require("@src/feature/config/module/stateConverter")
local scopeState = require("@ui/scope/scopeState")
local uiState = require("@ui/uiState")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe

export type ScopeKind = scopeState.ScopeKind
export type ScopeDef = scopeState.ScopeDef

export type Resolved = {
	value: any,
	source: string,
	inherited: boolean,
	exists: boolean,
}

local GLOBAL_ID = "global"

local ScopeController = {
	state = scopeState,
	GLOBAL_ID = GLOBAL_ID,
}

local _bound: { [string]: { element: any, unsubs: { () -> () } } } = {}
local _globalOnlyKeys: { [string]: boolean } = {}
local _scopeKeyResolvers: { (weaponName: string?) -> string? } = {}

local function ensureScope(id: string, def: ScopeDef): ()
	local current = peek(scopeState.scopes)
	if current[id] then
		return
	end
	scopeState.scopes(Sift.Dictionary.set(current, id, def))
	local order = peek(scopeState.order)
	scopeState.order(Sift.Array.push(order, id))
end

ensureScope(GLOBAL_ID, {
	id = GLOBAL_ID,
	parent = nil,
	label = "Global",
	kind = "global",
	layoutOrder = 0,
})

stateConverter.RegisterExtension("scopes", function(): any
	local values: { [string]: { [string]: any } } = {}
	for scopeId, bucket in next, peek(scopeState.values) do
		local out: { [string]: any } = {}
		for key, value in next, bucket do
			out[key] = stateConverter.serializeValue(value)
		end
		values[scopeId] = out
	end
	return {
		values = values,
		enabled = peek(scopeState.enabled),
	}
end, function(data: any)
	if type(data) ~= "table" then
		return
	end

	local values: { [string]: { [string]: any } } = {}
	if type(data.values) == "table" then
		for scopeId, bucket in next, data.values do
			if type(bucket) == "table" then
				local out: { [string]: any } = {}
				for key, value in next, bucket do
					out[key] = stateConverter.deserializeValue(value)
				end
				values[scopeId] = out
			end
		end
	end

	local globalBucket = peek(scopeState.values)[GLOBAL_ID]
	if globalBucket then
		local merged = values[GLOBAL_ID] or {}
		for key, value in next, globalBucket do
			if merged[key] == nil then
				merged[key] = value
			end
		end
		values[GLOBAL_ID] = merged
	end

	local enabled: { [string]: boolean } = {}
	if type(data.enabled) == "table" then
		for scopeId, state in next, data.enabled do
			if state == true then
				enabled[scopeId] = true
			end
		end
	end

	scopeState.values(values)
	scopeState.enabled(enabled)
end)

sub(uiState.isOpen, function(open: boolean): ()
	if not open or not peek(scopeState.autoFollowEquipped) then
		return
	end
	if peek(scopeState.equipped) == nil then
		return
	end
	local target = peek(scopeState.equippedScope)
	if target == GLOBAL_ID then
		return
	end
	if peek(scopeState.enabled)[target] ~= true then
		return
	end
	if peek(scopeState.currentScope) ~= target and peek(scopeState.scopes)[target] then
		scopeState.currentScope(target)
	end
end)

function ScopeController.RegisterScope(def: ScopeDef): ScopeDef
	ensureScope(def.id, def)
	return def
end

function ScopeController.RegisterGroup(id: string, label: string, layoutOrder: number?): ScopeDef
	return ScopeController.RegisterScope({
		id = `group:{id}`,
		parent = GLOBAL_ID,
		label = label,
		kind = "group",
		groupLabel = "Groups",
		layoutOrder = layoutOrder,
	})
end

function ScopeController.RegisterWeapon(id: string, label: string, group: string?, layoutOrder: number?): ScopeDef
	return ScopeController.RegisterScope({
		id = `weapon:{id}`,
		parent = group and `group:{group}` or GLOBAL_ID,
		label = label,
		kind = "weapon",
		groupLabel = "Weapons",
		layoutOrder = layoutOrder,
	})
end

function ScopeController.GetScope(id: string): ScopeDef?
	return peek(scopeState.scopes)[id]
end

function ScopeController.RemoveScope(id: string): ()
	if id == GLOBAL_ID then
		return
	end
	local scopes = peek(scopeState.scopes)
	if not scopes[id] then
		return
	end
	scopeState.scopes(Sift.Dictionary.removeKey(scopes, id))
	scopeState.order(Sift.Array.filter(peek(scopeState.order), function(other: string)
		return other ~= id
	end))
	scopeState.values(Sift.Dictionary.removeKey(peek(scopeState.values), id))
	scopeState.enabled(Sift.Dictionary.removeKey(peek(scopeState.enabled), id))
	if peek(scopeState.currentScope) == id then
		scopeState.currentScope(GLOBAL_ID)
	end
end

function ScopeController.GetChildren(parent: string?): { ScopeDef }
	local out: { ScopeDef } = {}
	for _, id in next, peek(scopeState.order) do
		local scope = peek(scopeState.scopes)[id]
		if scope and scope.parent == parent then
			out[#out + 1] = scope
		end
	end
	return out
end

local function isScopeBucketActive(scopeId: string): boolean
	if scopeId == GLOBAL_ID then
		return true
	end
	return peek(scopeState.enabled)[scopeId] == true
end

local function resolveAt(scopeId: string, key: string): Resolved
	local scopes = peek(scopeState.scopes)
	local values = peek(scopeState.values)
	local globalOnly = _globalOnlyKeys[key] == true

	local current: string? = globalOnly and GLOBAL_ID or scopeId
	while current do
		if isScopeBucketActive(current) then
			local bucket = values[current]
			if bucket and bucket[key] ~= nil then
				return {
					value = bucket[key],
					source = current,
					inherited = current ~= scopeId,
					exists = true,
				}
			end
		end
		local def = scopes[current]
		current = def and def.parent or nil
	end

	return {
		value = nil,
		source = GLOBAL_ID,
		inherited = scopeId ~= GLOBAL_ID,
		exists = false,
	}
end

local function resolveOverrideFromElement(element: any): (any, boolean)
	if not element or type(element.GetEffectiveValue) ~= "function" then
		return nil, false
	end
	if not element.IsOverridden or not element:IsOverridden() then
		return nil, false
	end
	return element:GetEffectiveValue(), true
end

function ScopeController.Resolve(key: string, scopeId: string?): Resolved
	local bound = _bound[key]
	if bound then
		local value, has = resolveOverrideFromElement(bound.element)
		if has then
			return {
				value = value,
				source = GLOBAL_ID,
				inherited = false,
				exists = true,
			}
		end
	end
	return resolveAt(scopeId or peek(scopeState.equippedScope), key)
end

function ScopeController.GetResolvedValue(key: string, scopeId: string?): any
	local bound = _bound[key]
	if bound then
		local value, has = resolveOverrideFromElement(bound.element)
		if has then
			return value
		end
	end
	return resolveAt(scopeId or peek(scopeState.equippedScope), key).value
end

function ScopeController.GetResolvedSettings(scopeId: string?): { [string]: any }
	local target = scopeId or peek(scopeState.equippedScope)
	local scopes = peek(scopeState.scopes)
	local values = peek(scopeState.values)

	local chain: { string } = {}
	local cursor: string? = target
	while cursor do
		table.insert(chain, 1, cursor)
		local def = scopes[cursor]
		cursor = def and def.parent or nil
	end

	local merged: { [string]: any } = {}
	for _, scopeNode in next, chain do
		local bucket = values[scopeNode]
		if bucket then
			for k, v in next, bucket do
				merged[k] = v
			end
		end
	end
	return merged
end

function ScopeController.HasOverride(key: string, scopeId: string?): boolean
	local target = scopeId or peek(scopeState.currentScope)
	local bucket = peek(scopeState.values)[target]
	return bucket ~= nil and bucket[key] ~= nil
end

function ScopeController.IsScopeEnabled(scopeId: string): boolean
	if scopeId == GLOBAL_ID then
		return true
	end
	return peek(scopeState.enabled)[scopeId] == true
end

function ScopeController.SetScopeEnabled(scopeId: string, enabled: boolean): ()
	if scopeId == GLOBAL_ID then
		return
	end
	local store = peek(scopeState.enabled)
	if (store[scopeId] == true) == enabled then
		return
	end
	if enabled then
		scopeState.enabled(Sift.Dictionary.set(store, scopeId, true))
	else
		scopeState.enabled(Sift.Dictionary.removeKey(store, scopeId))
	end
end

function ScopeController.ToggleScopeEnabled(scopeId: string): ()
	ScopeController.SetScopeEnabled(scopeId, not ScopeController.IsScopeEnabled(scopeId))
end

function ScopeController.SetValue(key: string, value: any, scopeId: string?): ()
	local target = scopeId or peek(scopeState.currentScope)
	local store = peek(scopeState.values)
	local bucket = store[target] or {}
	if bucket[key] == value then
		return
	end
	local nextBucket = Sift.Dictionary.set(bucket, key, value)
	scopeState.values(Sift.Dictionary.set(store, target, nextBucket))
end

function ScopeController.ClearValue(key: string, scopeId: string?): ()
	local target = scopeId or peek(scopeState.currentScope)
	local store = peek(scopeState.values)
	local bucket = store[target]
	if not bucket or bucket[key] == nil then
		return
	end
	local nextBucket = Sift.Dictionary.removeKey(bucket, key)
	if next(nextBucket) == nil then
		scopeState.values(Sift.Dictionary.removeKey(store, target))
	else
		scopeState.values(Sift.Dictionary.set(store, target, nextBucket))
	end
end

function ScopeController.SetCurrentScope(id: string): ()
	if not peek(scopeState.scopes)[id] then
		return
	end
	if peek(scopeState.currentScope) == id then
		return
	end
	scopeState.currentScope(id)
end

function ScopeController.GetCurrentScope(): string
	return peek(scopeState.currentScope)
end

function ScopeController.RegisterScopeResolver(resolver: (weaponName: string?) -> string?): () -> ()
	table.insert(_scopeKeyResolvers, resolver)
	return function()
		local idx = table.find(_scopeKeyResolvers, resolver)
		if idx then
			table.remove(_scopeKeyResolvers, idx)
		end
	end
end

function ScopeController.GetResolvedScope(weaponName: string?): string
	local name = weaponName ~= nil and weaponName or peek(scopeState.equipped)

	for _, resolver in next, _scopeKeyResolvers do
		local id = resolver(name)
		if id and peek(scopeState.scopes)[id] then
			return id
		end
	end

	if name then
		local weaponId = `weapon:{name:lower()}`
		local scopes = peek(scopeState.scopes)
		if scopes[weaponId] then
			local enabledMap = peek(scopeState.enabled)
			if enabledMap[weaponId] then
				return weaponId
			end
			local cursor = scopes[weaponId].parent
			while cursor and cursor ~= GLOBAL_ID do
				if enabledMap[cursor] then
					return cursor
				end
				local def = scopes[cursor]
				cursor = def and def.parent or nil
			end
		end
	end

	return GLOBAL_ID
end

function ScopeController.SetEquipped(weaponName: string?): ()
	if peek(scopeState.equipped) ~= weaponName then
		scopeState.equipped(weaponName)
	end
	local resolved = ScopeController.GetResolvedScope(weaponName)
	if peek(scopeState.equippedScope) ~= resolved then
		scopeState.equippedScope(resolved)
	end
	if peek(scopeState.autoFollowEquipped) and peek(uiState.isOpen) then
		ScopeController.SetCurrentScope(resolved)
	end
end

function ScopeController.SetAutoFollow(enabled: boolean): ()
	scopeState.autoFollowEquipped(enabled)
	if enabled then
		ScopeController.SetCurrentScope(ScopeController.GetResolvedScope(peek(scopeState.equipped)))
	end
end

export type BindOptions = {
	globalOnly: boolean?,
}

function ScopeController.BindElement(element: any, key: string, opts: BindOptions?): () -> ()
	if _bound[key] then
		ScopeController.UnbindElement(key)
	end

	local globalOnly = opts ~= nil and opts.globalOnly == true
	if globalOnly then
		_globalOnlyKeys[key] = true
	else
		_globalOnlyKeys[key] = nil
	end

	local syncing = false

	if element._scopeIsInherited == nil then
		element._scopeIsInherited = at(false)
	end
	if element._scopeSource == nil then
		element._scopeSource = at(GLOBAL_ID)
	end
	if element._scopeKey == nil then
		element._scopeKey = at(key :: string?)
	else
		element._scopeKey(key)
	end

	if not ScopeController.HasOverride(key, GLOBAL_ID) then
		ScopeController.SetValue(key, peek(element._state), GLOBAL_ID)
	end

	local function pushFromStore(): ()
		local resolved = resolveAt(peek(scopeState.currentScope), key)
		syncing = true
		if resolved.exists then
			element._state(resolved.value)
		end
		element._scopeSource(resolved.source)
		element._scopeIsInherited(resolved.inherited)
		syncing = false
	end

	local unsubs: { () -> () } = {}

	table.insert(
		unsubs,
		sub(element._state, function(value: any): ()
			if syncing then
				return
			end
			local target = globalOnly and GLOBAL_ID or peek(scopeState.currentScope)
			ScopeController.SetValue(key, value, target)
		end)
	)

	table.insert(unsubs, sub(scopeState.currentScope, pushFromStore))
	table.insert(unsubs, sub(scopeState.values, pushFromStore))
	table.insert(unsubs, sub(scopeState.enabled, pushFromStore))

	pushFromStore()

	_bound[key] = { element = element, unsubs = unsubs }

	return function()
		ScopeController.UnbindElement(key)
	end
end

function ScopeController.UnbindElement(key: string): ()
	local entry = _bound[key]
	if not entry then
		return
	end
	for _, fn in next, entry.unsubs do
		fn()
	end
	_bound[key] = nil
	_globalOnlyKeys[key] = nil
end

function ScopeController.IsBound(key: string): boolean
	return _bound[key] ~= nil
end

function ScopeController.RevertOverride(key: string, scopeId: string?): ()
	ScopeController.ClearValue(key, scopeId)
end

function ScopeController.ListScopesGrouped(): { { groupLabel: string?, scopes: { ScopeDef } } }
	local order = peek(scopeState.order)
	local scopes = peek(scopeState.scopes)

	local groupOrder: { string? } = {}
	local seen: { [string]: boolean } = {}
	local buckets: { [string]: { ScopeDef } } = {}

	for _, id in next, order do
		local def = scopes[id]
		if not def then
			continue
		end
		local groupLabel = def.groupLabel
		local key = groupLabel or "__root__"
		if not seen[key] then
			seen[key] = true
			groupOrder[#groupOrder + 1] = groupLabel
		end
		local bucket = buckets[key] or {}
		bucket[#bucket + 1] = def
		buckets[key] = bucket
	end

	local out: { { groupLabel: string?, scopes: { ScopeDef } } } = {}
	for _, label in next, groupOrder do
		local key = label or "__root__"
		out[#out + 1] = { groupLabel = label, scopes = buckets[key] }
	end
	return out
end

local SettingsProxy = {}
SettingsProxy.__index = function(self, key: string): any
	local prefix = rawget(self, "_prefix")
	local fullKey = prefix == "" and key or prefix :: string .. "." .. key
	return ScopeController.GetResolvedValue(fullKey)
end

export type Settings = typeof(setmetatable({} :: { _prefix: string }, SettingsProxy))

function ScopeController.Settings(prefix: string): Settings
	return setmetatable({ _prefix = prefix or "" }, SettingsProxy) :: any
end

local function buildSnapshot(prefix: string): { [string]: any }
	local prefixDot = prefix == "" and "" or prefix .. "."
	local prefixLen = #prefixDot
	local snap: { [string]: any } = {}
	for key in next, _bound do
		if prefixLen == 0 or string.sub(key, 1, prefixLen) == prefixDot then
			local subkey = prefixLen == 0 and key or string.sub(key, prefixLen + 1)
			snap[subkey] = ScopeController.GetResolvedValue(key)
		end
	end
	return snap
end

function ScopeController.Snapshot(prefix: string?): { [string]: any }
	return buildSnapshot(prefix or "")
end

function ScopeController.Watch(prefix: string, callback: (snapshot: { [string]: any }) -> ()): () -> ()
	local function refresh(): ()
		callback(buildSnapshot(prefix))
	end

	refresh()

	local unsubs: { () -> () } = {
		sub(scopeState.values, refresh),
		sub(scopeState.equippedScope, refresh),
		sub(scopeState.enabled, refresh),
	}

	return function()
		for _, fn in next, unsubs do
			fn()
		end
	end
end

function ScopeController.OnChange(key: string, callback: (value: any) -> ()): () -> ()
	local last = ScopeController.GetResolvedValue(key)
	callback(last)

	local function refresh(): ()
		local current = ScopeController.GetResolvedValue(key)
		if current == last then
			return
		end
		last = current
		callback(current)
	end

	local unsubs: { () -> () } = {
		sub(scopeState.values, refresh),
		sub(scopeState.equippedScope, refresh),
		sub(scopeState.enabled, refresh),
	}

	local bound = _bound[key]
	if bound and bound.element and bound.element._overrides then
		table.insert(unsubs, sub(bound.element._overrides, refresh))
	end

	return function()
		for _, fn in next, unsubs do
			fn()
		end
	end
end

function ScopeController.new(): ScopeController
	return ScopeController
end

function ScopeController.Destroy(): ()
	stateConverter.UnregisterExtension("scopes")
	for key in next, _bound do
		ScopeController.UnbindElement(key)
	end
	_globalOnlyKeys = {}
	_scopeKeyResolvers = {}
end

export type ScopeController = typeof(ScopeController)

return ScopeController
