local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local SpectateState = require("@game/bloxstrike/client/spectateState")
local ClientState = require("@game/bloxstrike/client/clientState")
local Players = cloneref(game:GetService("Players")) :: Players
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local peek = Charm.peek

local SpectateController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
}

local function onSpectatingChanged(isSpectating: boolean): ()
	local spectateController = ModuleController.GetModule("SpectateController")

	if isSpectating then
		local function onSpectatorSwitch(): ()
			local currentSpectateInstance = spectateController.GetCurrentSpectateInstance()

			SpectateState.instance(currentSpectateInstance)
			if not currentSpectateInstance then
				ClientState.team(LocalPlayer:GetAttribute("Team") :: string)
				SpectateState.instance(nil)
				return
			end

			local player = currentSpectateInstance.Player
			ClientState.team(player:GetAttribute("Team"))
		end

		SpectateController._janitor:Add(
			Camera:GetPropertyChangedSignal("CameraSubject"):Connect(onSpectatorSwitch),
			"Disconnect",
			"listener"
		)
		onSpectatorSwitch()
	else
		SpectateController._janitor:Remove("listener")
		task.defer(function()
			ClientState.team(LocalPlayer:GetAttribute("Team") :: string)
		end)
	end
end

function SpectateController.new(): SpectateController
	SpectateController._janitor:Add(
		LocalPlayer:GetAttributeChangedSignal("IsSpectating"):Connect(function(): ()
			local isSpectating = LocalPlayer:GetAttribute("IsSpectating") :: boolean
			onSpectatingChanged(isSpectating)
		end),
		"Disconnect"
	)
	onSpectatingChanged(LocalPlayer:GetAttribute("IsSpectating") :: boolean)

	return SpectateController
end

function SpectateController.GetPlayer(): Player?
	return peek(SpectateState.player)
end

function SpectateController.Destroy(): ()
	SpectateController._janitor:Destroy()
end

export type SpectateController = typeof(SpectateController)
return SpectateController
