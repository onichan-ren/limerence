local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local ModuleController = require("@game/pf/module/ModuleController")
local grenadeState = require("@game/pf/grenade/grenadeState")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local peek = Charm.peek

local SCAN_RADIUS = 100000

local signals = {
	onMatchChanged = Signal.new(),
	onRoundStarted = Signal.new(),
	onRoundEnded = Signal.new(),
}

local bridged = false

local function ensureBridge(): ()
	if bridged then
		return
	end
	local roundEvents = ModuleController.GetModule("RoundSystemClientEvents")
	if not roundEvents then
		return
	end
	bridged = true
	for name, signal in next, signals do
		local event = roundEvents[name]
		if event then
			event:connect(function(): ()
				signal:Fire()
			end)
		end
	end
end

local function isInGame(): boolean
	local round = ModuleController.GetModule("RoundSystemClientInterface")
	return round ~= nil and round.getMatchData() ~= nil
end

local function getGamemode(): string?
	local round = ModuleController.GetModule("RoundSystemClientInterface")
	local mode = round and round.getGameModeType()
	return type(mode) == "string" and mode ~= "" and mode or nil
end

local function getDroppedWeapons(): { { name: string, position: Vector3?, model: Instance } }
	local env = ModuleController.GetModule("EnvironmentInterfaceClient")
	if not env then
		return {}
	end
	local drops = env.getNearbyWeapons(Vector3.zero, SCAN_RADIUS)
	if type(drops) ~= "table" then
		return {}
	end
	local out = {}
	for _, record in next, drops do
		local data = record.dropData
		if data and data.weaponModel then
			local weaponObject = data.weaponObject
			out[#out + 1] = {
				name = weaponObject and weaponObject.weaponName or "Weapon",
				position = data.dropPosition,
				model = data.weaponModel,
			}
		end
	end
	return out
end

local function getGrenades(): { { [string]: any } }
	local out = {}
	for _, grenade in next, peek(grenadeState.incoming) do
		out[#out + 1] = {
			name = grenade.name,
			position = grenade.landing,
			detonateAt = grenade.detonateAt,
			blastRadius = grenade.blastRadius,
			friendly = grenade.isFriendly == true,
			mine = grenade.isSelf == true,
		}
	end
	return out
end

local pfGameApi = {}

luauApiRegistry.Register("game", function(ctx)
	ensureBridge()
	local wrap = luauApiRegistry.WrapSignal
	return {
		isInGame = isInGame,
		getGamemode = getGamemode,
		getDroppedWeapons = getDroppedWeapons,
		getGrenades = getGrenades,
		onMatchChanged = wrap(signals.onMatchChanged, ctx.onUnload),
		onRoundStarted = wrap(signals.onRoundStarted, ctx.onUnload),
		onRoundEnded = wrap(signals.onRoundEnded, ctx.onUnload),
	}
end)

return pfGameApi
