local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local clientState = require("@game/ar2/client/clientState")
local chamsSession = require("@game/universal/feature/visual/chams/chamsSession")

local peek = Charm.peek
local sub = Charm.subscribe

local DEFAULT_COLOR = Color3.fromRGB(145, 190, 215)


local MATERIALS: { string } = {
	"ForceField",
	"Neon",
	"Glass",
}

local VehicleChams = {}
VehicleChams.__index = VehicleChams

setmetatable(VehicleChams, { __index = BaseFeature })

function VehicleChams.new(link: gameUi.Linker): VehicleChams
	local self = BaseFeature.new() :: any
	setmetatable(self, VehicleChams)

	self._enabled = false
	self._activeJanitor = nil :: Janitor.Janitor?
	self._vehicleJanitor = nil :: Janitor.Janitor?
	self._vehicle = nil :: Model?
	self._session = chamsSession.new({
		overlayMeshParts = false,
	})
	self._parts = setmetatable({}, { __mode = "k" }) :: any

	local toggle = link:Toggle("vehicleChams", "Vehicle Chams", false):SetTip({
		title = "Vehicle Chams",
		body = "Recolors the vehicle you are in.",
	})
	local chamsLink = link:OnKey("vehicleChams")
	chamsLink:Extra(toggle, "color", "Colorpicker", "Color", DEFAULT_COLOR, 0)
	chamsLink:Extra(toggle, "opts", "Submenu", "Vehicle Chams Options")
	local optsLink = chamsLink:OnKey("opts")
	optsLink:Dropdown("material", "Material", MATERIALS, "Neon"):SetTip({
		title = "Material",
		body = "Material applied to recolored parts.",
	})
	optsLink:Slider("reflectance", "Reflectance", 0, 0, 1, 0.05):SetTip({
		title = "Reflectance",
		body = "How reflective the recolored parts look.",
	})

	self._colorLink = chamsLink:Get("color")
	self._materialLink = optsLink:Get("material")
	self._reflectanceLink = optsLink:Get("reflectance")

	self:Track(link:Get("vehicleChams"):OnChange(function(state: boolean): ()
		if state then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("vehicleChams") then
		self:Enable()
	end

	return self
end

function VehicleChams._material(self: VehicleChams): Enum.Material
	local name = self._materialLink:Peek() or "Neon"
	return (Enum.Material :: any)[name] or Enum.Material.Neon
end

function VehicleChams._color(self: VehicleChams): Color3
	return (self._colorLink :: any):GetColor()
end

function VehicleChams._transparency(self: VehicleChams): number
	return (self._colorLink :: any):GetTransparency()
end

function VehicleChams._reflectance(self: VehicleChams): number
	local value = self._reflectanceLink:Peek()
	if type(value) ~= "number" then
		return 0
	end
	return value
end

VehicleChams._style = LPH_NO_VIRTUALIZE(function(self: VehicleChams): chamsSession.Style
	return {
		material = self:_material(),
		color = self:_color(),
		transparency = self:_transparency(),
		reflectance = self:_reflectance(),
	}
end)

function VehicleChams._applyPart(self: VehicleChams, part: BasePart): ()
	if self._parts[part] then
		return
	end
	self._parts[part] = true
	self._session.apply(part, self:_style())
end

function VehicleChams._restorePart(self: VehicleChams, part: BasePart): ()
	if not self._parts[part] then
		return
	end
	self._parts[part] = nil
	self._session.restore(part)
end

function VehicleChams._restoreAll(self: VehicleChams): ()
	self._session.restoreAll()
	table.clear(self._parts)
end

VehicleChams._applyVehicle = LPH_NO_VIRTUALIZE(function(self: VehicleChams, vehicle: Model): ()
	local style = self:_style()
	for _, desc in next, vehicle:QueryDescendants("BasePart") do
		local part = desc :: BasePart
		if part.Transparency < 1 and not self._parts[part] then
			self._parts[part] = true
			self._session.apply(part, style)
		end
	end
end)

VehicleChams._refreshStyle = LPH_NO_VIRTUALIZE(function(self: VehicleChams): ()
	local style = self:_style()
	for part in next, self._parts do
		self._session.apply(part, style)
	end
end)

function VehicleChams._onVehicleChanged(self: VehicleChams, vehicle: Model?): ()
	if vehicle == self._vehicle then
		return
	end

	self:_restoreAll()
	if self._vehicleJanitor then
		self._vehicleJanitor:Destroy()
		self._vehicleJanitor = nil
	end

	self._vehicle = vehicle
	if not vehicle then
		return
	end

	local janitor = Janitor.new()
	self._vehicleJanitor = janitor

	self:_applyVehicle(vehicle)

	janitor:Add(
		vehicle.DescendantAdded:Connect(function(desc: Instance): ()
			if self._vehicle ~= vehicle then
				return
			end
			if desc:IsA("BasePart") then
				self:_applyPart(desc :: BasePart)
			else
				self._session.onDescendantAdded(desc)
			end
		end),
		"Disconnect"
	)
	janitor:Add(
		vehicle.DescendantRemoving:Connect(function(desc: Instance): ()
			if desc:IsA("BasePart") and self._parts[desc] then
				self:_restorePart(desc :: BasePart)
			end
		end),
		"Disconnect"
	)
end

function VehicleChams.Enable(self: VehicleChams): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local janitor = Janitor.new()
	self._activeJanitor = janitor

	janitor:Add(sub(clientState.vehicle, function(vehicle: Model?): ()
		self:_onVehicleChanged(vehicle)
	end))

	janitor:Add(self._colorLink:OnUpdate(function(): ()
		self:_refreshStyle()
	end))
	janitor:Add(self._materialLink:OnChange(function(): ()
		self:_refreshStyle()
	end))
	janitor:Add(self._reflectanceLink:OnChange(function(): ()
		self:_refreshStyle()
	end))

	self:_onVehicleChanged(peek(clientState.vehicle))
end

function VehicleChams.Disable(self: VehicleChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self:_restoreAll()
	self._vehicle = nil

	if self._vehicleJanitor then
		self._vehicleJanitor:Destroy()
		self._vehicleJanitor = nil
	end
	if self._activeJanitor then
		self._activeJanitor:Destroy()
		self._activeJanitor = nil
	end
end

function VehicleChams.Destroy(self: VehicleChams): ()
	self:Disable()
	self._session.destroy()
	BaseFeature.Destroy(self)
end

export type VehicleChams =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_activeJanitor: Janitor.Janitor?,
			_vehicleJanitor: Janitor.Janitor?,
			_vehicle: Model?,
			_session: chamsSession.Session,
			_parts: { [BasePart]: boolean },
			_colorLink: any,
			_materialLink: any,
			_reflectanceLink: any,
			_style: (VehicleChams) -> chamsSession.Style,
			_applyVehicle: (VehicleChams, Model) -> (),
			_refreshStyle: (VehicleChams) -> (),
		},
		VehicleChams
	))
	& BaseFeature.BaseFeature

return VehicleChams
