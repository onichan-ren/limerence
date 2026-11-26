local Players = cloneref(game:GetService("Players")) :: Players
local HttpService = cloneref(game:GetService("HttpService")) :: HttpService

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local Signal = require("@pkg/Signal")

local itemDefs = require("@game/bloxstrike/purchase/itemDefs")
local purchaseState = require("@game/bloxstrike/purchase/purchaseState")
local gamemodeState = require("@game/bloxstrike/gamemodeState")

local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer

local MONEY_WINDOW = 0.75
local MAX_RECENT = 32
local SLOT_COUNT = 5

local WIPE_WINDOW = 0.1
local WIPE_COOLDOWN = 1

local BLOCKED_STATES: { [string]: boolean } = {
	["Intermission"] = true,
	["Game Ending"] = true,
	["Map Voting"] = true,
}

local SELL_STATES: { [string]: boolean } = {
	["Buy Period"] = true,
	["Warmup"] = true,
}

type Pending = {
	name: string,
	at: number,
}

type Record = {
	player: Player,
	janitor: Janitor.Janitor,
	characterJanitor: Janitor.Janitor,
	ready: boolean,
	alive: boolean,
	hasMoney: boolean,
	money: number,
	dropAt: number,
	riseAt: number,
	slotIds: { [number]: string },
	slotNames: { [number]: string },
	armorType: string,
	defuseKit: boolean,
	rescueKit: boolean,
	gains: { Pending },
	losses: { Pending },
	lastLossAt: number,
	wipedAt: number,
}

local PurchaseController = {
	purchased = Signal.new(),
	sold = Signal.new(),
	_janitor = Janitor.new(),
	_records = {} :: { [Player]: Record },
}

local function emit(record: Record, name: string, refund: boolean): ()
	local player = record.player
	local team = player:GetAttribute("Team")
	local localTeam = LocalPlayer:GetAttribute("Team")

	local kind: purchaseState.PurchaseKind = "weapon"
	if itemDefs.IsEquipment(name) then
		kind = "equipment"
	end

	local event: purchaseState.PurchaseEvent = {
		player = player,
		playerName = player.DisplayName,
		name = name,
		kind = kind,
		icon = itemDefs.GetIcon(name),
		cost = itemDefs.GetCost(name),
		refund = refund,
		friendly = team ~= nil and team == localTeam,
		isLocal = player == LocalPlayer,
		at = os.clock(),
	}

	local list = table.clone(peek(purchaseState.recent))
	list[#list + 1] = event
	if #list > MAX_RECENT then
		table.remove(list, 1)
	end
	purchaseState.recent(list)

	if refund then
		PurchaseController.sold:Fire(event)
	else
		PurchaseController.purchased:Fire(event)
	end
end

local function prune(list: { Pending }, now: number): ()
	local index = 1
	while index <= #list do
		if now - list[index].at > MONEY_WINDOW then
			table.remove(list, index)
		else
			index += 1
		end
	end
end

local function canSell(record: Record): boolean
	if not record.alive or not record.hasMoney then
		return false
	end
	if os.clock() - record.wipedAt <= WIPE_COOLDOWN then
		return false
	end
	return SELL_STATES[peek(gamemodeState.gameState) or ""] == true
end

local function flush(record: Record, list: { Pending }, refund: boolean): ()
	local count = #list
	if count == 0 then
		return
	end
	if refund and not canSell(record) then
		table.clear(list)
		return
	end
	local now = os.clock()
	for i = 1, count do
		local entry = list[i]
		if now - entry.at <= MONEY_WINDOW then
			emit(record, entry.name, refund)
		end
	end
	table.clear(list)
end

local function eligible(record: Record): boolean
	if not record.ready then
		return false
	end
	return not BLOCKED_STATES[peek(gamemodeState.gameState) or ""]
end

local function gained(record: Record, name: string): ()
	if name == "" or not eligible(record) then
		return
	end
	if not record.hasMoney then
		if peek(gamemodeState.gameState) == "Buy Period" then
			emit(record, name, false)
		end
		return
	end

	local now = os.clock()
	if now - record.dropAt <= MONEY_WINDOW then
		emit(record, name, false)
		return
	end
	prune(record.gains, now)
	record.gains[#record.gains + 1] = { name = name, at = now }
end

local function lost(record: Record, name: string): ()
	if name == "" or not eligible(record) then
		return
	end

	local now = os.clock()
	local batched = now - record.lastLossAt <= WIPE_WINDOW
	record.lastLossAt = now
	if batched then
		record.wipedAt = now
		table.clear(record.losses)
		return
	end

	if not canSell(record) then
		return
	end

	if now - record.riseAt <= MONEY_WINDOW then
		emit(record, name, true)
		return
	end
	prune(record.losses, now)
	record.losses[#record.losses + 1] = { name = name, at = now }
end

local function syncMoney(record: Record): ()
	local raw = record.player:GetAttribute("Money")
	record.hasMoney = raw ~= nil

	local value = tonumber(raw) or 0
	local delta = value - record.money
	record.money = value

	if delta < 0 then
		record.dropAt = os.clock()
		flush(record, record.gains, false)
	elseif delta > 0 then
		record.riseAt = os.clock()
		flush(record, record.losses, true)
	end
end

local function syncSlot(record: Record, index: number): ()
	local raw = record.player:GetAttribute("Slot" .. index)
	local name = ""
	local id = ""

	if type(raw) == "string" and raw ~= "" then
		local data = HttpService:JSONDecode(raw)
		if type(data) == "table" then
			local weapon = data.Weapon
			if type(weapon) == "string" then
				name = weapon
			end
			local identifier = data.Identifier
			id = (type(identifier) == "string" and identifier) or name
		end
	end

	if id == record.slotIds[index] then
		return
	end

	local previous = record.slotNames[index]
	record.slotIds[index] = id
	record.slotNames[index] = name

	if previous ~= "" then
		lost(record, previous)
	end
	gained(record, name)
end

local function syncArmor(record: Record): ()
	local raw = record.player:GetAttribute("Armor")
	local kind = ""

	if type(raw) == "string" and raw ~= "" then
		local data = HttpService:JSONDecode(raw)
		if type(data) == "table" and (tonumber(data.Health) or 0) > 0 then
			kind = tostring(data.Type or "")
		end
	end

	if kind == record.armorType then
		return
	end

	local previous = record.armorType
	record.armorType = kind

	if kind ~= "" then
		gained(record, kind)
	else
		lost(record, previous)
	end
end

local function syncDefuseKit(record: Record): ()
	local value = record.player:GetAttribute("HasDefuseKit") == true
	if value == record.defuseKit then
		return
	end
	record.defuseKit = value
	if value then
		gained(record, "Defuse Kit")
	else
		lost(record, "Defuse Kit")
	end
end

local function syncRescueKit(record: Record): ()
	local value = record.player:GetAttribute("HasRescueKit") == true
	if value == record.rescueKit then
		return
	end
	record.rescueKit = value
	if value then
		gained(record, "Rescue Kit")
	else
		lost(record, "Rescue Kit")
	end
end

local function markDead(record: Record): ()
	if not record.alive then
		return
	end
	record.alive = false
	record.wipedAt = os.clock()
	table.clear(record.losses)
end

local function bindCharacter(record: Record, character: Model): ()
	record.characterJanitor:Cleanup()
	record.alive = true

	local function bindHumanoid(humanoid: Humanoid): ()
		if humanoid.Health <= 0 then
			markDead(record)
			return
		end
		record.characterJanitor:Add(
			humanoid.Died:Connect(function(): ()
				markDead(record)
			end),
			"Disconnect"
		)
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		bindHumanoid(humanoid)
		return
	end

	record.characterJanitor:Add(
		character.ChildAdded:Connect(function(child: Instance): ()
			if child.ClassName == "Humanoid" then
				bindHumanoid(child :: Humanoid)
			end
		end),
		"Disconnect"
	)
end

function PurchaseController._watch(player: Player): ()
	if PurchaseController._records[player] then
		return
	end

	local janitor = Janitor.new()
	local characterJanitor = Janitor.new()
	janitor:Add(characterJanitor, "Destroy")

	local record: Record = {
		player = player,
		janitor = janitor,
		characterJanitor = characterJanitor,
		ready = false,
		alive = false,
		hasMoney = player:GetAttribute("Money") ~= nil,
		money = tonumber(player:GetAttribute("Money")) or 0,
		dropAt = -math.huge,
		riseAt = -math.huge,
		slotIds = table.create(SLOT_COUNT, ""),
		slotNames = table.create(SLOT_COUNT, ""),
		armorType = "",
		defuseKit = false,
		rescueKit = false,
		gains = {},
		losses = {},
		lastLossAt = -math.huge,
		wipedAt = -math.huge,
	}
	PurchaseController._records[player] = record

	for index = 1, SLOT_COUNT do
		syncSlot(record, index)
	end
	syncArmor(record)
	syncDefuseKit(record)
	syncRescueKit(record)
	record.ready = true

	for index = 1, SLOT_COUNT do
		janitor:Add(
			player:GetAttributeChangedSignal("Slot" .. index):Connect(function(): ()
				syncSlot(record, index)
			end),
			"Disconnect"
		)
	end

	janitor:Add(
		player:GetAttributeChangedSignal("Armor"):Connect(function(): ()
			syncArmor(record)
		end),
		"Disconnect"
	)
	janitor:Add(
		player:GetAttributeChangedSignal("HasDefuseKit"):Connect(function(): ()
			syncDefuseKit(record)
		end),
		"Disconnect"
	)
	janitor:Add(
		player:GetAttributeChangedSignal("HasRescueKit"):Connect(function(): ()
			syncRescueKit(record)
		end),
		"Disconnect"
	)
	janitor:Add(
		player:GetAttributeChangedSignal("Money"):Connect(function(): ()
			syncMoney(record)
		end),
		"Disconnect"
	)

	janitor:Add(
		player.CharacterAdded:Connect(function(character: Model): ()
			bindCharacter(record, character)
		end),
		"Disconnect"
	)
	janitor:Add(
		player.CharacterRemoving:Connect(function(): ()
			markDead(record)
			record.characterJanitor:Cleanup()
		end),
		"Disconnect"
	)

	if player.Character then
		bindCharacter(record, player.Character :: Model)
	end
end

function PurchaseController._unwatch(player: Player): ()
	local record = PurchaseController._records[player]
	if not record then
		return
	end
	PurchaseController._records[player] = nil
	record.janitor:Destroy()
end

function PurchaseController.GetRecent(): { purchaseState.PurchaseEvent }
	return peek(purchaseState.recent)
end

function PurchaseController.new(): PurchaseController
	for _, player in next, Players:GetPlayers() do
		PurchaseController._watch(player)
	end

	PurchaseController._janitor:Add(
		Players.PlayerAdded:Connect(function(player: Player): ()
			PurchaseController._watch(player)
		end),
		"Disconnect"
	)
	PurchaseController._janitor:Add(
		Players.PlayerRemoving:Connect(function(player: Player): ()
			PurchaseController._unwatch(player)
		end),
		"Disconnect"
	)

	return PurchaseController
end

function PurchaseController.Destroy(): ()
	for player in next, PurchaseController._records do
		PurchaseController._unwatch(player)
	end
	purchaseState.recent({})
	PurchaseController._janitor:Destroy()
end

export type PurchaseController = typeof(PurchaseController)

return PurchaseController
