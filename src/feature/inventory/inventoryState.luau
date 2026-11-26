local Charm = require("@pkg/Charm")

local at = Charm.atom

export type SortMode = "rarity" | "name" | "weapon"

local inventoryState = {
	activeCategory = at("all") :: Charm.Atom<string>,
	currentPage = at(1) :: Charm.Atom<number>,
	pageSize = at(12) :: Charm.Atom<number>,
	sortMode = at("rarity" :: SortMode) :: Charm.Atom<SortMode>,
}

return inventoryState
