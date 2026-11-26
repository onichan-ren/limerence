local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService
local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local RivalsPlayer = require("@game/rivals/player/RivalsPlayer")
local ClientState = require("@game/rivals/client/clientState")

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

local ClientController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
	_player = nil :: RivalsPlayer.RivalsPlayer?,
}

local function forward(source: any, target: any): ()
	target(peek(source))
	ClientController._janitor:Add(sub(source, function(value: any): ()
		target(value)
	end))
end

function ClientController.new(): ClientController
	setthreadidentity(8)

	local player = RivalsPlayer.new(LocalPlayer)
	ClientController._player = player
	ClientController._janitor:Add(player, "Destroy")

	forward(player.character, ClientState.character)
	forward(player.hrp, ClientState.hrp)
	forward(player.humanoid, ClientState.humanoid)
	forward(player.parts, ClientState.parts)
	forward(player.alive, ClientState.alive)
	forward(player.health, ClientState.health)
	forward(player.maxHealth, ClientState.maxHealth)
	forward(player.team, ClientState.team)
	forward(player.environmentId, ClientState.environmentId)

	forward(player.currentEquipped, ClientState.currentEquipped)
	forward(player.isInDuel, ClientState.isInDuel)
	forward(player.isSpectating, ClientState.isSpectating)
	forward(player.isHidden, ClientState.isHidden)
	forward(player.isCrouching, ClientState.isCrouching)
	forward(player.isSliding, ClientState.isSliding)
	forward(player.isFrozen, ClientState.isFrozen)
	forward(player.isInvincible, ClientState.isInvincible)
	forward(player.controls, ClientState.controls)
	forward(player.items, ClientState.items)
	forward(player.velocity, ClientState.velocity)

	forward(player.level, ClientState.level)
	forward(player.winStreak, ClientState.winStreak)
	forward(player.displayElo, ClientState.displayElo)

	return ClientController
end

function ClientController.GetPlayer(): RivalsPlayer.RivalsPlayer?
	return ClientController._player
end

function ClientController.GetTeam(): string
	return peek(ClientState.team)
end

function ClientController.Destroy(): ()
	ClientController._janitor:Destroy()
	ClientController._player = nil
end

export type ClientController = typeof(ClientController)

return ClientController
