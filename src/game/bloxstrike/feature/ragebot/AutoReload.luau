local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local peek = Charm.peek

local AutoReload = {}
AutoReload.__index = AutoReload

setmetatable(AutoReload, { __index = BaseFeature })

local _instance: any = nil

local tryReload = LPH_JIT_MAX(function(weapon: any): ()
	if not weapon then
		return
	end
	if weapon.IsEquipped ~= true then
		return
	end
	if weapon.IsReloading or weapon.IsShooting or weapon.IsAdjustingSuppressor or weapon.IsChargeFiring then
		return
	end
	if (weapon.Rounds or 0) > 0 then
		return
	end
	if (weapon.Capacity or 0) <= 0 then
		return
	end
	if type(weapon.reload) ~= "function" then
		return
	end
	setthreadidentity(8)
	weapon.reload(weapon)
end)

function AutoReload.new(link: gameUi.Linker): AutoReload
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoReload)

	link:Toggle("autoReload", "Auto Reload", false):SetTip({
		title = "Auto Reload",
		body = "Reloads for you as soon as your magazine is empty.",
	})

	self._janitor = Janitor.new()
	self._enabled = false
	self._enabledLink = link:Get("autoReload")

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("autoReload") then
		self:Enable()
	end

	_instance = self
	return self
end

function AutoReload.Enable(self: AutoReload): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._janitor:Add(
		RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
			local weapon = peek(loadoutState.currentEquipped) :: any
			tryReload(weapon)
		end)),
		"Disconnect"
	)
end

function AutoReload.Disable(self: AutoReload): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function AutoReload.Destroy(self: AutoReload): ()
	self:Disable()
	if (_instance :: any) == self then
		_instance = nil
	end
	BaseFeature.Destroy(self)
end

function AutoReload.IsEnabled(): boolean
	return _instance ~= nil and _instance._enabled == true
end

export type AutoReload =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_enabledLink: any,
			_janitor: Janitor.Janitor,
		},
		AutoReload
	))
	& BaseFeature.BaseFeature

return AutoReload
