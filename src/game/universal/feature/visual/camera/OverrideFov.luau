local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")

local BIND_NAME = "limerence_overrideFov"
local BIND_PRIORITY = Enum.RenderPriority.Camera.Value + 1
local DEFAULT_FOV = 70

local OverrideFov = {}
OverrideFov.__index = OverrideFov

setmetatable(OverrideFov, { __index = BaseFeature })

function OverrideFov.new(link: gameUi.Linker): OverrideFov
	local self = BaseFeature.new() :: any
	setmetatable(self, OverrideFov)

	local toggle = link:Toggle("overrideFov", "Override FOV", false):SetTip({
		title = "Override FOV",
		body = "Sets your field of view.",
	})
	local overrideFovLink = link:OnKey("overrideFov")
	overrideFovLink:Submenu("opts", "Override FOV Options")
	local fovOptionsLink = overrideFovLink:OnKey("opts")
	fovOptionsLink:Slider("fov", "Field of View", 80, 60, 120, 1, nil, "°"):SetTip({
		title = "Field of View",
		body = "How wide your view is while this is enabled.",
	})

	self._enabled = false
	self._bound = false
	self._fov = fovOptionsLink:Get("fov"):Peek()
	self._original = DEFAULT_FOV

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

	return self
end

OverrideFov._step = LPH_NO_VIRTUALIZE(function(self: OverrideFov): ()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = self._fov
	end
end)

function OverrideFov.Enable(self: OverrideFov): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local camera = Workspace.CurrentCamera
	self._original = camera and camera.FieldOfView or DEFAULT_FOV

	if not self._bound then
		self._bound = true
		RunService:BindToRenderStep(
			BIND_NAME,
			BIND_PRIORITY,
			LPH_NO_VIRTUALIZE(function(): ()
				self:_step()
			end)
		)
	end
end

function OverrideFov.Disable(self: OverrideFov): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._bound then
		RunService:UnbindFromRenderStep(BIND_NAME)
		self._bound = false
	end

	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = self._original
	end
end

function OverrideFov.Destroy(self: OverrideFov): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type OverrideFov =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_bound: boolean,
			_fov: number,
			_original: number,
		},
		OverrideFov
	))
	& BaseFeature.BaseFeature

return OverrideFov
