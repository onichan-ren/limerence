local Players = cloneref(game:GetService("Players")) :: Players
local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local OverkillPlayer = require("@game/overkill/player/OverkillPlayer")
local ClientState = require("@game/overkill/client/clientState")

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

local ClientController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
	_player = nil :: OverkillPlayer.OverkillPlayer?,
}

local function forward(source: any, target: any): ()
	target(peek(source))
	ClientController._janitor:Add(sub(source, function(value: any): ()
		target(value)
	end))
end

function ClientController.new(): ClientController
	local player = OverkillPlayer.new(LocalPlayer)
	ClientController._player = player
	ClientController._janitor:Add(player, "Destroy")

	forward(player.character, ClientState.character)
	forward(player.hrp, ClientState.hrp)
	forward(player.humanoid, ClientState.humanoid)
	forward(player.parts, ClientState.parts)
	forward(player.alive, ClientState.alive)
	forward(player.health, ClientState.health)
	forward(player.maxHealth, ClientState.maxHealth)

	return ClientController
end

function ClientController.GetPlayer(): OverkillPlayer.OverkillPlayer?
	return ClientController._player
end

function ClientController.GetTeam(): string
	return peek(ClientState.team)
end

function ClientController.GetMatchId(): any
	return peek(ClientState.matchId)
end

function ClientController.IsInMatch(): boolean
	return peek(ClientState.matchId) ~= nil
end

function ClientController.IsInLobby(): boolean
	return peek(ClientState.matchId) == nil
end

function ClientController.Destroy(): ()
	ClientController._janitor:Destroy()
	ClientController._player = nil
end

export type ClientController = typeof(ClientController)

return ClientController
