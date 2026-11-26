local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/pf/module/ModuleController")
local hook = require("@share/hook")

local InstantReload = {}
InstantReload.__index = InstantReload

setmetatable(InstantReload, { __index = BaseFeature })

local fillMag = LPH_NO_VIRTUALIZE(function(firearm: any): ()
	local magsize = firearm:getWeaponStat("magsize") or 0
	firearm:applyReloadCount(magsize + 1)
end)

function InstantReload.new(link: gameUi.Linker): InstantReload
	local self = BaseFeature.new() :: any
	setmetatable(self, InstantReload)

	link:Toggle("instantReload", "Instant Reload", false):SetTip({
		title = "Instant Reload",
		body = "Reloads finish instantly with no animation.",
	})

	self._enabled = false
	self._reloadTarget = nil :: any
	self._fireTarget = nil :: any

	self:Track(link:Get("instantReload"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("instantReload") then
		self:Enable()
	end

	return self
end

function InstantReload.Enable(self: InstantReload): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local firearmClass = ModuleController.GetModule("FirearmObject")
	if not firearmClass then
		return
	end

	if type(firearmClass.reload) == "function" then
		local target = firearmClass.reload
		self._reloadTarget = target
		local original
		original = hook.add(
			target,
			LPH_NO_VIRTUALIZE(function(firearm: any, ...: any): ...any
				if firearm and not firearm:isChambering() then
					fillMag(firearm)
					return
				end
				return original(firearm, ...)
			end)
		)
	end

	if type(firearmClass.fireRound) == "function" then
		local target = firearmClass.fireRound
		self._fireTarget = target
		local original
		original = hook.add(
			target,
			LPH_NO_VIRTUALIZE(function(firearm: any, ...: any): ...any
				if firearm and type(firearm._magCount) == "number" and firearm._magCount <= 1 then
					fillMag(firearm)
				end
				return original(firearm, ...)
			end)
		)
	end
end

function InstantReload.Disable(self: InstantReload): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._reloadTarget then
		hook.restore(self._reloadTarget)
		self._reloadTarget = nil
	end
	if self._fireTarget then
		hook.restore(self._fireTarget)
		self._fireTarget = nil
	end
end

function InstantReload.Destroy(self: InstantReload): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type InstantReload =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_reloadTarget: any,
			_fireTarget: any,
		},
		InstantReload
	))
	& BaseFeature.BaseFeature

return InstantReload
