local RunService = cloneref(game:GetService("RunService")) :: RunService
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local Janitor = require("@pkg/Janitor")
local ModuleController = require("@game/pf/module/ModuleController")

local OverrideFov = {}
OverrideFov.__index = OverrideFov

setmetatable(OverrideFov, { __index = BaseFeature })

local function getCamera(): any?
	local CameraInterface = ModuleController.GetModule("CameraInterface")
	if not CameraInterface then
		return nil
	end
	return CameraInterface.getActiveCamera("MainCamera", true)
end

local function getCharacterObject(): any?
	local CharacterInterface = ModuleController.GetModule("CharacterInterface")
	if not CharacterInterface then
		return nil
	end
	return CharacterInterface.getCharacterObject()
end

function OverrideFov.new(link: gameUi.Linker): OverrideFov
	local self = BaseFeature.new() :: any
	setmetatable(self, OverrideFov)

	local toggle = link:Toggle("overrideFov", "Override FOV", false):SetTip({
		title = "Override FOV",
		body = "Sets your field of view and can make scoped zoom less extreme.",
	})
	local overrideFovLink = link:OnKey("overrideFov")
	overrideFovLink:Submenu("opts", "Override FOV Options")
	local fovOptionsLink = overrideFovLink:OnKey("opts")
	fovOptionsLink:Slider("fov", "Field of View", 80, 60, 120, 1, nil, "°"):SetTip({
		title = "Field of View",
		body = "How wide your view is while this is enabled.",
	})
	fovOptionsLink:Slider("reduceZoom", "Reduce Zoom", 0, 0, 100, 1, nil, "%"):SetTip({
		title = "Reduce Zoom",
		body = "How much aim-in and scope zoom is toned down. 0% is normal; 100% removes the zoom.",
	})

	self._enabled = false
	self._fov = fovOptionsLink:Get("fov"):Peek()
	self._reduceZoom = fovOptionsLink:Get("reduceZoom"):Peek()
	self._janitor = Janitor.new()
	self._tracked = nil :: any
	self._origFov = nil :: number?
	self._magHooked = nil :: any

	self:Track(toggle:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(fovOptionsLink:Get("fov"):OnChange(function(value: number): ()
		self._fov = value
	end))
	self:Track(fovOptionsLink:Get("reduceZoom"):OnChange(function(value: number): ()
		self._reduceZoom = value
	end))

	return self
end

function OverrideFov.ensureMagHook(self: OverrideFov, cam: any): ()
	if self._magHooked then
		return
	end
	local setMagnification = cam.setMagnification
	if type(setMagnification) ~= "function" then
		return
	end
	self._magHooked = setMagnification

	local original
	original = hook.add(setMagnification, LPH_NO_VIRTUALIZE(function(camera: any, value: any, ...): ...any
		if self._enabled and self._reduceZoom > 0 and type(value) == "number" then
			local restMag = 1
			local baseFov = camera:getBaseFov()
			if type(baseFov) == "number" then
				restMag = math.tan(baseFov * 0.008726646259971648) / math.tan(self._fov * 0.008726646259971648)
			end
			value = restMag + (value - restMag) * (1 - self._reduceZoom / 100)
		end
		return original(camera, value, ...)
	end))
end

function OverrideFov._restoreFov(self: OverrideFov): ()
	if self._tracked and self._origFov ~= nil then
		self._tracked.unaimedfov = self._origFov
	end
	self._tracked = nil
	self._origFov = nil
end

function OverrideFov.Enable(self: OverrideFov): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._janitor:Add(
		RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
			local co = getCharacterObject()
			if co then
				if co ~= self._tracked then
					self:_restoreFov()
					self._tracked = co
					self._origFov = co.unaimedfov
				end
				co.unaimedfov = self._fov
			end
			if not self._magHooked then
				local cam = getCamera()
				if cam then
					self:ensureMagHook(cam)
				end
			end
		end)),
		"Disconnect"
	)

	self._janitor:Add(function(): ()
		self:_restoreFov()
		if self._magHooked then
			hook.restore(self._magHooked)
			self._magHooked = nil
		end
	end, true)
end

function OverrideFov.Disable(self: OverrideFov): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function OverrideFov.Destroy(self: OverrideFov): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type OverrideFov =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_fov: number,
			_reduceZoom: number,
			_janitor: Janitor.Janitor,
			_tracked: any,
			_origFov: number?,
			_magHooked: any,
		},
		OverrideFov
	))
	& BaseFeature.BaseFeature

return OverrideFov
