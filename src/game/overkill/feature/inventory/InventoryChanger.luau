local Charm = require("@pkg/Charm")
local hook = require("@share/hook")

local Players = cloneref(game:GetService("Players")) :: Players
local LocalPlayer = Players.LocalPlayer

local ModuleController = require("@game/overkill/module/ModuleController")
local NetworkController = require("@game/overkill/network/NetworkController")
local ClientState = require("@game/overkill/client/clientState")
local overkillInventoryState = require("@game/overkill/feature/inventory/overkillInventoryState")
local cosmeticCatalog = require("@game/overkill/feature/inventory/cosmeticCatalog")
local stateConverter = require("@src/feature/config/module/stateConverter")

local peek = Charm.peek

local InventoryChanger = {}

type Overlay = {
	skin: string?,
	wrap: string?,
	charm: string?,
	finisher: string?,
	killEffect: string?,
}

local TYPE_FIELD = overkillInventoryState.TYPE_FIELD

local COSMETIC_FIELDS = { "wrap", "charm", "finisher", "killEffect" }
local COSMETIC_TYPES = { "Wrap", "Charm", "Finisher", "KillEffect" }

local _overlay: { [string]: Overlay } = {}
local _origItems: { [string]: { [string]: any } } = {}

local _viewModel: any = nil
local _hotbar: any = nil
local _clientModule: any = nil
local _dataHandler: any = nil
local _dataAsync: any = nil

local _vmNewTarget: any = nil
local _origVmNew: any = nil
local _paintTarget: any = nil
local _origPaint: any = nil
local _updateTarget: any = nil
local _origUpdate: any = nil
local _unlockSubs: { () -> () } = {}
local _applyStateTargets: { any } = {}
local _packetHooked = false

local _started = false

local function isSkinUnlocked(weaponId: string, skinId: string): boolean
	local map = peek(overkillInventoryState.unlockedSkins)
	local weapon = map[weaponId]
	return weapon ~= nil and weapon[skinId] == true
end

local function isCosmeticUnlocked(typeName: string, name: string): boolean
	local map = peek(overkillInventoryState.unlockedCosmetics)
	local set = map[typeName]
	return set ~= nil and set[name] == true
end

local function isFakeUnlocked(typeName: string, weaponId: any, cosmeticId: any): boolean
	if type(cosmeticId) ~= "string" then
		return false
	end
	if typeName == "Skin" then
		return type(weaponId) == "string" and isSkinUnlocked(weaponId, cosmeticId)
	end
	return isCosmeticUnlocked(typeName, cosmeticId)
end

local function getDataAsync(): any?
	if type(_dataAsync) == "table" then
		return _dataAsync
	end
	local dh = _dataHandler
	if dh == nil then
		dh = ModuleController.GetModule("dataHandler") or false
		_dataHandler = dh
	end
	if not dh or type(dh.GetDataAsync) ~= "function" then
		return nil
	end
	setthreadidentity(2)
	local data = dh.GetDataAsync(dh)
	setthreadidentity(8)
	if type(data) == "table" then
		_dataAsync = data
		return data
	end
	return nil
end

local OWNED_ENTRY = { serial = 0 }
local _injections: { { tbl: any, key: string } } = {}

local function ensureTable(parent: any, key: string): any
	local existing = parent[key]
	if type(existing) ~= "table" then
		existing = {}
		parent[key] = existing
	end
	return existing
end

local function inject(tbl: any, key: string): ()
	if tbl[key] == nil then
		tbl[key] = OWNED_ENTRY
		_injections[#_injections + 1] = { tbl = tbl, key = key }
	end
end

local function clearInjections(): ()
	for i = #_injections, 1, -1 do
		local entry = _injections[i]
		if entry.tbl[entry.key] == OWNED_ENTRY then
			entry.tbl[entry.key] = nil
		end
		_injections[i] = nil
	end
end

local GLOBAL_COSMETIC_KEYS: { [string]: string } = {
	Wrap = "GlobalWraps",
	Charm = "GlobalCharms",
	Finisher = "GlobalFinishers",
	KillEffect = "GlobalFinishers",
}

local function syncFakeOwnership(): ()
	local data = getDataAsync()
	if not data then
		return
	end
	clearInjections()

	for weaponId, set in next, peek(overkillInventoryState.unlockedSkins) do
		local nID = cosmeticCatalog.getNID(weaponId)
		if nID and type(set) == "table" then
			local weaponSkins = ensureTable(ensureTable(data, "Skins"), nID)
			for skinId in next, set do
				if type(skinId) == "string" then
					inject(weaponSkins, skinId)
				end
			end
		end
	end

	local cosmetics = peek(overkillInventoryState.unlockedCosmetics)
	for typeName, globalKey in next, GLOBAL_COSMETIC_KEYS do
		local set = cosmetics[typeName]
		if type(set) == "table" then
			local globalTable = ensureTable(data, globalKey)
			for id in next, set do
				if type(id) == "string" then
					inject(globalTable, id)
				end
			end
		end
	end
end

local function reconcileCosmetics(): ()
	local data = getDataAsync()
	if not data then
		return
	end
	local items = data.Items
	if type(items) ~= "table" then
		return
	end

	local desired: { [string]: Overlay } = {}
	for weaponId, ov in next, _overlay do
		if ov.wrap == nil and ov.charm == nil and ov.finisher == nil and ov.killEffect == nil then
			continue
		end
		local nID = cosmeticCatalog.getNID(weaponId)
		if nID then
			desired[nID] = ov
		end
	end

	for nID, orig in next, _origItems do
		if desired[nID] == nil then
			local entry = items[nID]
			if type(entry) == "table" then
				for _, field in next, COSMETIC_FIELDS do
					entry[field] = orig[field]
				end
			end
			_origItems[nID] = nil
		end
	end

	for nID, ov in next, desired do
		local entry = items[nID]
		if type(entry) ~= "table" then
			continue
		end
		local orig = _origItems[nID]
		if not orig then
			orig = {
				wrap = entry.wrap,
				charm = entry.charm,
				finisher = entry.finisher,
				killEffect = entry.killEffect,
			}
			_origItems[nID] = orig
		end
		for _, field in next, COSMETIC_FIELDS do
			local override = (ov :: any)[field]
			if override ~= nil then
				entry[field] = override
			else
				entry[field] = orig[field]
			end
		end
	end
end

local function simState(): any
	local clientModule = _clientModule
	local localChickynoid = clientModule and clientModule.localChickynoid
	local simulation = localChickynoid and localChickynoid.simulation
	local state = simulation and simulation.state
	if type(state) == "table" then
		return state
	end
	return nil
end

local function forceRebuild(): ()
	local viewModel = _viewModel
	local character = peek(ClientState.character)
	if not viewModel or not character then
		return
	end

	local active = viewModel.activeVMCs
	local map = active and active[character]
	if type(map) ~= "table" then
		return
	end

	local list = {}
	for _, vmc in next, map do
		if type(vmc) == "table" then
			list[#list + 1] = vmc
		end
	end

	setthreadidentity(2)
	for _, vmc in next, list do
		if not vmc.destroying then
			viewModel.destroy(vmc)
		end
	end
	setthreadidentity(8)
end

local function refreshHud(): ()
	local hotbar = _hotbar
	local state = simState()
	if not hotbar or not _origPaint or not state then
		return
	end

	local paint = hotbar.paintHotbarSlot
	local update = hotbar.updateWeaponsUI
	local equippedSlot = state.equippedSlot

	setthreadidentity(2)
	for slot = 1, 4 do
		local weaponId = state["slot" .. slot .. "_weaponID"]
		if type(weaponId) == "string" and weaponId ~= "" then
			local ammo = {
				magCount = state["slot" .. slot .. "_magCount"] or 0,
				reserveCount = state["slot" .. slot .. "_reserveCount"] or 0,
			}
			local skin = state["slot" .. slot .. "_skin"]
			paint(weaponId, ammo, skin)
			if slot == equippedSlot and update then
				update(weaponId, ammo, skin)
			end
		end
	end
	setthreadidentity(8)
end

local function apply(): ()
	reconcileCosmetics()
	forceRebuild()
	refreshHud()
end

local function installViewModelHook(): ()
	if _origVmNew then
		return
	end
	local viewModel = ModuleController.GetModule("viewModel")
	_viewModel = viewModel
	if not viewModel then
		return
	end

	local target = viewModel.new
	_vmNewTarget = target
	_origVmNew = hook.add(target, function(...)
		local count = select("#", ...)
		local weaponId, skin, character = ...
		local ov = _overlay[weaponId]
		local override = ov and ov.skin

		if
			override ~= nil
			and override ~= skin
			and character == peek(ClientState.character)
			and cosmeticCatalog.skinExists(weaponId, override)
		then
			local args = table.pack(...)
			args[2] = override
			local vmc = _origVmNew(table.unpack(args, 1, count))
			if type(vmc) == "table" then
				vmc.skin = skin
			end
			return vmc
		end

		return _origVmNew(...)
	end)
end

local function installHudHooks(): ()
	if _origPaint then
		return
	end
	local hotbar = ModuleController.GetModule("hotbarHud")
	_hotbar = hotbar
	_clientModule = ModuleController.GetModule("clientModule")
	if not hotbar then
		return
	end

	if type(hotbar.paintHotbarSlot) == "function" then
		_paintTarget = hotbar.paintHotbarSlot
		_origPaint = hook.add(hotbar.paintHotbarSlot, function(weaponId, ammo, skinId)
			local ov = _overlay[weaponId]
			local override = ov and ov.skin
			if override ~= nil and override ~= skinId and cosmeticCatalog.skinExists(weaponId, override) then
				return _origPaint(weaponId, ammo, override)
			end
			return _origPaint(weaponId, ammo, skinId)
		end)
	end

	if type(hotbar.updateWeaponsUI) == "function" then
		_updateTarget = hotbar.updateWeaponsUI
		_origUpdate = hook.add(hotbar.updateWeaponsUI, function(weaponId, ammo, skinId)
			local ov = _overlay[weaponId]
			local override = ov and ov.skin
			if override ~= nil and override ~= skinId and cosmeticCatalog.skinExists(weaponId, override) then
				return _origUpdate(weaponId, ammo, override)
			end
			return _origUpdate(weaponId, ammo, skinId)
		end)
	end
end

local function redirectPacket(typeName: string, weaponId: any, cosmeticId: any): (boolean?, any?)
	if type(weaponId) ~= "string" then
		return true
	end
	if cosmeticId == nil or cosmeticId == "none" or cosmeticId == "random" then
		task.defer(function()
			InventoryChanger.Equip(weaponId, typeName, nil)
		end)
		return true
	end
	if not isFakeUnlocked(typeName, weaponId, cosmeticId) then
		task.defer(function()
			InventoryChanger.Equip(weaponId, typeName, nil)
		end)
		return true
	end
	task.defer(function()
		InventoryChanger.Equip(weaponId, typeName, cosmeticId)
	end)
	return false
end

local function installUnlockHooks(): ()
	if _packetHooked then
		return
	end
	_packetHooked = true

	syncFakeOwnership()
	_unlockSubs = {
		Charm.subscribe(overkillInventoryState.unlockedSkins, syncFakeOwnership),
		Charm.subscribe(overkillInventoryState.unlockedCosmetics, syncFakeOwnership),
	}

	NetworkController.HookPacket("armory_change_skin", function(weaponId, skinId)
		return redirectPacket("Skin", weaponId, skinId)
	end)
	NetworkController.HookPacket("armory_change_wrap", function(weaponId, wrapId)
		return redirectPacket("Wrap", weaponId, wrapId)
	end)
	NetworkController.HookPacket("armory_change_charm", function(weaponId, charmId)
		return redirectPacket("Charm", weaponId, charmId)
	end)
	NetworkController.HookPacket("armory_change_finisher", function(weaponId, finisherId)
		return redirectPacket("Finisher", weaponId, finisherId)
	end)
	NetworkController.HookPacket("armory_change_killeffect", function(weaponId, killEffectId)
		return redirectPacket("KillEffect", weaponId, killEffectId)
	end)
end

local function overrideDeadValue(value: any): ()
	if type(value) ~= "table" or value.lastActor ~= LocalPlayer.Name then
		return
	end
	local weaponId = value.weaponID
	if type(weaponId) ~= "string" then
		return
	end
	local ov = _overlay[weaponId]
	if not ov then
		return
	end
	if ov.finisher ~= nil then
		value.finisherID = ov.finisher
	end
	if ov.killEffect ~= nil then
		value.killEffectID = ov.killEffect
	end
end

local function installFinisherHook(): ()
	if #_applyStateTargets > 0 then
		return
	end
	local targets = filtergc("function", { Constants = { "applyReplicatedState: no character" } }, false)
	if type(targets) ~= "table" then
		return
	end
	for _, target in next, targets do
		if type(target) ~= "function" then
			continue
		end
		local orig
		orig = hook.add(
			target,
			LPH_NO_VIRTUALIZE(function(character, id, isValueUpdate, isRemoveUpdate, ignoreOwner, stateName, value, ...)
				if stateName == "Dead" then
					overrideDeadValue(value)
				end
				return orig(character, id, isValueUpdate, isRemoveUpdate, ignoreOwner, stateName, value, ...)
			end)
		)
		_applyStateTargets[#_applyStateTargets + 1] = target
	end
end

local function syncState(): ()
	local out: { [string]: overkillInventoryState.WeaponEquipped } = {}
	for weaponId, ov in next, _overlay do
		out[weaponId] = {
			skin = ov.skin,
			wrap = ov.wrap,
			charm = ov.charm,
			finisher = ov.finisher,
			killEffect = ov.killEffect,
		}
	end
	overkillInventoryState.weaponInventory(out)
end

function InventoryChanger.Equip(weaponId: string, cosmeticType: string, name: string?): boolean
	if type(weaponId) ~= "string" or type(cosmeticType) ~= "string" then
		return false
	end
	local field = TYPE_FIELD[cosmeticType]
	if not field then
		return false
	end

	local ov = _overlay[weaponId]
	if not ov then
		ov = {}
		_overlay[weaponId] = ov
	end

	if name == nil or name == "" or name == "base" or name == "none" then
		(ov :: any)[field] = nil
	else
		(ov :: any)[field] = name
	end

	if ov.skin == nil and ov.wrap == nil and ov.charm == nil and ov.finisher == nil and ov.killEffect == nil then
		_overlay[weaponId] = nil
	end

	apply()
	syncState()
	return true
end

function InventoryChanger.Unequip(weaponId: string, cosmeticType: string): boolean
	return InventoryChanger.Equip(weaponId, cosmeticType, nil)
end

function InventoryChanger.ApplyToAll(cosmeticType: string, name: string?): boolean
	if type(cosmeticType) ~= "string" or not TYPE_FIELD[cosmeticType] then
		return false
	end
	for _, weaponId in next, cosmeticCatalog.getWeapons() do
		local field = TYPE_FIELD[cosmeticType]
		local ov = _overlay[weaponId]
		if not ov then
			ov = {}
			_overlay[weaponId] = ov
		end
		if name == nil or name == "" or name == "base" or name == "none" then
			(ov :: any)[field] = nil
		else
			(ov :: any)[field] = name
		end
		if ov.skin == nil and ov.wrap == nil and ov.charm == nil and ov.finisher == nil and ov.killEffect == nil then
			_overlay[weaponId] = nil
		end
	end
	apply()
	syncState()
	return true
end

function InventoryChanger.UnapplyFromAll(cosmeticType: string, name: string): boolean
	if type(cosmeticType) ~= "string" or type(name) ~= "string" or not TYPE_FIELD[cosmeticType] then
		return false
	end
	local field = TYPE_FIELD[cosmeticType]
	for weaponId, ov in next, _overlay do
		if (ov :: any)[field] == name then
			(ov :: any)[field] = nil
			if
				ov.skin == nil
				and ov.wrap == nil
				and ov.charm == nil
				and ov.finisher == nil
				and ov.killEffect == nil
			then
				_overlay[weaponId] = nil
			end
		end
	end
	apply()
	syncState()
	return true
end

function InventoryChanger.GetEquipped(weaponId: string, cosmeticType: string): string?
	local field = TYPE_FIELD[cosmeticType]
	local ov = _overlay[weaponId]
	if not field or not ov then
		return nil
	end
	return (ov :: any)[field]
end

function InventoryChanger.ClearAll(): ()
	table.clear(_overlay)
	apply()
	syncState()
end

function InventoryChanger.IsUnlocked(cosmeticType: string, weaponId: string?, name: string): boolean
	if cosmeticType == "Skin" then
		return weaponId ~= nil and isSkinUnlocked(weaponId, name)
	end
	return isCosmeticUnlocked(cosmeticType, name)
end

function InventoryChanger.Unlock(cosmeticType: string, weaponId: string?, name: string): ()
	if type(name) ~= "string" or name == "base" or name == "none" or name == "random" then
		return
	end
	if InventoryChanger.IsUnlocked(cosmeticType, weaponId, name) then
		return
	end
	if cosmeticType == "Skin" then
		if not weaponId then
			return
		end
		local map = table.clone(peek(overkillInventoryState.unlockedSkins))
		local weapon = map[weaponId]
		weapon = weapon and table.clone(weapon) or {}
		weapon[name] = true
		map[weaponId] = weapon
		overkillInventoryState.unlockedSkins(map)
	else
		if not TYPE_FIELD[cosmeticType] then
			return
		end
		local map = table.clone(peek(overkillInventoryState.unlockedCosmetics))
		local set = map[cosmeticType]
		set = set and table.clone(set) or {}
		set[name] = true
		map[cosmeticType] = set
		overkillInventoryState.unlockedCosmetics(map)
	end
end

function InventoryChanger.Lock(cosmeticType: string, weaponId: string?, name: string): ()
	if not InventoryChanger.IsUnlocked(cosmeticType, weaponId, name) then
		return
	end
	if cosmeticType == "Skin" then
		if not weaponId then
			return
		end
		local current = peek(overkillInventoryState.unlockedSkins)
		local weapon = current[weaponId]
		local map = table.clone(current)
		local copy = table.clone(weapon)
		copy[name] = nil
		if next(copy) == nil then
			map[weaponId] = nil
		else
			map[weaponId] = copy
		end
		overkillInventoryState.unlockedSkins(map)
	else
		local current = peek(overkillInventoryState.unlockedCosmetics)
		local set = current[cosmeticType]
		local map = table.clone(current)
		local copy = table.clone(set)
		copy[name] = nil
		if next(copy) == nil then
			map[cosmeticType] = nil
		else
			map[cosmeticType] = copy
		end
		overkillInventoryState.unlockedCosmetics(map)
	end
end

function InventoryChanger.ToggleUnlock(cosmeticType: string, weaponId: string?, name: string): ()
	if InventoryChanger.IsUnlocked(cosmeticType, weaponId, name) then
		InventoryChanger.Lock(cosmeticType, weaponId, name)
	else
		InventoryChanger.Unlock(cosmeticType, weaponId, name)
	end
end

function InventoryChanger.UnlockAll(): ()
	local skinMap: { [string]: { [string]: boolean } } = {}
	for _, weaponId in next, cosmeticCatalog.getWeapons() do
		local set: { [string]: boolean } = {}
		for _, entry in next, cosmeticCatalog.listByType("Skin", weaponId) do
			if entry.name ~= "base" then
				set[entry.name] = true
			end
		end
		if next(set) ~= nil then
			skinMap[weaponId] = set
		end
	end
	overkillInventoryState.unlockedSkins(skinMap)

	local cosMap: { [string]: { [string]: boolean } } = {}
	for _, typeName in next, COSMETIC_TYPES do
		local set: { [string]: boolean } = {}
		for _, entry in next, cosmeticCatalog.listByType(typeName, nil) do
			set[entry.name] = true
		end
		if next(set) ~= nil then
			cosMap[typeName] = set
		end
	end
	overkillInventoryState.unlockedCosmetics(cosMap)
end

function InventoryChanger.LockAll(): ()
	if next(peek(overkillInventoryState.unlockedSkins)) ~= nil then
		overkillInventoryState.unlockedSkins({})
	end
	if next(peek(overkillInventoryState.unlockedCosmetics)) ~= nil then
		overkillInventoryState.unlockedCosmetics({})
	end
end

local _saveConfig = LPH_NO_VIRTUALIZE(function(): { [string]: any }
	local out: { [string]: any } = {}
	for weaponId, ov in next, _overlay do
		if type(weaponId) ~= "string" then
			continue
		end
		local serialized: { [string]: any } = {}
		if ov.skin ~= nil then
			serialized.skin = ov.skin
		end
		if ov.wrap ~= nil then
			serialized.wrap = ov.wrap
		end
		if ov.charm ~= nil then
			serialized.charm = ov.charm
		end
		if ov.finisher ~= nil then
			serialized.finisher = ov.finisher
		end
		if ov.killEffect ~= nil then
			serialized.killEffect = ov.killEffect
		end
		if next(serialized) ~= nil then
			out[weaponId] = serialized
		end
	end
	return out
end)

local _prepareConfig = LPH_NO_VIRTUALIZE(function(_data: any): ()
	table.clear(_overlay)
	apply()
	syncState()
end)

local _loadConfig = LPH_NO_VIRTUALIZE(function(data: any): ()
	if type(data) ~= "table" then
		return
	end
	table.clear(_overlay)
	for weaponId, entry in next, data do
		if type(weaponId) ~= "string" or type(entry) ~= "table" then
			continue
		end
		local clean: Overlay = {}
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
		if type(entry.killEffect) == "string" then
			clean.killEffect = entry.killEffect
		end
		if next(clean :: any) ~= nil then
			_overlay[weaponId] = clean
		end
	end
	apply()
	syncState()
end)

local _saveUnlocks = LPH_NO_VIRTUALIZE(function(): { [string]: any }
	local skins: { [string]: { string } } = {}
	for weaponId, set in next, peek(overkillInventoryState.unlockedSkins) do
		if type(weaponId) == "string" and type(set) == "table" then
			local list: { string } = {}
			for skinId in next, set do
				if type(skinId) == "string" then
					list[#list + 1] = skinId
				end
			end
			if #list > 0 then
				skins[weaponId] = list
			end
		end
	end

	local cosmetics: { [string]: { string } } = {}
	for typeName, set in next, peek(overkillInventoryState.unlockedCosmetics) do
		if type(typeName) == "string" and type(set) == "table" then
			local list: { string } = {}
			for name in next, set do
				if type(name) == "string" then
					list[#list + 1] = name
				end
			end
			if #list > 0 then
				cosmetics[typeName] = list
			end
		end
	end

	return { skins = skins, cosmetics = cosmetics }
end)

local _loadUnlocks = LPH_NO_VIRTUALIZE(function(data: any): ()
	local skinMap: { [string]: { [string]: boolean } } = {}
	local cosMap: { [string]: { [string]: boolean } } = {}
	if type(data) == "table" then
		if type(data.skins) == "table" then
			for weaponId, list in next, data.skins do
				if type(weaponId) == "string" and type(list) == "table" then
					local set: { [string]: boolean } = {}
					for _, skinId in next, list do
						if type(skinId) == "string" then
							set[skinId] = true
						end
					end
					if next(set) ~= nil then
						skinMap[weaponId] = set
					end
				end
			end
		end
		if type(data.cosmetics) == "table" then
			for typeName, list in next, data.cosmetics do
				if type(typeName) == "string" and type(list) == "table" then
					local set: { [string]: boolean } = {}
					for _, name in next, list do
						if type(name) == "string" then
							set[name] = true
						end
					end
					if next(set) ~= nil then
						cosMap[typeName] = set
					end
				end
			end
		end
	end
	overkillInventoryState.unlockedSkins(skinMap)
	overkillInventoryState.unlockedCosmetics(cosMap)
end)

local _prepareUnlocks = LPH_NO_VIRTUALIZE(function(_data: any): ()
	overkillInventoryState.unlockedSkins({})
	overkillInventoryState.unlockedCosmetics({})
end)

function InventoryChanger.new(): typeof(InventoryChanger)
	if _started then
		return InventoryChanger
	end
	_started = true

	installViewModelHook()
	installHudHooks()
	installUnlockHooks()
	installFinisherHook()

	local weapons = cosmeticCatalog.getWeapons()
	if peek(overkillInventoryState.selectedWeapon) == nil and weapons[1] then
		overkillInventoryState.selectedWeapon(weapons[1])
	end

	stateConverter.RegisterExtension("overkillInventory", _saveConfig, _loadConfig, _prepareConfig)
	stateConverter.RegisterExtension("overkillUnlocks", _saveUnlocks, _loadUnlocks, _prepareUnlocks)
	syncState()
	overkillInventoryState.ready(true)

	return InventoryChanger
end

function InventoryChanger.Destroy(): ()
	overkillInventoryState.ready(false)
	stateConverter.UnregisterExtension("overkillInventory")
	stateConverter.UnregisterExtension("overkillUnlocks")

	table.clear(_overlay)
	apply()
	table.clear(_origItems)

	if _packetHooked then
		NetworkController.UnhookPacket("armory_change_skin")
		NetworkController.UnhookPacket("armory_change_wrap")
		NetworkController.UnhookPacket("armory_change_charm")
		NetworkController.UnhookPacket("armory_change_finisher")
		NetworkController.UnhookPacket("armory_change_killeffect")
		_packetHooked = false
	end
	for _, unsub in next, _unlockSubs do
		unsub()
	end
	table.clear(_unlockSubs)
	clearInjections()
	if _paintTarget then
		hook.restore(_paintTarget)
		_paintTarget = nil
	end
	if _updateTarget then
		hook.restore(_updateTarget)
		_updateTarget = nil
	end
	if _vmNewTarget then
		hook.restore(_vmNewTarget)
		_vmNewTarget = nil
	end
	for _, target in next, _applyStateTargets do
		hook.restore(target)
	end
	table.clear(_applyStateTargets)
	_origVmNew = nil
	_origPaint = nil
	_origUpdate = nil

	_viewModel = nil
	_hotbar = nil
	_clientModule = nil
	_dataHandler = nil
	_dataAsync = nil
	overkillInventoryState.weaponInventory({})
	overkillInventoryState.unlockedSkins({})
	overkillInventoryState.unlockedCosmetics({})
	overkillInventoryState.selectedWeapon(nil)
	_started = false
end

export type InventoryChanger = typeof(InventoryChanger)
return InventoryChanger
