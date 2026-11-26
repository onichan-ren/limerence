local Players = cloneref(game:GetService("Players")) :: Players
local HttpService = cloneref(game:GetService("HttpService")) :: HttpService

local Charm = require("@pkg/Charm")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local inventoryGameState = require("@game/bloxstrike/feature/inventory/inventoryGameState")
local inventoryDataAccess = require("@game/bloxstrike/feature/inventory/inventoryDataAccess")
local inventoryClassifier = require("@game/bloxstrike/feature/inventory/inventoryClassifier")
local fakeFactory = require("@game/bloxstrike/feature/inventory/fakeFactory")
local inventoryHooks = require("@game/bloxstrike/feature/inventory/inventoryHooks")
local stateConverter = require("@src/feature/config/module/stateConverter")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")

local peek = Charm.peek
local LocalPlayer = Players.LocalPlayer

local InventoryChanger = {}

local _inventoryModule: any = nil
local _charAddedConn: RBXScriptConnection? = nil

-- key = team .. "|" .. grantWeaponName (e.g. "Counter-Terrorists|CT Knife")
local _assignments: { [string]: inventoryHooks.AssignmentEntry } = {}

local function _getLoadout(): any?
	local pd = inventoryDataAccess.getPlayerData()
	return pd and pd.Loadout
end

local function _setGunSlot(team: string, category: string, slotIdx: number, id: string?): ()
	local loadout = _getLoadout()
	if not loadout then
		return
	end
	local tl = loadout[team]
	if not tl then
		return
	end
	if not tl.Loadout then
		tl.Loadout = {}
	end
	if not tl.Loadout[category] then
		tl.Loadout[category] = { Options = {} }
	end
	if not tl.Loadout[category].Options then
		tl.Loadout[category].Options = {}
	end
	tl.Loadout[category].Options[slotIdx] = id
end

local function _setSpecialSlot(team: string, path: string, id: string?): ()
	local loadout = _getLoadout()
	if not loadout then
		return
	end
	local tl = loadout[team]
	if not tl then
		return
	end
	if not tl.Equipped then
		tl.Equipped = {}
	end
	tl.Equipped[path] = id
end

local function _assignmentKey(team: string, grantWeaponName: string): string
	return team .. "|" .. grantWeaponName
end

local function _getGrantWeaponName(weaponName: string, team: string): string
	if inventoryClassifier.isMeleeName(weaponName) then
		return inventoryClassifier.KNIFE_BY_TEAM[team] or weaponName
	end
	if inventoryClassifier.isGloveName(weaponName) then
		return inventoryClassifier.GLOVE_BY_TEAM[team] or weaponName
	end
	return weaponName
end

local function _findGunSlot(team: string, category: string, weaponName: string): (number?, string?)
	local loadout = _getLoadout()
	if not loadout then
		return nil, nil
	end
	local tl = loadout[team]
	if not tl or not tl.Loadout then
		return nil, nil
	end
	local cat = tl.Loadout[category]
	if not cat or not cat.Options then
		return nil, nil
	end
	local inventory = inventoryDataAccess.getInventory()
	local idToName: { [string]: string } = {}
	for _, item in next, inventory do
		if type(item) == "table" and item._id and item.Name then
			idToName[item._id] = item.Name
		end
	end
	for slotIdx, slotId in next, cat.Options do
		if type(slotId) ~= "string" then
			continue
		end
		if idToName[slotId] == weaponName or slotId == weaponName .. "_Stock" then
			return slotIdx, slotId
		end
	end
	return nil, nil
end

local function _findSpecialOriginalId(team: string, specialPath: string): string?
	local loadout = _getLoadout()
	if not loadout then
		return nil
	end
	local tl = loadout[team]
	if not tl or not tl.Equipped then
		return nil
	end
	local current = tl.Equipped[specialPath]
	if type(current) == "string" and not fakeFactory.isFakeId(current) then
		return current
	end
	return nil
end

local function _fireLoadoutListeners(): ()
	inventoryDataAccess.fireListeners({ "Loadout" })
end

local function _getLoadoutObject(): any?
	local loadout: any = peek(loadoutState.loadout)
	if not loadout or loadout.IsDestroyed then
		return nil
	end
	return loadout
end

local function _findWeaponComponent(u27: any, weaponName: string): any?
	local inv = rawget(u27, "Inventory")
	if type(inv) ~= "table" then
		return nil
	end
	for _, slot in next, inv do
		if type(slot) ~= "table" then
			continue
		end
		local items = rawget(slot, "_items")
		if type(items) ~= "table" then
			continue
		end
		for _, comp in next, items do
			if type(comp) == "table" and comp.Name == weaponName then
				return comp
			end
		end
	end
	return nil
end

local function _reconstructViewmodel(
	comp: any,
	weaponName: string,
	skin: string,
	float: number,
	statTrack: any,
	nameTag: any,
	charm: any,
	stickers: any
): ()
	local vm = rawget(comp, "Viewmodel")
	if not vm or vm.IsDestroyed then
		return
	end

	comp.Name = weaponName
	comp.Skin = skin
	comp.Float = float
	comp.StatTrack = statTrack
	comp.NameTag = nameTag
	comp.Charm = charm
	comp.Stickers = stickers or {}

	vm.Weapon = weaponName
	vm.CameraModelWeapon = weaponName
	vm.Skin = skin
	vm.Float = float
	vm.StatTrack = statTrack
	vm.NameTag = nameTag
	vm.Charm = charm
	vm.Stickers = stickers or {}

	local character = LocalPlayer and LocalPlayer.Character
	if not character then
		return
	end

	setthreadidentity(2)
	vm.construct(vm, character, comp)
	setthreadidentity(8)
end

local function _applyViewmodelSkin(comp: any, fake: inventoryGameState.FakeItem): ()
	_reconstructViewmodel(
		comp,
		fake.Name,
		fake.Skin or "Stock",
		type(fake.Float) == "number" and fake.Float or 0,
		fake.StatTrack,
		fake.NameTag,
		fake.Charm,
		fake.Stickers or {}
	)
end

local function _revertViewmodelSkin(
	comp: any,
	originalWeaponName: string,
	originalSkin: string,
	originalFloat: number
): ()
	_reconstructViewmodel(comp, originalWeaponName, originalSkin, originalFloat, false, false, false, {})
end

local _savedGloveAttr: any = nil
local _gloveAttrOverridden = false
local _activeGloveFake: inventoryGameState.FakeItem? = nil

local function _reconstructAllWeapons(): ()
	local u27 = _getLoadoutObject()
	if not u27 then
		return
	end
	local inv = rawget(u27, "Inventory")
	if type(inv) == "table" then
		for _, slot in next, inv do
			if type(slot) ~= "table" then
				continue
			end
			local items = rawget(slot, "_items")
			if type(items) ~= "table" then
				continue
			end
			for _, comp in next, items do
				if type(comp) ~= "table" or not rawget(comp, "Viewmodel") then
					continue
				end
				_reconstructViewmodel(
					comp,
					comp.Name,
					comp.Skin,
					comp.Float,
					comp.StatTrack,
					comp.NameTag,
					comp.Charm,
					comp.Stickers
				)
			end
		end
	end
	local current = u27.CurrentEquipped
	if type(current) == "table" and _inventoryModule then
		_inventoryModule.OnInventoryItemEquipped:Fire(current.Slot, current)
	end
end

local function _applyGloveToViewmodel(fake: inventoryGameState.FakeItem): ()
	_activeGloveFake = fake
	local character = LocalPlayer and LocalPlayer.Character
	if not character then
		return
	end
	if not _gloveAttrOverridden then
		_savedGloveAttr = character:GetAttribute("EquippedGloves")
		_gloveAttrOverridden = true
	end
	local payload = HttpService:JSONEncode({
		Name = fake.Name,
		Skin = type(fake.Skin) == "string" and fake.Skin or "Stock",
		Float = type(fake.Float) == "number" and fake.Float or 0,
	})
	character:SetAttribute("EquippedGloves", payload)
	task.defer(_reconstructAllWeapons)
end

local function _revertGloveFromViewmodel(): ()
	local character = LocalPlayer and LocalPlayer.Character
	if character then
		character:SetAttribute("EquippedGloves", _savedGloveAttr)
	end
	_savedGloveAttr = nil
	_gloveAttrOverridden = false
	_activeGloveFake = nil
	task.defer(_reconstructAllWeapons)
end

local function _updateLiveViewmodelForFake(fake: inventoryGameState.FakeItem): ()
	if inventoryClassifier.isGloveName(fake.Name) then
		_applyGloveToViewmodel(fake)
		return
	end
	local u27 = _getLoadoutObject()
	if not u27 then
		return
	end
	local team = LocalPlayer and LocalPlayer:GetAttribute("Team") :: string?
	local grantWeaponName = team and _getGrantWeaponName(fake.Name, team) or fake.Name
	task.defer(function()
		local comp = _findWeaponComponent(u27, fake.Name)
		if not comp and fake.Name ~= grantWeaponName then
			comp = _findWeaponComponent(u27, grantWeaponName)
		end
		if not comp then
			return
		end
		_applyViewmodelSkin(comp, fake)
		local loadout: any = peek(loadoutState.loadout)
		if loadout and loadout.CurrentEquipped == comp and _inventoryModule then
			_inventoryModule.OnInventoryItemEquipped:Fire(comp.Slot, comp)
		end
	end)
end

local function _revertLiveViewmodel(fake: inventoryGameState.FakeItem, originalId: string?): ()
	if inventoryClassifier.isGloveName(fake.Name) then
		_revertGloveFromViewmodel()
		return
	end
	local u27 = _getLoadoutObject()
	if not u27 then
		return
	end
	local team = LocalPlayer and LocalPlayer:GetAttribute("Team") :: string?
	local grantWeaponName = team and _getGrantWeaponName(fake.Name, team) or fake.Name
	local comp = _findWeaponComponent(u27, fake.Name)
	if not comp and fake.Name ~= grantWeaponName then
		comp = _findWeaponComponent(u27, grantWeaponName)
	end
	if not comp then
		return
	end
	local originalSkin = "Stock"
	local originalFloat = 0
	if originalId then
		local realItem = inventoryDataAccess.findInventoryItem(originalId)
		if realItem then
			originalSkin = type(realItem.Skin) == "string" and realItem.Skin or "Stock"
			originalFloat = type(realItem.Float) == "number" and realItem.Float or 0
		end
	end
	task.defer(function()
		_revertViewmodelSkin(comp, grantWeaponName, originalSkin, originalFloat)
		local loadout: any = peek(loadoutState.loadout)
		if loadout and loadout.CurrentEquipped == comp and _inventoryModule then
			_inventoryModule.OnInventoryItemEquipped:Fire(comp.Slot, comp)
		end
	end)
end

local function _equipFakeForTeam(fake: inventoryGameState.FakeItem, team: string): ()
	local specialPath = inventoryClassifier.getSpecialPath(fake.Name)
	local category = inventoryClassifier.getCategory(fake.Name)
	local grantWeaponName = _getGrantWeaponName(fake.Name, team)
	local key = _assignmentKey(team, grantWeaponName)

	if specialPath then
		local originalId = _findSpecialOriginalId(team, specialPath)
		_assignments[key] = {
			fakeId = fake._id,
			originalId = originalId,
			isSpecial = true,
			specialPath = specialPath,
			grantWeaponName = grantWeaponName,
		}
		_setSpecialSlot(team, specialPath, fake._id)
	elseif category then
		local slotIdx, originalId = _findGunSlot(team, category, fake.Name)
		if slotIdx then
			_assignments[key] = {
				fakeId = fake._id,
				originalId = originalId,
				isSpecial = false,
				category = category,
				slotIdx = slotIdx,
				grantWeaponName = grantWeaponName,
			}
			_setGunSlot(team, category, slotIdx, fake._id)
		end
	end
end

local function _unequipFakeForTeam(fake: inventoryGameState.FakeItem, team: string): string?
	local grantWeaponName = _getGrantWeaponName(fake.Name, team)
	local key = _assignmentKey(team, grantWeaponName)
	local entry = _assignments[key]
	if not entry or entry.fakeId ~= fake._id then
		return nil
	end

	local originalId = entry.originalId
	local specialPath = inventoryClassifier.getSpecialPath(fake.Name)
	local category = inventoryClassifier.getCategory(fake.Name)

	if specialPath and entry.isSpecial then
		_setSpecialSlot(team, specialPath, originalId)
	elseif category and not entry.isSpecial and entry.slotIdx then
		_setGunSlot(team, category, entry.slotIdx, originalId)
	end

	_assignments[key] = nil
	return originalId
end

function InventoryChanger.GetTeamsForFake(fakeId: string): { string }
	local fake = peek(inventoryGameState.fakeItems)[fakeId]
	if not fake then
		return {}
	end
	return inventoryClassifier.getTeamsForWeapon(fake.Name)
end

function InventoryChanger.IsEquippedForTeam(fakeId: string, team: string): boolean
	local fake = peek(inventoryGameState.fakeItems)[fakeId]
	if not fake then
		return false
	end
	local grantWeaponName = _getGrantWeaponName(fake.Name, team)
	local entry = _assignments[_assignmentKey(team, grantWeaponName)]
	return entry ~= nil and entry.fakeId == fakeId
end

function InventoryChanger.SetEquippedForTeam(fakeId: string, team: string, equipped: boolean): ()
	local fake = peek(inventoryGameState.fakeItems)[fakeId]
	if not fake then
		return
	end
	if equipped then
		_equipFakeForTeam(fake, team)
		_fireLoadoutListeners()
		_updateLiveViewmodelForFake(fake)
	else
		local originalId = _unequipFakeForTeam(fake, team)
		_fireLoadoutListeners()
		_revertLiveViewmodel(fake, originalId)
	end
end

function InventoryChanger.AddItem(weaponName: string, options: fakeFactory.FakeOptions?): string
	local fakes = peek(inventoryGameState.fakeItems)
	for _, existing in next, fakes do
		if existing.Name == weaponName then
			InventoryChanger.RemoveItem(existing._id)
			break
		end
	end

	local fake = fakeFactory.generate(weaponName, options)
	local newFakes = table.clone(peek(inventoryGameState.fakeItems))
	newFakes[fake._id] = fake
	inventoryGameState.fakeItems(newFakes)

	inventoryDataAccess.applyInventoryDelta({ fake }, nil)

	for _, team in next, inventoryClassifier.getTeamsForWeapon(weaponName) do
		_equipFakeForTeam(fake, team)
	end

	_fireLoadoutListeners()
	_updateLiveViewmodelForFake(fake)

	return fake._id
end

function InventoryChanger.RemoveItem(fakeId: string): ()
	local fakes = peek(inventoryGameState.fakeItems)
	local fake = fakes[fakeId]
	if not fake then
		return
	end

	local newFakes = table.clone(fakes)
	newFakes[fakeId] = nil
	inventoryGameState.fakeItems(newFakes)

	inventoryDataAccess.applyInventoryDelta({}, { fakeId })

	local firstOriginalId: string? = nil

	for _, team in next, inventoryClassifier.getTeamsForWeapon(fake.Name) do
		local originalId = _unequipFakeForTeam(fake, team)
		firstOriginalId = firstOriginalId or originalId
	end

	_revertLiveViewmodel(fake, firstOriginalId)
	_fireLoadoutListeners()
end

local function _onEquipLoadoutSkin(team: string, slotType: string, slotIdx: number, fakeId: string): ()
	local fakes = peek(inventoryGameState.fakeItems)
	local fake = fakes[fakeId]
	if not fake then
		return
	end
	local grantWeaponName = _getGrantWeaponName(fake.Name, team)
	local key = _assignmentKey(team, grantWeaponName)

	local existingEntry = _assignments[key]
	local originalId: string? = existingEntry and existingEntry.originalId
	if not originalId then
		local loadout = _getLoadout()
		if loadout then
			local tl = loadout[team]
			if tl and tl.Loadout and tl.Loadout[slotType] and tl.Loadout[slotType].Options then
				local slotVal = tl.Loadout[slotType].Options[slotIdx]
				if type(slotVal) == "string" and not fakeFactory.isFakeId(slotVal) then
					originalId = slotVal
				end
			end
		end
	end

	_assignments[key] = {
		fakeId = fakeId,
		originalId = originalId,
		isSpecial = false,
		category = slotType,
		slotIdx = slotIdx,
		grantWeaponName = grantWeaponName,
	}
	_setGunSlot(team, slotType, slotIdx, fakeId)
	_fireLoadoutListeners()
	_updateLiveViewmodelForFake(fake)
end

local function _onEquipSpecialItem(team: string, path: string, fakeId: string): ()
	local fakes = peek(inventoryGameState.fakeItems)
	local fake = fakes[fakeId]
	if not fake then
		return
	end
	local grantWeaponName = _getGrantWeaponName(fake.Name, team)
	local key = _assignmentKey(team, grantWeaponName)

	local existingEntry = _assignments[key]
	local originalId: string? = existingEntry and existingEntry.originalId
	if not originalId then
		originalId = _findSpecialOriginalId(team, path)
	end

	_assignments[key] = {
		fakeId = fakeId,
		originalId = originalId,
		isSpecial = true,
		specialPath = path,
		grantWeaponName = grantWeaponName,
	}
	_setSpecialSlot(team, path, fakeId)
	_fireLoadoutListeners()
	_updateLiveViewmodelForFake(fake)
end

local function _onSwapLoadoutSkins(team: string, slotType: string, slotOne: number, slotTwo: number): boolean
	local loadout = _getLoadout()
	if not loadout then
		return false
	end
	local tl = loadout[team]
	if not tl or not tl.Loadout or not tl.Loadout[slotType] then
		return false
	end
	local opts = tl.Loadout[slotType].Options
	if not opts then
		return false
	end
	local idOne = opts[slotOne]
	local idTwo = opts[slotTwo]
	local oneFake = type(idOne) == "string" and fakeFactory.isFakeId(idOne)
	local twoFake = type(idTwo) == "string" and fakeFactory.isFakeId(idTwo)
	if not oneFake and not twoFake then
		return false
	end
	opts[slotOne] = idTwo
	opts[slotTwo] = idOne

	for key, entry in next, _assignments do
		if not entry.isSpecial and entry.category == slotType then
			local keyTeam = string.match(key, "^(.+)|")
			if keyTeam == team then
				if entry.slotIdx == slotOne then
					entry.slotIdx = slotTwo
				elseif entry.slotIdx == slotTwo then
					entry.slotIdx = slotOne
				end
			end
		end
	end

	_fireLoadoutListeners()
	return true
end

local function _onRealEquipOverSlot(team: string, isSpecial: boolean, typeOrPath: string, slotIdx: number?): ()
	local prefix = team .. "|"
	for key, entry in next, _assignments do
		if string.sub(key, 1, #prefix) ~= prefix then
			continue
		end
		if isSpecial then
			if entry.isSpecial and entry.specialPath == typeOrPath then
				_assignments[key] = nil
				break
			end
		else
			if not entry.isSpecial and entry.category == typeOrPath and entry.slotIdx == slotIdx then
				_assignments[key] = nil
				break
			end
		end
	end
end

local function _getFakeForGrant(team: string, grantWeapon: string): any?
	local key = _assignmentKey(team, grantWeapon)
	local entry = _assignments[key]
	if not entry then
		return nil
	end
	local fakes = peek(inventoryGameState.fakeItems)
	return fakes[entry.fakeId]
end

local function _saveConfig(): { any }
	local out: { any } = {}
	local seen: { [string]: boolean } = {}
	local equippedFakeIds: { [string]: boolean } = {}
	for _, entry in next, _assignments do
		if entry.isSpecial and entry.fakeId then
			equippedFakeIds[entry.fakeId] = true
		end
	end
	for _, fake in next, peek(inventoryGameState.fakeItems) do
		if seen[fake._id] then
			continue
		end
		seen[fake._id] = true
		local entry: { [string]: any } = {
			weapon = fake.Name,
			skin = fake.Skin,
			float = fake.Float,
			rarity = fake.MetaData and fake.MetaData.LimerenceRarity,
		}
		if fake.StatTrack ~= false then
			entry.statTrack = fake.StatTrack
		end
		if fake.NameTag ~= false then
			entry.nameTag = fake.NameTag
		end
		if fake.Charm then
			entry.charm = fake.Charm
		end
		if equippedFakeIds[fake._id] then
			entry.equipped = true
		end
		out[#out + 1] = entry
	end
	return out
end

local function _prepareConfig(data: any): ()
	if type(data) ~= "table" then
		return
	end
	local currentFakes = table.clone(peek(inventoryGameState.fakeItems))
	for id in next, currentFakes do
		InventoryChanger.RemoveItem(id)
	end
end

local function _addConfigEntry(entry: any): ()
	InventoryChanger.AddItem(entry.weapon, {
		skin = type(entry.skin) == "string" and entry.skin or nil,
		float = type(entry.float) == "number" and entry.float or nil,
		statTrack = entry.statTrack,
		nameTag = entry.nameTag,
		charm = entry.charm,
		rarity = type(entry.rarity) == "string" and entry.rarity or nil,
	})
end

local function _loadConfig(data: any): ()
	if type(data) ~= "table" then
		return
	end
	local equipped: { any } = {}
	for _, entry in next, data do
		if type(entry) ~= "table" or type(entry.weapon) ~= "string" then
			continue
		end
		if entry.equipped then
			equipped[#equipped + 1] = entry
		else
			_addConfigEntry(entry)
		end
	end
	for _, entry in next, equipped do
		_addConfigEntry(entry)
	end
end

function InventoryChanger.new(): typeof(InventoryChanger)
	_inventoryModule = ModuleController.GetModule("Inventory")

	if _inventoryModule then
		inventoryHooks.install(_inventoryModule, {
			getFakeForGrant = _getFakeForGrant,
			onEquipLoadoutSkin = _onEquipLoadoutSkin,
			onEquipSpecialItem = _onEquipSpecialItem,
			onSwapLoadoutSkins = _onSwapLoadoutSkins,
			onRealEquipOverSlot = _onRealEquipOverSlot,
		})
	end

	if LocalPlayer then
		_charAddedConn = LocalPlayer.CharacterAdded:Connect(function(): ()
			if not _activeGloveFake then
				return
			end
			task.defer(function(): ()
				local fake = _activeGloveFake
				if not fake then
					return
				end
				_gloveAttrOverridden = false
				_applyGloveToViewmodel(fake)
			end)
		end)
	end

	stateConverter.RegisterExtension("fakeInventory", _saveConfig, _loadConfig, _prepareConfig)

	return InventoryChanger
end

function InventoryChanger.Destroy(): ()
	stateConverter.UnregisterExtension("fakeInventory")

	for id in next, peek(inventoryGameState.fakeItems) do
		InventoryChanger.RemoveItem(id)
	end

	if _inventoryModule then
		inventoryHooks.uninstall(_inventoryModule)
	end

	for k in next, _assignments do
		_assignments[k] = nil
	end

	if _charAddedConn then
		_charAddedConn:Disconnect()
		_charAddedConn = nil
	end
	_activeGloveFake = nil
	_savedGloveAttr = nil
	_gloveAttrOverridden = false

	inventoryGameState.fakeItems({})
	_inventoryModule = nil
end

export type InventoryChanger = typeof(InventoryChanger)
return InventoryChanger
