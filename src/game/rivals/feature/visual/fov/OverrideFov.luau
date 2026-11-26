local RunService = cloneref(game:GetService("RunService")) :: RunService
local ModuleController = require("@game/rivals/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local EXTERNAL_KEY = "limerence_fov"

local OverrideFov = {}
OverrideFov.__index = OverrideFov

setmetatable(OverrideFov, { __index = BaseFeature })

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
	fovOptionsLink:Slider("scopeZoom", "Reduce Scope", 0, 0, 100, 1, nil, "%"):SetTip({
		title = "Reduce Scope",
		body = "How much scoped zoom (sniper, crossbow scopes) is toned down. 0% is normal; 100% removes the scope zoom.",
	})
	fovOptionsLink:Slider("adsZoom", "Reduce Zoom", 0, 0, 100, 1, nil, "%"):SetTip({
		title = "Reduce Zoom",
		body = "How much the aim-in zoom of non-scoped weapons (AR, pistols) is toned down. 0% is normal; 100% removes the ADS zoom.",
	})

	self._enabled = false
	self._fov = fovOptionsLink:Get("fov"):Peek()
	self._scopeZoom = fovOptionsLink:Get("scopeZoom"):Peek()
	self._adsZoom = fovOptionsLink:Get("adsZoom"):Peek()
	self._optionsLink = fovOptionsLink
	self._janitor = Janitor.new()
	self._cc = nil
	self._origScoped = nil
	self._origUnscoped = nil

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
	self:Track(fovOptionsLink:Get("scopeZoom"):OnChange(function(value: number): ()
		self._scopeZoom = value
		self:_applyZoom()
	end))
	self:Track(fovOptionsLink:Get("adsZoom"):OnChange(function(value: number): ()
		self._adsZoom = value
		self:_applyZoom()
	end))

	return self
end

function OverrideFov._applyZoom(self: OverrideFov): ()
	local cc = self._cc
	if not cc or not self._enabled then
		return
	end
	if self._origScoped ~= nil then
		cc._fov_offset_strength_scoped = (self._origScoped :: number) * (1 - self._scopeZoom / 100)
	end
	if self._origUnscoped ~= nil then
		cc._fov_offset_strength = (self._origUnscoped :: number) * (1 - self._adsZoom / 100)
	end
end

function OverrideFov.Enable(self: OverrideFov): ()
	if self._enabled then
		return
	end

	local cc = ModuleController.GetModule("CameraController")
	if not cc then
		return
	end

	self._enabled = true
	self._cc = cc
	self._origScoped = cc._fov_offset_strength_scoped
	self._origUnscoped = cc._fov_offset_strength

	self:_applyZoom()

	self._janitor:Add(
		RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
			cc:SetExternalFOVOffset(EXTERNAL_KEY, self._fov - cc._base_fov)
			self:_applyZoom()
		end)),
		"Disconnect"
	)

	self._janitor:Add(function(): ()
		cc:SetExternalFOVOffset(EXTERNAL_KEY, 0)
		if self._origScoped ~= nil then
			cc._fov_offset_strength_scoped = self._origScoped
		end
		if self._origUnscoped ~= nil then
			cc._fov_offset_strength = self._origUnscoped
		end
	end, true)
end

function OverrideFov.Disable(self: OverrideFov): ()
	if not self._enabled then
		return
	end
	self._janitor:Cleanup()
	self._enabled = false
	self._cc = nil
	self._origScoped = nil
	self._origUnscoped = nil
end

function OverrideFov.Destroy(self: OverrideFov): ()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type OverrideFov =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_fov: number,
			_scopeZoom: number,
			_adsZoom: number,
			_janitor: Janitor.Janitor,
			_optionsLink: gameUi.Linker,
			_cc: any,
			_origScoped: number?,
			_origUnscoped: number?,
		},
		OverrideFov
	))
	& BaseFeature.BaseFeature

return OverrideFov
