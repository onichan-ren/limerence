local Charm = require("@pkg/Charm")

local PurchaseController = require("@game/bloxstrike/purchase/PurchaseController")
local purchaseState = require("@game/bloxstrike/purchase/purchaseState")
local itemDefs = require("@game/bloxstrike/purchase/itemDefs")

local peek = Charm.peek

export type Purchase = purchaseState.PurchaseEvent

local signals = {
	onPurchase = PurchaseController.purchased,
	onSell = PurchaseController.sold,
}

local purchaseApi = {
	state = purchaseState,
	signals = signals,
}

function purchaseApi.GetPurchases(): { Purchase }
	return table.clone(peek(purchaseState.recent))
end

function purchaseApi.GetLastPurchase(player: Player?): Purchase?
	local list = peek(purchaseState.recent)
	for index = #list, 1, -1 do
		local event = list[index]
		if not player or event.player == player then
			return event
		end
	end
	return nil
end

function purchaseApi.GetItemIcon(name: string): string
	return itemDefs.GetIcon(name)
end

function purchaseApi.GetItemCost(name: string): number
	return itemDefs.GetCost(name)
end

return purchaseApi
