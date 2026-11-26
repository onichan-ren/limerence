local Players = cloneref(game:GetService("Players")) :: Players
local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local ClientState = require("@game/pf/client/clientState")

local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer

local ClientController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
}

local function readTeam(): string
	local team = LocalPlayer.Team
	if team then
		return team.Name
	end
	return ""
end

local function onCharacter(character: Model?): ()
	ClientState.character(character)
	ClientState.alive(character ~= nil)
end

function ClientController.new(): ClientController
	ClientState.team(readTeam())

	ClientController._janitor:Add(LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function(): ()
		ClientState.team(readTeam())
	end))

	ClientController._janitor:Add(LocalPlayer.CharacterAdded:Connect(onCharacter))
	ClientController._janitor:Add(LocalPlayer.CharacterRemoving:Connect(function(): ()
		onCharacter(nil)
	end))

	onCharacter(LocalPlayer.Character)

	return ClientController
end

function ClientController.GetTeam(): string
	return peek(ClientState.team)
end

function ClientController.IsAlive(): boolean
	return peek(ClientState.alive)
end

function ClientController.Destroy(): ()
	ClientController._janitor:Destroy()
end

export type ClientController = typeof(ClientController)

return ClientController
