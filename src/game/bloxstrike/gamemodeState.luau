local Charm = require("@pkg/Charm")

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local at = Charm.atom
local peek = Charm.peek

local gamemodeAtom = at(Workspace:GetAttribute("Gamemode") :: string?)
local serverGamemodeAtom = at(Workspace:GetAttribute("ServerGamemode") :: string?)
local gameStateAtom = at(Workspace:GetAttribute("GameState") :: string?)

local gamemodeState = {
	gamemode = gamemodeAtom,
	serverGamemode = serverGamemodeAtom,
	gameState = gameStateAtom,
}

Workspace:GetAttributeChangedSignal("Gamemode"):Connect(function()
	gamemodeState.gamemode(Workspace:GetAttribute("Gamemode"))
end)

Workspace:GetAttributeChangedSignal("ServerGamemode"):Connect(function()
	gamemodeState.serverGamemode(Workspace:GetAttribute("ServerGamemode"))
end)

Workspace:GetAttributeChangedSignal("GameState"):Connect(function()
	gamemodeState.gameState(Workspace:GetAttribute("GameState"))
end)

function gamemodeState.isDeathmatch(): boolean
	return peek(gamemodeAtom) == "Deathmatch"
end

function gamemodeState.isBombDefusal(): boolean
	return peek(gamemodeAtom) == "Bomb Defusal"
end

function gamemodeState.isHostageRescue(): boolean
	return peek(gamemodeAtom) == "Hostage Rescue"
end

function gamemodeState.isCompetitive(): boolean
	return peek(serverGamemodeAtom) == "Competitive"
end

function gamemodeState.isRoundOver(): boolean
	local state = peek(gameStateAtom)
	return state == "Intermission" or state == "Game Ending"
end

export type GamemodeState = typeof(gamemodeState)

return gamemodeState
