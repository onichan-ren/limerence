local Charm = require("@pkg/Charm")

local at = Charm.atom

export type EquippedItem = {
	Name: string,
	Rounds: number?,
	Capacity: number?,
}

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
	maxHealth = at(150) :: Charm.Atom<number>,
	team = at("") :: Charm.Atom<string>,
	environmentId = at("") :: Charm.Atom<string>,

	currentEquipped = at(nil :: EquippedItem?) :: Charm.Atom<EquippedItem?>,
	isInDuel = at(false) :: Charm.Atom<boolean>,
	isSpectating = at(false) :: Charm.Atom<boolean>,
	isHidden = at(false) :: Charm.Atom<boolean>,
	isCrouching = at(false) :: Charm.Atom<boolean>,
	isSliding = at(false) :: Charm.Atom<boolean>,
	isFirstPerson = at(false) :: Charm.Atom<boolean>,
	isFrozen = at(false) :: Charm.Atom<boolean>,
	isInvincible = at(false) :: Charm.Atom<boolean>,
	controls = at("") :: Charm.Atom<string>,
	aimCFrame = at(CFrame.identity) :: Charm.Atom<CFrame>,
	items = at({} :: { string }) :: Charm.Atom<{ string }>,
	velocity = at(Vector3.zero) :: Charm.Atom<Vector3>,

	level = at(0) :: Charm.Atom<number>,
	winStreak = at(0) :: Charm.Atom<number>,
	displayElo = at(0) :: Charm.Atom<number>,
}

export type ClientState = typeof(ClientState)

return ClientState
