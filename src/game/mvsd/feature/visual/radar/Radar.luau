local Charm = require("@pkg/Charm")
local UniversalRadar = require("@game/universal/feature/visual/radar/Radar")
local ClientState = require("@game/mvsd/client/clientState")
local mapRange = require("@game/mvsd/feature/visual/radar/mapRange")
local gameUi = require("@game/gameUi")

local peek = Charm.peek

local isTeammate = LPH_NO_VIRTUALIZE(function(basePlayer: any): boolean
	local localTeam = peek(ClientState.team)
	return localTeam ~= "" and peek(basePlayer.team) == localTeam
end)

local filter = LPH_NO_VIRTUALIZE(function(basePlayer: any): boolean
	local theirMatch = peek(basePlayer.matchId)
	local localMatch = peek(ClientState.matchId)
	if localMatch ~= nil then
		return theirMatch ~= localMatch
	end
	local spectateMatch = peek(ClientState.spectateMatchId)
	if spectateMatch ~= nil then
		return theirMatch ~= spectateMatch
	end
	return true
end)

local Radar = {}

function Radar.new(link: gameUi.Linker): UniversalRadar.Radar
	return UniversalRadar.new(link, {
		isTeammate = isTeammate,
		getRange = mapRange.Get,
		filter = filter,
	})
end

return Radar
