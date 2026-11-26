local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local folderChams = require("@game/pf/feature/visual/chams/folderChams")

local DEFAULT_COLOR = Color3.fromRGB(120, 200, 255)

local DroppedWeaponChams = {}
DroppedWeaponChams.__index = DroppedWeaponChams

setmetatable(DroppedWeaponChams, { __index = BaseFeature })

local function anyPart(_part: BasePart): boolean
	return true
end

function DroppedWeaponChams.new(link: gameUi.Linker): DroppedWeaponChams
	local self = BaseFeature.new() :: any
	setmetatable(self, DroppedWeaponChams)

	link:Toggle("droppedWeaponChams", "Chams", false):SetTip({
		title = "Chams",
		body = "Recolors guns left on the ground.",
	})
	local chamsLink = link:OnKey("droppedWeaponChams")
	chamsLink:Submenu("opts", "Chams")
	local optsLink = chamsLink:OnKey("opts")
	optsLink:Dropdown("material", "Material", folderChams.MATERIALS, "Neon")
	optsLink:Colorpicker("color", "Color", DEFAULT_COLOR)

	self._chams = folderChams.new("GunDrop", anyPart)
	self._colorLink = link:Get("droppedWeaponChams.opts.color")
	self._material = folderChams.material(link:Peek("droppedWeaponChams.opts.material"))

	self:Track(link:Get("droppedWeaponChams"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))
	self:Track(link:Watch("droppedWeaponChams.opts.material", function(value: string): ()
		self._material = folderChams.material(value)
		self._chams:setStyle(self._colorLink:GetColor(), self._material)
	end))
	self:Track(self._colorLink:OnColorChange(function(color: Color3): ()
		self._chams:setStyle(color, self._material)
	end))

	return self
end

function DroppedWeaponChams.Enable(self: DroppedWeaponChams): ()
	self._chams:enable(self._colorLink:GetColor(), self._material)
end

function DroppedWeaponChams.Disable(self: DroppedWeaponChams): ()
	self._chams:disable()
end

function DroppedWeaponChams.Destroy(self: DroppedWeaponChams): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type DroppedWeaponChams =
	typeof(setmetatable(
		{} :: {
			_chams: folderChams.folderChams,
			_colorLink: any,
			_material: Enum.Material,
		},
		DroppedWeaponChams
	))
	& BaseFeature.BaseFeature

return DroppedWeaponChams
