local Charm = require("@pkg/Charm")

local at = Charm.atom

export type DroppedEntry = {
	model: Model,
	label: string,
	position: Vector3,
}

local droppedWeaponState = {
	entries = at({} :: { [any]: DroppedEntry }),
}

export type DroppedWeaponState = typeof(droppedWeaponState)

return droppedWeaponState
