local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")

local droppedItemState = require("@game/bloxstrike/dropped/droppedItemState")

local peek = Charm.peek
local sub = Charm.subscribe

export type DroppedItem = {
	model: Model,
	kind: droppedItemState.DroppedKind,
	label: string,
	weaponName: string,
	rounds: number,
	maxRounds: number,
	position: Vector3,
}

local signals = {
	onDroppedItemAdded = Signal.new(),
	onDroppedItemRemoved = Signal.new(),
}

local droppedItemApi = {
	state = droppedItemState,
	signals = signals,
}

local function toPublic(entry: droppedItemState.DroppedEntry): DroppedItem
	return {
		model = entry.model,
		kind = entry.kind,
		label = entry.label,
		weaponName = entry.weaponName,
		rounds = entry.rounds,
		maxRounds = entry.maxRounds,
		position = entry.model:GetPivot().Position,
	}
end

function droppedItemApi.GetDroppedItems(): { DroppedItem }
	local out: { DroppedItem } = {}
	for _, entry in next, peek(droppedItemState.entries) do
		out[#out + 1] = toPublic(entry)
	end
	return out
end

function droppedItemApi.GetDroppedItem(model: Model): DroppedItem?
	local entry = peek(droppedItemState.entries)[model]
	if not entry then
		return nil
	end
	return toPublic(entry)
end

local lastEntries = peek(droppedItemState.entries)
sub(droppedItemState.entries, function(entries: { [Model]: droppedItemState.DroppedEntry }): ()
	local previous = lastEntries
	lastEntries = entries
	for model, entry in next, entries do
		if not previous[model] then
			signals.onDroppedItemAdded:Fire(toPublic(entry))
		end
	end
	for model, entry in next, previous do
		if not entries[model] then
			signals.onDroppedItemRemoved:Fire(toPublic(entry))
		end
	end
end)

return droppedItemApi
