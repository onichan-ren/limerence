local Charm = require("@pkg/Charm")

local ModuleController = require("@game/pf/module/ModuleController")
local pfSkinState = require("@game/pf/feature/inventory/pfSkinState")
local skinCatalog = require("@game/pf/feature/inventory/skinCatalog")
local stateConverter = require("@src/feature/config/module/stateConverter")
local hook = require("@share/hook")

local SkinChanger = {}

local _overlay: { [string]: { [string]: pfSkinState.SlotData } } = {}
local _started = false
local _building: string? = nil
local _firearmNew: any = nil
local _construct: any = nil

local function ensureSlot(weaponName: string, slotTag: string): pfSkinState.SlotData
	local weapon = _overlay[weaponName]
	if not weapon then
		weapon = {}
		_overlay[weaponName] = weapon
	end
	local slot = weapon[slotTag]
	if not slot then
		slot = {}
		weapon[slotTag] = slot
	end
	return slot
end

local buildCamo = LPH_NO_VIRTUALIZE(function(weaponName: string, baseCamo: any): { [string]: any }?
	local weapon = _overlay[weaponName]
	local camo: { [string]: any } = {}
	if type(baseCamo) == "table" then
		for tag, data in next, baseCamo do
			camo[tag] = data
		end
	end
	if weapon then
		for slotTag, slot in next, weapon do
			if slot.skin and slot.skin ~= "" then
				local entry: { [string]: any } = { Name = slot.skin }
				if slot.brick and next(slot.brick) then
					entry.BrickProperties = table.clone(slot.brick)
				end
				if slot.texture and next(slot.texture) then
					entry.TextureProperties = table.clone(slot.texture)
				end
				camo[slotTag] = entry
			else
				camo[slotTag] = type(baseCamo) == "table" and baseCamo[slotTag] or nil
			end
		end
	end
	if next(camo) == nil then
		return nil
	end
	return camo
end)

local repaintWeapon = LPH_NO_VIRTUALIZE(function(weapon: any): ()
	if not weapon or weapon:getWeaponType() ~= "Firearm" then
		return
	end
	local weaponName = weapon.weaponName
	if type(weaponName) ~= "string" then
		return
	end
	local model = rawget(weapon, "_weaponModel")
	if typeof(model) ~= "Instance" then
		return
	end
	local weaponUtils = ModuleController.GetModule("WeaponUtils")
	local textureModel = weaponUtils and rawget(weaponUtils, "textureModel")
	if type(textureModel) ~= "function" then
		return
	end

	local base = rawget(weapon, "weaponCamo")
	local camo = buildCamo(weaponName, base)
	if type(camo) ~= "table" then
		return
	end

	local id = getthreadidentity()
	setthreadidentity(8)
	textureModel(model, camo, nil)
	setthreadidentity(id)
end)

local function refresh(): ()
	local ci = ModuleController.GetModule("CharacterInterface")
	local co = ci and ci.getCharacterObject()
	local wc = co and co:getWeaponController()
	local registry = wc and wc:getWeapons()
	if type(registry) ~= "table" then
		return
	end
	for _, weapon in next, registry do
		repaintWeapon(weapon)
	end
end

local function syncState(): ()
	local out: { [string]: pfSkinState.WeaponEquipped } = {}
	for weaponName, slots in next, _overlay do
		local outSlots: { [string]: pfSkinState.SlotData } = {}
		for slotTag, slot in next, slots do
			outSlots[slotTag] = {
				skin = slot.skin,
				brick = slot.brick and table.clone(slot.brick) or nil,
				texture = slot.texture and table.clone(slot.texture) or nil,
			}
		end
		out[weaponName] = { slots = outSlots }
	end
	pfSkinState.weaponInventory(out)
end

local function commit(): ()
	refresh()
	syncState()
end

local function installHooks(): ()
	local firearm = ModuleController.GetModule("FirearmObject")
	local weaponUtils = ModuleController.GetModule("WeaponUtils")
	if not firearm or not weaponUtils then
		return
	end
	local newFn = rawget(firearm, "new")
	local constructFn = rawget(weaponUtils, "constructWeapon")
	if type(newFn) ~= "function" or type(constructFn) ~= "function" then
		return
	end

	_firearmNew = newFn
	local origNew
	origNew = hook.add(
		newFn,
		LPH_NO_VIRTUALIZE(function(p1: any, p2: any, p3: any, p4: any, p5: any, p6: any, p7: any): ...any
			local prev = _building
			_building = (type(p3) == "string" and _overlay[p3]) and p3 or nil
			local result = { origNew(p1, p2, p3, p4, p5, p6, p7) }
			_building = prev
			return table.unpack(result)
		end)
	)

	_construct = constructFn
	local origConstruct
	origConstruct = hook.add(
		constructFn,
		LPH_NO_VIRTUALIZE(function(p1: any, p2: any, p3: any, p4: any, p5: any, p6: any, p7: any): ...any
			if _building then
				local injected = buildCamo(p1, p4)
				if injected then
					p4 = injected
				end
			end
			return origConstruct(p1, p2, p3, p4, p5, p6, p7)
		end)
	)
end

local function restoreHooks(): ()
	if _firearmNew then
		hook.restore(_firearmNew)
		_firearmNew = nil
	end
	if _construct then
		hook.restore(_construct)
		_construct = nil
	end
end

function SkinChanger.Equip(weaponName: string, slotTag: string, skinName: string?): boolean
	if type(weaponName) ~= "string" or type(slotTag) ~= "string" then
		return false
	end
	if skinName and skinName ~= "" then
		local weapon = _overlay[weaponName]
		if not weapon then
			weapon = {}
			_overlay[weaponName] = weapon
		end
		weapon[slotTag] = { skin = skinName }
	else
		local weapon = _overlay[weaponName]
		if weapon then
			weapon[slotTag] = nil
			if next(weapon) == nil then
				_overlay[weaponName] = nil
			end
		end
	end
	commit()
	return true
end

function SkinChanger.SetProperty(
	weaponName: string,
	slotTag: string,
	group: "brick" | "texture",
	name: string,
	value: any
): boolean
	if type(weaponName) ~= "string" or type(slotTag) ~= "string" then
		return false
	end
	local weapon = _overlay[weaponName]
	local existing = weapon and weapon[slotTag]
	if not existing or not existing.skin then
		return false
	end
	local slot = ensureSlot(weaponName, slotTag)
	local bucket = slot[group]
	if value == nil then
		if bucket then
			bucket[name] = nil
		end
	else
		if not bucket then
			bucket = {}
			slot[group] = bucket
		end
		bucket[name] = value
	end
	if slot[group] and next(slot[group]) == nil then
		slot[group] = nil
	end
	commit()
	return true
end

function SkinChanger.ClearSlot(weaponName: string, slotTag: string): boolean
	return SkinChanger.Equip(weaponName, slotTag, nil)
end

function SkinChanger.ApplyToAll(slotTag: string, skinName: string?): boolean
	if type(slotTag) ~= "string" then
		return false
	end
	for _, weaponName in next, skinCatalog.getWeapons() do
		if skinName and skinName ~= "" then
			ensureSlot(weaponName, slotTag).skin = skinName
			local slot = _overlay[weaponName][slotTag]
			slot.brick = nil
			slot.texture = nil
		else
			local weapon = _overlay[weaponName]
			if weapon then
				weapon[slotTag] = nil
				if next(weapon) == nil then
					_overlay[weaponName] = nil
				end
			end
		end
	end
	commit()
	return true
end

function SkinChanger.UnapplyFromAll(slotTag: string, skinName: string): boolean
	if type(slotTag) ~= "string" or type(skinName) ~= "string" then
		return false
	end
	for weaponName, weapon in next, _overlay do
		local slot = weapon[slotTag]
		if slot and slot.skin == skinName then
			weapon[slotTag] = nil
		end
		if next(weapon) == nil then
			_overlay[weaponName] = nil
		end
	end
	commit()
	return true
end

function SkinChanger.ClearAll(): ()
	_overlay = {}
	commit()
end

local function serColor(color: Color3): { r: number, g: number, b: number }
	return { r = color.R, g = color.G, b = color.B }
end

local function deserColor(data: any): Color3?
	if type(data) == "table" and type(data.r) == "number" and type(data.g) == "number" and type(data.b) == "number" then
		return Color3.new(data.r, data.g, data.b)
	end
	return nil
end

local function serProps(props: any): { [string]: any }?
	if type(props) ~= "table" then
		return nil
	end
	local out: { [string]: any } = {}
	for key, value in next, props do
		if typeof(value) == "Color3" then
			out[key] = serColor(value)
		elseif type(value) == "number" or type(value) == "string" then
			out[key] = value
		end
	end
	if next(out) == nil then
		return nil
	end
	return out
end

local function deserProps(data: any): { [string]: any }?
	if type(data) ~= "table" then
		return nil
	end
	local out: { [string]: any } = {}
	for key, value in next, data do
		if key == "Color" then
			local color = deserColor(value)
			if color then
				out[key] = color
			end
		elseif type(value) == "number" or type(value) == "string" then
			out[key] = value
		end
	end
	if next(out) == nil then
		return nil
	end
	return out
end

local _saveConfig = LPH_NO_VIRTUALIZE(function(): { [string]: any }
	local out: { [string]: any } = {}
	for weaponName, slots in next, _overlay do
		local outSlots: { [string]: any } = {}
		for slotTag, slot in next, slots do
			if slot.skin and slot.skin ~= "" then
				outSlots[slotTag] = {
					skin = slot.skin,
					brick = serProps(slot.brick),
					texture = serProps(slot.texture),
				}
			end
		end
		if next(outSlots) ~= nil then
			out[weaponName] = outSlots
		end
	end
	return out
end)

local _prepareConfig = LPH_NO_VIRTUALIZE(function(_data: any): ()
	_overlay = {}
	commit()
end)

local _loadConfig = LPH_NO_VIRTUALIZE(function(data: any): ()
	if type(data) ~= "table" then
		return
	end
	local rebuilt: { [string]: { [string]: pfSkinState.SlotData } } = {}
	for weaponName, slots in next, data do
		if type(weaponName) == "string" and type(slots) == "table" then
			local outSlots: { [string]: pfSkinState.SlotData } = {}
			for slotTag, slot in next, slots do
				if type(slotTag) == "string" and type(slot) == "table" and type(slot.skin) == "string" then
					outSlots[slotTag] = {
						skin = slot.skin,
						brick = deserProps(slot.brick),
						texture = deserProps(slot.texture),
					}
				end
			end
			if next(outSlots) ~= nil then
				rebuilt[weaponName] = outSlots
			end
		end
	end
	_overlay = rebuilt
	commit()
end)

function SkinChanger.new(): typeof(SkinChanger)
	if _started then
		return SkinChanger
	end
	_started = true

	installHooks()

	local weapons = skinCatalog.getWeapons()
	if Charm.peek(pfSkinState.selectedWeapon) == nil and weapons[1] then
		pfSkinState.selectedWeapon(weapons[1])
	end

	stateConverter.RegisterExtension("pfSkins", _saveConfig, _loadConfig, _prepareConfig)
	syncState()
	pfSkinState.ready(true)

	return SkinChanger
end

function SkinChanger.Destroy(): ()
	pfSkinState.ready(false)
	stateConverter.UnregisterExtension("pfSkins")
	restoreHooks()
	_overlay = {}
	refresh()
	pfSkinState.weaponInventory({})
	pfSkinState.selectedWeapon(nil)
	pfSkinState.activeSlot(nil)
	_started = false
end

export type SkinChanger = typeof(SkinChanger)
return SkinChanger
