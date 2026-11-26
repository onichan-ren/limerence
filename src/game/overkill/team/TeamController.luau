local Players = cloneref(game:GetService("Players")) :: Players

local logger = require("@share/logger").new("TeamController")
local PlayerController = require("@feature/player/PlayerController")
local NetworkController = require("@game/overkill/network/NetworkController")
local ModuleController = require("@game/overkill/module/ModuleController")
local ClientState = require("@game/overkill/client/clientState")

local LocalPlayer = Players.LocalPlayer

local TEAM_PACKETS = {
	"active_duels",
	"created",
	"ended",
	"joined_range",
	"left_duel",
	"round_created",
	"round_started",
}

local TeamController = {}

local gameplayHandler: any = nil
local unhooks: { () -> () } = {}
local playerAddedConn: any = nil
local playerRemovingConn: any = nil
local pending = false

local lastMatch: { [Player]: any } = {}
local lastTeamId: { [Player]: number } = {}

local resolveDuelData = LPH_NO_VIRTUALIZE(function(player: Player): any
	if not gameplayHandler then
		return nil
	end
	local data = gameplayHandler.PlayerGameData[player]
	return data and data.duelData
end)

local resolveTeamId = LPH_NO_VIRTUALIZE(function(player: Player, duelData: any): number
	if not duelData then
		return -1
	end
	local team = gameplayHandler:GetPlayerTeam(duelData.id, player)
	return team and team.id or -1
end)

local teamString = LPH_NO_VIRTUALIZE(function(teamId: number): string
	return teamId == -1 and "" or tostring(teamId)
end)

local recomputeAll = LPH_NO_VIRTUALIZE(function(): ()
	for player, basePlayer in next, PlayerController.GetAll() do
		local duelData = resolveDuelData(player)
		local matchId = duelData and duelData.id or nil
		local teamId = resolveTeamId(player, duelData)

		if lastMatch[player] ~= matchId then
			lastMatch[player] = matchId;
			(basePlayer :: any).matchId(matchId)
		end
		if lastTeamId[player] ~= teamId then
			lastTeamId[player] = teamId;
			(basePlayer :: any).team(teamString(teamId))
		end
	end

	local localDuelData = resolveDuelData(LocalPlayer)
	local localMatch = localDuelData and localDuelData.id or nil
	local localTeamId = resolveTeamId(LocalPlayer, localDuelData)

	if lastMatch[LocalPlayer] ~= localMatch then
		lastMatch[LocalPlayer] = localMatch
		ClientState.matchId(localMatch)
		ClientState.inRange((localDuelData and localDuelData.mode == "range") == true)
	end
	if lastTeamId[LocalPlayer] ~= localTeamId then
		lastTeamId[LocalPlayer] = localTeamId
		ClientState.team(teamString(localTeamId))
	end
end)

local function scheduleRecompute(): ()
	if pending then
		return
	end
	pending = true
	task.defer(function(): ()
		pending = false
		recomputeAll()
	end)
end

function TeamController.new(): TeamController
	gameplayHandler = ModuleController.GetModule("gameplayHandler")
	if not gameplayHandler then
		logger:error("failed to resolve GameplayHandler")
	end

	for _, name in next, TEAM_PACKETS do
		table.insert(unhooks, NetworkController.HookInbound(name, scheduleRecompute))
	end

	playerAddedConn = PlayerController.playerAdded:Connect(scheduleRecompute)
	playerRemovingConn = PlayerController.playerRemoving:Connect(function(basePlayer: any): ()
		local player = basePlayer:GetPlayer()
		lastMatch[player] = nil
		lastTeamId[player] = nil
	end)

	scheduleRecompute()

	return TeamController
end

function TeamController.GetTeam(player: Player): string
	return teamString(resolveTeamId(player, resolveDuelData(player)))
end

function TeamController.Destroy(): ()
	for _, unhook in next, unhooks do
		unhook()
	end
	table.clear(unhooks)

	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end

	table.clear(lastMatch)
	table.clear(lastTeamId)
	gameplayHandler = nil
	pending = false
end

export type TeamController = typeof(TeamController)

return TeamController
