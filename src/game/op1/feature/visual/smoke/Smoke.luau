local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local SmokeController = require("@game/op1/smoke/SmokeController")

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)
local DEFAULT_TRANSPARENCY = 0.8

local MATERIAL_DEFAULT = "Default"
local MATERIAL_OPTIONS = { MATERIAL_DEFAULT, "ForceField", "Neon", "Glass" }
local MATERIAL_MAP: { [string]: Enum.Material } = {
	Neon = Enum.Material.Neon,
	ForceField = Enum.Material.ForceField,
	SmoothPlastic = Enum.Material.SmoothPlastic,
	Glass = Enum.Material.Glass,
	Plastic = Enum.Material.Plastic,
	Metal = Enum.Material.Metal,
}

local Smoke = {}
Smoke.__index = Smoke

setmetatable(Smoke, { __index = BaseFeature })

export type Smoke = typeof(setmetatable({} :: any, Smoke))

function Smoke.new(link: gameUi.Linker): Smoke
	local self = BaseFeature.new() :: any
	setmetatable(self, Smoke)

	self._janitor = nil :: Janitor.Janitor?
	self._target = DEFAULT_TRANSPARENCY
	self._color = DEFAULT_COLOR
	self._material = nil :: Enum.Material?

	link:Toggle("smoke", "Smoke", false):SetTip({
		title = "Smoke",
		body = "Recolors smoke clouds and lets you see through them.",
	})
	link:Extra(link:Get("smoke"), "smokeOpts", "Submenu", "Smoke")
	local opts = link:OnKey("smokeOpts")
	self._opts = opts

	opts:Colorpicker("color", "Color", DEFAULT_COLOR, DEFAULT_TRANSPARENCY):SetTip({
		title = "Color",
		body = "Smoke color and how transparent it becomes.",
	})
	opts:Dropdown("material", "Material", MATERIAL_OPTIONS, MATERIAL_DEFAULT):SetTip({
		title = "Material",
		body = "Material applied to the smoke.",
	})

	self:Track(link:Get("smoke"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("smoke") then
		self:Enable()
	end

	return self
end

function Smoke.Refresh(self: Smoke): ()
	local picker: any = self._opts:Get("color")
	self._color = picker and picker:GetColor() or DEFAULT_COLOR
	self._target = picker and picker:GetTransparency() or 0
	self._material = MATERIAL_MAP[self._opts:Peek("material")]
	self:Reclamp()
end

function Smoke.Apply(self: Smoke, part: BasePart): ()
	part.Color = self._color
	if self._material then
		part.Material = self._material
	end
	local target = self._target
	if target > 0 and part.Transparency < target then
		part.Transparency = target
	end
end

function Smoke.Clamp(self: Smoke, part: BasePart): ()
	local target = self._target
	if target > 0 and part.Transparency < target then
		part.Transparency = target
	end
end

function Smoke.Reclamp(self: Smoke): ()
	if not self._janitor then
		return
	end
	for part in next, SmokeController.GetVoxels() do
		self:Apply(part)
	end
end

function Smoke.HookVoxel(self: Smoke, part: BasePart): ()
	local janitor = self._janitor
	if not janitor then
		return
	end

	self:Apply(part)

	janitor:Add(
		part:GetPropertyChangedSignal("Transparency"):Connect(function(): ()
			self:Clamp(part)
		end),
		"Disconnect",
		part
	)

	part.Destroying:Once(function(): ()
		if self._janitor == janitor then
			janitor:Remove(part)
		end
	end)
end

function Smoke.Enable(self: Smoke): ()
	if self._janitor then
		return
	end

	local janitor = Janitor.new()
	self._janitor = janitor

	local picker: any = self._opts:Get("color")
	if picker then
		janitor:Add(
			picker:OnUpdate(function(): ()
				self:Refresh()
			end),
			true
		)
	end

	local materialEl: any = self._opts:Get("material")
	if materialEl then
		janitor:Add(
			materialEl:OnChange(function(): ()
				self:Refresh()
			end),
			true
		)
	end

	janitor:Add(
		SmokeController.voxelAdded:Connect(function(part: BasePart): ()
			self:HookVoxel(part)
		end),
		"Disconnect"
	)

	self:Refresh()

	for part in next, SmokeController.GetVoxels() do
		self:HookVoxel(part)
	end
end

function Smoke.Disable(self: Smoke): ()
	local janitor = self._janitor
	if janitor then
		janitor:Destroy()
		self._janitor = nil
	end
end

function Smoke.Destroy(self: Smoke): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

return Smoke
