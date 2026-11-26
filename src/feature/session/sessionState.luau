local Charm = require("@pkg/Charm")

local at = Charm.atom

local sessionState = {
	username = at("") :: Charm.Atom<string>,
	cheat = at("limerence") :: Charm.Atom<string>,
	build = at("") :: Charm.Atom<string>,
	gameName = at("") :: Charm.Atom<string>,
	ping = at(0) :: Charm.Atom<number>,
	fps = at(0) :: Charm.Atom<number>,
	playTime = at(0) :: Charm.Atom<number>,
}

export type SessionState = typeof(sessionState)

return sessionState
