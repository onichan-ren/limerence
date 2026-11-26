local Charm = require("@pkg/Charm")

local at = Charm.atom

export type WeaponEquipped = {
	skin: string?,
	wrap: string?,
	charm: string?,
	finisher: string?,
	killEffect: string?,
}

local overkillInventoryState = {
	TYPE_FIELD = {
		Skin = "skin",
		Wrap = "wrap",
		Charm = "charm",
		Finisher = "finisher",
		KillEffect = "killEffect",
	} :: { [string]: string },
	ready = at(false),
	selectedWeapon = at(nil :: string?),
	selectedType = at("Skin"),
	weaponInventory = at({} :: { [string]: WeaponEquipped }),
	unlockedSkins = at({} :: { [string]: { [string]: boolean } }),
	unlockedCosmetics = at({} :: { [string]: { [string]: boolean } }),
	inventorySearch = at(""),
	weaponSearch = at(""),
}

return overkillInventoryState
