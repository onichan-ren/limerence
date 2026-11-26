local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ScopeController = require("@ui/scope/ScopeController")
local scopeState = require("@ui/scope/scopeState")

local useAt = ReactCharm.useAtom
local useMemo = React.useMemo
local useCallback = React.useCallback

local hooks = {}

export type ScopeContext = {
	currentScope: string,
	currentScopeDef: ScopeController.ScopeDef?,
	scopes: { [string]: ScopeController.ScopeDef },
	equipped: string?,
	autoFollow: boolean,
	setCurrentScope: (id: string) -> (),
	setAutoFollow: (enabled: boolean) -> (),
}

export type ScopedValue<T> = {
	value: T,
	source: string,
	inherited: boolean,
	exists: boolean,
	setValue: (value: T) -> (),
	clearOverride: () -> (),
}

function hooks.useScope(): ScopeContext
	local current = useAt(scopeState.currentScope)
	local scopes = useAt(scopeState.scopes)
	local equipped = useAt(scopeState.equipped)
	local autoFollow = useAt(scopeState.autoFollowEquipped)

	return useMemo(function(): ScopeContext
		return {
			currentScope = current,
			currentScopeDef = scopes[current],
			scopes = scopes,
			equipped = equipped,
			autoFollow = autoFollow,
			setCurrentScope = ScopeController.SetCurrentScope,
			setAutoFollow = ScopeController.SetAutoFollow,
		}
	end, { current, scopes, equipped, autoFollow } :: { any })
end

function hooks.useScopedValue<T>(key: string): ScopedValue<T>
	local current = useAt(scopeState.currentScope)
	useAt(scopeState.values)

	local resolved = ScopeController.Resolve(key, current)

	local setValue = useCallback(function(value: T): ()
		ScopeController.SetValue(key, value, current)
	end, { key, current } :: { any })

	local clearOverride = useCallback(function(): ()
		ScopeController.ClearValue(key, current)
	end, { key, current } :: { any })

	return useMemo(function(): ScopedValue<T>
		return {
			value = resolved.value :: T,
			source = resolved.source,
			inherited = resolved.inherited,
			exists = resolved.exists,
			setValue = setValue,
			clearOverride = clearOverride,
		}
	end, { resolved.value, resolved.source, resolved.inherited, resolved.exists, setValue, clearOverride } :: { any })
end

function hooks.useResolvedSettings(scopeId: string?): { [string]: any }
	local currentScope = useAt(scopeState.currentScope)
	local values = useAt(scopeState.values)
	local scopes = useAt(scopeState.scopes)
	local target = scopeId or currentScope

	return useMemo(function(): { [string]: any }
		return ScopeController.GetResolvedSettings(target)
	end, { target, values, scopes } :: { any })
end

function hooks.useGroupedScopes(): { { groupLabel: string?, scopes: { ScopeController.ScopeDef } } }
	useAt(scopeState.scopes)
	useAt(scopeState.order)
	return ScopeController.ListScopesGrouped()
end

return hooks
