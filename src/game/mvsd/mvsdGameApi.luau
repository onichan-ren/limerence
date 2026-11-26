local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")

local clientState = require("@game/mvsd/client/clientState")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local peek = Charm.peek
local sub = Charm.subscribe

local mvsdGameApi = {}

local signals = {
	onMatchChanged = Signal.new(),
	onTeamChanged = Signal.new(),
}

local lastMatch = peek(clientState.matchId)
sub(clientState.matchId, function(value: any): ()
	if value == lastMatch then
		return
	end
	lastMatch = value
	signals.onMatchChanged:Fire(value)
end)

local lastTeam = peek(clientState.team)
sub(clientState.team, function(value: string): ()
	if value == lastTeam then
		return
	end
	lastTeam = value
	signals.onTeamChanged:Fire(value ~= "" and value or nil)
end)

luauApiRegistry.Register("game", function(ctx)
	local wrap = luauApiRegistry.WrapSignal
	return {
		isInMatch = function(): boolean
			return peek(clientState.matchId) ~= nil
		end,
		getMatchId = function(): any
			return peek(clientState.matchId)
		end,
		getTeam = function(): string?
			local team = peek(clientState.team)
			return team ~= "" and team or nil
		end,
		getGamemode = function(): string?
			return peek(clientState.gamemode)
		end,

		onMatchChanged = wrap(signals.onMatchChanged, ctx.onUnload),
		onTeamChanged = wrap(signals.onTeamChanged, ctx.onUnload),
	}
end)

return mvsdGameApi
