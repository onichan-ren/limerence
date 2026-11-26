local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local droppedItemState = require("@game/bloxstrike/dropped/droppedItemState")
local droppedAmmoTracker = require("@game/bloxstrike/dropped/droppedAmmoTracker")

export type DroppedKind = droppedItemState.DroppedKind

local weaponLimitsCache: { [string]: { class: string, slot: string, muzzleType: string? } } = {}

local ITEM_LABELS: { [string]: string } = {
	["HE Grenade"] = "HE",
	["Smoke Grenade"] = "SMOKE",
	["Flashbang"] = "FLASH",
	["Decoy Grenade"] = "DECOY",
	["Incendiary Grenade"] = "INC",
	["Molotov"] = "MOLOTOV",
}

local function getWeaponDef(weaponName: string): any?
	local cached = weaponLimitsCache[weaponName]
	if cached then
		return cached
	end

	local database = (ReplicatedStorage :: any).Database
	local defInst = database.Custom.Weapons:FindFirstChild(weaponName)
	if not defInst then
		return nil
	end

	setthreadidentity(2)
	local def = require(defInst)
	setthreadidentity(8)
	if type(def) ~= "table" then
		return nil
	end

	local entry = {
		class = (def :: any).Class or "",
		slot = (def :: any).Slot or "",
		muzzleType = (def :: any).MuzzleType,
	}
	weaponLimitsCache[weaponName] = entry
	return entry
end

local function classifyKind(weaponName: string, def: any?): DroppedKind
	if weaponName == "C4" then
		return "bomb"
	end
	if def then
		if def.class == "C4" then
			return "bomb"
		end
		if def.class == "Weapon" and def.muzzleType ~= "Zeus x27" then
			return "weapon"
		end
		if def.class == "Grenade" or def.slot == "Grenade" then
			return "item"
		end
	end
	return "item"
end

local function buildLabel(weaponName: string, kind: DroppedKind): string
	if kind == "bomb" then
		return "C4"
	end
	if kind == "item" then
		return ITEM_LABELS[weaponName] or weaponName:upper()
	end
	return weaponName:upper()
end

local function parseModel(model: Model): droppedItemState.DroppedEntry?
	local weaponName = model:GetAttribute("Weapon")
	if type(weaponName) ~= "string" or weaponName == "" then
		return nil
	end

	local def = getWeaponDef(weaponName)
	local kind: DroppedKind = classifyKind(weaponName, def)
	local ammo = droppedAmmoTracker.resolve(model, weaponName, kind)

	return {
		model = model,
		kind = kind,
		label = buildLabel(weaponName, kind),
		weaponName = weaponName,
		showAmmo = ammo ~= nil,
		rounds = (ammo and ammo.rounds or 0),
		maxRounds = (ammo and ammo.maxRounds or 0),
	} :: droppedItemState.DroppedEntry
end

local function setEntry(model: Model): ()
	local parsed = parseModel(model)
	if not parsed then
		return
	end
	local current = table.clone(droppedItemState.entries())
	current[model] = parsed
	droppedItemState.entries(current)
end

local function removeEntry(model: Model): ()
	local current = droppedItemState.entries()
	if not current[model] then
		return
	end
	local nextEntries = table.clone(current)
	nextEntries[model] = nil
	droppedItemState.entries(nextEntries)
end

local function refreshEntry(model: Model): ()
	if not model.Parent then
		removeEntry(model)
		return
	end
	setEntry(model)
end

local droppedItemRegistry = {}

function droppedItemRegistry.bindModel(model: Model): ()
	setEntry(model)
	task.defer(refreshEntry, model)

	local conns: { RBXScriptConnection } = {}
	conns[#conns + 1] = model:GetAttributeChangedSignal("Weapon"):Connect(function()
		refreshEntry(model)
	end)
	conns[#conns + 1] = model.Destroying:Connect(function()
		for _, conn in next, conns do
			conn:Disconnect()
		end
		removeEntry(model)
	end)
end

function droppedItemRegistry.unbindModel(model: Model): ()
	removeEntry(model)
end

return droppedItemRegistry
