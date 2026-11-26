local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local ModuleController = require("@game/pf/module/ModuleController")

local RunService = cloneref(game:GetService("RunService")) :: RunService

local ReduceRecoil = {}
ReduceRecoil.__index = ReduceRecoil

setmetatable(ReduceRecoil, { __index = BaseFeature })

function ReduceRecoil.new(link: gameUi.Linker): ReduceRecoil
	local self = BaseFeature.new() :: any
	setmetatable(self, ReduceRecoil)

	link:Toggle("reduceRecoil", "Reduce Recoil", false):SetTip({
		title = "Reduce Recoil",
		body = "Reduces view and weapon kick while shooting. Tune vertical and horizontal separately.",
	})

	local masterLink = link:OnKey("reduceRecoil")
	masterLink:Submenu("opts", "Reduce Recoil")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Slider("amount", "Amount", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Amount",
		body = "How much recoil to remove. 100% removes all view kick.",
	})

	self._enabled = false
	self._scale = 0
	self._hooked = nil
	self._waitConn = nil

	self:Track(link:Watch("reduceRecoil.opts.amount", function(v: any): ()
		self._scale = 1 - (tonumber(v) or 100) / 100
	end))

	self:Track(link:Get("reduceRecoil"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("reduceRecoil") then
		self:Enable()
	end

	return self
end

local function getCamera(): any?
	local CameraInterface = ModuleController.GetModule("CameraInterface")
	if not CameraInterface then
		return nil
	end
	return CameraInterface.getActiveCamera("MainCamera", true)
end

function ReduceRecoil.ensureHook(self: ReduceRecoil): ()
	if self._hooked then
		return
	end
	local cam = getCamera()
	if not cam then
		return
	end
	local applyImpulse = cam.applyImpulse
	if type(applyImpulse) ~= "function" then
		return
	end
	self._hooked = applyImpulse

	local original
	original = hook.add(
		applyImpulse,
		LPH_NO_VIRTUALIZE(function(camera: any, mult: any, ...): ...any
			if self._enabled and type(mult) == "number" then
				return original(camera, mult * self._scale, ...)
			end
			return original(camera, mult, ...)
		end)
	)
end

function ReduceRecoil.Enable(self: ReduceRecoil): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self:ensureHook()
	if self._hooked then
		return
	end

	self._waitConn = RunService.Heartbeat:Connect(function(): ()
		self:ensureHook()
		if self._hooked and self._waitConn then
			self._waitConn:Disconnect()
			self._waitConn = nil
		end
	end)
end

function ReduceRecoil.Disable(self: ReduceRecoil): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._waitConn then
		self._waitConn:Disconnect()
		self._waitConn = nil
	end
	if self._hooked then
		hook.restore(self._hooked)
		self._hooked = nil
	end
end

function ReduceRecoil.Destroy(self: ReduceRecoil): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ReduceRecoil =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_scale: number,
			_hooked: any,
			_waitConn: RBXScriptConnection?,
		},
		ReduceRecoil
	))
	& BaseFeature.BaseFeature

return ReduceRecoil
