local Charm = require("@pkg/Charm")

local at = Charm.atom

local clientState = {
	alive = at(false) :: Charm.Atom<boolean>,
	parts = at({}) :: Charm.Atom<{ [string]: Instance }>,
	character = at(nil :: Model?) :: Charm.Atom<Model?>,
	hrp = at(nil :: BasePart?) :: Charm.Atom<BasePart?>,
	humanoid = at(nil :: Humanoid?) :: Charm.Atom<Humanoid?>,
	health = at(0) :: Charm.Atom<number>,
	maxHealth = at(100) :: Charm.Atom<number>,
	team = at("") :: Charm.Atom<string>,
	charObject = at(nil :: any) :: Charm.Atom<any>,
	spectatorCount = at(0) :: Charm.Atom<number>,
}

return clientState
