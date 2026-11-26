local bombApi = require("@game/bloxstrike/bomb/bombApi")
local hostageApi = require("@game/bloxstrike/hostage/hostageApi")
local gamemodeApi = require("@game/bloxstrike/gamemodeApi")
local droppedItemApi = require("@game/bloxstrike/dropped/droppedItemApi")
local grenadeApi = require("@game/bloxstrike/grenade/grenadeApi")
local purchaseApi = require("@game/bloxstrike/purchase/purchaseApi")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local luauGameApi = {}

luauApiRegistry.Register("game", function(ctx)
	local wrap = luauApiRegistry.WrapSignal
	return {
		getBomb = bombApi.GetBomb,
		getBombTime = bombApi.GetBombTime,
		isBombPlanted = bombApi.IsPlanted,
		isBombDefusing = bombApi.IsDefusing,
		isBombDefused = bombApi.IsDefused,
		isBombExploded = bombApi.IsExploded,
		getPlanting = bombApi.GetPlanting,

		onBombPlanted = wrap(bombApi.signals.onBombPlanted, ctx.onUnload),
		onBombDefused = wrap(bombApi.signals.onBombDefused, ctx.onUnload),
		onBombExploded = wrap(bombApi.signals.onBombExploded, ctx.onUnload),
		onBombCleared = wrap(bombApi.signals.onBombCleared, ctx.onUnload),
		onPlantingStarted = wrap(bombApi.signals.onPlantingStarted, ctx.onUnload),
		onPlantingEnded = wrap(bombApi.signals.onPlantingEnded, ctx.onUnload),

		getHostages = hostageApi.GetHostages,
		getHostage = hostageApi.GetHostage,
		getRescueRemaining = hostageApi.GetRescueRemaining,
		getRescueProgress = hostageApi.GetRescueProgress,

		onHostageAdded = wrap(hostageApi.signals.onHostageAdded, ctx.onUnload),
		onHostageRemoved = wrap(hostageApi.signals.onHostageRemoved, ctx.onUnload),
		onHostageChanged = wrap(hostageApi.signals.onHostageChanged, ctx.onUnload),

		getGamemode = gamemodeApi.GetGamemode,
		getServerGamemode = gamemodeApi.GetServerGamemode,
		isDeathmatch = gamemodeApi.IsDeathmatch,
		isBombDefusal = gamemodeApi.IsBombDefusal,
		isHostageRescue = gamemodeApi.IsHostageRescue,
		isCompetitive = gamemodeApi.IsCompetitive,

		onGamemodeChanged = wrap(gamemodeApi.signals.onGamemodeChanged, ctx.onUnload),
		onServerGamemodeChanged = wrap(gamemodeApi.signals.onServerGamemodeChanged, ctx.onUnload),

		getDroppedItems = droppedItemApi.GetDroppedItems,
		getDroppedItem = droppedItemApi.GetDroppedItem,

		onDroppedItemAdded = wrap(droppedItemApi.signals.onDroppedItemAdded, ctx.onUnload),
		onDroppedItemRemoved = wrap(droppedItemApi.signals.onDroppedItemRemoved, ctx.onUnload),

		getGrenades = grenadeApi.GetGrenades,

		onGrenadeAdded = wrap(grenadeApi.signals.onGrenadeAdded, ctx.onUnload),
		onGrenadeRemoved = wrap(grenadeApi.signals.onGrenadeRemoved, ctx.onUnload),

		getPurchases = purchaseApi.GetPurchases,
		getLastPurchase = purchaseApi.GetLastPurchase,
		getItemIcon = purchaseApi.GetItemIcon,
		getItemCost = purchaseApi.GetItemCost,

		onPurchase = wrap(purchaseApi.signals.onPurchase, ctx.onUnload),
		onSell = wrap(purchaseApi.signals.onSell, ctx.onUnload),
	}
end)

return luauGameApi
