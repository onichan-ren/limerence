local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local CommandController = require("@game/overkill/weapon/CommandController")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local ModuleController = require("@game/overkill/module/ModuleController")
local Backtrack = require("@game/overkill/feature/legitbot/BacktrackController")
local bulletRedirection = require("@game/overkill/feature/legitbot/bulletRedirection")
local slotKeys = require("@game/overkill/weapon/slotKeys")
local hudState = require("@game/universal/feature/visual/hud/hudState")

local ACTION_BUTTONS = 331
local INFO_ORDER = 20

local clientModule: any = nil
local items: any = nil

local function equippedInfo(): (any, any, number)
	if not clientModule then
		clientModule = ModuleController.GetModule("clientModule")
	end
	local localChickynoid = clientModule and clientModule.localChickynoid
	local simulation = localChickynoid and localChickynoid.simulation
	local state = simulation and simulation.state
	if type(state) ~= "table" then
		return nil, nil, 1
	end
	local slot = state.equippedSlot or 1
	if not items then
		items = ModuleController.GetModule("items")
	end
	local weaponId = state[(slotKeys[slot] or slotKeys[1]).weaponID]
	local item = (items and type(weaponId) == "string" and weaponId ~= "") and items.all[weaponId] or nil
	return state, item, slot
end

local function reloadThreshold(item: any, state: any, keys: any): number
	local handling = item and item.stats and item.stats.handling
	if not handling then
		return 0
	end
	local endTime = handling.reloadEndTime or 0
	if handling.reloadType == "per_shell" then
		local magSize = (item.stats.ammo and item.stats.ammo.magSize) or 0
		local need = magSize - ((state and state[keys.magCount]) or 0)
		if need < 0 then
			need = 0
		end
		return (handling.reloadStartTime or 0) + need * (handling.reloadShellTime or 0) + endTime
	end
	return (handling.reloadTime or 0) + endTime
end

local TickManipulation = {}
TickManipulation.__index = TickManipulation

setmetatable(TickManipulation, { __index = BaseFeature })

function TickManipulation.new(link: gameUi.Linker): TickManipulation
	local self = BaseFeature.new() :: any
	setmetatable(self, TickManipulation)

	local toggle = link:Toggle("tickManipulation", "Tick Manipulation", false):SetTip({
		title = "Tick Manipulation",
		body = "The longer you go without firing, the larger your next burst. It has to build up again after each burst.",
	})
	local chargeLink = link:OnKey("tickManipulation")
	chargeLink:Submenu("opts", "Tick Manipulation")
	local optsLink = chargeLink:OnKey("opts")
	local maxBank = optsLink:Slider("bank", "Max Charge", 100000, 100, 100000, 10, nil, "ms"):SetTip({
		title = "Max Charge",
		body = "Largest burst you can build up to.",
	})
	local shiftCap = optsLink
		:Slider("shiftCap", "Shift Offset", 0, 0, 1000, 10, nil, "ms")
		:SetTip({
			title = "Shift Offset",
			body = "Upper limit on how far into the past burst shots aim at your target. Auto adjusts to your ping.",
		})
		:SetValueTextOverrides({ [0] = "Auto" })
	local minCharge = optsLink
		:Slider("minCharge", "Min Charge", 0, 0, 100, 5, nil, "%")
		:SetTip({
			title = "Min Charge",
			body = "Leftover charge below this is quickly worked off before shooting instead of being fired as a weak burst.",
		})
		:SetValueTextOverrides({ [0] = "Off" })
	local maxHealth = optsLink
		:Slider("maxHealth", "Max Health", 0, 0, 100, 1, nil, "hp")
		:SetTip({
			title = "Max Health",
			body = "Targets at or below this health aren't worth a burst. The charge is quickly worked off, then shots fire as normal.",
		})
		:SetValueTextOverrides({ [0] = "Off" })
	local noWait = optsLink:Toggle("noWait", "No Wait", false):SetTip({
		title = "No Wait",
		body = "Never wait. When the charged burst can't land, the charge is quickly worked off and shots fire as normal.",
	})
	local reloadDrain = optsLink:Toggle("reloadDrain", "Reload Drain", true):SetTip({
		title = "Reload Drain",
		body = "Spends charge while reloading to finish the reload much faster.",
	})

	self._enabled = false
	self._installed = false
	self._aim = 0
	self._lastRate = 0.1
	self._lastPct = -1
	self._maxBank = optsLink:Get("bank"):Peek() / 1000
	self._minPct = (minCharge:Peek() or 0) / 100
	self._reloadDrain = reloadDrain:Peek() == true
	self._lastFireSeen = 0
	self._lastFireSlot = 0
	self._unregister = nil :: (() -> ())?
	self._pendingUnregister = false

	local function pushMinRelease(): ()
		bulletRedirection.SetChargeMinRelease(self._maxBank * self._minPct)
	end
	pushMinRelease()

	bulletRedirection.SetAimShiftCap((shiftCap:Peek() or 380) / 1000)
	self:Track(shiftCap:OnChange(function(value: number): ()
		bulletRedirection.SetAimShiftCap(value / 1000)
	end))

	self:Track(toggle:OnChange(function(value: boolean): ()
		self._enabled = value
		if not value then
			self._lastPct = -1
			Backtrack.SetHistoryDemand("tickManipulation", 0)
			hudState.SetInfo("tickManipulation", nil)
		end
		if value then
			Backtrack.SetHistoryDemand("tickManipulation", self._maxBank + 0.25)
			self:_install()
		end
	end))
	self:Track(maxBank:OnChange(function(value: number): ()
		self._maxBank = value / 1000
		pushMinRelease()
		if self._enabled then
			Backtrack.SetHistoryDemand("tickManipulation", self._maxBank + 0.25)
		end
	end))
	self:Track(minCharge:OnChange(function(value: number): ()
		self._minPct = value / 100
		pushMinRelease()
	end))
	bulletRedirection.SetChargeNoWait(noWait:Peek() == true)
	self:Track(noWait:OnChange(function(value: boolean): ()
		bulletRedirection.SetChargeNoWait(value)
	end))
	self:Track(reloadDrain:OnChange(function(value: boolean): ()
		self._reloadDrain = value
	end))
	bulletRedirection.SetChargeMaxHealth(maxHealth:Peek() or 0)
	self:Track(maxHealth:OnChange(function(value: number): ()
		bulletRedirection.SetChargeMaxHealth(value)
	end))

	if link:Peek("tickManipulation") then
		self._enabled = true
		Backtrack.SetHistoryDemand("tickManipulation", self._maxBank + 0.25)
		self:_install()
	end

	return self
end

function TickManipulation._install(self: TickManipulation): ()
	if self._installed then
		return
	end
	self._installed = true

	self._unregister = CommandController.Register(
		LPH_JIT_MAX(function(command: any): ()
			if type(command) ~= "table" or type(command.serverTime) ~= "number" then
				return
			end
			local applied = self._aim
			if not self._enabled and applied <= 0 then
				if not self._pendingUnregister then
					self._pendingUnregister = true
					task.defer(function(): ()
						self._pendingUnregister = false
						local aim: number = self._aim
						if self._enabled or aim > 0 then
							return
						end
						local unregister = self._unregister
						if unregister then
							self._unregister = nil
							self._installed = false
							unregister()
						end
					end)
				end
				return
			end
			local dt = command.deltaTime
			if type(dt) ~= "number" or dt <= 0 then
				dt = 1 / 60
			end

			local state, item, slot = equippedInfo()
			local keys = slotKeys[slot] or slotKeys[1]
			local reloading = state ~= nil and (state[keys.reloadStartServerTime] or 0) ~= 0
			local acting = bit32.band(command.buttons or 0, ACTION_BUTTONS) ~= 0 or WeaponController._firing == true

			local rate = self._lastRate
			local firingStats = item and item.stats and item.stats.firing
			if firingStats and type(firingStats.rate) == "number" then
				rate = firingStats.rate
				self._lastRate = rate
			end

			local stamp = 0
			if state then
				stamp = (state[keys.lastFireServerTime] or 0)
					+ (state[keys.weakNextAllowedServerTime] or 0)
					+ (state[keys.strongNextAllowedServerTime] or 0)
			end
			local fired = false
			if slot ~= self._lastFireSlot then
				self._lastFireSlot = slot
				self._lastFireSeen = stamp
			elseif stamp ~= self._lastFireSeen then
				self._lastFireSeen = stamp
				fired = true
			end

			if applied > 0 then
				command.serverTime -= applied
			end

			local nextAim
			if not self._enabled or bulletRedirection.GetChargeDump() then
				nextAim = math.max(0, applied - rate)
			elseif fired then
				nextAim = math.max(0, applied - rate)
			elseif reloading and self._reloadDrain then
				local reloadStart = (state and state[keys.reloadStartServerTime]) or 0
				local threshold = reloadThreshold(item, state, keys)
				if reloadStart ~= 0 and threshold > 0 then
					local floor = command.serverTime + applied - reloadStart - threshold
					if floor < 0 then
						floor = 0
					end
					nextAim = applied - rate
					if nextAim < floor then
						nextAim = floor
					end
					if nextAim > applied then
						nextAim = applied
					end
				else
					nextAim = applied
				end
			elseif reloading or (state ~= nil and (state.tased == true or (state.pendingHealServerTime or 0) > 0)) then
				nextAim = applied
			elseif acting or bulletRedirection.GetChargeHold() then
				nextAim = applied
			else
				nextAim = applied + dt
				if nextAim > self._maxBank then
					nextAim = math.max(self._maxBank, applied - rate)
				end
			end
			self._aim = nextAim
			bulletRedirection.SetTimeShift("tickManipulation", nextAim)

			if not self._enabled then
				return
			end

			local pct = math.floor(nextAim / self._maxBank * 100 + 0.5)
			if pct > 100 then
				pct = 100
			end
			local draining = acting and applied > 0
			local infoKey = pct
			if draining and pct < 100 then
				infoKey = pct + 1000
			end
			if infoKey ~= self._lastPct then
				self._lastPct = infoKey
				local label
				if pct >= 100 then
					label = "charge: ready"
				elseif draining then
					label = "charge: firing"
				else
					label = "charge: " .. pct .. "%"
				end
				hudState.SetInfo("tickManipulation", label, INFO_ORDER)
			end
		end),
		30
	)
end

function TickManipulation.Destroy(self: TickManipulation): ()
	self._enabled = false
	self._aim = 0
	bulletRedirection.SetTimeShift("tickManipulation", 0)
	bulletRedirection.SetAimShiftCap(0.38)
	bulletRedirection.SetChargeNoWait(false)
	bulletRedirection.SetChargeMaxHealth(0)
	bulletRedirection.SetChargeMinRelease(0)
	Backtrack.SetHistoryDemand("tickManipulation", 0)
	hudState.SetInfo("tickManipulation", nil)
	local unregister = self._unregister
	if unregister then
		unregister()
		self._unregister = nil
	end
	BaseFeature.Destroy(self)
end

export type TickManipulation =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_installed: boolean,
			_aim: number,
			_lastRate: number,
			_lastPct: number,
			_maxBank: number,
			_minPct: number,
			_reloadDrain: boolean,
			_lastFireSeen: number,
			_lastFireSlot: number,
			_unregister: (() -> ())?,
			_pendingUnregister: boolean,
			_install: (TickManipulation) -> (),
		},
		TickManipulation
	))
	& BaseFeature.BaseFeature

return TickManipulation
