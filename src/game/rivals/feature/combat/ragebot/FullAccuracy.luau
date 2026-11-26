local ModuleController = require("@game/rivals/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local Janitor = require("@pkg/Janitor")

local FullAccuracy = {}
FullAccuracy.__index = FullAccuracy

setmetatable(FullAccuracy, { __index = BaseFeature })

function FullAccuracy.new(link: gameUi.Linker): FullAccuracy
	local self = BaseFeature.new() :: any
	setmetatable(self, FullAccuracy)

	link:Toggle("fullAccuracy", "Full Accuracy", false):SetTip({
		title = "Full Accuracy",
		body = "Forces your weapons to be fully accurate.",
	})

	self._link = link
	self._enabledLink = link:Get("fullAccuracy")
	self._janitor = Janitor.new()

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	return self
end

function FullAccuracy.Enable(self: FullAccuracy): ()
	if self._enabled then
		return
	end

	self._enabled = true

	local gunModule = ModuleController.GetModule("Gun")
	local isFullyAiming = gunModule and rawget(gunModule, "IsFullyAiming")
	if type(isFullyAiming) ~= "function" then
		return
	end
	hook.add(
		isFullyAiming,
		LPH_NO_VIRTUALIZE(function(...: any): boolean
			return true
		end)
	)

	self._janitor:Add(function()
		hook.restore(isFullyAiming)
	end)
end

function FullAccuracy.Disable(self: FullAccuracy): ()
	if not self._enabled then
		return
	end

	self._enabled = false
	self._janitor:Cleanup()
end

function FullAccuracy.Destroy(self: FullAccuracy): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type FullAccuracy =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabledLink: any,
			_enabled: boolean,
			_janitor: Janitor.Janitor,
		},
		FullAccuracy
	))
	& BaseFeature.BaseFeature

return FullAccuracy
