local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)
local DEFAULT_MATERIAL = "ForceField"
local MATERIALS: { string } = {
	"ForceField",
	"Neon",
	"Glass",
	"Plastic",
	"SmoothPlastic",
	"Metal",
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
		body = "Material used for the trajectory nodes and impact marker.",
	})

	self._enabled = false
	self._colorLink = optsLink:Get("color")
	self._materialLink = optsLink:Get("material")
	self._janitor = Janitor.new()
	self._originals = setmetatable({}, { __mode = "k" }) :: any
	self._fx = nil :: Instance?

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

function TrajectoryColor._getFx(self: TrajectoryColor): Instance?
	local fx = self._fx
	if fx and fx.Parent then
		return fx
	end
	local world = Workspace:FindFirstChild("World")
	fx = world and world:FindFirstChild("FX")
	self._fx = fx
	return fx
end

local applyInstance = LPH_NO_VIRTUALIZE(function(self: any, inst: Instance, color: Color3, transparency: number, material: Enum.Material): ()
	if inst:IsA("BasePart") then
		if self._originals[inst] == nil then
			if inst.Transparency >= 1 then
				return
			end
			self._originals[inst] = {
				kind = "part",
				Color = inst.Color,
				Material = inst.Material,
				Transparency = inst.Transparency,
			}
		end
		inst.Color = color
		if inst.Name == "PathImpact" then
			inst.Material = material
			inst.Transparency = transparency
		end
	elseif inst:IsA("Beam") then
		if self._originals[inst] == nil then
			self._originals[inst] = {
				kind = "beam",
				Color = inst.Color,
				Transparency = inst.Transparency,
			}
		end
		inst.Color = ColorSequence.new(color)
		inst.Transparency = NumberSequence.new(transparency)
	end
end)

function TrajectoryColor._applyRoot(self: TrajectoryColor, root: Instance?): ()
	if not root then
		return
	end
	local color = (self._colorLink :: any):GetColor()
	local transparency = (self._colorLink :: any):GetTransparency()
	local material = resolveMaterial(self._materialLink:Peek())
	applyInstance(self, root, color, transparency, material)
	for _, descendant in next, root:QueryDescendants("Instance") do
		applyInstance(self, descendant, color, transparency, material)
	end
end

function TrajectoryColor._apply(self: TrajectoryColor): ()
	local misc = ReplicatedStorage.Assets:FindFirstChild("Misc")
	if misc then
		self:_applyRoot(misc:FindFirstChild("PathImpact"))
		self:_applyRoot(misc:FindFirstChild("PathVisualNode"))
	end
	local fx = self:_getFx()
	self:_applyRoot(fx and fx:FindFirstChild("TrajectoryPreview"))
end

function TrajectoryColor._reapply(self: TrajectoryColor): ()
	if self._enabled then
		self:_apply()
	end
end

local restore = LPH_NO_VIRTUALIZE(function(self: any): ()
	for inst, original in next, self._originals do
		if inst.Parent then
			if original.kind == "part" then
				inst.Color = original.Color
				inst.Material = original.Material
				inst.Transparency = original.Transparency
			else
				inst.Color = original.Color
				inst.Transparency = original.Transparency
			end
		end
		self._originals[inst] = nil
	end
end)

function TrajectoryColor.Enable(self: TrajectoryColor): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self:_apply()
	self._janitor:Add(function(): ()
		restore(self)
	end, true)
end

function TrajectoryColor.Disable(self: TrajectoryColor): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function TrajectoryColor.Destroy(self: TrajectoryColor): ()
	self:Disable()
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
			_originals: any,
			_fx: Instance?,
		},
		TrajectoryColor
	))
	& BaseFeature.BaseFeature

return TrajectoryColor
