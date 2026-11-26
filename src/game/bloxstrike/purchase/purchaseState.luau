local Charm = require("@pkg/Charm")

local at = Charm.atom

export type PurchaseKind = "weapon" | "equipment"

export type PurchaseEvent = {
	player: Player,
	playerName: string,
	name: string,
	kind: PurchaseKind,
	icon: string,
	cost: number,
	refund: boolean,
	friendly: boolean,
	isLocal: boolean,
	at: number,
}

local purchaseState = {
	recent = at({} :: { PurchaseEvent }) :: Charm.Atom<{ PurchaseEvent }>,
}

export type PurchaseState = typeof(purchaseState)

return purchaseState
