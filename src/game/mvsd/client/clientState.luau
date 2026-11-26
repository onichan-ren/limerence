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
	roundActive = at(false) :: Charm.Atom<boolean>,
	spectateMatchId = at(nil :: any) :: Charm.Atom<any>,
	gamemode = at(nil :: string?) :: Charm.Atom<string?>,
	weapon = at("") :: Charm.Atom<string>,
	equippedTool = at(nil :: Tool?) :: Charm.Atom<Tool?>,
	blinded = at(false) :: Charm.Atom<boolean>,
	combatDisabled = at(false) :: Charm.Atom<boolean>,
	invulnerable = at(false) :: Charm.Atom<boolean>,
	sprinting = at(false) :: Charm.Atom<boolean>,
	spectatorCount = at(0) :: Charm.Atom<number>,
}

export type ClientState = typeof(ClientState)

return ClientState
