local Charm = require("@pkg/Charm")

local at = Charm.atom

type Character = Model & {
	HumanoidRootPart: BasePart,
	Humanoid: Humanoid,
}

local ClientState = {
	character = at(nil :: Character?) :: Charm.Atom<Character?>,
	hrp = at(nil :: BasePart?) :: Charm.Atom<BasePart?>,
	humanoid = at(nil :: Humanoid?) :: Charm.Atom<Humanoid?>,
	parts = at({}) :: Charm.Atom<{ [string]: Instance }>,
	alive = at(false) :: Charm.Atom<boolean>,
	health = at(0) :: Charm.Atom<number>,
	maxHealth = at(100) :: Charm.Atom<number>,
	team = at("") :: Charm.Atom<string>,
	matchId = at(nil :: any) :: Charm.Atom<any>,
	inRange = at(false) :: Charm.Atom<boolean>,
	aiming = at(false) :: Charm.Atom<boolean>,
	scoped = at(false) :: Charm.Atom<boolean>,
	fpCamera = at(nil :: CFrame?) :: Charm.Atom<CFrame?>,
	inAir = at(false) :: Charm.Atom<boolean>,
	sprinting = at(false) :: Charm.Atom<boolean>,
	canFire = at(false) :: Charm.Atom<boolean>,
	weaponId = at("") :: Charm.Atom<string>,
	weapon = at("") :: Charm.Atom<string>,
	weaponCategory = at("") :: Charm.Atom<string>,
	ammo = at(0) :: Charm.Atom<number>,
	ammoReserve = at(0) :: Charm.Atom<number>,
	magSize = at(0) :: Charm.Atom<number>,
	isReloading = at(false) :: Charm.Atom<boolean>,
	equippedSlot = at(1) :: Charm.Atom<number>,
	spectatorCount = at(0) :: Charm.Atom<number>,
}

export type ClientState = typeof(ClientState)

return ClientState
