local Charm = require("@pkg/Charm")

local ModuleController = require("@game/ar2/module/ModuleController")
local clientState = require("@game/ar2/client/clientState")
local ar2InventoryState = require("@game/ar2/feature/inventory/ar2InventoryState")
local skinLibrary = require("@game/ar2/feature/inventory/skinLibrary")
local stateConverter = require("@src/feature/config/module/stateConverter")

local sub = Charm.subscribe

local InventoryChanger = {}

-- weaponName -> skinId chosen by the user
local _overlay: { [string]: string? } = {}
-- itemId -> { item, orig } so we can restore the gun's real skin
local _painted: { [any]: { item: any, orig: any } } = {}

local _gunBuilder: any = nil
local _charConn: (() -> ())? = nil
local _conns: { any } = {}
local _bindToken: any = nil
local _applying = false
local _started = false

local BIND_TRIES = 10

local function getCharacter(): any
	local module = ModuleController.GetModule("LocalPlayer")
	local getter = module and module.module and module.module.get
	local player = getter and getter()
	return player and player.Character or nil
end

local function resolveGunBuilder(): any
	if _gunBuilder == nil then
		_gunBuilder = ModuleController.FrameworkRequire("Libraries", "GunBuilder") or false
	end
	return _gunBuilder or nil
end

local function forEachFirearm(inventory: any, fn: (any) -> ()): ()
	for _, container in next, inventory.Containers do
		if container.IsCarried then
			for _, item in next, container.Occupants do
				if item.Type == "Firearm" then
					fn(item)
				end
			end
		end
	end
	local equipment = inventory.Equipment
	if type(equipment) == "table" then
		for _, entry in next, equipment do
			if type(entry) == "table" and entry.Type == "Firearm" and entry.Id then
				fn(entry)
			end
		end
	end
end

local function refreshEquipped(character: any): ()
	local item = character.EquippedItem
	if not item then
		return
	end
	local gunBuilder = resolveGunBuilder()
	local animator = character.Animator
	if not gunBuilder or not animator then
		return
	end
	local serialized = gunBuilder:Serialize(item)
	if type(serialized) ~= "table" then
		return
	end
	serialized.SkinId = item.SkinId or ""
	animator:SetState("EquippedItem", serialized)
end

local function applyOverlay(): ()
	if _applying then
		return
	end
	_applying = true

	local character = getCharacter()
	local inventory = character and character.Inventory
	if not inventory then
		_applying = false
		return
	end

	local equipped = character.EquippedItem
	local equippedChanged = false
	local seen: { [any]: boolean } = {}

	forEachFirearm(inventory, function(item: any): ()
		seen[item.Id] = true
		local desired = _overlay[item.Name]
		if desired ~= nil then
			if _painted[item.Id] == nil then
				_painted[item.Id] = { item = item, orig = item.SkinId }
			end
			if item.SkinId ~= desired then
				item.SkinId = desired
				if equipped and equipped.Id == item.Id then
					equippedChanged = true
				end
			end
		else
			local rec = _painted[item.Id]
			if rec then
				if item.SkinId ~= rec.orig then
					item.SkinId = rec.orig
					if equipped and equipped.Id == item.Id then
						equippedChanged = true
					end
				end
				_painted[item.Id] = nil
			end
		end
	end)

	for id in next, _painted do
		if not seen[id] then
			_painted[id] = nil
		end
	end

	_applying = false

	if equippedChanged then
		refreshEquipped(character)
	end
end

local function syncState(): ()
	local out: { [string]: ar2InventoryState.WeaponEquipped } = {}
	for weaponName, skin in next, _overlay do
		out[weaponName] = { skin = skin }
	end
	ar2InventoryState.weaponInventory(out)
end

local function unbind(): ()
	_bindToken = nil
	for _, conn in next, _conns do
		conn:Disconnect()
	end
	_conns = {}
end

local function bind(): ()
	unbind()

	local token = {}
	_bindToken = token

	local function attempt(tries: number): ()
		if _bindToken ~= token then
			return
		end

		local character = getCharacter()
		local inventory = character and character.Inventory
		local changed = inventory and inventory.InventoryChanged
		if type(changed) ~= "table" or type(changed.Connect) ~= "function" then
			if tries > 0 then
				task.delay(0.5, function(): ()
					attempt(tries - 1)
				end)
			end
			return
		end

		_conns[#_conns + 1] = changed:Connect(function(): ()
			applyOverlay()
		end)
		if type(inventory.ContainerAdded) == "table" and type(inventory.ContainerAdded.Connect) == "function" then
			_conns[#_conns + 1] = inventory.ContainerAdded:Connect(function(): ()
				applyOverlay()
			end)
		end
		applyOverlay()
	end

	attempt(BIND_TRIES)
end

local function restoreAll(): ()
	for _, rec in next, _painted do
		if rec.item and rec.item.SkinId ~= rec.orig then
			rec.item.SkinId = rec.orig
		end
	end
	_painted = {}
	local character = getCharacter()
	if character then
		refreshEquipped(character)
	end
end

function InventoryChanger.Equip(weaponName: string, skinName: string?): boolean
	if type(weaponName) ~= "string" then
		return false
	end
	_overlay[weaponName] = skinName
	applyOverlay()
	syncState()
	return true
end

function InventoryChanger.Unequip(weaponName: string): boolean
	return InventoryChanger.Equip(weaponName, nil)
end

function InventoryChanger.ApplyToAll(skinName: string?): boolean
	for _, weaponName in next, skinLibrary.getWeapons() do
		_overlay[weaponName] = skinName
	end
	applyOverlay()
	syncState()
	return true
end

function InventoryChanger.UnapplyFromAll(skinName: string): boolean
	if type(skinName) ~= "string" then
		return false
	end
	for weaponName, skin in next, _overlay do
		if skin == skinName then
			_overlay[weaponName] = nil
		end
	end
	applyOverlay()
	syncState()
	return true
end

function InventoryChanger.ClearAll(): ()
	_overlay = {}
	restoreAll()
	syncState()
end

local _saveConfig = LPH_NO_VIRTUALIZE(function(): { [string]: string }
	local out: { [string]: string } = {}
	for weaponName, skin in next, _overlay do
		if type(weaponName) == "string" and type(skin) == "string" then
			out[weaponName] = skin
		end
	end
	return out
end)

local _prepareConfig = LPH_NO_VIRTUALIZE(function(_data: any): ()
	_overlay = {}
	restoreAll()
	syncState()
end)

local _loadConfig = LPH_NO_VIRTUALIZE(function(data: any): ()
	if type(data) ~= "table" then
		return
	end
	local rebuilt: { [string]: string } = {}
	for weaponName, skin in next, data do
		if type(weaponName) == "string" and type(skin) == "string" then
			rebuilt[weaponName] = skin
		end
	end
	_overlay = rebuilt
	applyOverlay()
	syncState()
end)

function InventoryChanger.new(): typeof(InventoryChanger)
	if _started then
		return InventoryChanger
	end
	_started = true

	_charConn = sub(clientState.character, function(model: Model?): ()
		if model then
			task.defer(bind)
		else
			unbind()
		end
	end)

	bind()

	local weapons = skinLibrary.getWeapons()
	if Charm.peek(ar2InventoryState.selectedWeapon) == nil and weapons[1] then
		ar2InventoryState.selectedWeapon(weapons[1])
	end

	stateConverter.RegisterExtension("ar2Inventory", _saveConfig, _loadConfig, _prepareConfig)
	syncState()
	ar2InventoryState.ready(true)

	return InventoryChanger
end

function InventoryChanger.Destroy(): ()
	ar2InventoryState.ready(false)
	stateConverter.UnregisterExtension("ar2Inventory")

	if _charConn then
		_charConn()
		_charConn = nil
	end
	unbind()
	restoreAll()

	_overlay = {}
	ar2InventoryState.weaponInventory({})
	ar2InventoryState.selectedWeapon(nil)
	_started = false
end

export type InventoryChanger = typeof(InventoryChanger)
return InventoryChanger
