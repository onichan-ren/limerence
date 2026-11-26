local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local ClientController = require("@game/overkill/client/ClientController")
local ClientState = require("@game/overkill/client/clientState")
local NetworkController = require("@game/overkill/network/NetworkController")
local grenadeState = require("@game/overkill/grenade/grenadeState")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local peek = Charm.peek
local sub = Charm.subscribe

local signals = {
	onMatchChanged = Signal.new(),
	onTeamChanged = Signal.new(),
	onProjectileAdded = Signal.new(),
	onProjectileRemoved = Signal.new(),
}

local watching = false

local function toPublicProjectile(entry: any): { [string]: any }
	return {
		id = entry.id,
		name = entry.displayName,
		position = entry.predictedPosition or entry.spawnPosition,
		detonateAt = entry.detonateAt,
		explosive = entry.isExplosive == true,
		radius = entry.explosionRadius,
		friendly = entry.isFriendly == true,
	}
end

local function ensureWatch(): ()
	if watching then
		return
	end
	watching = true

	sub(ClientState.matchId, function(matchId: any): ()
		signals.onMatchChanged:Fire(matchId)
	end)
	sub(ClientState.team, function(team: string): ()
		signals.onTeamChanged:Fire(team ~= "" and team or nil)
	end)

	local last = peek(grenadeState.activeProjectiles)
	sub(grenadeState.activeProjectiles, function(current: any): ()
		for id, entry in next, current do
			if last[id] == nil then
				signals.onProjectileAdded:Fire(toPublicProjectile(entry))
			end
		end
		for id, entry in next, last do
			if current[id] == nil then
				signals.onProjectileRemoved:Fire(toPublicProjectile(entry))
			end
		end
		last = current
	end)
end

local send = LPH_NO_VIRTUALIZE(function(name: string, data: any?): ()
	setthreadidentity(2)
	NetworkController.Fire(name, data)
	setthreadidentity(8)
end)

local function getTeamId(): string?
	local team = ClientController.GetTeam()
	return team ~= "" and team or nil
end

local function getProjectiles(): { { [string]: any } }
	local out = {}
	for _, entry in next, peek(grenadeState.activeProjectiles) do
		out[#out + 1] = toPublicProjectile(entry)
	end
	return out
end

local function queueMatch(mode: any): ()
	if type(mode) ~= "string" or mode == "" then
		error("api.game.queueMatch: mode must be a string, e.g. \"1v1\"", 2)
	end
	send("matchmaking_queue", mode)
end

local function cancelQueue(): ()
	send("matchmaking_cancel")
end

local function leaveMatch(): ()
	send("leave_duel")
end

local overkillGameApi = {}

luauApiRegistry.Register("game", function(ctx)
	ensureWatch()
	local wrap = luauApiRegistry.WrapSignal
	return {
		isInMatch = ClientController.IsInMatch,
		isInLobby = ClientController.IsInLobby,
		getMatchId = ClientController.GetMatchId,
		getTeamId = getTeamId,
		getProjectiles = getProjectiles,
		queueMatch = queueMatch,
		cancelQueue = cancelQueue,
		leaveMatch = leaveMatch,
		onMatchChanged = wrap(signals.onMatchChanged, ctx.onUnload),
		onTeamChanged = wrap(signals.onTeamChanged, ctx.onUnload),
		onProjectileAdded = wrap(signals.onProjectileAdded, ctx.onUnload),
		onProjectileRemoved = wrap(signals.onProjectileRemoved, ctx.onUnload),
	}
end)

return overkillGameApi
