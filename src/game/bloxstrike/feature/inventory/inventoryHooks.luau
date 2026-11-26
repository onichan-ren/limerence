local Players = cloneref(game:GetService("Players")) :: Players

local NetworkController = require("@game/bloxstrike/network/NetworkController")
local hook = require("@share/hook")
local fakeFactory = require("@game/bloxstrike/feature/inventory/fakeFactory")

local LocalPlayer = Players.LocalPlayer

export type AssignmentEntry = {
	fakeId: string,
	originalId: string?,
	isSpecial: boolean,
	category: string?,
	slotIdx: number?,
	specialPath: string?,
	grantWeaponName: string,
}

local inventoryHooks = {
	_installed = false,
	_origNewInventoryItem = nil :: (({ [string]: any }) -> ())?,
}

local _callbacks: {
	getFakeForGrant: (team: string, grantWeapon: string) -> any?,
	onEquipLoadoutSkin: (team: string, slotType: string, slotIdx: number, fakeId: string) -> (),
	onEquipSpecialItem: (team: string, path: string, fakeId: string) -> (),
	onSwapLoadoutSkins: (team: string, slotType: string, slotOne: number, slotTwo: number) -> boolean,
	onRealEquipOverSlot: (team: string, isSpecial: boolean, typeOrPath: string, slotIdx: number?) -> (),
} =
	nil :: any

inventoryHooks.install = LPH_JIT_MAX(function(InventoryModule: any, callbacks: typeof(_callbacks)): ()
	if inventoryHooks._installed then
		return
	end
	inventoryHooks._installed = true
	_callbacks = callbacks

	local origFn = InventoryModule.newInventoryItem

	inventoryHooks._origNewInventoryItem = hook.add(origFn, function(grant: { [string]: any }): ()
		local orig = inventoryHooks._origNewInventoryItem
		if not orig then
			return
		end
		local team = LocalPlayer and LocalPlayer:GetAttribute("Team") :: string?
		if type(team) ~= "string" then
			pcall(orig, grant)
			return
		end
		local grantWeapon = grant.weapon
		local fake = type(grantWeapon) == "string" and callbacks.getFakeForGrant(team, grantWeapon) or nil
		if fake then
			grant = table.clone(grant)
			if fake.Name ~= grantWeapon then
				grant.weapon = fake.Name
			end
			grant.skin = fake.Skin or "Stock"
			grant.Float = type(fake.Float) == "number" and fake.Float or 0
			grant.StatTrack = fake.StatTrack
			grant.NameTag = fake.NameTag
			grant.Charm = fake.Charm
			grant.Stickers = fake.Stickers or {}
		end
		pcall(orig, grant)
	end)

	NetworkController.HookPacket("Inventory", "EquipLoadoutSkin", function(payload)
		if type(payload) ~= "table" then
			return true
		end
		local id = payload.Identifier
		local team = payload.Team
		local slotType = payload.Type
		local slot = payload.Slot
		if type(id) ~= "string" or type(team) ~= "string" or type(slotType) ~= "string" or type(slot) ~= "number" then
			return true
		end
		local slotIdx = slot + 1
		if fakeFactory.isFakeId(id) then
			callbacks.onEquipLoadoutSkin(team, slotType, slotIdx, id)
			return false
		end
		callbacks.onRealEquipOverSlot(team, false, slotType, slotIdx)
		return true
	end)

	NetworkController.HookPacket("Inventory", "EquipSpecialItem", function(payload)
		if type(payload) ~= "table" then
			return true
		end
		local id = payload.Identifier
		local team = payload.Team
		local path = payload.Path
		if type(id) ~= "string" or type(team) ~= "string" or type(path) ~= "string" then
			return true
		end
		if fakeFactory.isFakeId(id) then
			callbacks.onEquipSpecialItem(team, path, id)
			return false
		end
		callbacks.onRealEquipOverSlot(team, true, path, nil)
		return true
	end)

	NetworkController.HookPacket("Inventory", "SwapLoadoutSkins", function(payload)
		if type(payload) ~= "table" then
			return true
		end
		local team = payload.Team
		local slotType = payload.Type
		local slotOne = payload.SlotOne
		local slotTwo = payload.SlotTwo
		if
			type(team) ~= "string"
			or type(slotType) ~= "string"
			or type(slotOne) ~= "number"
			or type(slotTwo) ~= "number"
		then
			return true
		end
		local handled = callbacks.onSwapLoadoutSkins(team, slotType, slotOne + 1, slotTwo + 1)
		if handled then
			return false
		end
		return true
	end)
end)

function inventoryHooks.uninstall(InventoryModule: any): ()
	if not inventoryHooks._installed then
		return
	end
	inventoryHooks._installed = false

	local orig = inventoryHooks._origNewInventoryItem
	if orig then
		hook.restore(InventoryModule.newInventoryItem)
		inventoryHooks._origNewInventoryItem = nil
	end

	NetworkController.UnhookPacket("Inventory", "EquipLoadoutSkin")
	NetworkController.UnhookPacket("Inventory", "EquipSpecialItem")
	NetworkController.UnhookPacket("Inventory", "SwapLoadoutSkins")
end

return inventoryHooks
