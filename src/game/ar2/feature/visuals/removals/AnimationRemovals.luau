local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local hook = require("@share/hook")

local RunService = cloneref(game:GetService("RunService")) :: RunService

local ANIM_OPTIONS: { string } = { "Reload", "Sprint" }

local AnimationRemovals = {}
AnimationRemovals.__index = AnimationRemovals

setmetatable(AnimationRemovals, { __index = BaseFeature })

local advanceReload = LPH_NO_VIRTUALIZE(function(self: AnimationRemovals, arLocalPlayer: any): ()
	local character = arLocalPlayer.Character
	if not character then
		self._reloadHandled = nil
		return
	end

	local animator = character.Animator
	if not animator or type(animator.IsReloadPlaying) ~= "function" then
		return
	end
	if not animator:IsReloadPlaying() then
		self._reloadHandled = nil
		return
	end

	local callback = animator.ReloadCallback
	if self._reloadHandled == callback then
		return
	end
	self._reloadHandled = callback

	setthreadidentity(2)
	if type(callback) == "function" then
		callback("Commit", "Load")
	end
	animator:RunAction("Stop Firearm Reload", false, "Natural")
	setthreadidentity(8)
end)

function AnimationRemovals.new(link: gameUi.Linker): AnimationRemovals
	local self = BaseFeature.new() :: any
	setmetatable(self, AnimationRemovals)

	self._sprintFn = nil :: ((...any) -> any)?
	self._reloadConn = nil :: RBXScriptConnection?
	self._reloadHandled = nil :: any

	local dropdown = link:Dropdown("animations", "Animations", ANIM_OPTIONS, {}):SetMode("multi")
	dropdown:SetTip({
		title = "Animations",
		body = "Hide the animations you pick.",
	})

	self:Track(dropdown:OnChange(function(value: any): ()
		self:Reconcile(value)
	end))

	self:Reconcile(dropdown:Peek())

	return self
end

function AnimationRemovals.Reconcile(self: AnimationRemovals, selection: any): ()
	local selected: { [string]: boolean } = {}
	if type(selection) == "table" then
		for _, label in next, selection do
			selected[label] = true
		end
	end

	if selected.Sprint then
		self:EnableSprint()
	else
		self:DisableSprint()
	end

	if selected.Reload then
		self:EnableReload()
	else
		self:DisableReload()
	end
end

function AnimationRemovals.EnableSprint(self: AnimationRemovals): ()
	if self._sprintFn then
		return
	end

	local animators = ModuleController.GetModule("Animators")
	local localPlayer = ModuleController.GetModule("LocalPlayer")
	if not animators or not localPlayer then
		return
	end

	local setStateFn = rawget(animators.module, "SetState")
	if type(setStateFn) ~= "function" then
		return
	end

	local getLocal = localPlayer.module.get

	local original
	original = hook.add(
		setStateFn,
		LPH_NO_VIRTUALIZE(function(animator: any, key: any, value: any, ...): ...any
			if key == "MoveState" and value == "Running" then
				local arLocalPlayer = getLocal()
				if arLocalPlayer and arLocalPlayer.Character and animator == arLocalPlayer.Character.Animator then
					return original(animator, key, "Walking", ...)
				end
			end
			return original(animator, key, value, ...)
		end)
	)

	self._sprintFn = setStateFn
end

function AnimationRemovals.DisableSprint(self: AnimationRemovals): ()
	if not self._sprintFn then
		return
	end
	hook.restore(self._sprintFn)
	self._sprintFn = nil
end

function AnimationRemovals.EnableReload(self: AnimationRemovals): ()
	if self._reloadConn then
		return
	end

	local localPlayer = ModuleController.GetModule("LocalPlayer")
	if not localPlayer then
		return
	end

	local arLocalPlayer = localPlayer.module.get()

	self._reloadHandled = nil
	self._reloadConn = RunService.Heartbeat:Connect(function(): ()
		advanceReload(self, arLocalPlayer)
	end)
end

function AnimationRemovals.DisableReload(self: AnimationRemovals): ()
	if self._reloadConn then
		self._reloadConn:Disconnect()
		self._reloadConn = nil
	end
	self._reloadHandled = nil
end

function AnimationRemovals.Destroy(self: AnimationRemovals): ()
	self:DisableSprint()
	self:DisableReload()
	BaseFeature.Destroy(self)
end

export type AnimationRemovals =
	typeof(setmetatable(
		{} :: {
			_sprintFn: ((...any) -> any)?,
			_reloadConn: RBXScriptConnection?,
			_reloadHandled: any,
			Reconcile: (AnimationRemovals, any) -> (),
		},
		AnimationRemovals
	))
	& BaseFeature.BaseFeature

return AnimationRemovals
