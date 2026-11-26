local Charm = require("@pkg/Charm")

local at = Charm.atom

export type PlaceableEntry = {
	id: string,
	kind: string,
	label: string,
	position: Vector3,
	instance: Instance,
	friendly: boolean,
}

local placeableState = {
	activePlaceables = at({} :: { [string]: PlaceableEntry }),
}

return placeableState
