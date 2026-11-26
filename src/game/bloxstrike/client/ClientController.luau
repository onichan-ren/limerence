local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local SpectateController = require("@game/bloxstrike/client/SpectateController")
local NetworkController = require("@game/bloxstrike/network/NetworkController")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local ScopeController = require("@feature/ui/scope/ScopeController")
local ClientState = require("@game/bloxstrike/client/clientState")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local weaponSpreadState = require("@game/bloxstrike/client/weaponSpreadState")
local flashVisibility = require("@game/bloxstrike/client/flashVisibility")
local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService
local HttpService = cloneref(game:GetService("HttpService")) :: HttpService
local LocalPlayer = Players.LocalPlayer

local peek = Charm.peek

local function syncSlot5(): ()
	local raw = LocalPlayer:GetAttribute("Slot5")
	if type(raw) ~= "string" or raw == "" then
		ClientState.hasC4(false)
		return
	end
	local data = HttpService:JSONDecode(raw)
	if type(data) ~= "table" then
		ClientState.hasC4(false)
		return
	end
	ClientState.hasC4(data.Weapon == "C4")
end

local function syncSpectators(): ()
	local state = workspace:GetAttribute("GameState")
	if state == "Game Ending" or state == "Map Voting" or state == "Intermission" then
		ClientState.spectatorCount(0)
		return
	end
	ClientState.spectatorCount(tonumber(LocalPlayer:GetAttribute("Spectators")) or 0)
end

local function syncArmor(): ()
	local raw = LocalPlayer:GetAttribute("Armor")
	if type(raw) ~= "string" or raw == "" then
		ClientState.armor(ClientState.EMPTY_ARMOR)
		return
	end
	local data = HttpService:JSONDecode(raw)
	if type(data) ~= "table" then
		ClientState.armor(ClientState.EMPTY_ARMOR)
		return
	end
	local t = tostring(data.Type or "")
	local hp = tonumber(data.Health) or 0
	if hp <= 0 then
		ClientState.armor(ClientState.EMPTY_ARMOR)
		return
	end
	local hasKevlar = t == "Kevlar" or t == "Kevlar + Helmet"
	local hasHelmet = t == "Kevlar + Helmet"
	if not hasKevlar then
		ClientState.armor(ClientState.EMPTY_ARMOR)
		return
	end
	ClientState.armor({ kevlar = hasKevlar, helmet = hasHelmet, health = hp })
end

local ClientController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
}

function ClientController.new(): ClientController
	SpectateController.new()

	ClientController._janitor:Add(
		LocalPlayer:GetAttributeChangedSignal("Team"):Connect(function()
			local team = LocalPlayer:GetAttribute("Team") :: Team

			ClientState.team(team)
		end),
		"Disconnect"
	)
	ClientState.team(LocalPlayer:GetAttribute("Team") :: Team)

	local character = LocalPlayer.Character
	if character then
		ClientController._onCharacterAdded(character)
	end

	ClientController._janitor:Add(
		LocalPlayer.CharacterAdded:Connect(function(character: Model): ()
			ClientController._onCharacterAdded(character)
		end),
		"Disconnect"
	)

	ClientController._janitor:Add(
		LocalPlayer:GetAttributeChangedSignal("IsSpectating"):Connect(function(): ()
			ClientState.isSpectating(LocalPlayer:GetAttribute("IsSpectating") :: boolean)
		end),
		"Disconnect"
	)

	ClientController._janitor:Add(
		LocalPlayer:GetAttributeChangedSignal("ScopeIncrement"):Connect(function(): ()
			ClientState.isScoped((LocalPlayer:GetAttribute("ScopeIncrement") or 0) > 0)
		end),
		"Disconnect"
	)
	ClientState.isScoped((LocalPlayer:GetAttribute("ScopeIncrement") or 0) > 0)

	ClientController._janitor:Add(
		LocalPlayer:GetAttributeChangedSignal("IsDefusingBomb"):Connect(function(): ()
			ClientState.isDefusing(LocalPlayer:GetAttribute("IsDefusingBomb") == true)
		end),
		"Disconnect"
	)
	ClientState.isDefusing(LocalPlayer:GetAttribute("IsDefusingBomb") == true)

	ClientController._janitor:Add(LocalPlayer:GetAttributeChangedSignal("Slot5"):Connect(syncSlot5), "Disconnect")
	syncSlot5()

	ClientController._janitor:Add(LocalPlayer:GetAttributeChangedSignal("Armor"):Connect(syncArmor), "Disconnect")
	syncArmor()

	ClientController._janitor:Add(
		LocalPlayer:GetAttributeChangedSignal("Spectators"):Connect(syncSpectators),
		"Disconnect"
	)
	ClientController._janitor:Add(
		workspace:GetAttributeChangedSignal("GameState"):Connect(syncSpectators),
		"Disconnect"
	)
	syncSpectators()

	local FlashClass = ModuleController.GetModule("FlashClass")
	local isFlashed = FlashClass and rawget(FlashClass, "IsFlashed")
	ClientController._janitor:Add(
		RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
			local equipped = peek(loadoutState.currentEquipped)
			if equipped then
				weaponSpreadState.step(equipped)
			end

			if not isFlashed or not isFlashed() then
				if peek(ClientState.isFlashed) then
					ClientState.isFlashed(false)
					ClientState.flashVisibility(0)
					flashVisibility.reset()
				end
			else
				ClientState.isFlashed(true)
				ClientState.flashVisibility(flashVisibility.sample())
			end
		end)),
		"Disconnect",
		"WeaponSpreadState"
	)

	ClientState.isSpectating(LocalPlayer:GetAttribute("IsSpectating") :: boolean)

	return ClientController
end

function ClientController._onCharacterAdded(character: Model): ()
	ClientController._janitor:Remove("Dead")
	ClientController._janitor:Remove("PartAdded")
	ClientController._janitor:Remove("PartRemoved")

	ClientState.character(character)

	ClientState.alive(character:GetAttribute("Dead") ~= true)

	ClientController._janitor:Add(
		character:GetAttributeChangedSignal("Dead"):Connect(function(): ()
			ClientState.alive(character:GetAttribute("Dead") ~= true)
		end),
		"Disconnect",
		"Dead"
	)

	local parts = {}

	for _, part in next, character:GetChildren() do
		parts[part.Name :: any] = part
	end
	ClientState.parts(parts)

	ClientController._janitor:Add(
		character.ChildAdded:Connect(function(part: Instance): ()
			ClientState.parts(Sift.Dictionary.set(peek(ClientState.parts), part.Name :: any, part))
		end),
		"Disconnect",
		"PartAdded"
	)

	ClientController._janitor:Add(
		character.ChildRemoved:Connect(function(part: Instance): ()
			ClientState.parts(Sift.Dictionary.removeKey(peek(ClientState.parts), part.Name :: any))
		end),
		"Disconnect",
		"PartRemoved"
	)
end

function ClientController.GetTeam(): string?
	return peek(ClientState.team)
end

local getCurrentCharacter: (() -> any)? = nil

function ClientController.GetCharacterObject(): any
	if not getCurrentCharacter then
		local characterController = ModuleController.GetModule("CharacterController")
		if not characterController then
			return nil
		end
		getCurrentCharacter = rawget(characterController, "getCurrentCharacter") :: () -> any
		if not getCurrentCharacter then
			return nil
		end
	end
	return getupvalue(getCurrentCharacter :: () -> any, 1)
end

function ClientController.IsClimbing(): boolean
	local character = ClientController.GetCharacterObject()
	return character ~= nil and rawget(character, "IsClimbing") == true and not rawget(character, "JumpedOffLadder")
end

function ClientController.Destroy(): ()
	SpectateController.Destroy()
	ClientController._janitor:Destroy()
	weaponSpreadState.reset()
end

export type ClientController = typeof(ClientController)
export type Team = ClientState.Team

return ClientController
