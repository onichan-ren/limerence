local Charm = require("@pkg/Charm")

local at = Charm.atom

local spectatorsState = {
	enabled = at(false),
	position = at(UDim2.new(0.5, 0, 0, 80)),
	hideWhenEmpty = at(true),
}

export type SpectatorsState = typeof(spectatorsState)

return spectatorsState
