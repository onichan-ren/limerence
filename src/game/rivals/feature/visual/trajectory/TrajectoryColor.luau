local ModuleController = require("@game/rivals/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)
local DEFAULT_MATERIAL = "ForceField"
local MATERIALS: { string } = {
	"ForceField",
	"Plastic",
	"Glass",
	"Neon",
}

local function resolveMaterial(name: any): Enum.Material
	return (Enum.Material :: any)[name] or Enum.Material.ForceField
end

local TrajectoryColor = {}
TrajectoryColor.__index = TrajectoryColor

setmetatable(TrajectoryColor, { __index = BaseFeature })

function TrajectoryColor.new(link: gameUi.Linker): TrajectoryColor
	local self = BaseFeature.new() :: any
	setmetatable(self, TrajectoryColor)

	local toggle = link:Toggle("trajectoryColor", "Throwable Prediction", false):SetTip({
		title = "Throwable Prediction",
		body = "Recolors the throw aim trajectory and its impact marker.",
	})
	local trajectoryLink = link:OnKey("trajectoryColor")
	trajectoryLink:Submenu("opts", "Throwable Prediction Options")
	local optsLink = trajectoryLink:OnKey("opts")
	optsLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0)
	optsLink:Dropdown("material", "Material", MATERIALS, DEFAULT_MATERIAL):SetTip({
		title = "Material",
		body = "Material used for the impact marker.",
	})

	self._enabled = false
	self._colorLink = optsLink:Get("color")
	self._materialLink = optsLink:Get("material")
	self._janitor = Janitor.new()
	self._module = nil
	self._originalNew = nil
	self._active = nil

	self:Track(toggle:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track((self._colorLink :: any):OnUpdate(function(): ()
		self:_reapply()
	end))
	self:Track((self._materialLink :: any):OnChange(function(): ()
		self:_reapply()
	end))

	return self
end

function TrajectoryColor._apply(self: TrajectoryColor, inst: any): ()
	if not inst then
		return
	end

	local color = (self._colorLink :: any):GetColor()
	local transparency = (self._colorLink :: any):GetTransparency()
	local material = resolveMaterial(self._materialLink:Peek())

	local sphere = rawget(inst, "_impact_sphere")
	if typeof(sphere) == "Instance" and sphere.Parent then
		sphere.Color = color
		sphere.Material = material
		sphere.Transparency = transparency
	end

	local segments = rawget(inst, "_segments")
	if type(segments) == "table" then
		local sequence = ColorSequence.new(color)
		local transparencySequence = NumberSequence.new(transparency)
		for _, segment in next, segments do
			if typeof(segment) ~= "Instance" or not segment.Parent then
				continue
			end
			segment.Color = color
			segment.Material = material
			local beam = segment:FindFirstChildWhichIsA("Beam")
			if beam then
				beam.Color = sequence
				beam.Transparency = transparencySequence
			end
		end
	end
end

function TrajectoryColor._reapply(self: TrajectoryColor): ()
	if self._enabled and self._active then
		self:_apply(self._active)
	end
end

function TrajectoryColor.Enable(self: TrajectoryColor): ()
	if self._enabled then
		return
	end

	local module = ModuleController.GetModule("TrajectoryVisual")
	local originalNew = module and rawget(module, "new")
	if type(originalNew) ~= "function" then
		return
	end

	self._enabled = true
	self._module = module
	self._originalNew = originalNew
;
	(module :: any).new = function(...): any
		local inst = originalNew(...)
		self._active = inst
		self:_apply(inst)
		return inst
	end

	self._janitor:Add(function(): ()
		if self._module and self._originalNew then
			(self._module :: any).new = self._originalNew
		end
		self._module = nil
		self._originalNew = nil
		self._active = nil
	end, true)
end

function TrajectoryColor.Disable(self: TrajectoryColor): ()
	if not self._enabled then
		return
	end
	self._janitor:Cleanup()
	self._enabled = false
	self._active = nil
end

function TrajectoryColor.Destroy(self: TrajectoryColor): ()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type TrajectoryColor =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_colorLink: any,
			_materialLink: any,
			_janitor: Janitor.Janitor,
			_module: any,
			_originalNew: any,
			_active: any,
		},
		TrajectoryColor
	))
	& BaseFeature.BaseFeature

return TrajectoryColor
