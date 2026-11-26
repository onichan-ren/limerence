local Charm = require("@pkg/Charm")

local at = Charm.atom

local speedometerState = {
	enabled = at(false),
	position = at(UDim2.new(0.5, 0, 1, -80)),
}

export type SpeedometerState = typeof(speedometerState)

return speedometerState
