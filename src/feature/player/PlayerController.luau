local Players = cloneref(game:GetService("Players")) :: Players

local BasePlayer = require("@feature/player/BasePlayer")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local Signal = require("@pkg/Signal")

local peek = Charm.peek

local PlayerController = {
	_janitor = nil :: Janitor.Janitor?,
	_players = Charm.atom({}) :: Charm.Atom<{ [Player]: BasePlayer.BasePlayer }>,
	_class = nil :: BasePlayer.BasePlayer & any,
	playerAdded = Signal.new() :: Signal.Signal<BasePlayer.BasePlayer>,
	playerRemoving = Signal.new() :: Signal.Signal<BasePlayer.BasePlayer>,
}

local function addPlayer(player: Player): ()
	if peek(PlayerController._players)[player] then
		return
	end
	local basePlayer = PlayerController._class.new(player)
	PlayerController._players(Sift.Dictionary.set(peek(PlayerController._players), player, basePlayer))
	PlayerController.playerAdded:Fire(basePlayer)
end

local function removePlayer(player: Player): ()
	local current = peek(PlayerController._players)
	local basePlayer = current[player]
	if not basePlayer then
		return
	end
	PlayerController._players(Sift.Dictionary.removeKey(current, player))
	PlayerController.playerRemoving:Fire(basePlayer)
	basePlayer:Destroy()
end

function PlayerController.SetPlayerClass(class: any): ()
	PlayerController._class = class
end

function PlayerController.new(): PlayerController
	local janitor = Janitor.new()
	PlayerController._janitor = janitor

	janitor:Add(Players.PlayerAdded:Connect(addPlayer), "Disconnect")
	janitor:Add(Players.PlayerRemoving:Connect(removePlayer), "Disconnect")

	for _, player in next, Players:GetPlayers() do
		if player == Players.LocalPlayer then
			continue
		end
		addPlayer(player)
	end

	return PlayerController
end

function PlayerController.GetAll(): { [Player]: BasePlayer.BasePlayer }
	return peek(PlayerController._players)
end

function PlayerController.Get(player: Player): BasePlayer.BasePlayer?
	return peek(PlayerController._players)[player]
end

function PlayerController.Destroy(): ()
	for _, basePlayer in next, peek(PlayerController._players) do
		basePlayer:Destroy()
	end
	PlayerController._players({})

	local janitor = PlayerController._janitor
	if janitor then
		janitor:Destroy()
		PlayerController._janitor = nil
	end
end

export type PlayerController = typeof(PlayerController)

return PlayerController
