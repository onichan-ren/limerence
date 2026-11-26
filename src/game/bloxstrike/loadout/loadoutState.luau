local Charm = require("@pkg/Charm")

local at = Charm.atom

local loadoutState = {
	loadout = at({ Inventory = {} }) :: Charm.Atom<Loadout>,
	inventory = at({}) :: Charm.Atom<{ [number]: LoadoutEntry }>,
	currentEquipped = at(nil) :: Charm.Atom<LoadoutEntry?>,
}

export type LoadoutState = typeof(loadoutState)
export type LoadoutEntry = {
	Viewmodel: any?,
	OriginalOwner: any?,
	Properties: any?,
	Identifier: any?,
	StatTrack: any?,
	Stickers: any?,
	NameTag: any?,
	Player: any?,
	Float: any?,
	Name: any?,
	Charm: any?,
	Skin: any?,
	Slot: any?,
	_id: any?,
}
export type Inventory = { [number]: LoadoutEntry }
export type Loadout = { Inventory: Inventory, CurrentEquipped: LoadoutEntry? }
return loadoutState
