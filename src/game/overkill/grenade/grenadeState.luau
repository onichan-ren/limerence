local Charm = require("@pkg/Charm")

local at = Charm.atom

export type ProjectileEntry = {
	id: string,
	weaponId: string,
	displayName: string,
	isExplosive: boolean,
	explosionRadius: number,
	fuseTime: number?,
	startedAt: number,
	detonateAt: number?,
	team: string?,
	isFriendly: boolean,
	spawnPosition: Vector3,
	predictedPosition: Vector3?,
	model: Model?,
}

local grenadeState = {
	activeProjectiles = at({} :: { [string]: ProjectileEntry }),
}

return grenadeState
