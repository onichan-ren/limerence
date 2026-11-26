local Charm = require("@pkg/Charm")

local at = Charm.atom

export type IncomingGrenade = {
	name: string,
	landing: Vector3,
	path: { Vector3 },
	detonateAt: number,
	fuse: number,
	blastRadius: number,
	damageGraph: any,
	isFriendly: boolean,
	isSelf: boolean,
}

local grenadeState = {
	incoming = at({} :: { [any]: IncomingGrenade }),
}

export type GrenadeState = typeof(grenadeState)

return grenadeState
