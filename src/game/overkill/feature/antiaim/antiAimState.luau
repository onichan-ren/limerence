local Charm = require("@pkg/Charm")

local at = Charm.atom

local antiAimState = {
	lookAngles = at(nil :: Vector3?) :: Charm.Atom<Vector3?>,
	yawOffset = at(0) :: Charm.Atom<number>,
}

return antiAimState
