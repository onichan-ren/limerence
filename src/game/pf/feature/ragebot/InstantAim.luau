local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local ModuleController = require("@game/pf/module/ModuleController")

local AIM_SPRING_SPEED = 9999

local InstantAim = {}
InstantAim.__index = InstantAim

setmetatable(InstantAim, { __index = BaseFeature })

function InstantAim.new(link: gameUi.Linker): InstantAim
	local self = BaseFeature.new() :: any
	setmetatable(self, InstantAim)

	link:Toggle("instantAim", "Instant Aim", false):SetTip({
		title = "Instant Aim",
		body = "Snaps to aim instantly with no transition.",
	})

	self._enabled = false
	self._hooked = nil

	self:Track(link:Get("instantAim"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("instantAim") then
		self:Enable()
	end

	return self
end

local boost = LPH_NO_VIRTUALIZE(function(firearm: any): ()
	local co = firearm._characterObject
	if co then
		co:getSpring("masteraimspring").s = AIM_SPRING_SPEED
		co:getSpring("zoommodspring").s = AIM_SPRING_SPEED
	end
	if firearm._aimArmSpring then
		firearm._aimArmSpring.s = AIM_SPRING_SPEED
	end
	local stats = firearm._activeAimStats
	if type(stats) == "table" then
		for _, stat in next, stats do
			if stat.sightmagspring then
				stat.sightmagspring.s = AIM_SPRING_SPEED
			end
			if stat.sightaimspring then
				stat.sightaimspring.s = AIM_SPRING_SPEED
			end
		end
	end
end)

function InstantAim.Enable(self: InstantAim): ()
	if self._enabled then
		return
	end
	self._enabled = true

	if self._hooked then
		return
	end

	local FirearmObject = ModuleController.GetModule("FirearmObject")
	if not FirearmObject then
		return
	end
	local updateAimStats = rawget(FirearmObject, "updateAimStats")
	if type(updateAimStats) ~= "function" then
		return
	end
	self._hooked = updateAimStats

	local original
	original = hook.add(updateAimStats, LPH_NO_VIRTUALIZE(function(firearm: any, ...): ...any
		local result = table.pack(original(firearm, ...))
		if self._enabled then
			boost(firearm)
		end
		return table.unpack(result, 1, result.n)
	end))
end

function InstantAim.Disable(self: InstantAim): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._hooked then
		hook.restore(self._hooked)
		self._hooked = nil
	end
end

function InstantAim.Destroy(self: InstantAim): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type InstantAim =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_hooked: any,
		},
		InstantAim
	))
	& BaseFeature.BaseFeature

return InstantAim
