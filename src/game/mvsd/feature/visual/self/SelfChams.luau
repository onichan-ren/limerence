local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local clientState = require("@game/mvsd/client/clientState")
local chamsSession = require("@game/universal/feature/visual/chams/chamsSession")

local peek = Charm.peek
local sub = Charm.subscribe

local MATERIALS: { string } = {
	"ForceField",
	"Neon",
	"Glass",
}

local EXCLUDED_PART_NAMES: { [string]: true } = {
	HumanoidRootPart = true,
}

local CLOTHING_PROPS: { [string]: string } = {
	Shirt = "ShirtTemplate",
	Pants = "PantsTemplate",
	ShirtGraphic = "Graphic",
}

export type SelfChamsScope = "weapon" | "body"

export type SelfChamsProps = {
	key: string,
	label: string,
	tip: string,
	scope: SelfChamsScope,
	color: Color3,
	material: string,
}


local function scopeOf(character: Model, inst: Instance): SelfChamsScope?
	if not inst:IsA("BasePart") then
		return nil
	end

	local part = inst :: BasePart
	if part.Transparency >= 1 or EXCLUDED_PART_NAMES[part.Name] then
		return nil
	end

	local current: Instance? = part
	while current and current ~= character do
		if current:IsA("Tool") then
			return "weapon"
		end
		current = current.Parent
	end

	if not current then
		return nil
	end

	return "body"
end

local SelfChams = {}
SelfChams.__index = SelfChams

setmetatable(SelfChams, { __index = BaseFeature })

function SelfChams.new(link: gameUi.Linker, props: SelfChamsProps): SelfChams
	local self = BaseFeature.new() :: any
	setmetatable(self, SelfChams)

	self._enabled = false
	self._scope = props.scope
	self._activeJanitor = nil :: Janitor.Janitor?
	self._characterJanitor = nil :: Janitor.Janitor?
	self._session = chamsSession.new({
		overlayMeshParts = false,
		skipTransparency = false,
		lockAppearance = false,
		lockTransparency = false,
	})
	self._parts = setmetatable({}, { __mode = "k" }) :: any
	self._clothing = {} :: { [Instance]: { prop: string, value: string } }

	local chamsToggle = link:Toggle(props.key, props.label, false):SetTip({
		title = props.label,
		body = props.tip,
	})
	local chamsLink = link:OnKey(props.key)
	chamsLink:Extra(chamsToggle, "color", "Colorpicker", "Color", props.color, 0)
	chamsLink:Extra(chamsToggle, "opts", "Submenu", props.label .. " Options")
	local optsLink = chamsLink:OnKey("opts")
	optsLink:Dropdown("material", "Material", MATERIALS, props.material):SetTip({
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

	self:Track(link:Get(props.key):OnChange(function(state: boolean): ()
		if state then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek(props.key) then
		self:Enable()
	end

	return self
end

function SelfChams._material(self: SelfChams): Enum.Material
	local name = self._materialLink:Peek() or "Neon"
	return (Enum.Material :: any)[name] or Enum.Material.Neon
end

function SelfChams._color(self: SelfChams): Color3
	return (self._colorLink :: any):GetColor()
end

function SelfChams._transparency(self: SelfChams): number
	return (self._colorLink :: any):GetTransparency()
end

function SelfChams._reflectance(self: SelfChams): number
	local value = self._reflectanceLink:Peek()
	if type(value) ~= "number" then
		return 0
	end
	return value
end

function SelfChams._style(self: SelfChams): chamsSession.Style
	return {
		material = self:_material(),
		color = self:_color(),
		transparency = self:_transparency(),
		reflectance = self:_reflectance(),
	}
end

function SelfChams._applyPart(self: SelfChams, part: BasePart): ()
	if self._parts[part] then
		return
	end
	self._parts[part] = true
	self._session.apply(part, self:_style())
end

function SelfChams._restorePart(self: SelfChams, part: BasePart): ()
	if not self._parts[part] then
		return
	end
	self._parts[part] = nil
	self._session.restore(part)
end

SelfChams._refreshStyle = LPH_NO_VIRTUALIZE(function(self: SelfChams): ()
	local style = self:_style()
	for part in next, self._parts do
		self._session.apply(part, style)
	end
end)

function SelfChams._restoreAll(self: SelfChams): ()
	self._session.restoreAll()
	table.clear(self._parts)
end

function SelfChams._stripClothing(self: SelfChams, clothing: Instance): ()
	local prop = CLOTHING_PROPS[clothing.ClassName]
	if not prop or self._clothing[clothing] then
		return
	end
	local target = clothing :: any
	self._clothing[clothing] = { prop = prop, value = target[prop] }
	target[prop] = ""
end

function SelfChams._restoreClothing(self: SelfChams): ()
	for clothing, entry in next, self._clothing do
		local target = clothing :: any
		target[entry.prop] = entry.value
	end
	table.clear(self._clothing)
end

function SelfChams._applyCharacter(self: SelfChams, character: Model?): ()
	if not character then
		return
	end

	for _, desc in next, character:QueryDescendants("Instance") do
		if scopeOf(character, desc) == self._scope then
			self:_applyPart(desc :: BasePart)
		end
	end
end

function SelfChams._onCharacterChanged(self: SelfChams, character: Model?): ()
	self:_restoreAll()
	self:_restoreClothing()

	if self._characterJanitor then
		self._characterJanitor:Destroy()
		self._characterJanitor = nil
	end

	if not character then
		return
	end

	local janitor = Janitor.new()
	self._characterJanitor = janitor

	if self._scope == "body" then
		for _, desc in next, character:QueryDescendants("Instance") do
			if CLOTHING_PROPS[desc.ClassName] then
				self:_stripClothing(desc)
			end
		end
	end

	self:_applyCharacter(character)

	janitor:Add(
		character.DescendantAdded:Connect(function(desc: Instance): ()
			if scopeOf(character, desc) == self._scope then
				self:_applyPart(desc :: BasePart)
			elseif self._scope == "body" and CLOTHING_PROPS[desc.ClassName] then
				self:_stripClothing(desc)
			else
				self._session.onDescendantAdded(desc)
			end
		end),
		"Disconnect"
	)

	janitor:Add(
		character.DescendantRemoving:Connect(function(desc: Instance): ()
			if desc:IsA("BasePart") and self._parts[desc :: BasePart] then
				self:_restorePart(desc :: BasePart)
			end
		end),
		"Disconnect"
	)
end

function SelfChams.Enable(self: SelfChams): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local janitor = Janitor.new()
	self._activeJanitor = janitor

	janitor:Add(sub(clientState.character, function(character: Model?): ()
		self:_onCharacterChanged(character)
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

	self:_onCharacterChanged(peek(clientState.character))
end

function SelfChams.Disable(self: SelfChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self:_restoreAll()
	self:_restoreClothing()

	if self._characterJanitor then
		self._characterJanitor:Destroy()
		self._characterJanitor = nil
	end

	if self._activeJanitor then
		self._activeJanitor:Destroy()
		self._activeJanitor = nil
	end
end

function SelfChams.Destroy(self: SelfChams): ()
	self:Disable()
	self._session.destroy()
	BaseFeature.Destroy(self)
end

export type SelfChams =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_scope: SelfChamsScope,
			_activeJanitor: Janitor.Janitor?,
			_characterJanitor: Janitor.Janitor?,
			_session: chamsSession.Session,
			_parts: { [BasePart]: boolean },
			_clothing: { [Instance]: { prop: string, value: string } },
			_colorLink: any,
			_materialLink: any,
			_reflectanceLink: any,
			_style: (SelfChams) -> chamsSession.Style,
			_applyPart: (SelfChams, BasePart) -> (),
			_restorePart: (SelfChams, BasePart) -> (),
			_refreshStyle: (SelfChams) -> (),
		},
		SelfChams
	))
	& BaseFeature.BaseFeature

return SelfChams
