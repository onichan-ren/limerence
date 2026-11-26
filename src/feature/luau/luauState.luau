local Charm = require("@pkg/Charm")

local at = Charm.atom

export type ScriptStatus = "discovered" | "loaded" | "error"

export type ScriptInfo = {
	name: string,
	status: ScriptStatus,
	error: string?,
	hasTab: boolean,
}

local luauState = {
	scripts = at({} :: { [string]: ScriptInfo }),
}

export type LuauState = typeof(luauState)

return luauState
