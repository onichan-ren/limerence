local Charm = require("@pkg/Charm")

local at = Charm.atom

export type ScopeKind = "global" | "group" | "weapon" | "custom"

export type ScopeDef = {
	id: string,
	parent: string?,
	label: string,
	kind: ScopeKind,
	groupLabel: string?,
	layoutOrder: number?,
	icon: string?,
}

export type ScopeValueMap = { [string]: { [string]: any } }

local scopeState = {
	scopes = at({} :: { [string]: ScopeDef }),
	order = at({} :: { string }),
	values = at({} :: ScopeValueMap),
	enabled = at({} :: { [string]: boolean }),
	currentScope = at("global"),
	equippedScope = at("global"),
	equipped = at(nil :: string?),
	autoFollowEquipped = at(true),
	menuOpen = at(false),
	menuPosition = at(UDim2.new(0, 0, 0, 0)),
}

export type ScopeState = typeof(scopeState)

return scopeState
