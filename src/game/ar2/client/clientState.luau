local Charm = require("@pkg/Charm")
local at = Charm.atom

local ClientState = {
	alive = at(false) :: Charm.Atom<boolean>,
	parts = at({}) :: Charm.Atom<{ [string]: Instance }>,
	character = at(nil :: Model?) :: Charm.Atom<Model?>,
	health = at(0) :: Charm.Atom<number>,
	hydration = at(0) :: Charm.Atom<number>,
	energy = at(0) :: Charm.Atom<number>,
	hrp = at(nil) :: Charm.Atom<BasePart?>,
	humanoid = at(nil) :: Charm.Atom<Humanoid?>,
	team = at(nil) :: Charm.Atom<string?>,
	thirdPerson = at(false) :: Charm.Atom<boolean>,
	vehicle = at(nil :: Model?) :: Charm.Atom<Model?>,
}
export type ClientState = typeof(ClientState)

return ClientState
