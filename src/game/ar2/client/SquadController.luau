local Signal = require("@pkg/Signal")
local NetworkController = require("@game/ar2/network/NetworkController")
local NotifyController = require("@ui/hud/notify/NotifyController")
local playerState = require("@feature/record/module/playerState")

local Players = cloneref(game:GetService("Players")) :: Players

local PACKET = "Squad Data Update"
local FRIENDLY = "friendly"

local SquadController = {
	_members = {} :: { [number]: boolean },
	_autoMarked = {} :: { [number]: boolean },
	_enabled = true,
	_notify = false,
	_hooked = false,
	onChanged = Signal.new() :: Signal.Signal<()>,
}

local function notifyMarked(id: number): ()
	if not SquadController._notify then
		return
	end
	local player = Players:GetPlayerByUserId(id)
	local name = player and (player.DisplayName or player.Name) or ("User " .. id)
	NotifyController.Push({
		title = "Squad Friendly",
		subtext = `{name} marked friendly.`,
		icon = "person",
		duration = 3,
	})
end

local function clearAutoMarked(): ()
	for id in next, SquadController._autoMarked do
		if playerState.GetState(id) == FRIENDLY then
			playerState.SetState(id, nil)
		end
		SquadController._autoMarked[id] = nil
	end
end

local function applyFriendlies(members: { [number]: boolean }): ()
	if not SquadController._enabled then
		return
	end

	local localPlayer = Players.LocalPlayer
	local localId = localPlayer and localPlayer.UserId

	for id in next, members do
		if id ~= localId and not SquadController._autoMarked[id] and playerState.GetState(id) == nil then
			playerState.SetState(id, FRIENDLY)
			SquadController._autoMarked[id] = true
			notifyMarked(id)
		end
	end

	for id in next, SquadController._autoMarked do
		if not members[id] then
			if playerState.GetState(id) == FRIENDLY then
				playerState.SetState(id, nil)
			end
			SquadController._autoMarked[id] = nil
		end
	end
end

local function update(payload: any): ()
	local members: { [number]: boolean } = {}
	if type(payload) == "table" then
		for key in next, payload do
			local id = tonumber(key)
			if id then
				members[id] = true
			end
		end
	end

	local previous = SquadController._members
	local changed = false
	for id in next, members do
		if not previous[id] then
			changed = true
			break
		end
	end
	if not changed then
		for id in next, previous do
			if not members[id] then
				changed = true
				break
			end
		end
	end

	SquadController._members = members
	applyFriendlies(members)
	if changed then
		SquadController.onChanged:Fire()
	end
end

function SquadController.new(): SquadController
	SquadController._members = {}
	SquadController._autoMarked = {}

	if not SquadController._hooked then
		NetworkController.hookReceiver(
			PACKET,
			LPH_NO_VIRTUALIZE(function(payload: any): ()
				update(payload)
			end)
		)
		SquadController._hooked = true
	end

	return SquadController
end

function SquadController.SetEnabled(value: boolean): ()
	local enabled = value == true
	if SquadController._enabled == enabled then
		return
	end
	SquadController._enabled = enabled
	if enabled then
		applyFriendlies(SquadController._members)
	else
		clearAutoMarked()
	end
end

function SquadController.SetNotify(value: boolean): ()
	SquadController._notify = value == true
end

function SquadController.IsSquadmate(player: Player?): boolean
	return player ~= nil and SquadController._members[player.UserId] == true
end

function SquadController.GetMemberIds(): { number }
	local out = {}
	for id in next, SquadController._members do
		out[#out + 1] = id
	end
	return out
end

function SquadController.Destroy(): ()
	if SquadController._hooked then
		NetworkController.restoreReceiver(PACKET)
		SquadController._hooked = false
	end

	clearAutoMarked()

	SquadController._members = {}
	SquadController._autoMarked = {}
end

export type SquadController = typeof(SquadController)

return SquadController
