local Charm = require("@pkg/Charm")

local at = Charm.atom

export type BrickProperties = {
	Color: Color3?,
	Material: string?,
	Reflectance: number?,
}

export type TextureProperties = {
	Color: Color3?,
	Transparency: number?,
	Emissivity: number?,
	StudsPerTileU: number?,
	StudsPerTileV: number?,
	OffsetStudsU: number?,
	OffsetStudsV: number?,
}

export type SlotData = {
	skin: string?,
	brick: BrickProperties?,
	texture: TextureProperties?,
}

export type WeaponEquipped = {
	slots: { [string]: SlotData },
}

local pfSkinState = {
	ready = at(false),
	selectedWeapon = at(nil :: string?),
	activeSlot = at(nil :: string?),
	weaponInventory = at({} :: { [string]: WeaponEquipped }),
	inventorySearch = at(""),
	weaponSearch = at(""),
	inventoryFolder = at(nil :: string?),
}

return pfSkinState
