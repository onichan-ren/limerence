local Charm = require("@pkg/Charm")

local at = Charm.atom

local ViewmodelState = {
	_viewmodel = at(nil :: any?),
}

return ViewmodelState
