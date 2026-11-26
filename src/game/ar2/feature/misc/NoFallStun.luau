local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local hook = require("@share/hook")

local NoFallStun = {}
NoFallStun.__index = NoFallStun

setmetatable(NoFallStun, { __index = BaseFeature })

function NoFallStun.new(link: gameUi.Linker): NoFallStun
	local self = BaseFeature.new() :: any
	setmetatable(self, NoFallStun)

	self._enabled = false
	self._animTarget = nil :: any

	link:Toggle("noFallStun", "No Fall Stun", false):SetTip({
		title = "No Fall Stun",
		body = "Removes the landing impact that locks your movement.",
	})

	self:Track(link:Get("noFallStun"):OnChange(function(value: boolean): ()
		self._enabled = value
		if value then
			self:_ensureHook()
		end
	end))

	self._enabled = link:Peek("noFallStun") == true
	if self._enabled then
		self:_ensureHook()
	end

	return self
end

function NoFallStun._ensureHook(self: NoFallStun): ()
	if self._animTarget then
		return
	end

	local animators = ModuleController.GetModule("Animators")
	local target = animators and rawget(animators.module, "PlayAnimation")
	if not target then
		return
	end

	self._animTarget = target

	local old
	old = hook.add(
		target,
		LPH_NO_VIRTUALIZE(function(animator: any, name: string, ...)
			if self._enabled and name == "Actions.Fall Impact" then
				return
			end
			return old(animator, name, ...)
		end)
	)
end

function NoFallStun.Destroy(self: NoFallStun): ()
	if self._animTarget then
		hook.restore(self._animTarget)
		self._animTarget = nil
	end
	BaseFeature.Destroy(self)
end

export type NoFallStun =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_animTarget: any,
		},
		NoFallStun
	))
	& BaseFeature.BaseFeature

return NoFallStun
