local ModuleController = require("@game/op1/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")

local RunAndGun = {}
RunAndGun.__index = RunAndGun

setmetatable(RunAndGun, { __index = BaseFeature })

local function spoofRunning(owner: any, original: any, gunSelf: any, ...): ()
	local running = owner and owner.states and owner.states.running
	if not running or not running.value then
		original(gunSelf, ...)
		return
	end

	running.value = false
	original(gunSelf, ...)
	running.value = true
end

function RunAndGun.new(link: gameUi.Linker): RunAndGun
	local self = BaseFeature.new() :: any
	setmetatable(self, RunAndGun)

	link:Toggle("runAndGun", "Run And Gun", false):SetTip({
		title = "Run And Gun",
		body = "Lets you fire while sprinting without dropping your sprint.",
	})

	self._enabledLink = link:Get("runAndGun")
	self._renderFn = nil :: any
	self._shootFn = nil :: any

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if self._enabledLink:Peek() then
		self:Enable()
	end

	return self
end

function RunAndGun.Enable(self: RunAndGun): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local gun = ModuleController.GetModule("Gun")
	local render = gun and gun.input_render
	local shoot = gun and gun.input_shoot

	if type(render) == "function" and not hook.isFunctionHooked(render) then
		local old
		old = hook.add(render, function(gunSelf: any, ...)
			spoofRunning(gunSelf.owner, old, gunSelf, ...)
		end)
		self._renderFn = render
	end

	if type(shoot) == "function" and not hook.isFunctionHooked(shoot) then
		local old
		old = hook.add(shoot, function(gunSelf: any, ...)
			spoofRunning(gunSelf.owner, old, gunSelf, ...)
		end)
		self._shootFn = shoot
	end
end

function RunAndGun.Disable(self: RunAndGun): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._renderFn then
		hook.restore(self._renderFn)
		self._renderFn = nil
	end
	if self._shootFn then
		hook.restore(self._shootFn)
		self._shootFn = nil
	end
end

function RunAndGun.Destroy(self: RunAndGun): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type RunAndGun =
	typeof(setmetatable(
		{} :: {
			_enabledLink: any,
			_enabled: boolean,
			_renderFn: any,
			_shootFn: any,
			Enable: (RunAndGun) -> (),
			Disable: (RunAndGun) -> (),
		},
		RunAndGun
	))
	& BaseFeature.BaseFeature

return RunAndGun
