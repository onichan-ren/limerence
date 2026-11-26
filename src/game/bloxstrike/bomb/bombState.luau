local Charm = require("@pkg/Charm")

local at = Charm.atom

export type BombState = {
	model: Model,
	startedAt: number,
	explodeAt: number,
	duration: number,
	isDefusing: boolean,
	isDefused: boolean,
	isExploded: boolean,
}

export type PlantingState = {
	site: string?,
	startedAt: number,
	duration: number,
}

local bombState = {
	bomb = at(nil :: BombState?),
	leaving = at(false),
	planting = at(nil :: PlantingState?),
	hudEnabled = at(false),
	hudPosition = at(UDim2.new(0.5, -80, 0, 64)),
}

export type State = typeof(bombState)

return bombState
