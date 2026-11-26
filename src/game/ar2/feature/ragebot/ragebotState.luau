local Charm = require("@pkg/Charm")

local at = Charm.atom

local ragebotState = {
	currentTarget = at(nil :: Player?),
	currentTargetPart = at(nil :: BasePart?),
	lastShotAt = at(nil :: number?),
	enabled = at(false),
}

return ragebotState
