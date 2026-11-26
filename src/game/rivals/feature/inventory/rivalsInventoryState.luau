local Charm = require("@pkg/Charm")

local at = Charm.atom

export type WeaponEquipped = {
	skin: string?,
	wrap: string?,
	charm: string?,
	finisher: string?,
	wrapInverted: boolean?,
}

local rivalsInventoryState = {
	ready = at(false),
	selectedWeapon = at(nil :: string?),
	selectedType = at("Skin"),
	currentPage = at(1),
	pageSize = at(24),
	weaponInventory = at({} :: { [string]: WeaponEquipped }),
	equippedEmotes = at({} :: { [number]: string }),
	unlockedCosmetics = at({} :: { [string]: boolean }),
	inventorySearch = at(""),
	weaponSearch = at(""),
	rankCharmSeasons = at({} :: { [string]: number }),
	rankCharmArchRank = at(1),
	customWrapsRev = at(0),
}

return rivalsInventoryState
