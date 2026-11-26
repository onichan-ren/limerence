local Players = cloneref(game:GetService("Players")) :: Players

local NetworkController = require("@game/rivals/network/NetworkController")

local LocalPlayer = Players.LocalPlayer

local VOTE_PATH = "Duels.Vote"

local duelVote = {}

local function getDuelController(): any?
	local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local controllers = scripts and scripts:FindFirstChild("Controllers")
	local module = controllers and controllers:FindFirstChild("DuelController")
	if not module then
		return nil
	end
	return require(module :: ModuleScript)
end

local function isLocalDuel(duel: any): boolean
	if not duel or not duel.GetDueler then
		return false
	end
	return duel:GetDueler(LocalPlayer) ~= nil
end

function duelVote.isBanPhase(duel: any, optionsType: string): boolean
	local mode = duel:Get("VoteSelectionMode")
	if type(mode) == "string" then
		return string.find(string.lower(mode), "ban") ~= nil
	end
	local maxBans = optionsType == "Maps" and duel:Get("MaxMapBansPerTeam") or duel:Get("MaxWeaponBansPerTeam")
	return (maxBans or 0) > 0
end

function duelVote.send(name: string): ()
	NetworkController.SendRemote(VOTE_PATH, name)
end

function duelVote.bind(janitor: any, onPhase: (duel: any) -> ()): ()
	local duelController = getDuelController()
	if not duelController then
		return
	end

	local function bind(duel: any): ()
		local function fire(): ()
			if isLocalDuel(duel) then
				onPhase(duel)
			end
		end
		janitor:Add(duel:GetDataChangedSignal("VoteOptions"):Connect(fire), "Disconnect")
		fire()
	end

	for _, duel in next, duelController.Objects do
		bind(duel)
	end
	janitor:Add(duelController.ObjectAdded:Connect(bind), "Disconnect")
end

return duelVote
