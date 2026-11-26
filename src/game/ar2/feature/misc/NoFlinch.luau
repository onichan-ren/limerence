local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local hook = require("@share/hook")

local NoFlinch = {}
NoFlinch.__index = NoFlinch

setmetatable(NoFlinch, { __index = BaseFeature })

function NoFlinch.new(link: gameUi.Linker): NoFlinch
	local self = BaseFeature.new() :: any
	setmetatable(self, NoFlinch)

	self._enabled = false
	self._target = nil :: any

	link:Toggle("noFlinch", "No Flinch", false):SetTip({
		title = "No Flinch",
		body = "Stops your view from kicking when you take damage.",
	})

	self:Track(link:Get("noFlinch"):OnChange(function(value: boolean): ()
		self._enabled = value
		if value then
			self:_ensureHook()
		end
	end))

	self._enabled = link:Peek("noFlinch") == true
	if self._enabled then
		self:_ensureHook()
	end

	return self
end

function NoFlinch._ensureHook(self: NoFlinch): ()
	if self._target then
		return
	end

	local camerasModule = ModuleController.GetModule("Cameras")
	if not camerasModule then
		return
	end

	local camera = camerasModule.module:GetCamera("Character")
	local target = camera and rawget(camera, "Flinch")
	if not target then
		return
	end

	self._target = target

	local old
	old = hook.add(
		target,
		LPH_NO_VIRTUALIZE(function(...)
			if self._enabled then
				return
			end
			return old(...)
		end)
	)
end

function NoFlinch.Destroy(self: NoFlinch): ()
	if self._target then
		hook.restore(self._target)
		self._target = nil
	end
	BaseFeature.Destroy(self)
end

export type NoFlinch =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_target: any,
		},
		NoFlinch
	))
	& BaseFeature.BaseFeature

return NoFlinch
