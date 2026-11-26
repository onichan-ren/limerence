local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")

local MatchState = require("@game/rivals/client/matchState")
local placeableState = require("@game/rivals/placeable/placeableState")
local grenadeApi = require("@game/rivals/grenade/grenadeApi")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local peek = Charm.peek
local sub = Charm.subscribe

local luauRivalsGameApi = {}

local signals = {
	onInGameChanged = Signal.new(),
	onTeamChanged = Signal.new(),
	onEnvironmentChanged = Signal.new(),
	onPlaceableAdded = Signal.new(),
	onPlaceableRemoved = Signal.new(),
}

local lastInGame = peek(MatchState.inGame)
sub(MatchState.inGame, function(value: boolean): ()
	if value == lastInGame then
		return
	end
	lastInGame = value
	signals.onInGameChanged:Fire(value)
end)

local lastTeam = peek(MatchState.teamId)
sub(MatchState.teamId, function(value: string): ()
	if value == lastTeam then
		return
	end
	lastTeam = value
	signals.onTeamChanged:Fire(value)
end)

local lastEnv = peek(MatchState.environmentId)
sub(MatchState.environmentId, function(value: string): ()
	if value == lastEnv then
		return
	end
	lastEnv = value
	signals.onEnvironmentChanged:Fire(value)
end)

local known: { [string]: placeableState.PlaceableEntry } = {}
for id, entry in next, peek(placeableState.activePlaceables) do
	known[id] = entry
end
sub(placeableState.activePlaceables, function(current: { [string]: placeableState.PlaceableEntry }): ()
	for id, entry in next, current do
		if not known[id] then
			signals.onPlaceableAdded:Fire(id, entry)
		end
	end
	for id, entry in next, known do
		if not current[id] then
			signals.onPlaceableRemoved:Fire(id, entry)
		end
	end
	known = {}
	for id, entry in next, current do
		known[id] = entry
	end
end)

luauApiRegistry.Register("game", function(ctx)
	local wrap = luauApiRegistry.WrapSignal
	return {
		isInGame = function(): boolean
			return peek(MatchState.inGame)
		end,
		getTeamId = function(): string
			return peek(MatchState.teamId)
		end,
		getEnvironmentId = function(): string
			return peek(MatchState.environmentId)
		end,
		getPlaceables = function(): { placeableState.PlaceableEntry }
			local out: { placeableState.PlaceableEntry } = {}
			for _, entry in next, peek(placeableState.activePlaceables) do
				out[#out + 1] = entry
			end
			return out
		end,
		getPlaceable = function(id: string): placeableState.PlaceableEntry?
			return peek(placeableState.activePlaceables)[id]
		end,
		getGrenades = grenadeApi.GetGrenades,

		onInGameChanged = wrap(signals.onInGameChanged, ctx.onUnload),
		onTeamChanged = wrap(signals.onTeamChanged, ctx.onUnload),
		onEnvironmentChanged = wrap(signals.onEnvironmentChanged, ctx.onUnload),
		onPlaceableAdded = wrap(signals.onPlaceableAdded, ctx.onUnload),
		onPlaceableRemoved = wrap(signals.onPlaceableRemoved, ctx.onUnload),
		onGrenadeAdded = wrap(grenadeApi.signals.onGrenadeAdded, ctx.onUnload),
		onGrenadeRemoved = wrap(grenadeApi.signals.onGrenadeRemoved, ctx.onUnload),
	}
end)

return luauRivalsGameApi
