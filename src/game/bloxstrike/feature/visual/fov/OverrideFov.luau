local ModuleController = require("@game/bloxstrike/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

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
	fovOptionsLink:Slider("fov", "Field of View", 70, 60, 100, 1, nil, "°"):SetTip({
		title = "Field of View",
		body = "How wide your view is while this is enabled.",
	})
	fovOptionsLink:Slider("scopeZoom", "Reduce Zoom", 10, 0, 100, 1, nil, "%"):SetTip({
		title = "Reduce Zoom",
		body = "How much scoped zoom is reduced. 100% keeps normal scope FOV; lower values zoom out more while scoped.",
	})

	self._enabled = false

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
	end))

	self._fov = fovOptionsLink:Get("fov"):Peek()
	self._scopeZoom = fovOptionsLink:Get("scopeZoom"):Peek()
	self._optionsLink = fovOptionsLink
	self._janitor = Janitor.new()

	if toggle:Peek() then
		self:Enable()
	end

	return self
end

function OverrideFov.Enable(self: OverrideFov): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local CameraController = ModuleController.GetModule("CameraController")
	local updateCameraFOV = rawget(CameraController, "updateCameraFOV") :: any
	local updateCamera = rawget(CameraController, "updateCamera") :: any

	if not updateCameraFOV then
		return
	end

	local spring: any = nil
	local springIdx: number? = nil
	for idx, value in next, debug.getupvalues(updateCameraFOV) do
		if type(value) == "table" and type(rawget(value, "setGoal")) == "function" then
			spring = value
			springIdx = idx
			break
		end
	end
	if not spring or not springIdx then
		return
	end
	local currentScoped = nil :: number?
	debug.setupvalue(updateCameraFOV, springIdx, {
		setGoal = LPH_NO_VIRTUALIZE(function(_: any, value: number): ()
			if value == 70 then
				currentScoped = nil
				return spring:setGoal(self._fov)
			end
			currentScoped = (70 - value)
			local scopedValue = currentScoped :: number * ((100 - self._scopeZoom) / 100)
			return spring:setGoal(self._fov - scopedValue)
		end),
	})

	getfenv(updateCamera).math = {
		clamp = function(value: number): number
			return value
		end,
		abs = function(value: number): number
			return math.abs(value)
		end,
	}

	self._janitor:Add(function()
		debug.setupvalue(updateCameraFOV, 2, spring)
		getfenv(updateCamera).math = nil
	end, true)

	self._janitor:Add(
		self._optionsLink:Get("fov"):OnChange(function(value: number): ()
			self._fov = value
			spring:setGoal(self._fov)
		end),
		true
	)
	self._janitor:Add(
		self._optionsLink:Get("scopeZoom"):OnChange(function(value: number): ()
			self._scopeZoom = value
			if currentScoped then
				local scopedValue = currentScoped :: number * ((100 - self._scopeZoom) / 100)
				spring:setGoal(self._fov - scopedValue)
			end
		end),
		true
	)

	spring:setGoal(self._fov)
end

function OverrideFov.Disable(self: OverrideFov): ()
	if not self._enabled then
		return
	end
	self._janitor:Cleanup()
	self._enabled = false
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
			_janitor: Janitor.Janitor,
			_scopeZoom: number,
			_optionsLink: gameUi.Linker,
		},
		OverrideFov
	))
	& BaseFeature.BaseFeature

return OverrideFov
