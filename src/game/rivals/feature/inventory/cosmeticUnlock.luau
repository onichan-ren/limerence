local Charm = require("@pkg/Charm")
local logger = require("@share/logger").new("cosmeticUnlock")
local NetworkController = require("@game/rivals/network/NetworkController")
local inventoryEquip = require("@game/rivals/feature/inventory/inventoryEquip")
local playerDataAccess = require("@game/rivals/feature/inventory/playerDataAccess")
local cosmeticLibraryAccess = require("@game/rivals/feature/inventory/cosmeticLibraryAccess")
local rivalsInventoryState = require("@game/rivals/feature/inventory/rivalsInventoryState")
local stateConverter = require("@src/feature/config/module/stateConverter")

local peek = Charm.peek

local EQUIP_REMOTE = "Data.EquipCosmetic"

local cosmeticUnlock = {
	_blocked = false,
	_started = false,
}

local _equipHandler: ((weaponName: string, cosmeticType: string, cosmeticName: string?, opts: any) -> boolean)? = nil

local function getSet(): { [string]: boolean }
	return peek(rivalsInventoryState.unlockedCosmetics)
end

local function refreshNative(): ()
	inventoryEquip.fireDataChanged(playerDataAccess.getController(), "CosmeticInventory")
end

local function blockEquip(...: any): (boolean, any?)
	local weaponName, cosmeticType, cosmeticName = ...
	local handler = _equipHandler
	if handler then
		local ok, blocked = pcall(handler, weaponName, cosmeticType, cosmeticName, select(4, ...))
		if ok then
			return not blocked
		end
	end
	if type(cosmeticName) == "string" and getSet()[cosmeticName] then
		return false
	end
	return true
end

function cosmeticUnlock.setEquipHandler(handler: ((
	weaponName: string,
	cosmeticType: string,
	cosmeticName: string?,
	opts: any
) -> boolean)?): ()
	_equipHandler = handler
end

local function installBlock(): ()
	if cosmeticUnlock._blocked then
		return
	end
	if not NetworkController.GetRemote(EQUIP_REMOTE) then
		logger:warn("EquipCosmetic remote missing")
		return
	end
	NetworkController.HookRemote(EQUIP_REMOTE, blockEquip)
	cosmeticUnlock._blocked = true
end

function cosmeticUnlock.IsUnlocked(name: string): boolean
	return getSet()[name] == true
end

function cosmeticUnlock.Unlock(name: string): ()
	if type(name) ~= "string" or getSet()[name] then
		return
	end
	local copy = table.clone(getSet())
	copy[name] = true
	rivalsInventoryState.unlockedCosmetics(copy)
	refreshNative()
end

function cosmeticUnlock.Lock(name: string): ()
	if type(name) ~= "string" or not getSet()[name] then
		return
	end
	local copy = table.clone(getSet())
	copy[name] = nil
	rivalsInventoryState.unlockedCosmetics(copy)
	refreshNative()
end

function cosmeticUnlock.Toggle(name: string): ()
	if getSet()[name] then
		cosmeticUnlock.Lock(name)
	else
		cosmeticUnlock.Unlock(name)
	end
end

function cosmeticUnlock.UnlockAll(): ()
	local lib = cosmeticLibraryAccess.getLibrary()
	if not lib or type(lib.Cosmetics) ~= "table" then
		return
	end
	local copy: { [string]: boolean } = {}
	for name, info in next, lib.Cosmetics do
		if type(name) == "string" and type(info) == "table" and not info.Hidden then
			copy[name] = true
		end
	end
	rivalsInventoryState.unlockedCosmetics(copy)
	refreshNative()
end

function cosmeticUnlock.LockAll(): ()
	if next(getSet()) == nil then
		return
	end
	rivalsInventoryState.unlockedCosmetics({})
	refreshNative()
end

local _saveConfig = LPH_NO_VIRTUALIZE(function(): { string }
	local out: { string } = {}
	for name in next, getSet() do
		if type(name) == "string" then
			out[#out + 1] = name
		end
	end
	return out
end)

local _applyConfig = LPH_NO_VIRTUALIZE(function(data: any): ()
	local copy: { [string]: boolean } = {}
	if type(data) == "table" then
		for key, value in next, data do
			if type(value) == "string" then
				copy[value] = true
			elseif type(key) == "string" and value then
				copy[key] = true
			end
		end
	end
	rivalsInventoryState.unlockedCosmetics(copy)
	refreshNative()
end)

local _prepareConfig = LPH_NO_VIRTUALIZE(function(_data: any): ()
	rivalsInventoryState.unlockedCosmetics({})
	refreshNative()
end)

function cosmeticUnlock.new(): typeof(cosmeticUnlock)
	if cosmeticUnlock._started then
		return cosmeticUnlock
	end
	cosmeticUnlock._started = true

	inventoryEquip.setUnlockProvider(getSet)
	installBlock()
	stateConverter.RegisterExtension("rivalsUnlocks", _saveConfig, _applyConfig, _prepareConfig)

	return cosmeticUnlock
end

function cosmeticUnlock.Destroy(): ()
	_equipHandler = nil
	stateConverter.UnregisterExtension("rivalsUnlocks")
	inventoryEquip.setUnlockProvider(nil)
	if cosmeticUnlock._blocked then
		NetworkController.UnhookRemote(EQUIP_REMOTE)
		cosmeticUnlock._blocked = false
	end
	rivalsInventoryState.unlockedCosmetics({})
	refreshNative()
	cosmeticUnlock._started = false
end

export type CosmeticUnlock = typeof(cosmeticUnlock)
return cosmeticUnlock
