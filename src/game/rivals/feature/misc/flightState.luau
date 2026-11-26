local Charm = require("@pkg/Charm")

local flightState = {
	enabled = Charm.atom(false),
}

return flightState
