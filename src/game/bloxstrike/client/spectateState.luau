local Charm = require("@pkg/Charm")

local at = Charm.atom

local SpectateState = {
	player = at(nil :: Player?),
	instance = at(nil :: any?),
}

return SpectateState
