local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")

local gamemodeState = require("@game/bloxstrike/gamemodeState")

local peek = Charm.peek
local sub = Charm.subscribe

local signals = {
	onGamemodeChanged = Signal.new(),
	onServerGamemodeChanged = Signal.new(),
}

local gamemodeApi = {
	state = gamemodeState,
	signals = signals,
}

function gamemodeApi.GetGamemode(): string?
	return peek(gamemodeState.gamemode)
end

function gamemodeApi.GetServerGamemode(): string?
	return peek(gamemodeState.serverGamemode)
end

gamemodeApi.IsDeathmatch = gamemodeState.isDeathmatch
gamemodeApi.IsBombDefusal = gamemodeState.isBombDefusal
gamemodeApi.IsHostageRescue = gamemodeState.isHostageRescue
gamemodeApi.IsCompetitive = gamemodeState.isCompetitive

local lastGamemode = peek(gamemodeState.gamemode)
sub(gamemodeState.gamemode, function(gamemode: string?): ()
	if gamemode == lastGamemode then
		return
	end
	lastGamemode = gamemode
	signals.onGamemodeChanged:Fire(gamemode)
end)

local lastServerGamemode = peek(gamemodeState.serverGamemode)
sub(gamemodeState.serverGamemode, function(serverGamemode: string?): ()
	if serverGamemode == lastServerGamemode then
		return
	end
	lastServerGamemode = serverGamemode
	signals.onServerGamemodeChanged:Fire(serverGamemode)
end)

return gamemodeApi
