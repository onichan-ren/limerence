local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local hook = require("@share/hook")

local TweenService = cloneref(game:GetService("TweenService")) :: TweenService

local FAST_DURATION = 0.02

local InstantClimb = {}
InstantClimb.__index = InstantClimb

setmetatable(InstantClimb, { __index = BaseFeature })

function InstantClimb.new(link: gameUi.Linker): InstantClimb
	local self = BaseFeature.new() :: any
	setmetatable(self, InstantClimb)

	self._enabled = false
	self._hooked = false
	self._lpModule = nil :: any
	self._charConn = nil :: RBXScriptConnection?
	self._parkourRot = nil :: Instance?

	link:Toggle("instantClimb", "Instant Climb", false):SetTip({
		title = "Instant Climb",
		body = "Snap onto and over ladders instantly.",
	})

	self:Track(link:Get("instantClimb"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("instantClimb") then
		self:Enable()
	end

	return self
end

function InstantClimb._currentParkourRot(self: InstantClimb): Instance?
	local module = self._lpModule
	local arLocalPlayer = module and module.module.get()
	local character = arLocalPlayer and arLocalPlayer.Character
	return character and character.ParkourAlignRotation or nil
end

function InstantClimb.Enable(self: InstantClimb): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._lpModule = ModuleController.GetModule("LocalPlayer")

	local arLocalPlayer = self._lpModule and self._lpModule.module.get()
	if arLocalPlayer then
		self._charConn = arLocalPlayer.CharacterAdded:Connect(function(): ()
			self._parkourRot = nil
		end)
	end
	self._parkourRot = self:_currentParkourRot()

	if not self._hooked then
		hook.addInstance(TweenService)
		hook.overrideMethod(
			TweenService,
			"Create",
			LPH_NO_VIRTUALIZE(function(instance: any, tweenInfo: any, ...): ...any
				if typeof(tweenInfo) == "TweenInfo" then
					local rot = self._parkourRot
					if not rot then
						rot = self:_currentParkourRot()
						self._parkourRot = rot
					end
					if instance == rot then
						return instance,
							TweenInfo.new(
								FAST_DURATION,
								tweenInfo.EasingStyle,
								tweenInfo.EasingDirection,
								tweenInfo.RepeatCount,
								tweenInfo.Reverses,
								tweenInfo.DelayTime
							),
							...
					end
				end
				return instance, tweenInfo, ...
			end)
		)
		self._hooked = true
	end
end

function InstantClimb.Disable(self: InstantClimb): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._hooked then
		hook.restoreMethod(TweenService, "Create")
		self._hooked = false
	end

	if self._charConn then
		self._charConn:Disconnect()
		self._charConn = nil
	end

	self._parkourRot = nil
end

function InstantClimb.Destroy(self: InstantClimb): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type InstantClimb =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_hooked: boolean,
			_lpModule: any,
			_charConn: RBXScriptConnection?,
			_parkourRot: Instance?,
			_currentParkourRot: (InstantClimb) -> Instance?,
		},
		InstantClimb
	))
	& BaseFeature.BaseFeature

return InstantClimb
