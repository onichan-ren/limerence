local Charm = require("@pkg/Charm")

local at = Charm.atom

export type WeaponEquipped = {
	skin: string?,
}

local ar2InventoryState = {
	ready = at(false),
	selectedWeapon = at(nil :: string?),
	weaponInventory = at({} :: { [string]: WeaponEquipped }),
	inventorySearch = at(""),
	weaponSearch = at(""),
	inventoryFolder = at(nil :: string?),
}

return ar2InventoryState
