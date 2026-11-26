local Charm = require("@pkg/Charm")

local thirdPersonState = {
	active = Charm.atom(false),
	clone = Charm.atom(nil :: any),
	revision = Charm.atom(0),
}

function thirdPersonState.bump(): ()
	thirdPersonState.revision(thirdPersonState.revision() + 1)
end

return thirdPersonState
