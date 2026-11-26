local Charm = require("@pkg/Charm")

local at = Charm.atom

export type HostageEntry = {
	model: Model,
	state: string,
	canRescue: boolean,
	rescuingPlayer: string?,
	carryingPlayer: string?,
	rescueStartedAt: number?,
	rescueDuration: number?,
}

local hostageState = {
	hostages = at({} :: { [string]: HostageEntry }),
}

export type State = typeof(hostageState)

return hostageState
