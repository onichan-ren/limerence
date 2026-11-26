local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local ClientState = require("@game/overkill/client/clientState")

local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer

local targeting = {}

targeting.HITBOX_PARTS = {
	Head = { "Head" },
	Torso = { "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart" },
	Arms = { "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "Left Arm", "Right Arm" },
	Legs = { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" },
	Feet = { "LeftFoot", "RightFoot" },
} :: { [string]: { string } }

targeting.isEnemy = LPH_NO_VIRTUALIZE(function(bp: any): boolean
	if not bp:IsAlive() then
		return false
	end
	if bp.isBot then
		return true
	end
	if bp:GetPlayer() == LocalPlayer then
		return false
	end
	local localMatch = peek(ClientState.matchId)
	if localMatch == nil or peek(bp.matchId) ~= localMatch then
		return false
	end
	local localTeam = peek(ClientState.team)
	if localTeam ~= "" and peek(bp.team) == localTeam then
		return false
	end
	return true
end)

return targeting
