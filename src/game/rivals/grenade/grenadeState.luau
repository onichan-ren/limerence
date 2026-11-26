local Charm = require("@pkg/Charm")

local at = Charm.atom

export type FireEntry = {
	fireId: string,
	position: Vector3?,
	duration: number?,
	startedAt: number?,
	team: string?,
	isFriendly: boolean?,
}

export type SmokeEntry = {
	smokeId: string,
	position: Vector3?,
	duration: number?,
	startedAt: number?,
	team: string?,
	isFriendly: boolean?,
	part: BasePart?,
	model: Model?,
}

export type ProjectileEntry = {
	id: string,
	weapon: string,
	landingPosition: Vector3,
	detonateAt: number,
	startedAt: number,
	team: string?,
	isFriendly: boolean,
	projectilePart: BasePart?,
	visualModel: Model?,
	sourceItem: any?,
	gravityY: number?,
	raycastParams: RaycastParams?,
	raycastCharacter: Model?,
}

local grenadeState = {
	activeSmokes = at({} :: { [string]: SmokeEntry }),
	activeFires = at({} :: { [string]: FireEntry }),
	activeProjectiles = at({} :: { [string]: ProjectileEntry }),
}

return grenadeState
