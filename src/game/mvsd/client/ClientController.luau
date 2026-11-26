local Players = cloneref(game:GetService("Players")) :: Players
local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage
local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local MvsdPlayer = require("@game/mvsd/player/MvsdPlayer")
local ClientState = require("@game/mvsd/client/clientState")

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

local ClientController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
	_player = nil :: MvsdPlayer.MvsdPlayer?,
}

local function forward(source: any, target: any): ()
	target(peek(source))
	ClientController._janitor:Add(sub(source, function(value: any): ()
		target(value)
	end))
end

local function watchAttribute(name: string, target: any): ()
	target(LocalPlayer:GetAttribute(name))
	ClientController._janitor:Add(LocalPlayer:GetAttributeChangedSignal(name):Connect(function(): ()
		target(LocalPlayer:GetAttribute(name))
	end))
end

local function watchTag(tag: string, source: any, target: any): ()
	ClientController._janitor:Add(CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance): ()
		if instance == peek(source) then
			target(true)
		end
	end))
	ClientController._janitor:Add(CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance: Instance): ()
		if instance == peek(source) then
			target(false)
		end
	end))
	ClientController._janitor:Add(sub(source, function(instance: Instance?): ()
		target(instance ~= nil and CollectionService:HasTag(instance, tag))
	end))

	local instance = peek(source)
	target(instance ~= nil and CollectionService:HasTag(instance, tag))
end

local function setTool(tool: Tool?): ()
	ClientState.equippedTool(tool)
	if tool and CollectionService:HasTag(tool, "GunTool") then
		ClientState.weapon("gun")
	elseif tool and CollectionService:HasTag(tool, "KnifeTool") then
		ClientState.weapon("knife")
	elseif tool and tool.Name == "ShroudTool" then
		ClientState.weapon("shroud")
	else
		ClientState.weapon("")
	end
end

local function watchTools(): ()
	local toolJanitor = Janitor.new()
	ClientController._janitor:Add(toolJanitor, "Destroy")

	local function onCharacter(character: Model?): ()
		toolJanitor:Cleanup()
		if not character then
			setTool(nil)
			return
		end

		local current: Tool? = nil
		for _, child in next, character:GetChildren() do
			if child:IsA("Tool") then
				current = child
				break
			end
		end
		setTool(current)

		toolJanitor:Add(character.ChildAdded:Connect(function(child: Instance): ()
			if child:IsA("Tool") then
				setTool(child)
			end
		end))
		toolJanitor:Add(character.ChildRemoved:Connect(function(child: Instance): ()
			if child == peek(ClientState.equippedTool) then
				setTool(nil)
			end
		end))
	end

	ClientController._janitor:Add(sub(ClientState.character, onCharacter))
	onCharacter(peek(ClientState.character))
end

function ClientController.new(): ClientController
	local player = MvsdPlayer.new(LocalPlayer)
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
	forward(player.matchId, ClientState.matchId)

	watchAttribute("SpectateMatchId", ClientState.spectateMatchId)
	watchAttribute("Gamemode", ClientState.gamemode)

	watchTag("Shrouded", ClientState.character, ClientState.blinded)
	watchTag("CombatDisabled", ClientState.character, ClientState.combatDisabled)
	watchTag("Invulnerable", ClientState.character, ClientState.invulnerable)
	watchTag("SpeedTrail", ClientState.hrp, ClientState.sprinting)

	watchTools()

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	ClientController._janitor:Add((remotes :: any).StartRoundCountdown.OnClientEvent:Connect(function(): ()
		ClientState.roundActive(true)
	end))
	ClientController._janitor:Add((remotes :: any).OnRoundEnded.OnClientEvent:Connect(function(): ()
		ClientState.roundActive(false)
	end))
	ClientController._janitor:Add((remotes :: any).OnMatchFinished.OnClientEvent:Connect(function(): ()
		ClientState.roundActive(false)
	end))
	ClientController._janitor:Add(sub(ClientState.matchId, function(id: any): ()
		if id == nil then
			ClientState.roundActive(false)
		end
	end))

	return ClientController
end

function ClientController.GetPlayer(): MvsdPlayer.MvsdPlayer?
	return ClientController._player
end

function ClientController.GetTeam(): string
	return peek(ClientState.team)
end

function ClientController.GetMatchId(): any
	return peek(ClientState.matchId)
end

function ClientController.GetEffectiveMatchId(): any
	local matchId = peek(ClientState.matchId)
	if matchId ~= nil then
		return matchId
	end
	return peek(ClientState.spectateMatchId)
end

function ClientController.IsInMatch(): boolean
	return peek(ClientState.matchId) ~= nil
end

function ClientController.IsInLobby(): boolean
	return peek(ClientState.matchId) == nil
end

function ClientController.GetWeapon(): string
	return peek(ClientState.weapon)
end

function ClientController.GetEquippedTool(): Tool?
	return peek(ClientState.equippedTool)
end

function ClientController.IsBlinded(): boolean
	return peek(ClientState.blinded)
end

function ClientController.IsCombatDisabled(): boolean
	return peek(ClientState.combatDisabled)
end

function ClientController.IsInvulnerable(): boolean
	return peek(ClientState.invulnerable)
end

function ClientController.IsSprinting(): boolean
	return peek(ClientState.sprinting)
end

function ClientController.Destroy(): ()
	ClientController._janitor:Destroy()
	ClientController._player = nil
	ClientState.roundActive(false)
end

export type ClientController = typeof(ClientController)

return ClientController
