local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local PlayerController = require("@feature/player/PlayerController")
local NetworkController = require("@game/bloxstrike/network/NetworkController")
local droppedWeaponAmmo = require("@game/bloxstrike/dropped/droppedWeaponAmmo")

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

local UNEQUIP_MATCH_WINDOW = 4
local SNAPSHOT_TTL = 45
local RECENT_CAP = 12

export type AmmoSnapshot = {
	rounds: number,
	maxRounds: number,
}

type StoredSnapshot = AmmoSnapshot & {
	weaponName: string,
	team: string?,
	at: number,
}

type PlayerItem = {
	Identifier: string?,
	Name: string?,
	Rounds: number?,
}

local droppedAmmoTracker = {}

local byIdentifier: { [string]: StoredSnapshot } = {}
local recentUnequips: { StoredSnapshot & { identifier: string? } } = {}
local lastEquippedByUserId: { [number]: PlayerItem? } = {}
local playerUnsubs: { [number]: () -> () } = {}
local localUnsub: (() -> ())? = nil
local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local initialized = false

local function now(): number
	return os.clock()
end

local pruneExpired = LPH_NO_VIRTUALIZE(function(): ()
	local t = now()
	for identifier, snapshot in next, byIdentifier do
		if t - snapshot.at > SNAPSHOT_TTL then
			byIdentifier[identifier] = nil
		end
	end

	local write = 1
	for i = 1, #recentUnequips do
		local entry = recentUnequips[i]
		if t - entry.at <= SNAPSHOT_TTL then
			recentUnequips[write] = entry
			write += 1
		end
	end
	for i = write, #recentUnequips do
		recentUnequips[i] = nil
	end
end)

local function pushRecent(entry: StoredSnapshot & { identifier: string? }): ()
	recentUnequips[#recentUnequips + 1] = entry
	if #recentUnequips > RECENT_CAP then
		table.remove(recentUnequips, 1)
	end
end

local function snapshotFromItem(item: PlayerItem, team: string?): StoredSnapshot?
	if type(item.Name) ~= "string" or item.Name == "" then
		return nil
	end
	if not droppedWeaponAmmo.isAmmoWeapon(item.Name) then
		return nil
	end

	local maxRounds = droppedWeaponAmmo.getMaxRounds(item.Name)
	local rounds = (type(item.Rounds) == "number" and math.max(item.Rounds, 0) or 0)

	return {
		weaponName = item.Name,
		rounds = rounds,
		maxRounds = maxRounds,
		team = team,
		at = now(),
	}
end

local function rememberUnequip(userId: number, team: string?, item: PlayerItem): ()
	local snapshot = snapshotFromItem(item, team)
	if not snapshot then
		return
	end

	local identifier = item.Identifier
	if type(identifier) == "string" and identifier ~= "" then
		byIdentifier[identifier] = snapshot
		pushRecent({
			identifier = identifier,
			weaponName = snapshot.weaponName,
			rounds = snapshot.rounds,
			maxRounds = snapshot.maxRounds,
			team = snapshot.team,
			at = snapshot.at,
		})
	else
		pushRecent({
			identifier = nil,
			weaponName = snapshot.weaponName,
			rounds = snapshot.rounds,
			maxRounds = snapshot.maxRounds,
			team = snapshot.team,
			at = snapshot.at,
		})
	end
end

local function onEquippedChanged(userId: number, team: string?, item: PlayerItem?): ()
	local previous = lastEquippedByUserId[userId]
	lastEquippedByUserId[userId] = item

	if previous and (not item or previous.Identifier ~= item.Identifier) then
		rememberUnequip(userId, team, previous)
	end
end

local function bindRemotePlayer(basePlayer: any): ()
	local player = (basePlayer :: any):GetPlayer()
	local userId = player.UserId
	if playerUnsubs[userId] then
		return
	end

	lastEquippedByUserId[userId] = peek(basePlayer.currentEquipped)

	playerUnsubs[userId] = sub(
		basePlayer.currentEquipped,
		LPH_NO_VIRTUALIZE(function(item: PlayerItem?): ()
			onEquippedChanged(userId, peek(basePlayer.team), item)
		end)
	)
end

local function unbindRemotePlayer(basePlayer: any): ()
	local userId = (basePlayer :: any):GetPlayer().UserId
	local disconnect = playerUnsubs[userId]
	if disconnect then
		disconnect()
		playerUnsubs[userId] = nil
	end
	lastEquippedByUserId[userId] = nil
end

local function decodeEquipped(raw: string?): PlayerItem?
	if not raw then
		return nil
	end
	local item = HttpService:JSONDecode(raw)
	if type(item) == "table" then
		return item
	end
	return nil
end

local function bindLocalPlayer(): ()
	if localUnsub then
		return
	end

	local sync = LPH_NO_VIRTUALIZE(function(): ()
		onEquippedChanged(
			LocalPlayer.UserId,
			LocalPlayer:GetAttribute("Team"),
			decodeEquipped(LocalPlayer:GetAttribute("CurrentEquipped"))
		)
	end)

	sync()
	local conn = LocalPlayer:GetAttributeChangedSignal("CurrentEquipped"):Connect(sync)
	local teamConn = LocalPlayer:GetAttributeChangedSignal("Team"):Connect(sync)
	localUnsub = function()
		conn:Disconnect()
		teamConn:Disconnect()
		localUnsub = nil
	end
end

local findTeamFallback = LPH_NO_VIRTUALIZE(function(weaponName: string, team: string?): AmmoSnapshot?
	if type(team) ~= "string" or team == "" then
		return nil
	end

	local t = now()
	local best: StoredSnapshot? = nil
	for i = #recentUnequips, 1, -1 do
		local entry = recentUnequips[i]
		if entry.weaponName == weaponName and entry.team == team and t - entry.at <= UNEQUIP_MATCH_WINDOW then
			if not best or entry.at > best.at then
				best = entry
			end
		end
	end

	if not best then
		return nil
	end

	return {
		rounds = best.rounds,
		maxRounds = best.maxRounds,
	}
end)

function droppedAmmoTracker.resolve(model: Model, weaponName: string, kind: string): AmmoSnapshot?
	if kind ~= "weapon" or not droppedWeaponAmmo.isAmmoWeapon(weaponName) then
		return nil
	end

	pruneExpired()

	local identity = model.Name
	local byId = byIdentifier[identity]
	if byId and byId.weaponName == weaponName and now() - byId.at <= SNAPSHOT_TTL then
		byIdentifier[identity] = nil
		return {
			rounds = byId.rounds,
			maxRounds = byId.maxRounds,
		}
	end

	local team = model:GetAttribute("DroppedByTeam")
	if type(team) ~= "string" then
		team = nil
	end

	return findTeamFallback(weaponName, team)
end

function droppedAmmoTracker.noteDropIdentifier(identifier: string): ()
	local snapshot = byIdentifier[identifier]
	if snapshot then
		snapshot.at = now()
	end
end

function droppedAmmoTracker.init(): ()
	if initialized then
		return
	end
	initialized = true

	bindLocalPlayer()

	for _, basePlayer in next, PlayerController.GetAll() do
		bindRemotePlayer(basePlayer)
	end

	playerAddedConn = PlayerController.playerAdded:Connect(bindRemotePlayer)
	playerRemovingConn = PlayerController.playerRemoving:Connect(unbindRemotePlayer)

	NetworkController.HookPacket("Inventory", "DropWeapon", function(payload: any): boolean
		if type(payload) == "table" and type(payload.Identifier) == "string" then
			droppedAmmoTracker.noteDropIdentifier(payload.Identifier)
		end
		return true
	end)
end

function droppedAmmoTracker.destroy(): ()
	if not initialized then
		return
	end
	initialized = false

	if localUnsub then
		localUnsub()
	end

	for userId, disconnect in next, playerUnsubs do
		disconnect()
		playerUnsubs[userId] = nil
	end

	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end

	NetworkController.UnhookPacket("Inventory", "DropWeapon")

	table.clear(byIdentifier)
	table.clear(recentUnequips)
	table.clear(lastEquippedByUserId)
end

return droppedAmmoTracker
