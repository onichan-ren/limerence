local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local themeState = require("@ui/theme/themeState")
local ToastController = require("@ui/hud/toast/ToastController")
local toastState = require("@ui/hud/toast/toastState")
local PurchaseController = require("@game/bloxstrike/purchase/PurchaseController")
local purchaseState = require("@game/bloxstrike/purchase/purchaseState")
local Charm = require("@pkg/Charm")

local peek = Charm.peek

local ICON_FADE_TIME = 0.35

type Item = {
	key: string,
	name: string,
	image: string,
	removing: boolean,
}

type Entry = {
	id: string,
	items: { Item },
	counter: number,
	seq: number,
}

local BuyLog = {}
BuyLog.__index = BuyLog

setmetatable(BuyLog, { __index = BaseFeature })

function BuyLog.new(link: gameUi.Linker): BuyLog
	local self = BaseFeature.new() :: any
	setmetatable(self, BuyLog)

	link:Toggle("buyLogs", "Buy Logs", false):SetTip({
		title = "Buy Logs",
		body = "Shows what each player buys as a row of icons. Selling an item takes its icon back off the row.",
	})

	local rootLink = link:OnKey("buyLogs")
	rootLink:Submenu("opts", "Buy Logs")
	local optionsLink = rootLink:OnKey("opts")

	optionsLink:Toggle("showTeammates", "Show Teammates", true):SetTip({
		title = "Show Teammates",
		body = "Includes buys from players on your team.",
	})
	optionsLink:Toggle("showYourself", "Show Yourself", false):SetTip({
		title = "Show Yourself",
		body = "Includes your own buys.",
	})
	optionsLink:Toggle("showEnemies", "Show Enemies", true):SetTip({
		title = "Show Enemies",
		body = "Includes buys from the enemy team.",
	})
	optionsLink:Slider("duration", "Duration", 4, 1, 15, 0.5, nil, "s"):SetTip({
		title = "Duration",
		body = "How long a row stays on screen after its last change.",
	})

	self._options = optionsLink
	self._enabledLink = link:Get("buyLogs")
	self._enabled = false
	self._entries = {}

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("buyLogs") then
		self:Enable()
	end

	return self
end

function BuyLog._accepts(self: BuyLog, event: purchaseState.PurchaseEvent): boolean
	if event.isLocal then
		return self._options:Peek("showYourself") == true
	end
	if event.friendly then
		return self._options:Peek("showTeammates") == true
	end
	return self._options:Peek("showEnemies") == true
end

function BuyLog._toIcons(self: BuyLog, entry: Entry): { toastState.ToastIcon }
	local items = entry.items
	local icons = table.create(#items)
	for index = 1, #items do
		local item = items[index]
		icons[index] = {
			key = item.key,
			image = item.image,
			removing = item.removing,
		}
	end
	return icons
end

function BuyLog._schedule(self: BuyLog, player: Player, entry: Entry): ()
	entry.seq += 1
	local seq = entry.seq
	local duration = tonumber(self._options:Peek("duration")) or 4
	local entries = self._entries :: { [Player]: Entry }
	task.delay(duration, function(): ()
		if entry.seq ~= seq or entries[player] ~= entry then
			return
		end
		self:_close(player, entry)
	end)
end

function BuyLog._close(self: BuyLog, player: Player, entry: Entry): ()
	local entries = self._entries :: { [Player]: Entry }
	if entries[player] == entry then
		entries[player] = nil
	end
	ToastController.Dismiss(entry.id)
end

function BuyLog._onPurchase(self: BuyLog, event: purchaseState.PurchaseEvent): ()
	if not self._enabled or not self:_accepts(event) then
		return
	end

	local entries = self._entries :: { [Player]: Entry }
	local entry = entries[event.player]
	if not entry then
		local accent = peek(themeState.colors.status.danger)
		if event.friendly or event.isLocal then
			accent = peek(themeState.colors.status.good)
		end

		entry = {
			id = ToastController.Push({
				text = string.format("<hl>%s</hl> bought", event.playerName),
				icons = {},
				accent = accent,
				duration = 0,
			}),
			items = {},
			counter = 0,
			seq = 0,
		}
		entries[event.player] = entry
	end

	entry.counter += 1
	entry.items[#entry.items + 1] = {
		key = `{event.name}#{entry.counter}`,
		name = event.name,
		image = event.icon,
		removing = false,
	}

	ToastController.Update(entry.id, { icons = self:_toIcons(entry) })
	self:_schedule(event.player, entry)
end

function BuyLog._onSell(self: BuyLog, event: purchaseState.PurchaseEvent): ()
	if not self._enabled then
		return
	end

	local entries = self._entries :: { [Player]: Entry }
	local entry = entries[event.player]
	if not entry then
		return
	end

	local target: Item? = nil
	for index = #entry.items, 1, -1 do
		local item = entry.items[index]
		if item.name == event.name and not item.removing then
			target = item
			break
		end
	end
	if not target then
		return
	end

	local removed = target :: Item
	removed.removing = true
	ToastController.Update(entry.id, { icons = self:_toIcons(entry) })
	self:_schedule(event.player, entry)

	task.delay(ICON_FADE_TIME, function(): ()
		if entries[event.player] ~= entry then
			return
		end
		local index = table.find(entry.items, removed)
		if not index then
			return
		end
		table.remove(entry.items, index)
		if #entry.items == 0 then
			self:_close(event.player, entry)
			return
		end
		ToastController.Update(entry.id, { icons = self:_toIcons(entry) })
	end)
end

function BuyLog.Enable(self: BuyLog): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._connections = {
		PurchaseController.purchased:Connect(function(event: purchaseState.PurchaseEvent): ()
			self:_onPurchase(event)
		end),
		PurchaseController.sold:Connect(function(event: purchaseState.PurchaseEvent): ()
			self:_onSell(event)
		end),
	}
end

function BuyLog.Disable(self: BuyLog): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	local connections = self._connections
	if connections then
		for index = 1, #connections do
			connections[index]:Disconnect()
		end
		self._connections = nil
	end

	local entries = self._entries :: { [Player]: Entry }
	for player, entry in next, entries do
		entries[player] = nil
		ToastController.Dismiss(entry.id)
	end
end

function BuyLog.Destroy(self: BuyLog): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type BuyLog = typeof(setmetatable(
	{} :: {
		_options: gameUi.Linker,
		_enabledLink: any,
		_enabled: boolean,
		_entries: { [Player]: Entry },
		_connections: { any }?,
	},
	BuyLog
)) & BaseFeature.BaseFeature

return BuyLog
