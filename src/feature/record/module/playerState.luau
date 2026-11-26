local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local themeState = require("@ui/theme/themeState")

local at = Charm.atom
local peek = Charm.peek

local status = themeState.colors.status

export type StateDef = {
	id: string,
	label: string,
	color: Charm.Atom<Color3>,
	icon: string?,
	priority: number?,
}

local DEFAULT_STATES: { StateDef } = {
	{ id = "friendly", label = "Friendly", color = status.good, priority = 1 },
	{ id = "priority", label = "Priority", color = status.warning, priority = 2 },
}

local playerState = {
	_states = at(table.clone(DEFAULT_STATES)),
	_assignments = at({} :: { [number]: string }),
}

function playerState.GetAll(): { StateDef }
	return peek(playerState._states)
end

function playerState.SetState(userId: number, stateId: string?): ()
	local current = peek(playerState._assignments)
	if stateId == nil then
		if current[userId] == nil then
			return
		end
		playerState._assignments(Sift.Dictionary.removeKey(current, userId))
	else
		if current[userId] == stateId then
			return
		end
		playerState._assignments(Sift.Dictionary.set(current, userId, stateId))
	end
end

function playerState.GetState(userId: number?): string?
	if type(userId) ~= "number" then
		return nil
	end
	return peek(playerState._assignments)[userId]
end

function playerState.GetStateDef(userId: number?): StateDef?
	return playerState.Get(playerState.GetState(userId))
end

function playerState.GetAssignments(): { [number]: string }
	return peek(playerState._assignments)
end

function playerState.SubscribeAssignments(callback: () -> ()): () -> ()
	return Charm.subscribe(playerState._assignments, callback)
end

function playerState.ShouldSkip(userId: number?): boolean
	local id = playerState.GetState(userId)
	return id == "friendly"
end

function playerState.GetRank(userId: number?): number
	local id = playerState.GetState(userId)
	if id == "priority" then
		return 1
	end
	return 0
end

function playerState.HasPriorityTargets(): boolean
	for _, id in next, peek(playerState._assignments) do
		if id == "priority" then
			return true
		end
	end
	return false
end

function playerState.Get(id: string?): StateDef?
	if id == nil then
		return nil
	end
	for _, def in next, peek(playerState._states) do
		if def.id == id then
			return def
		end
	end
	return nil
end

function playerState.GetByLabel(label: string?): StateDef?
	if label == nil then
		return nil
	end
	for _, def in next, peek(playerState._states) do
		if def.label == label then
			return def
		end
	end
	return nil
end

function playerState.GetLabels(): { string }
	local labels: { string } = {}
	for _, def in next, peek(playerState._states) do
		table.insert(labels, def.label)
	end
	return labels
end

function playerState.AddState(state: StateDef): boolean
	for _, def in next, peek(playerState._states) do
		if def.id == state.id then
			return false
		end
	end
	playerState._states(Sift.Array.push(peek(playerState._states), state))
	return true
end

function playerState.RemoveState(id: string): boolean
	local current = peek(playerState._states)
	local idx: number? = nil
	for i, def in next, current do
		if def.id == id then
			idx = i
			break
		end
	end
	if not idx then
		return false
	end
	playerState._states(Sift.Array.removeIndex(current, idx))
	return true
end

return playerState
