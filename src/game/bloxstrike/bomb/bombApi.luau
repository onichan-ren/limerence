local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local bombState = require("@game/bloxstrike/bomb/bombState")

local peek = Charm.peek
local sub = Charm.subscribe

local state = bombState

local signals = {
	onBombPlanted = Signal.new(),
	onBombDefused = Signal.new(),
	onBombExploded = Signal.new(),
	onBombCleared = Signal.new(),
	onPlantingStarted = Signal.new(),
	onPlantingEnded = Signal.new(),
}

local bombApi = {
	state = state,
	signals = signals,
}

function bombApi.GetBomb(): bombState.BombState?
	return peek(state.bomb)
end

function bombApi.GetBombTime(): number?
	local bomb = peek(state.bomb)
	if not bomb then
		return nil
	end
	return math.max(bomb.explodeAt - Workspace:GetServerTimeNow(), 0)
end

function bombApi.IsPlanted(): boolean
	return peek(state.bomb) ~= nil
end

function bombApi.IsDefusing(): boolean
	local bomb = peek(state.bomb)
	return bomb ~= nil and bomb.isDefusing
end

function bombApi.IsDefused(): boolean
	local bomb = peek(state.bomb)
	return bomb ~= nil and bomb.isDefused
end

function bombApi.IsExploded(): boolean
	local bomb = peek(state.bomb)
	return bomb ~= nil and bomb.isExploded
end

function bombApi.GetPlanting(): bombState.PlantingState?
	return peek(state.planting)
end

local lastBomb: bombState.BombState? = peek(state.bomb)
sub(state.bomb, function(bomb: bombState.BombState?): ()
	local previous = lastBomb
	lastBomb = bomb

	local wasPresent = previous ~= nil
	local isPresent = bomb ~= nil

	if not wasPresent and isPresent then
		signals.onBombPlanted:Fire(bomb)
	end

	if isPresent and bomb then
		local wasDefused = previous ~= nil and previous.isDefused
		local wasExploded = previous ~= nil and previous.isExploded
		if bomb.isDefused and not wasDefused then
			signals.onBombDefused:Fire(bomb)
		end
		if bomb.isExploded and not wasExploded then
			signals.onBombExploded:Fire(bomb)
		end
	end

	if wasPresent and not isPresent then
		signals.onBombCleared:Fire()
	end
end)

local lastPlanting: bombState.PlantingState? = peek(state.planting)
sub(state.planting, function(planting: bombState.PlantingState?): ()
	local previous = lastPlanting
	lastPlanting = planting
	if previous == nil and planting ~= nil then
		signals.onPlantingStarted:Fire(planting)
	elseif previous ~= nil and planting == nil then
		signals.onPlantingEnded:Fire(previous)
	end
end)

return bombApi
