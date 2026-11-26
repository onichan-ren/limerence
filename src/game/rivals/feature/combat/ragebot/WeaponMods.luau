local ModuleController = require("@game/rivals/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")

type PatchId = "rapidFire" | "noRecoil"

local PATCH_ORDER: { PatchId } = { "rapidFire", "noRecoil" }

local PATCH_FIELDS: { [PatchId]: { [string]: number } } = {
	rapidFire = { ShootCooldown = 0.03, QuickShotCooldown = 0.03 },
	noRecoil = { ShootRecoil = 0 },
}

local PATCH_LABEL: { [PatchId]: string } = {
	rapidFire = "Rapid Fire",
	noRecoil = "No Recoil",
}

local PATCH_BODY: { [PatchId]: string } = {
	rapidFire = "Sets shoot cooldown to zero.",
	noRecoil = "Zeroes weapon recoil.",
}

local function setInfoField(info: any, key: string, value: any): ()
	local wasReadonly = isreadonly(info)
	if wasReadonly then
		setreadonly(info, false)
	end
	info[key] = value
	if wasReadonly then
		setreadonly(info, true)
	end
end

local WeaponMods = {}
WeaponMods.__index = WeaponMods

setmetatable(WeaponMods, { __index = BaseFeature })

function WeaponMods.new(link: gameUi.Linker): WeaponMods
	local self = BaseFeature.new() :: any
	setmetatable(self, WeaponMods)

	self._enabled = {} :: { [PatchId]: boolean }
	self._originals = {} :: { [PatchId]: { [any]: { [string]: { value: any } } } }

	local sorted = table.clone(PATCH_ORDER)
	table.sort(sorted, function(a: PatchId, b: PatchId): boolean
		return #PATCH_LABEL[a] < #PATCH_LABEL[b]
	end)

	for i = 1, #sorted do
		local id: PatchId = sorted[i]
		link:Toggle(id, PATCH_LABEL[id], false):SetTip({
			title = PATCH_LABEL[id],
			body = PATCH_BODY[id],
		})
		self._enabled[id] = false
		self:Track(link:Get(id):OnChange(function(value: boolean): ()
			if value then
				self:EnablePatch(id)
			else
				self:DisablePatch(id)
			end
		end))
	end

	return self
end

local function forEachGun(callback: (info: any) -> ()): ()
	local itemLibrary = ModuleController.GetModule("ItemLibrary")
	if not itemLibrary then
		return
	end
	local items = rawget(itemLibrary, "Items")
	if type(items) ~= "table" then
		return
	end
	for _, info in next, items do
		if type(info) == "table" and info.Type == "Gun" then
			callback(info)
		end
	end
end

function WeaponMods.EnablePatch(self: WeaponMods, id: PatchId): ()
	if self._enabled[id] then
		return
	end
	self._enabled[id] = true

	local fields = PATCH_FIELDS[id]
	local store: { [any]: { [string]: { value: any } } } = {}
	self._originals[id] = store

	forEachGun(function(info: any): ()
		local saved: { [string]: { value: any } } = {}
		store[info] = saved
		for key, value in next, fields do
			saved[key] = { value = info[key] }
			setInfoField(info, key, value)
		end
	end)
end

function WeaponMods.DisablePatch(self: WeaponMods, id: PatchId): ()
	if not self._enabled[id] then
		return
	end
	self._enabled[id] = false

	local store = self._originals[id]
	if not store then
		return
	end
	for info, saved in next, store do
		for key, original in next, saved do
			setInfoField(info, key, original.value)
		end
	end
	self._originals[id] = nil
end

function WeaponMods.Destroy(self: WeaponMods): ()
	for _, id in next, PATCH_ORDER do
		self:DisablePatch(id)
	end
	BaseFeature.Destroy(self)
end

export type WeaponMods =
	typeof(setmetatable(
		{} :: {
			_enabled: { [PatchId]: boolean },
			_originals: { [PatchId]: { [any]: { [string]: { value: any } } } },
		},
		WeaponMods
	))
	& BaseFeature.BaseFeature

return WeaponMods
