local Charm = require("@pkg/Charm")

local at = Charm.atom

local legitbotState = {
	target = at(nil :: Player?),
	targetPart = at(nil :: BasePart?),
}

return legitbotState
