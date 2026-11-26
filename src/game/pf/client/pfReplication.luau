local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService
local PlayerController = require("@feature/player/PlayerController")
local ModuleController = require("@game/pf/module/ModuleController")
local NetworkController = require("@game/pf/network/NetworkController")

local LocalPlayer = Players.LocalPlayer

local pfReplication = {
	_conn = nil :: RBXScriptConnection?,
	_interface = nil :: any,
	_entries = nil :: any,
	_entryRemovedConn = nil :: any,
	_diedUnhook = nil :: (() -> ())?,
	_spawnUnhook = nil :: (() -> ())?,
	_fireUnhook = nil :: (() -> ())?,
	_spotUnhook = nil :: (() -> ())?,
	_unspotUnhook = nil :: (() -> ())?,
	_spotSeeded = false,
}

local function onEntry(player: Player, entry: any): ()
	if player == LocalPlayer then
		return
	end
	local pf = PlayerController.Get(player)
	if pf and (pf :: any).SyncFromEntry then
		(pf :: any):SyncFromEntry(entry)
	end
end

local step = LPH_NO_VIRTUALIZE(function(): ()
	local interface = pfReplication._interface or ModuleController.GetModule("ReplicationInterface")
	if not interface then
		return
	end
	pfReplication._interface = interface

	local entries = pfReplication._entries
	if not entries then
		local up = debug.getupvalue(interface.operateOnAllEntries, 1)
		if type(up) ~= "table" then
			return
		end
		entries = up
		pfReplication._entries = entries
	end

	local id = getthreadidentity()
	setthreadidentity(8)

	for player, entry in next, entries do
		onEntry(player, entry)
	end

	if not pfReplication._spotSeeded then
		local spotting = ModuleController.GetModule("HudSpottingInterface")
		if spotting then
			pfReplication._spotSeeded = true
			for player in next, entries do
				if player ~= LocalPlayer then
					local pf = PlayerController.Get(player) :: any
					if pf and pf.spotted then
						pf.spotted(spotting.isSpotted(player) == true)
					end
				end
			end
		end
	end

	setthreadidentity(id)
end)

local onDied = LPH_NO_VIRTUALIZE(function(payload: any): ()
	if type(payload) ~= "table" then
		return
	end
	local victim = payload.victim
	if typeof(victim) ~= "Instance" or not victim:IsA("Player") or victim == LocalPlayer then
		return
	end
	local pf = PlayerController.Get(victim) :: any
	if pf and pf.OnDied then
		local id = getthreadidentity()
		setthreadidentity(8)
		pf:OnDied()
		setthreadidentity(id)
	end
end)

local onSpawn = LPH_NO_VIRTUALIZE(function(player: any): ()
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player == LocalPlayer then
		return
	end
	local pf = PlayerController.Get(player)
	if pf and (pf :: any).OnRespawn then
		(pf :: any):OnRespawn()
	end
end)

local onFire = LPH_NO_VIRTUALIZE(function(payload: any): ()
	if type(payload) ~= "table" then
		return
	end
	local player = payload.player
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player == LocalPlayer then
		return
	end
	local pf = PlayerController.Get(player) :: any
	if pf and pf.OnFire then
		local id = getthreadidentity()
		setthreadidentity(8)
		pf:OnFire()
		setthreadidentity(id)
	end
end)

local onEntryRemoved = LPH_NO_VIRTUALIZE(function(player: any): ()
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player == LocalPlayer then
		return
	end
	local pf = PlayerController.Get(player) :: any
	if pf and pf.MarkDead then
		local id = getthreadidentity()
		setthreadidentity(8)
		pf:MarkDead()
		setthreadidentity(id)
	end
end)

local function makeSpotHandler(value: boolean): (any) -> ()
	return LPH_NO_VIRTUALIZE(function(player: any): ()
		if typeof(player) ~= "Instance" or not player:IsA("Player") or player == LocalPlayer then
			return
		end
		local pf = PlayerController.Get(player) :: any
		if pf and pf.spotted then
			local id = getthreadidentity()
			setthreadidentity(8)
			pf.spotted(value)
			setthreadidentity(id)
		end
	end)
end

function pfReplication.new(): pfReplication
	pfReplication._conn = RunService.Heartbeat:Connect(step)
	pfReplication._diedUnhook = NetworkController.HookInbound("died", onDied)
	pfReplication._spawnUnhook = NetworkController.HookInbound("newspawn", onSpawn)
	pfReplication._fireUnhook = NetworkController.HookInbound("newbullets", onFire)
	pfReplication._spotUnhook = NetworkController.HookInbound("spotplayer", makeSpotHandler(true))
	pfReplication._unspotUnhook = NetworkController.HookInbound("unspotplayer", makeSpotHandler(false))
	local repEvents = ModuleController.GetModule("ReplicationEvents")
	if repEvents then
		pfReplication._entryRemovedConn = repEvents.onEntryRemoved:connect(onEntryRemoved)
	end
	return pfReplication
end

function pfReplication.Destroy(): ()
	if pfReplication._conn then
		pfReplication._conn:Disconnect()
		pfReplication._conn = nil
	end
	if pfReplication._diedUnhook then
		pfReplication._diedUnhook()
		pfReplication._diedUnhook = nil
	end
	if pfReplication._spawnUnhook then
		pfReplication._spawnUnhook()
		pfReplication._spawnUnhook = nil
	end
	if pfReplication._fireUnhook then
		pfReplication._fireUnhook()
		pfReplication._fireUnhook = nil
	end
	if pfReplication._spotUnhook then
		pfReplication._spotUnhook()
		pfReplication._spotUnhook = nil
	end
	if pfReplication._unspotUnhook then
		pfReplication._unspotUnhook()
		pfReplication._unspotUnhook = nil
	end
	if pfReplication._entryRemovedConn then
		pfReplication._entryRemovedConn:disconnect()
		pfReplication._entryRemovedConn = nil
	end
	pfReplication._spotSeeded = false
	pfReplication._interface = nil
	pfReplication._entries = nil
end

export type pfReplication = typeof(pfReplication)

return pfReplication
