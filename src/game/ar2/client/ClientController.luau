local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local ModuleController = require("@game/ar2/module/ModuleController")
local clientState = require("@game/ar2/client/clientState")

local peek = Charm.peek
local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService

local LocalPlayer = Players.LocalPlayer

local ClientController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
}

function ClientController.new(): ClientController
	local ARLocalPlayer = ModuleController.GetModule("LocalPlayer").module.get()

	if ARLocalPlayer.Character then
		ClientController._onCharacterAdded(ARLocalPlayer.Character, LocalPlayer.Character)
	end

	ClientController._janitor:Add(
		ARLocalPlayer.CharacterAdded:Connect(function(character)
			ClientController._onCharacterAdded(character, LocalPlayer.Character)
		end),
		"Disconnect"
	)

	ClientController._janitor:Add(
		ARLocalPlayer.CharacterRemoving:Connect(function()
			ClientController._onCharacterRemoving()
		end),
		"Disconnect"
	)

	ClientController._janitor:Add(
		RunService.Heartbeat:Connect(function(): ()
			local character = ARLocalPlayer.Character
			local vehicle = character and character.Sitting and character.Vehicle or nil
			if peek(clientState.vehicle) ~= vehicle then
				clientState.vehicle(vehicle)
			end
		end),
		"Disconnect"
	)

	return ClientController
end

function ClientController.Destroy()
	ClientController._janitor:Destroy()
end

function ClientController._onCharacterRemoving()
	clientState.character(nil)
	clientState.health(0)
	clientState.hydration(0)
	clientState.energy(0)
	clientState.alive(false)
	clientState.team(nil)
	clientState.vehicle(nil)
end

function ClientController._onCharacterAdded(arCharacter: any, character: Model)
	ClientController._janitor:Remove("HealthChanged")
	ClientController._janitor:Remove("EnergyChanged")
	ClientController._janitor:Remove("HydrationChanged")
	ClientController._janitor:Remove("PartAdded")
	ClientController._janitor:Remove("PartRemoved")

	ClientController._janitor:Add(
		arCharacter.Health.Changed:Connect(function(newValue)
			clientState.health(newValue)
		end),
		"Disconnect",
		"HealthChanged"
	)

	ClientController._janitor:Add(
		arCharacter.Energy.Changed:Connect(function(newValue)
			clientState.energy(newValue)
		end),
		"Disconnect",
		"EnergyChanged"
	)

	ClientController._janitor:Add(
		arCharacter.Hydration.Changed:Connect(function(newValue)
			clientState.hydration(newValue)
		end),
		"Disconnect",
		"HydrationChanged"
	)

	clientState.health(arCharacter.Health:Get())
	clientState.energy(arCharacter.Energy:Get())
	clientState.hydration(arCharacter.Hydration:Get())
	clientState.alive(true)
	clientState.character(character)
	clientState.team(LocalPlayer.Name)

	local parts = {}

	for _, part in next, character:GetChildren() do
		parts[part.Name :: any] = part
	end

	clientState.parts(parts)

	ClientController._janitor:Add(
		character.ChildAdded:Connect(function(part: Instance): ()
			clientState.parts(Sift.Dictionary.set(peek(clientState.parts), part.Name :: any, part))
		end),
		"Disconnect",
		"PartAdded"
	)

	ClientController._janitor:Add(
		character.ChildRemoved:Connect(function(part: Instance): ()
			clientState.parts(Sift.Dictionary.removeKey(peek(clientState.parts), part.Name :: any))
		end),
		"Disconnect",
		"PartRemoved"
	)
end

export type ClientController = typeof(ClientController)
return ClientController
