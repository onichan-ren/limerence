local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local ragebotState = require("@game/ar2/feature/ragebot/ragebotState")

local peek = Charm.peek

type Entry = {
	id: number,
	priority: number,
	fn: any,
}

local signals = {
	onShotFired = Signal.new(),
	onTargetChanged = Signal.new(),
}

local state = {
	lastShotAt = ragebotState.lastShotAt,
	lastTarget = ragebotState.currentTarget,
	lastTargetPart = ragebotState.currentTargetPart,
}

local targetFilters: { Entry } = {}
local shotGates: { Entry } = {}
local nextId = 0

local forcedTarget: Player? = nil
local forcedExpiry: number? = nil

local function byPriorityDesc(a: Entry, b: Entry): boolean
	return a.priority > b.priority
end

local function insertEntry(list: { Entry }, fn: any, priority: number): number
	nextId += 1
	local id = nextId
	list[#list + 1] = { id = id, priority = priority, fn = fn }
	table.sort(list, byPriorityDesc)
	return id
end

local function removeEntry(list: { Entry }, id: number): ()
	for i, entry in next, list do
		if entry.id == id then
			table.remove(list, i)
			return
		end
	end
end

local ragebotApi = {
	signals = signals,
	state = state,
}

function ragebotApi.IsEnabled(): boolean
	return peek(ragebotState.enabled)
end

function ragebotApi.GetInFlightStats(_basePlayer: any): (number, number)
	return 0, 0
end

function ragebotApi.IsPlayerCovered(_basePlayer: any): boolean
	return false
end

function ragebotApi.ClearInFlight(_basePlayer: any?): () end

function ragebotApi.AddTargetFilter(fn: any, priority: number?): number
	return insertEntry(targetFilters, fn, priority or 0)
end

function ragebotApi.RemoveTargetFilter(id: number): ()
	removeEntry(targetFilters, id)
end

function ragebotApi.AddShotGate(fn: any, priority: number?): number
	return insertEntry(shotGates, fn, priority or 0)
end

function ragebotApi.RemoveShotGate(id: number): ()
	removeEntry(shotGates, id)
end

function ragebotApi.GetForcedTarget(): Player?
	if forcedTarget then
		if forcedExpiry and os.clock() >= forcedExpiry then
			forcedTarget = nil
			forcedExpiry = nil
		end
	end
	return forcedTarget
end

function ragebotApi.SetForcedTarget(player: Player, durationSec: number?): ()
	forcedTarget = player
	forcedExpiry = durationSec and os.clock() + durationSec or nil
end

function ragebotApi.ClearForcedTarget(): ()
	forcedTarget = nil
	forcedExpiry = nil
end

function ragebotApi.HasFilters(): boolean
	return #targetFilters > 0
end

function ragebotApi.HasGates(): boolean
	return #shotGates > 0
end

function ragebotApi.RunFilters(player: Player, info: any): boolean
	for _, entry in next, targetFilters do
		local ok, result = pcall(entry.fn, player, info)
		if ok and result == false then
			return false
		end
	end
	return true
end

function ragebotApi.RunGates(shot: any): boolean
	for _, entry in next, shotGates do
		local ok, result = pcall(entry.fn, shot)
		if ok and result == false then
			return false
		end
	end
	return true
end

function ragebotApi.SetTarget(player: Player?, part: BasePart?): ()
	local changed = peek(ragebotState.currentTarget) ~= player or peek(ragebotState.currentTargetPart) ~= part
	if peek(ragebotState.currentTarget) ~= player then
		ragebotState.currentTarget(player)
	end
	if peek(ragebotState.currentTargetPart) ~= part then
		ragebotState.currentTargetPart(part)
	end
	if changed and player then
		signals.onTargetChanged:Fire({ player = player, part = part })
	end
end

function ragebotApi.NotifyShot(shot: any): ()
	ragebotState.lastShotAt(os.clock())
	signals.onShotFired:Fire(shot)
end

function ragebotApi.SetEnabled(enabled: boolean): ()
	if peek(ragebotState.enabled) ~= enabled then
		ragebotState.enabled(enabled)
	end
end

return ragebotApi
