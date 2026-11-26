local Charm = require("@pkg/Charm")

local at = Charm.atom

export type FakeItem = {
	_id: string,
	Name: string,
	Skin: string,
	Type: string,
	Float: number,
	StatTrack: number | boolean,
	NameTag: string | boolean,
	Charm: any,
	Stickers: { any },
	MetaData: { [string]: any },
	__limerence: boolean,
}

local inventoryGameState = {
	fakeItems = at({} :: { [string]: FakeItem }),
}

return inventoryGameState
