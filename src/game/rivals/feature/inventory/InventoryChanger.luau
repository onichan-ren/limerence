local playerDataAccess = require("@game/rivals/feature/inventory/playerDataAccess")
local cosmeticLibraryAccess = require("@game/rivals/feature/inventory/cosmeticLibraryAccess")
local inventoryEquip = require("@game/rivals/feature/inventory/inventoryEquip")
local rivalsInventoryState = require("@game/rivals/feature/inventory/rivalsInventoryState")
local customWrapController = require("@game/rivals/feature/inventory/customWrapController")
local customCharmController = require("@game/rivals/feature/inventory/customCharmController")
local deployableSkins = require("@game/rivals/feature/inventory/deployableSkins")
local finisherSpoofer = require("@game/rivals/feature/inventory/finisherSpoofer")
local cosmeticUnlock = require("@game/rivals/feature/inventory/cosmeticUnlock")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local stateConverter = require("@src/feature/config/module/stateConverter")
local Charm = require("@pkg/Charm")

local InventoryChanger = {}
local peek = Charm.peek

local _disconnects: { () -> () } = {}
local _overlay: inventoryEquip.OverlayMap = {}
local _hookInstalled = false

local _track = LPH_NO_VIRTUALIZE(function(disconnect: () -> ()): ()
	table.insert(_disconnects, disconnect)
end)

local _getOverlay = LPH_NO_VIRTUALIZE(function(): inventoryEquip.OverlayMap
	return _overlay
end)

local _readWeaponInventory = LPH_NO_VIRTUALIZE(function(): { [string]: rivalsInventoryState.WeaponEquipped }
	local out: { [string]: rivalsInventoryState.WeaponEquipped } = {}
	local function readCosmeticName(value: any): string?
		if type(value) == "table" then
			return type(value.Name) == "string" and value.Name or nil
		end
		if type(value) == "string" then
			return value
		end
		return nil
	end
	local list = playerDataAccess.get("WeaponInventory")
	if type(list) == "table" then
		for _, entry in next, list do
			if type(entry) ~= "table" then
				continue
			end
			local entryName: any = entry.Name
			if type(entryName) ~= "string" then
				continue
			end
			local skinValue: any, wrapValue: any, charmValue: any, finisherValue: any =
				entry.Skin, entry.Wrap, entry.Charm, entry.Finisher
			local wrapInverted: boolean? = nil
			if type(wrapValue) == "table" then
				wrapInverted = wrapValue.Inverted == true or nil
			end
			out[entryName] = {
				skin = readCosmeticName(skinValue),
				wrap = readCosmeticName(wrapValue),
				charm = readCosmeticName(charmValue),
				finisher = readCosmeticName(finisherValue),
				wrapInverted = wrapInverted,
			}
		end
	end
	if type(_overlay) == "table" then
		for weaponName, override in next, _overlay do
			if type(weaponName) ~= "string" or type(override) ~= "table" then
				continue
			end
			local entry = out[weaponName]
			if not entry then
				entry = {}
				out[weaponName] = entry
			end
			if override.skin ~= nil then
				entry.skin = override.skin
			end
			if override.wrap ~= nil then
				entry.wrap = override.wrap
			end
			if override.charm ~= nil then
				entry.charm = override.charm
			end
			if override.finisher ~= nil then
				entry.finisher = override.finisher
			end
			if override.wrapInverted ~= nil then
				entry.wrapInverted = override.wrapInverted
			end
		end
	end
	return out
end)

local _syncFromPlayerData = LPH_NO_VIRTUALIZE(function(): ()
	rivalsInventoryState.weaponInventory(_readWeaponInventory())
end)

local _fireWeaponInventoryChanged = LPH_NO_VIRTUALIZE(function(): ()
	inventoryEquip.fireDataChanged(playerDataAccess.getController(), "WeaponInventory")
end)

local _refreshLoadoutWeapon = LPH_NO_VIRTUALIZE(function(weaponName: string?, cosmeticType: string?): ()
	if cosmeticType == "Finisher" then
		return
	end

	if cosmeticType == "Wrap" then
		if WeaponController.RefreshLoadoutViewModel(weaponName, "wrap") then
			return
		end
	end

	WeaponController.RefreshLoadoutViewModel(weaponName, "rebuild")
end)

local _updateOverlay = LPH_NO_VIRTUALIZE(function(weaponName: string, mutator: (inventoryEquip.Overlay) -> ()): ()
	local entry = _overlay[weaponName]
	if not entry then
		entry = {}
		_overlay[weaponName] = entry
	end
	mutator(entry)
	local empty = entry.skin == nil
		and entry.wrap == nil
		and entry.charm == nil
		and entry.finisher == nil
		and entry.wrapInverted == nil
	if empty then
		_overlay[weaponName] = nil
	end
end)

function InventoryChanger.Equip(weaponName: string, cosmeticType: string, cosmeticName: string?): boolean
	if type(weaponName) ~= "string" or type(cosmeticType) ~= "string" then
		return false
	end
	if cosmeticType ~= "Skin" and cosmeticType ~= "Wrap" and cosmeticType ~= "Charm" and cosmeticType ~= "Finisher" then
		return false
	end
	if not cosmeticLibraryAccess.hasSkins(weaponName) then
		return false
	end
	_updateOverlay(weaponName, function(entry)
		if cosmeticType == "Skin" then
			entry.skin = cosmeticName
		elseif cosmeticType == "Wrap" then
			entry.wrap = cosmeticName
		elseif cosmeticType == "Charm" then
			entry.charm = cosmeticName
		elseif cosmeticType == "Finisher" then
			entry.finisher = cosmeticName
		end
	end)
	_syncFromPlayerData()
	_fireWeaponInventoryChanged()
	_refreshLoadoutWeapon(weaponName, cosmeticType)
	return true
end

function InventoryChanger.Unequip(weaponName: string, cosmeticType: string): boolean
	return InventoryChanger.Equip(weaponName, cosmeticType, nil)
end

function InventoryChanger.ApplyToAll(cosmeticType: string, cosmeticName: string?): boolean
	if type(cosmeticType) ~= "string" then
		return false
	end
	if cosmeticType ~= "Skin" and cosmeticType ~= "Wrap" and cosmeticType ~= "Charm" and cosmeticType ~= "Finisher" then
		return false
	end
	local specificWeapon: string? = nil
	if cosmeticName then
		local entry = cosmeticLibraryAccess.getCosmetic(cosmeticName)
		if entry and type(entry.weapon) == "string" then
			specificWeapon = entry.weapon
		end
	end
	for _, weaponName in next, cosmeticLibraryAccess.getWeapons() do
		if specificWeapon and specificWeapon ~= weaponName then
			continue
		end
		_updateOverlay(weaponName, function(entry)
			if cosmeticType == "Skin" then
				entry.skin = cosmeticName
			elseif cosmeticType == "Wrap" then
				entry.wrap = cosmeticName
			elseif cosmeticType == "Charm" then
				entry.charm = cosmeticName
			elseif cosmeticType == "Finisher" then
				entry.finisher = cosmeticName
			end
		end)
	end
	_syncFromPlayerData()
	_fireWeaponInventoryChanged()
	_refreshLoadoutWeapon(nil, nil)
	return true
end

function InventoryChanger.UnapplyFromAll(cosmeticType: string, cosmeticName: string): boolean
	if type(cosmeticType) ~= "string" or type(cosmeticName) ~= "string" then
		return false
	end
	if cosmeticType ~= "Skin" and cosmeticType ~= "Wrap" and cosmeticType ~= "Charm" and cosmeticType ~= "Finisher" then
		return false
	end
	local inventory = peek(rivalsInventoryState.weaponInventory)
	if type(inventory) ~= "table" then
		return false
	end
	for weaponName, entry in next, inventory do
		if type(entry) ~= "table" then
			continue
		end
		local current = (cosmeticType == "Skin" and entry.skin)
			or (cosmeticType == "Wrap" and entry.wrap)
			or (cosmeticType == "Charm" and entry.charm)
			or (cosmeticType == "Finisher" and entry.finisher)
		if current ~= cosmeticName then
			continue
		end
		_updateOverlay(weaponName, function(o)
			if cosmeticType == "Skin" then
				o.skin = nil
			elseif cosmeticType == "Wrap" then
				o.wrap = nil
			elseif cosmeticType == "Charm" then
				o.charm = nil
			elseif cosmeticType == "Finisher" then
				o.finisher = nil
			end
		end)
	end
	_syncFromPlayerData()
	_fireWeaponInventoryChanged()
	_refreshLoadoutWeapon(nil, nil)
	return true
end

function InventoryChanger.GetEquipped(weaponName: string, cosmeticType: string): string?
	local inv = peek(rivalsInventoryState.weaponInventory)
	local entry = inv[weaponName]
	if not entry then
		return nil
	end
	if cosmeticType == "Skin" then
		return entry.skin
	elseif cosmeticType == "Wrap" then
		return entry.wrap
	elseif cosmeticType == "Charm" then
		return entry.charm
	elseif cosmeticType == "Finisher" then
		return entry.finisher
	end
	return nil
end

function InventoryChanger.SetWrapInverted(weaponName: string, inverted: boolean): boolean
	if type(weaponName) ~= "string" or not cosmeticLibraryAccess.hasSkins(weaponName) then
		return false
	end
	_updateOverlay(weaponName, function(entry)
		entry.wrapInverted = inverted and true or nil
	end)
	_syncFromPlayerData()
	_fireWeaponInventoryChanged()
	_refreshLoadoutWeapon(weaponName, "Wrap")
	return true
end

function InventoryChanger.GetWrapInverted(weaponName: string): boolean
	local inv = peek(rivalsInventoryState.weaponInventory)
	local entry = inv[weaponName]
	return entry ~= nil and entry.wrapInverted == true
end

local function _clearOverlaySlot(weaponName: string, cosmeticType: string): ()
	if _overlay[weaponName] == nil then
		return
	end
	_updateOverlay(weaponName, function(entry)
		if cosmeticType == "Skin" then
			entry.skin = nil
		elseif cosmeticType == "Wrap" then
			entry.wrap = nil
			entry.wrapInverted = nil
		elseif cosmeticType == "Charm" then
			entry.charm = nil
		elseif cosmeticType == "Finisher" then
			entry.finisher = nil
		end
	end)
end

local function _slotHasOverlay(weaponName: string, cosmeticType: string): boolean
	local entry = _overlay[weaponName]
	if not entry then
		return false
	end
	if cosmeticType == "Skin" then
		return entry.skin ~= nil
	elseif cosmeticType == "Wrap" then
		return entry.wrap ~= nil
	elseif cosmeticType == "Charm" then
		return entry.charm ~= nil
	elseif cosmeticType == "Finisher" then
		return entry.finisher ~= nil
	end
	return false
end

function InventoryChanger.HandleNativeEquip(
	weaponName: string,
	cosmeticType: string,
	cosmeticName: string?,
	opts: any
): boolean
	if type(weaponName) ~= "string" or type(cosmeticType) ~= "string" then
		return false
	end
	if cosmeticType ~= "Skin" and cosmeticType ~= "Wrap" and cosmeticType ~= "Charm" and cosmeticType ~= "Finisher" then
		return false
	end
	if type(cosmeticName) == "string" then
		if not cosmeticUnlock.IsUnlocked(cosmeticName) then
			_clearOverlaySlot(weaponName, cosmeticType)
			return false
		end
		InventoryChanger.Equip(weaponName, cosmeticType, cosmeticName)
		if cosmeticType == "Wrap" and type(opts) == "table" then
			InventoryChanger.SetWrapInverted(weaponName, opts.IsInverted == true)
		end
		return true
	end
	if _slotHasOverlay(weaponName, cosmeticType) then
		InventoryChanger.Unequip(weaponName, cosmeticType)
		return true
	end
	return false
end

function InventoryChanger.RefreshLoadout(): ()
	_fireWeaponInventoryChanged()
	_refreshLoadoutWeapon(nil, nil)
end

function InventoryChanger.SetRemoteOverlayProvider(fn: ((userId: number) -> inventoryEquip.OverlayMap?)?): ()
	inventoryEquip.setRemoteProvider(fn)
end

function InventoryChanger.ClearAll(): ()
	_overlay = {}
	_syncFromPlayerData()
	_fireWeaponInventoryChanged()
	_refreshLoadoutWeapon(nil, nil)
end

local _saveConfig = LPH_NO_VIRTUALIZE(function(): { [string]: any }
	local out: { [string]: any } = {}
	for weaponName, entry in next, _overlay do
		if type(weaponName) ~= "string" or type(entry) ~= "table" then
			continue
		end
		local serialized: { [string]: any } = {}
		if entry.skin ~= nil then
			serialized.skin = entry.skin
		end
		if entry.wrap ~= nil then
			serialized.wrap = entry.wrap
		end
		if entry.charm ~= nil then
			serialized.charm = entry.charm
		end
		if entry.finisher ~= nil then
			serialized.finisher = entry.finisher
		end
		if entry.wrapInverted ~= nil then
			serialized.wrapInverted = entry.wrapInverted
		end
		if next(serialized) ~= nil then
			out[weaponName] = serialized
		end
	end
	return out
end)

local _prepareConfig = LPH_NO_VIRTUALIZE(function(data: any): ()
	if type(data) ~= "table" then
		return
	end
	_overlay = {}
	_syncFromPlayerData()
	_fireWeaponInventoryChanged()
	_refreshLoadoutWeapon(nil, nil)
end)

local _loadConfig = LPH_NO_VIRTUALIZE(function(data: any): ()
	if type(data) ~= "table" then
		return
	end
	local rebuilt: inventoryEquip.OverlayMap = {}
	for weaponName, entry in next, data do
		if type(weaponName) ~= "string" or type(entry) ~= "table" or not cosmeticLibraryAccess.hasSkins(weaponName) then
			continue
		end
		local clean: inventoryEquip.Overlay = {}
		if type(entry.skin) == "string" then
			clean.skin = entry.skin
		end
		if type(entry.wrap) == "string" then
			clean.wrap = entry.wrap
		end
		if type(entry.charm) == "string" then
			clean.charm = entry.charm
		end
		if type(entry.finisher) == "string" then
			clean.finisher = entry.finisher
		end
		if type(entry.wrapInverted) == "boolean" then
			clean.wrapInverted = entry.wrapInverted
		end
		if next(clean :: any) ~= nil then
			rebuilt[weaponName] = clean
		end
	end
	_overlay = rebuilt
	_syncFromPlayerData()
	_fireWeaponInventoryChanged()
	_refreshLoadoutWeapon(nil, nil)
end)

function InventoryChanger.new(): typeof(InventoryChanger)
	task.spawn(function()
		setthreadidentity(8)

		playerDataAccess.waitUntilLoaded()

		local controller = playerDataAccess.getController()
		if controller and not _hookInstalled then
			inventoryEquip.installHook(controller, _getOverlay)
			_hookInstalled = true
		end

		local replicatedClass = cosmeticLibraryAccess.getReplicatedClass()
		if replicatedClass then
			inventoryEquip.installEntityHook(replicatedClass, _getOverlay, cosmeticLibraryAccess.viewModelExists)
		end

		deployableSkins.install()

		_syncFromPlayerData()

		_track(playerDataAccess.subscribe("WeaponInventory", _syncFromPlayerData))

		local weapons = cosmeticLibraryAccess.getWeapons()
		if peek(rivalsInventoryState.selectedWeapon) == nil and weapons[1] then
			rivalsInventoryState.selectedWeapon(weapons[1])
		end

		setthreadidentity(8)

		stateConverter.RegisterExtension("rivalsInventory", _saveConfig, _loadConfig, _prepareConfig)
		customWrapController.new()
		customCharmController.new()
		finisherSpoofer.new()
		cosmeticUnlock.new()
		cosmeticUnlock.setEquipHandler(InventoryChanger.HandleNativeEquip)
		rivalsInventoryState.ready(true)
	end)

	return InventoryChanger
end

function InventoryChanger.Destroy(): ()
	rivalsInventoryState.ready(false)
	customWrapController.Destroy()
	customCharmController.Destroy()
	finisherSpoofer.Destroy()
	cosmeticUnlock.Destroy()
	stateConverter.UnregisterExtension("rivalsInventory")

	if _hookInstalled then
		inventoryEquip.uninstallHook()
		_hookInstalled = false
	end
	inventoryEquip.uninstallEntityHook()
	inventoryEquip.clearInjectedChildren()
	deployableSkins.uninstall()

	for _, disconnect in next, _disconnects do
		disconnect()
	end
	_disconnects = {}

	_overlay = {}
	_fireWeaponInventoryChanged()
	_refreshLoadoutWeapon(nil, nil)

	rivalsInventoryState.weaponInventory({})
	rivalsInventoryState.selectedWeapon(nil)
end

export type InventoryChanger = typeof(InventoryChanger)
return InventoryChanger
