local Players = cloneref(game:GetService("Players")) :: Players
local PlayerController = require("@feature/player/PlayerController")
local NetworkController = require("@game/overkill/network/NetworkController")
local ClientController = require("@game/overkill/client/ClientController")

local LocalPlayer = Players.LocalPlayer

local StateController = {}

local unhook: (() -> ())? = nil

local function resolvePlayer(character: any): Player?
	if typeof(character) ~= "Instance" then
		return nil
	end
	if character:IsA("Player") then
		return character
	end
	return Players:GetPlayerFromCharacter(character)
end

local route = LPH_NO_VIRTUALIZE(function(payload: any): ()
	if type(payload) ~= "table" then
		return
	end

	local stateData = payload.stateData
	if type(stateData) ~= "table" then
		return
	end

	local name = stateData[1]
	if name ~= "Health" and name ~= "MaxHealth" and name ~= "Dead" and name ~= "Tased" then
		return
	end

	local player = resolvePlayer(payload.character)
	if not player then
		return
	end

	local handle = PlayerController.Get(player) :: any
	if not handle and player == LocalPlayer then
		handle = ClientController.GetPlayer() :: any
	end
	if not handle then
		return
	end

	if name == "Dead" then
		handle.alive(false)
		return
	end

	if name == "Tased" then
		handle.tased(stateData[2] == true)
		return
	end

	local value = stateData[2]
	if type(value) ~= "number" then
		return
	end

	if name == "Health" then
		handle.health(value)
		handle.alive(value > 0)
	else
		handle.maxHealth(value)
	end
end)

function StateController.new(): StateController
	unhook = NetworkController.HookInbound("state_changed", route)
	return StateController
end

function StateController.Destroy(): ()
	if unhook then
		unhook()
		unhook = nil
	end
end

export type StateController = typeof(StateController)

return StateController
