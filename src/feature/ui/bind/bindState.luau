local Charm = require("@pkg/Charm")
local Bind = require("@ui/bind/Bind")

local at = Charm.atom

local bindState = {
	binds = at({}) :: Charm.Atom<{ [string]: Bind }>,
	activeBinds = at({}) :: Charm.Atom<{ [string]: Bind }>,
}

export type BindState = typeof(bindState)
type Bind = Bind.Bind

return bindState
