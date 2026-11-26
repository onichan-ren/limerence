local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/rivals/module/ModuleController")
local patchConstant = require("@game/rivals/util/patchConstant")

local RARE_ROLL = 0.1

local ForceRareInspects = {}
ForceRareInspects.__index = ForceRareInspects

setmetatable(ForceRareInspects, { __index = BaseFeature })

function ForceRareInspects.new(link: gameUi.Linker): ForceRareInspects
	local self = BaseFeature.new() :: any
	setmetatable(self, ForceRareInspects)

	link:Toggle("forceRareInspects", "Force Rare Inspects", false):SetTip({
		title = "Force Rare Inspects",
		body = "Inspecting always plays the special animation when one exists.",
	})

	self._enabled = false
	self._target = nil :: ((...any) -> any)?
	self._indices = {} :: { number }

	self:Track(link:Get("forceRareInspects"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("forceRareInspects") then
		self:Enable()
	end

	return self
end

function ForceRareInspects._installHook(self: ForceRareInspects): boolean
	if self._target then
		return true
	end

	local animator = ModuleController.GetModule("ViewModelAnimator")
	local inspect = animator and rawget(animator, "Inspect")
	if type(inspect) ~= "function" then
		return false
	end

	self._indices = patchConstant.apply(inspect, RARE_ROLL, 1)
	self._target = inspect
	return true
end

function ForceRareInspects.Enable(self: ForceRareInspects): ()
	if self._enabled then
		return
	end
	self._enabled = true

	if not self:_installHook() then
		task.spawn(function(): ()
			while self._enabled and not self._target do
				task.wait(1)
				self:_installHook()
			end
		end)
	end
end

function ForceRareInspects.Disable(self: ForceRareInspects): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._target then
		patchConstant.restore(self._target, self._indices, RARE_ROLL)
		self._target = nil
		self._indices = {}
	end
end

function ForceRareInspects.Destroy(self: ForceRareInspects): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ForceRareInspects =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_target: ((...any) -> any)?,
			_indices: { number },
		},
		ForceRareInspects
	))
	& BaseFeature.BaseFeature

return ForceRareInspects
