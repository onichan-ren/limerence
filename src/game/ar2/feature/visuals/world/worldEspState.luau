local Charm = require("@pkg/Charm")

local at = Charm.atom

export type WorldEntry = {
	model: Model,
	label: string,
}

local worldEspState = {
	corpses = at({} :: { [Model]: WorldEntry }),
	vehicles = at({} :: { [Model]: WorldEntry }),
}

export type WorldEspState = typeof(worldEspState)

return worldEspState
