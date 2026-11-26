local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local ModuleController = require("@game/rivals/module/ModuleController")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local NetworkController = require("@game/rivals/network/NetworkController")
local ClientController = require("@game/rivals/client/ClientController")
local PlayerController = require("@feature/player/PlayerController")
local botSource = require("@game/rivals/feature/training/botSource")

local peek = Charm.peek
local sub = Charm.subscribe

local COMMIT_COOLDOWN = 0.4

local ReloadCancel = {}
ReloadCancel.__index = ReloadCancel

setmetatable(ReloadCancel, { __index = BaseFeature })

local function runAsGame(fn: (...any) -> ...any, ...: any): ()
	setthreadidentity(2)
	fn(...)
	setthreadidentity(8)
end

local function delayOf(element: any): number
	if not element then
		return 0
	end
	local value = element:GetRandomValue()
	if type(value) == "number" then
		return math.max(value, 0) / 1000
	end
	return 0
end

local function modeOf(element: any): string
	if not element then
		return "Quick Melee"
	end
	local value = peek(element._state)
	if type(value) == "string" then
		return value
	end
	return "Quick Melee"
end

local function hasCondition(element: any, name: string): boolean
	if not element then
		return false
	end
	local list = peek(element._state)
	if type(list) ~= "table" then
		return false
	end
	for _, value in next, list do
		if value == name then
			return true
		end
	end
	return false
end

local function isBowEquipped(): boolean
	local name = peek(WeaponController.name)
	if type(name) ~= "string" then
		return false
	end

	local itemLibrary = ModuleController.GetModule("ItemLibrary")
	if not itemLibrary then
		return false
	end

	local items = rawget(itemLibrary, "Items")
	local entry = type(items) == "table" and items[name] or nil
	if type(entry) ~= "table" then
		return false
	end

	return entry.AmmoType == "Arrows"
end

local function isInTrainingRange(): boolean
	return peek(botSource._active) == true
end

local function enemiesAlive(): boolean
	local localTeam = ClientController.GetTeam()
	for _, playerData in next, PlayerController.GetAll() do
		if not peek(playerData.alive) then
			continue
		end
		if localTeam ~= "" and peek(playerData.team) == localTeam then
			continue
		end
		return true
	end
	return false
end

local function getCurrentSlot(): number?
	local name = peek(WeaponController.name)
	if type(name) ~= "string" then
		return nil
	end

	local itemLibrary = ModuleController.GetModule("ItemLibrary")
	if not itemLibrary then
		return nil
	end

	local items = rawget(itemLibrary, "Items")
	local entry = type(items) == "table" and items[name] or nil
	if type(entry) ~= "table" then
		return nil
	end

	local className = entry.Class
	if type(className) ~= "string" then
		return nil
	end

	local classes = rawget(itemLibrary, "Classes")
	local class = type(classes) == "table" and classes[className] or nil
	if type(class) ~= "table" then
		return nil
	end

	local slot = class.Slot
	return type(slot) == "number" and slot or nil
end

function ReloadCancel.new(link: gameUi.Linker): ReloadCancel
	local self = BaseFeature.new() :: any
	setmetatable(self, ReloadCancel)

	link:Toggle("enabled", "Reload Cancel", false):SetTip({
		title = "Reload Cancel",
		body = "Cancels the rest of a reload animation shortly after the reload finishes, keeping the reloaded ammo.",
	})
	local enabledLink = link:OnKey("enabled")
	enabledLink:Submenu("opts", "Reload Cancel")
	local optsLink = enabledLink:OnKey("opts")
	optsLink:Dropdown("mode", "Mode", { "Quick Melee", "Switch Weapon" }, "Quick Melee"):SetTip({
		title = "Mode",
		body = "Quick Melee swings then re-equips your gun. Switch Weapon swaps to your other weapon and back.",
	})
	optsLink:RangeSlider("delay", "Delay", 1, 25, 0, 150, 1, nil, "ms"):SetTip({
		title = "Delay",
		body = "Milliseconds to wait after the reload before canceling. Set both values equal for a fixed delay, or apart for a random delay between them.",
	})
	optsLink:Dropdown("conditions", "Conditions", { "Ignore When Match Over", "Ignore Bows" }, { "Ignore When Match Over", "Ignore Bows" }):SetMode("multi"):SetTip({
		title = "Conditions",
		body = "Ignore When Match Over skips canceling with no living enemies left. Ignore Bows skips while a bow or crossbow is equipped.",
	})

	self._detectionJanitor = Janitor.new()
	self._detecting = false
	self._enabled = false
	self._mode = link:Get("enabled.opts.mode")
	self._delay = link:Get("enabled.opts.delay")
	self._conditions = link:Get("enabled.opts.conditions")
	self._currentItem = peek(WeaponController.item)
	self._lastAmmo = peek(WeaponController.ammo)
	self._cooldownUntil = 0

	self:Track(link:Get("enabled"):OnChange(function(value: boolean): ()
		self._enabled = value
		self:_syncDetection()
	end))

	return self
end

function ReloadCancel._syncDetection(self: ReloadCancel): ()
	if self._enabled == self._detecting then
		return
	end
	self._detecting = self._enabled

	if not self._enabled then
		self._detectionJanitor:Cleanup()
		return
	end

	self._currentItem = peek(WeaponController.item)
	self._lastAmmo = peek(WeaponController.ammo)

	self._detectionJanitor:Add(
		sub(WeaponController.ammo, function(): ()
			self:_onAmmoChanged()
		end),
		true
	)
end

function ReloadCancel._onAmmoChanged(self: ReloadCancel): ()
	local item = peek(WeaponController.item)
	local newAmmo = peek(WeaponController.ammo)

	if item ~= self._currentItem then
		self._currentItem = item
		self._lastAmmo = newAmmo
		return
	end

	local prevAmmo = self._lastAmmo
	self._lastAmmo = newAmmo

	if newAmmo <= prevAmmo then
		return
	end
	if not WeaponController.IsGun() then
		return
	end
	if hasCondition(self._conditions, "Ignore Bows") and isBowEquipped() then
		return
	end
	if hasCondition(self._conditions, "Ignore When Match Over") and not enemiesAlive() and not isInTrainingRange() then
		return
	end

	local now = tick()
	if now < self._cooldownUntil then
		return
	end
	self._cooldownUntil = now + COMMIT_COOLDOWN

	self:_scheduleCancel()
end

function ReloadCancel._scheduleCancel(self: ReloadCancel): ()
	if not self._enabled then
		return
	end

	local delay = delayOf(self._delay)

	if modeOf(self._mode) == "Switch Weapon" then
		task.delay(delay, function(): ()
			self:_doSwitchWeapon()
		end)
		return
	end

	task.delay(delay, function(): ()
		self:_doQuickMelee()
	end)
end

function ReloadCancel._doQuickMelee(self: ReloadCancel): ()
	if not self._enabled then
		return
	end

	local fighter = WeaponController.GetLocalFighter()
	if not fighter or type(fighter.QuickAttack) ~= "function" then
		return
	end

	runAsGame(fighter.QuickAttack, fighter, "Melee")
	runAsGame(NetworkController.SendRemote, "Replication.Fighter.DontKeepQuickAttack")
end

function ReloadCancel._doSwitchWeapon(self: ReloadCancel): ()
	if not self._enabled then
		return
	end

	local fighter = WeaponController.GetLocalFighter()
	if not fighter or type(fighter.EquipItem) ~= "function" then
		return
	end

	local slot = getCurrentSlot()
	if slot ~= 1 and slot ~= 2 then
		return
	end

	local otherSlot = slot == 1 and 2 or 1
	runAsGame(fighter.EquipItem, fighter, otherSlot)

	task.wait()

	local current = WeaponController.GetLocalFighter()
	if not current or type(current.EquipItem) ~= "function" then
		return
	end

	runAsGame(current.EquipItem, current, slot)
end

function ReloadCancel.Destroy(self: ReloadCancel): ()
	self._detectionJanitor:Destroy()
	BaseFeature.Destroy(self)
end

export type ReloadCancel =
	typeof(setmetatable(
		{} :: {
			_detectionJanitor: Janitor.Janitor,
			_detecting: boolean,
			_enabled: boolean,
			_mode: any,
			_delay: any,
			_conditions: any,
			_currentItem: any,
			_lastAmmo: number,
			_cooldownUntil: number,
		},
		ReloadCancel
	))
	& BaseFeature.BaseFeature

return ReloadCancel
