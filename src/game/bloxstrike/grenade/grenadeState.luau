local Charm = require("@pkg/Charm")

local at = Charm.atom

export type FireEntry = {
	voxels: { Instance },
	fireId: string?,
	position: Vector3?,
	duration: number?,
	startedAt: number?,
	team: string?,
	isFriendly: boolean?,
}

export type SmokeEntry = {
	voxels: { Instance },
	smokeId: string?,
	position: Vector3?,
	duration: number?,
	deployTime: number?,
	startedAt: number?,
	team: string?,
	isFriendly: boolean?,
}

export type ProjectileEntry = {
	id: string,
	weapon: string,
	pathPoints: { Vector3 },
	bounceIndices: { number },
	landingPosition: Vector3,
	detonateAt: number,
	startedAt: number,
	fuseTime: number?,
	leavesFire: boolean,
	resolved: boolean,
	team: string?,
	isFriendly: boolean,
}

local grenadeState = {
	activeSmokes = at({} :: { [string]: SmokeEntry }),
	activeFires = at({} :: { [string]: FireEntry }),
	activeProjectiles = at({} :: { [string]: ProjectileEntry }),
}

return grenadeState
