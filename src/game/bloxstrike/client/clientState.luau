local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")

local at = Charm.atom

export type ArmorState = {
	kevlar: boolean,
	helmet: boolean,
	health: number,
}

local EMPTY_ARMOR: ArmorState = { kevlar = false, helmet = false, health = 0 }

local ClientState = {
	team = at(nil) :: Charm.Atom<Team?>,
	parts = at({}) :: Charm.Atom<{ [string]: Instance }>,
	alive = at(false) :: Charm.Atom<boolean>,
	character = at(nil :: Model?) :: Charm.Atom<Model?>,
	isSpectating = at(false) :: Charm.Atom<boolean>,
	isFlashed = at(false) :: Charm.Atom<boolean>,
	flashVisibility = at(0) :: Charm.Atom<number>,
	isScoped = at(false) :: Charm.Atom<boolean>,
	isDefusing = at(false) :: Charm.Atom<boolean>,
	hasC4 = at(false) :: Charm.Atom<boolean>,
	armor = at(EMPTY_ARMOR) :: Charm.Atom<ArmorState>,
	spectatorCount = at(0) :: Charm.Atom<number>,
}

ClientState.EMPTY_ARMOR = EMPTY_ARMOR

export type ClientState = typeof(ClientState)
export type Team = "Terrorists" | "Counter-Terrorists"
export type EquippedItemData = {
	Slot: number,
	Name: string,
	Janitor: Janitor.Janitor,
	Viewmodel: any?,
}
export type LoadoutEntry = {
	slot: number,
	identifier: string?,
	_id: any?,
	weapon: string,
	originalWeapon: string,
	skin: string?,
	originalSkin: string?,
	float: number?,
	statTrack: number?,
	nameTag: string?,
	originalOwner: any?,
	charm: any?,
	stickers: any?,
	customProperties: any?,
}
return ClientState
