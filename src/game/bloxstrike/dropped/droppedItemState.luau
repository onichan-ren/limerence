local Charm = require("@pkg/Charm")

local at = Charm.atom

export type DroppedKind = "weapon" | "bomb" | "item"

export type DroppedEntry = {
	model: Model,
	kind: DroppedKind,
	label: string,
	weaponName: string,
	showAmmo: boolean,
	rounds: number,
	maxRounds: number,
}

local droppedItemState = {
	entries = at({} :: { [Model]: DroppedEntry }),
}

export type DroppedItemState = typeof(droppedItemState)

return droppedItemState
