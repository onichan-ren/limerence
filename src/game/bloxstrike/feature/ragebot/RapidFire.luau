local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local peek = Charm.peek

local MAX_RATE = 60

local intervalFromPercent = LPH_NO_VIRTUALIZE(function(percent: number): number
	local rate = (percent / 100) * MAX_RATE
	return rate > 0 and 1 / rate or 0
end)

local RapidFire = {}
RapidFire.__index = RapidFire

setmetatable(RapidFire, { __index = BaseFeature })

local _instance: any = nil

local tryFireShot = LPH_NO_VIRTUALIZE(function(weapon: any): ()
	if not weapon then
		return
	end
	if weapon.IsReloading or weapon.IsAdjustingSuppressor or weapon.IsChargeFiring then
		return
	end
	if (weapon.Rounds or 0) <= 0 then
		return
	end
	if weapon.IsEquipped ~= true then
		return
	end

	local thread = weapon.ShootDelayThread
	if weapon.IsFireHeld and thread and coroutine.status(thread) == "suspended" then
		coroutine.resume(thread)
	elseif weapon.IsShooting then
		weapon.IsShooting = false
	end
	if weapon.Recoil then
		weapon.Recoil.Time = 0
	end
end)

function RapidFire.new(link: gameUi.Linker): RapidFire
	local self = BaseFeature.new() :: any
	setmetatable(self, RapidFire)

	link:Toggle("rapidFire", "Rapid Fire", false):SetTip({
		title = "Rapid Fire",
		body = "Allows you to fire as fast as you want.",
	})
	local masterLink = link:OnKey("rapidFire")
	masterLink:Submenu("opts", "Rapid Fire")
	local optsLink = masterLink:OnKey("opts")
	optsLink:Slider("speed", "Speed", 100, 1, 100, 1, nil, "%"):SetTip({
		title = "Speed",
		body = "How fast to fire, as a percent of max.",
	})

	self._janitor = Janitor.new()
	self._enabled = false
	self._enabledLink = link:Get("rapidFire")
	self._lastFire = 0
	local percent = optsLink:Peek("speed") or 100
	self._interval = intervalFromPercent(percent)

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(link:Watch("rapidFire.opts.speed", function(value: number): ()
		self._interval = intervalFromPercent(value)
	end))

	if link:Peek("rapidFire") then
		self:Enable()
	end

	_instance = self
	return self
end

function RapidFire.Enable(self: RapidFire): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._janitor:Add(
		RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
			local now = os.clock()
			if now - self._lastFire < self._interval then
				return
			end
			self._lastFire = now
			local weapon = peek(loadoutState.currentEquipped) :: any
			tryFireShot(weapon)
		end)),
		"Disconnect"
	)
end

function RapidFire.Disable(self: RapidFire): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function RapidFire.Destroy(self: RapidFire): ()
	self:Disable()
	if (_instance :: any) == self then
		_instance = nil
	end
	BaseFeature.Destroy(self)
end

function RapidFire.IsEnabled(): boolean
	return _instance ~= nil and _instance._enabled == true
end

function RapidFire.GetInterval(): number
	if _instance == nil or not _instance._enabled then
		return 0
	end
	return _instance._interval
end

export type RapidFire =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_enabledLink: any,
			_janitor: Janitor.Janitor,
			_lastFire: number,
			_interval: number,
		},
		RapidFire
	))
	& BaseFeature.BaseFeature

return RapidFire
