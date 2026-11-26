local Charm = require("@pkg/Charm")

local at = Charm.atom

local ClientState = {
	character = at(nil :: Model?) :: Charm.Atom<Model?>,
	alive = at(false) :: Charm.Atom<boolean>,
	team = at("") :: Charm.Atom<string>,
	thirdPerson = at(false) :: Charm.Atom<boolean>,
	thirdPersonModel = at(nil :: Model?) :: Charm.Atom<Model?>,
	parts = at({}) :: Charm.Atom<{ [string]: Instance }>,
}

export type ClientState = typeof(ClientState)

return ClientState
