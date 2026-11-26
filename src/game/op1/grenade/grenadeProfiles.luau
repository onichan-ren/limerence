export type Profile = {
	tag: string,
	displayName: string,
	blastRadius: number,
	bounces: number,
	throwSpeed: number,
	kind: string,
	image: string,
	fuse: number,
}

local grenadeProfiles: { [string]: Profile } = {
	FragGrenade = { tag = "FragGrenade", displayName = "Frag", blastRadius = 6, bounces = 1, throwSpeed = 60, kind = "explosive", image = "rbxassetid://97379391025395", fuse = 2.5 },
	ImpactGrenade = { tag = "ImpactGrenade", displayName = "Impact", blastRadius = 4, bounces = 0, throwSpeed = 75, kind = "explosive", image = "rbxassetid://82566182556978", fuse = 0 },
	StunGrenade = { tag = "StunGrenade", displayName = "Stun", blastRadius = 5, bounces = 1, throwSpeed = 60, kind = "flash", image = "rbxassetid://91607549185881", fuse = 1.5 },
	SmokeGrenade = { tag = "SmokeGrenade", displayName = "Smoke", blastRadius = 8, bounces = 1, throwSpeed = 60, kind = "smoke", image = "rbxassetid://132415942925232", fuse = 1.5 },
	IncendiaryGrenade = { tag = "IncendiaryGrenade", displayName = "Incendiary", blastRadius = 6, bounces = 1, throwSpeed = 60, kind = "fire", image = "rbxassetid://75242798725556", fuse = 2.5 },
	EMPGrenade = { tag = "EMPGrenade", displayName = "EMP", blastRadius = 5, bounces = 1, throwSpeed = 60, kind = "emp", image = "rbxassetid://108313165168310", fuse = 2.5 },
}

return grenadeProfiles
