local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local ModuleController = require("@game/overkill/module/ModuleController")
local ClientState = require("@game/overkill/client/clientState")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local slotKeys = require("@game/overkill/weapon/slotKeys")

local peek = Charm.peek

local LocalWeaponController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
}

local clientModule: any = nil
local items: any = nil
local fireSlot = 0
local fireLast = 0

local function put(atom: any, value: any): ()
	if peek(atom) ~= value then
		atom(value)
	end
end

local function reset(): ()
	put(ClientState.aiming, false)
	put(ClientState.scoped, false)
	put(ClientState.inAir, false)
	put(ClientState.sprinting, false)
	put(ClientState.canFire, false)
	put(ClientState.weaponId, "")
	put(ClientState.weapon, "")
	put(ClientState.weaponCategory, "")
	put(ClientState.ammo, 0)
	put(ClientState.ammoReserve, 0)
	put(ClientState.magSize, 0)
	put(ClientState.isReloading, false)
	put(ClientState.equippedSlot, 1)
end

local function serverTimeOf(localChickynoid: any): number
	local predicted = localChickynoid and localChickynoid.predictedCommands
	if type(predicted) ~= "table" then
		return 0
	end
	local lastCommand = predicted[#predicted]
	local serverTime = type(lastCommand) == "table" and lastCommand.serverTime
	return type(serverTime) == "number" and serverTime or 0
end

local poll = LPH_NO_VIRTUALIZE(function(): ()
	setthreadidentity(8)
	local localChickynoid = clientModule and clientModule.localChickynoid
	local simulation = localChickynoid and localChickynoid.simulation
	local state = simulation and simulation.state
	if type(state) ~= "table" then
		reset()
		return
	end

	local slot = state.equippedSlot or 1
	local keys = slotKeys[slot] or slotKeys[1]
	local aiming = state.aiming == true
	local mag = state[keys.magCount]
	local reserve = state[keys.reserveCount]
	local reloadStart = state[keys.reloadStartServerTime]
	local lastFire = state[keys.lastFireServerTime]

	local weaponId = state[keys.weaponID]
	local item = nil
	if items and type(weaponId) == "string" and weaponId ~= "" then
		item = items.all[weaponId]
	end
	local name = item and item.name or ""
	local category = item and item.category or ""
	local stats = item and item.stats
	local ammoStats = stats and stats.ammo
	local firing = stats and stats.firing

	local magCount = type(mag) == "number" and mag or 0
	local reloading = type(reloadStart) == "number" and reloadStart ~= 0
	local rate = firing and type(firing.rate) == "number" and firing.rate or 0.1
	local rateReady = serverTimeOf(localChickynoid) - (type(lastFire) == "number" and lastFire or 0) >= rate

	put(ClientState.aiming, aiming)
	put(ClientState.scoped, aiming and category == "sniper_rifle")
	put(ClientState.inAir, (state.inAir or 0) > 0)
	put(ClientState.sprinting, state.sprinting == true)
	put(ClientState.weaponId, type(weaponId) == "string" and weaponId or "")
	put(ClientState.weapon, name)
	put(ClientState.weaponCategory, category)
	put(ClientState.ammo, magCount)
	put(ClientState.ammoReserve, type(reserve) == "number" and reserve or 0)
	put(ClientState.magSize, ammoStats and ammoStats.magSize or 0)
	put(ClientState.isReloading, reloading)
	put(ClientState.canFire, magCount > 0 and not reloading and rateReady)
	put(ClientState.equippedSlot, slot)

	local lastFireNum = type(lastFire) == "number" and lastFire or 0
	if slot ~= fireSlot then
		fireSlot = slot
		fireLast = lastFireNum
	elseif lastFireNum > fireLast then
		fireLast = lastFireNum
		WeaponController.weaponFiredLocal:Fire()
	end
end)

function LocalWeaponController.new(): LocalWeaponController
	clientModule = ModuleController.GetModule("clientModule")
	items = ModuleController.GetModule("items")
	fireSlot = 0
	fireLast = 0

	LocalWeaponController._janitor:Add(RunService.Heartbeat:Connect(poll))

	return LocalWeaponController
end

function LocalWeaponController.Destroy(): ()
	LocalWeaponController._janitor:Cleanup()
	clientModule = nil
	items = nil
end

export type LocalWeaponController = typeof(LocalWeaponController)

return LocalWeaponController
