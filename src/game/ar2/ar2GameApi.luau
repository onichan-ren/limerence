local ModuleController = require("@game/ar2/module/ModuleController")
local NetworkController = require("@game/ar2/network/NetworkController")
local PlayerController = require("@feature/player/PlayerController")
local SquadController = require("@game/ar2/client/SquadController")
local ZombieController = require("@game/ar2/zombie/ZombieController")
local Charm = require("@pkg/Charm")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local Players = cloneref(game:GetService("Players")) :: Players

local peek = Charm.peek

local send = LPH_NO_VIRTUALIZE(function(...): ()
	local old = getthreadidentity()
	setthreadidentity(2)
	NetworkController.send(...)
	setthreadidentity(old)
end)

local function getCharacter(): any
	local module = ModuleController.GetModule("LocalPlayer")
	local getter = module and module.module and module.module.get
	local player = getter and getter()
	return player and player.Character or nil
end

local function pingIndex(): any
	local character = getCharacter()
	return (character and (character.DefaultPingIndex or character.LastPingIndex)) or 1
end

local function ping(position: Vector3): ()
	if typeof(position) ~= "Vector3" then
		error("api.game.ping: position must be a Vector3", 2)
	end
	send("Set World Ping", pingIndex(), position, nil)
end

local function pingPlayer(target: any): ()
	if typeof(target) ~= "Instance" or not target:IsA("Player") then
		error("api.game.pingPlayer: target must be a Player", 2)
	end
	local data = PlayerController.Get(target)
	local hrp = data and peek(data.hrp) :: BasePart?
	if not hrp then
		return
	end
	send("Set World Ping", pingIndex(), hrp.Position, nil)
end

local function clearPing(): ()
	send("Clear World Ping")
end

local function getSquad(): { Player }
	local out = {}
	for _, id in next, SquadController.GetMemberIds() do
		local player = Players:GetPlayerByUserId(id)
		if player then
			out[#out + 1] = player
		end
	end
	return out
end

local function isSquadmate(target: any): boolean
	if typeof(target) ~= "Instance" or not target:IsA("Player") then
		error("api.game.isSquadmate: target must be a Player", 2)
	end
	return SquadController.IsSquadmate(target)
end

local function getZombies(): { Model }
	local out = {}
	for zombie in next, ZombieController.GetZombies() do
		out[#out + 1] = zombie
	end
	return out
end

local ar2GameApi = {}

luauApiRegistry.Register("game", function(ctx)
	local wrap = luauApiRegistry.WrapSignal
	return {
		ping = ping,
		pingPlayer = pingPlayer,
		clearPing = clearPing,
		getSquad = getSquad,
		isSquadmate = isSquadmate,
		getZombies = getZombies,
		onSquadChanged = wrap(SquadController.onChanged, ctx.onUnload),
		onZombieAdded = wrap(ZombieController.zombieAdded, ctx.onUnload),
		onZombieRemoved = wrap(ZombieController.zombieRemoved, ctx.onUnload),
	}
end)

return ar2GameApi
