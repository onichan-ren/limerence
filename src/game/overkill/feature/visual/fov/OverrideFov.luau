local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/overkill/module/ModuleController")

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local OverrideFov = {}
OverrideFov.__index = OverrideFov

setmetatable(OverrideFov, { __index = BaseFeature })

function OverrideFov.new(link: gameUi.Linker): OverrideFov
	local self = BaseFeature.new() :: any
	setmetatable(self, OverrideFov)

	local toggle = link:Toggle("overrideFov", "Override FOV", false):SetTip({
		title = "Override FOV",
		body = "Sets your field of view and can make aim-in zoom less extreme.",
	})
	local overrideFovLink = link:OnKey("overrideFov")
	overrideFovLink:Submenu("opts", "Override FOV Options")
	local optsLink = overrideFovLink:OnKey("opts")
	optsLink:Slider("fov", "Field of View", 80, 60, 120, 1, nil, "°"):SetTip({
		title = "Field of View",
		body = "How wide your view is while this is enabled.",
	})
	optsLink:Slider("reduceZoom", "Reduce Zoom", 0, 0, 100, 1, nil, "%"):SetTip({
		title = "Reduce Zoom",
		body = "How much aim-in zoom is toned down. 0% is normal; 100% removes the zoom.",
	})

	self._enabled = false
	self._fov = optsLink:Get("fov"):Peek()
	self._reduceZoom = optsLink:Get("reduceZoom"):Peek()
	self._installed = false

	self:Track(toggle:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optsLink:Get("fov"):OnChange(function(value: number): ()
		self._fov = value
	end))
	self:Track(optsLink:Get("reduceZoom"):OnChange(function(value: number): ()
		self._reduceZoom = value
	end))

	return self
end

function OverrideFov._install(self: OverrideFov): ()
	if self._installed then
		return
	end
	local cameraHandler = ModuleController.GetModule("cameraHandler")
	if not cameraHandler then
		return
	end
	self._installed = true

	setthreadidentity(2)
	cameraHandler:addPostUpdateHook(LPH_NO_VIRTUALIZE(function(): ()
		if not self._enabled then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local value = camera.FieldOfView
		local baseFov = cameraHandler.baseFOV or 80
		local zoomDelta = (baseFov - value) * (1 - self._reduceZoom / 100)
		camera.FieldOfView = self._fov - zoomDelta
	end))
	setthreadidentity(8)
end

function OverrideFov.Enable(self: OverrideFov): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self:_install()
end

function OverrideFov.Disable(self: OverrideFov): ()
	self._enabled = false
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
			_installed: boolean,
		},
		OverrideFov
	))
	& BaseFeature.BaseFeature

return OverrideFov
