local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local ModuleController = require("@game/pf/module/ModuleController")
local ScopeController = require("@feature/ui/scope/ScopeController")

local RunService = cloneref(game:GetService("RunService")) :: RunService

local PREFIX = "recoil"

local RecoilControl = {}
RecoilControl.__index = RecoilControl

setmetatable(RecoilControl, { __index = BaseFeature })

local function getCamera(): any?
	local CameraInterface = ModuleController.GetModule("CameraInterface")
	if not CameraInterface then
		return nil
	end
	return CameraInterface.getActiveCamera("MainCamera", true)
end

function RecoilControl.new(link: gameUi.Linker): RecoilControl
	local self = BaseFeature.new() :: any
	setmetatable(self, RecoilControl)

	self._enabledValue = false
	self._installed = false
	self._hScale = 1
	self._vScale = 0.5
	self._origGetP = nil :: any
	self._shadowed = setmetatable({}, { __mode = "k" }) :: any
	self._setBody = nil :: any
	self._setHead = nil :: any
	self._waitConn = nil :: RBXScriptConnection?

	link:Toggle("enabled", "Enable", false):SetTip({
		title = "Recoil Control",
		body = "Counters this weapon's recoil while firing.",
	})
	link:Slider("horizontal", "Horizontal", 0, 0, 100, 1, nil, "%"):SetTip({
		title = "Horizontal",
		body = "How much horizontal (left/right) recoil to remove. 100% removes all horizontal kick.",
	})
	link:Slider("vertical", "Vertical", 50, 0, 100, 1, nil, "%"):SetTip({
		title = "Vertical",
		body = "How much vertical (up/down) recoil to remove. 100% removes all vertical kick.",
	})

	self._wrapper = function(spring: any): Vector3
		local p = self._origGetP(spring)
		if not self._installed then
			return p
		end
		return Vector3.new(p.X * self._vScale, p.Y * self._hScale, p.Z)
	end

	self:Track(ScopeController.OnChange(PREFIX .. ".horizontal", function(v: any): ()
		self._hScale = 1 - (tonumber(v) or 0) / 100
	end))
	self:Track(ScopeController.OnChange(PREFIX .. ".vertical", function(v: any): ()
		self._vScale = 1 - (tonumber(v) or 0) / 100
	end))
	self:Track(ScopeController.OnChange(PREFIX .. ".enabled", function(v: any): ()
		self._enabledValue = v == true
		self:_apply()
	end))

	return self
end

function RecoilControl._shadow(self: RecoilControl, spring: any): ()
	local shadowed: { [any]: boolean } = self._shadowed
	local wrapper = self._wrapper
	if not spring or shadowed[spring] then
		return
	end
	spring.getP = wrapper
	shadowed[spring] = true
end

function RecoilControl._apply(self: RecoilControl): ()
	if self._enabledValue then
		self:_install()
	else
		self:_uninstall()
	end
end

function RecoilControl._install(self: RecoilControl): ()
	if self._installed then
		return
	end

	local cam = getCamera()
	local body = cam and rawget(cam, "_cameraBodySprings")
	if not self._origGetP and body then
		local mt = getmetatable(body)
		self._origGetP = mt and rawget(mt, "getP")
	end
	if not self._origGetP then
		self:_startWait()
		return
	end

	self._installed = true

	if cam then
		self:_shadow(rawget(cam, "_cameraBodySprings"))
		self:_shadow(rawget(cam, "_cameraHeadSprings"))
	end

	local mco = ModuleController.GetModule("MainCameraObject")
	local setBody = mco and rawget(mco, "setBodyParameters")
	local setHead = mco and rawget(mco, "setHeadParameters")

	if type(setBody) == "function" then
		self._setBody = setBody
		local original
		original = hook.add(
			setBody,
			LPH_NO_VIRTUALIZE(function(camera: any, ...: any): ...any
				local result = { original(camera, ...) }
				if self._installed then
					self:_shadow(rawget(camera, "_cameraBodySprings"))
				end
				return table.unpack(result)
			end)
		)
	end

	if type(setHead) == "function" then
		self._setHead = setHead
		local original
		original = hook.add(
			setHead,
			LPH_NO_VIRTUALIZE(function(camera: any, ...: any): ...any
				local result = { original(camera, ...) }
				if self._installed then
					self:_shadow(rawget(camera, "_cameraHeadSprings"))
				end
				return table.unpack(result)
			end)
		)
	end
end

function RecoilControl._uninstall(self: RecoilControl): ()
	self:_stopWait()
	if not self._installed then
		return
	end
	self._installed = false

	for spring in next, self._shadowed do
		if rawget(spring, "getP") == self._wrapper then
			spring.getP = nil
		end
	end
	table.clear(self._shadowed)

	if self._setBody then
		hook.restore(self._setBody)
		self._setBody = nil
	end
	if self._setHead then
		hook.restore(self._setHead)
		self._setHead = nil
	end
end

function RecoilControl._startWait(self: RecoilControl): ()
	if self._waitConn then
		return
	end
	self._waitConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
		if not self._enabledValue then
			self:_stopWait()
			return
		end
		local cam = getCamera()
		if cam and rawget(cam, "_cameraBodySprings") then
			self:_stopWait()
			self:_install()
		end
	end))
end

function RecoilControl._stopWait(self: RecoilControl): ()
	if self._waitConn then
		self._waitConn:Disconnect()
		self._waitConn = nil
	end
end

function RecoilControl.Destroy(self: RecoilControl): ()
	self:_uninstall()
	BaseFeature.Destroy(self)
end

export type RecoilControl =
	typeof(setmetatable(
		{} :: {
			_enabledValue: boolean,
			_installed: boolean,
			_hScale: number,
			_vScale: number,
			_origGetP: any,
			_wrapper: (any) -> Vector3,
			_shadowed: any,
			_setBody: any,
			_setHead: any,
			_waitConn: RBXScriptConnection?,
		},
		RecoilControl
	))
	& BaseFeature.BaseFeature

return RecoilControl
