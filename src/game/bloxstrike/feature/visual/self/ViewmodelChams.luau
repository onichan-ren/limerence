local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local viewmodelState = require("@game/bloxstrike/viewmodel/viewmodelState")
local localLookController = require("@game/bloxstrike/client/localLookController")
local chamsSession = require("@game/universal/feature/visual/chams/chamsSession")

local peek = Charm.peek
local sub = Charm.subscribe

local MATERIALS: { string } = {
	"ForceField",
	"Neon",
	"Glass",
}


type CategoryId = "arms" | "sleeves" | "gloves" | "weapon"

local CATEGORY_ORDER: { CategoryId } = { "arms", "sleeves", "gloves", "weapon" }
local CATEGORY_LABEL: { [CategoryId]: string } = {
	arms = "Arms",
	sleeves = "Sleeves",
	gloves = "Gloves",
	weapon = "Weapon",
}
local CATEGORY_DEFAULTS: { [CategoryId]: { material: string, color: Color3 } } = {
	arms = { material = "Neon", color = Color3.fromRGB(195, 95, 95) },
	sleeves = { material = "Neon", color = Color3.fromRGB(145, 190, 215) },
	gloves = { material = "Neon", color = Color3.fromRGB(200, 186, 160) },
	weapon = { material = "Neon", color = Color3.fromRGB(168, 168, 168) },
}

local WEAPON_MODEL_NAMES: { [string]: true } = {
	Weapon = true,
	WeaponL = true,
	WeaponR = true,
	CameraModelWeapon = true,
}

local ARM_NAMES: { [string]: true } = {
	["Left Arm"] = true,
	["Right Arm"] = true,
}

-- this game is awesome
local DUMMY_ARM_NAMES: { [string]: true } = {
	["CameraModel1"] = true,
	["CameraModel2"] = true,
}

local function isInWeaponModel(part: BasePart): boolean
	local current = part.Parent
	while current do
		if current.ClassName == "Model" and WEAPON_MODEL_NAMES[current.Name] then
			return true
		end
		current = current.Parent
	end
	return false
end

local function partHiddenTransparency(part: BasePart): number?
	local hidden = part:GetAttribute("HiddenTransparency")
	if typeof(hidden) == "number" then
		return hidden
	end
	return nil
end

local function isViewmodelHiddenPart(part: BasePart): boolean
	return part.Transparency >= 1 and partHiddenTransparency(part) ~= nil
end

local function classifyPart(part: Instance): CategoryId?
	if not part:IsA("BasePart") then
		return nil
	end
	local base = part :: BasePart
	if base.Transparency >= 1 then
		local hidden = partHiddenTransparency(base)
		if hidden == nil or hidden >= 1 then
			return nil
		end
	end
	if part.Name == "Sleeve" then
		return "sleeves"
	end
	if part.Name == "Glove" then
		return "gloves"
	end
	if ARM_NAMES[part.Name] then
		return "arms"
	end
	if DUMMY_ARM_NAMES[part.Name] then
		return "arms"
	end
	if isInWeaponModel(part) then
		return "weapon"
	end
	return nil
end

local ViewmodelChams = {}
ViewmodelChams.__index = ViewmodelChams

setmetatable(ViewmodelChams, { __index = BaseFeature })

function ViewmodelChams.new(link: gameUi.Linker): ViewmodelChams
	local self = BaseFeature.new() :: any
	setmetatable(self, ViewmodelChams)

	self._enabled = false
	self._activeJanitor = nil :: Janitor.Janitor?
	self._vmJanitor = nil :: Janitor.Janitor?
	self._parts = { arms = {}, sleeves = {}, gloves = {}, weapon = {} } :: { [CategoryId]: { BasePart } }
	self._visConns = setmetatable({}, { __mode = "k" }) :: any
	self._session = chamsSession.new({
		overlayMeshParts = true,
		skipTransparency = true,
		skipInvisible = false,
	})
	self._settingsLink = nil :: gameUi.Linker?

	local chamsToggle = link:Toggle("viewmodelChams", "Viewmodel Chams", false):SetTip({
		title = "Viewmodel Chams",
		body = "Recolors your first-person arms and weapon.",
	})
	link:Extra(chamsToggle, "viewmodelChamsSettings", "Submenu", "Viewmodel Chams")
	local settingsLink = link:OnKey("viewmodelChamsSettings")
	self._settingsLink = settingsLink

	for i = 1, #CATEGORY_ORDER do
		local cat: CategoryId = CATEGORY_ORDER[i]
		local defaults = CATEGORY_DEFAULTS[cat]
		local catToggle = settingsLink:Toggle(cat, CATEGORY_LABEL[cat], true):SetTip({
			title = CATEGORY_LABEL[cat],
			body = "Enable chams for this viewmodel part group.",
		})
		settingsLink:Extra(catToggle, cat .. "Color", "Colorpicker", "Color", defaults.color, 0)
		local materialOptsKey = cat .. "MaterialOpts"
		settingsLink:Extra(catToggle, materialOptsKey, "Submenu", "Material")
		local materialLink = settingsLink:OnKey(materialOptsKey)
		materialLink:Dropdown("material", "Material", MATERIALS, defaults.material):SetTip({
			title = "Material",
			body = "Material applied to parts in this category.",
		})
		materialLink:Slider("reflectance", "Reflectance", 0, 0, 1, 0.05):SetTip({
			title = "Reflectance",
			body = "How reflective the parts in this category look.",
		})
	end

	self:Track(link:Get("viewmodelChams"):OnChange(function(state: boolean): ()
		if state then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Get("viewmodelChams"):Peek() then
		self:Enable()
	end

	return self
end

function ViewmodelChams._categoryEnabled(self: ViewmodelChams, category: CategoryId): boolean
	local settingsLink = self._settingsLink
	if not settingsLink then
		return false
	end
	return settingsLink:Peek(category) == true
end

function ViewmodelChams._categoryMaterial(self: ViewmodelChams, category: CategoryId): Enum.Material
	local settingsLink = self._settingsLink
	local name = "Neon"
	if settingsLink then
		name = settingsLink:OnKey(category .. "MaterialOpts"):Peek("material") or name
	end
	return (Enum.Material :: any)[name] or Enum.Material.Neon
end

function ViewmodelChams._categoryColor(self: ViewmodelChams, category: CategoryId): Color3
	local settingsLink = self._settingsLink
	if not settingsLink then
		return Color3.new(1, 1, 1)
	end
	return (settingsLink:Get(category .. "Color") :: any):GetColor()
end

function ViewmodelChams._categoryTransparency(self: ViewmodelChams, category: CategoryId): number
	local settingsLink = self._settingsLink
	if not settingsLink then
		return 0
	end
	return (settingsLink:Get(category .. "Color") :: any):GetTransparency()
end

function ViewmodelChams._categoryReflectance(self: ViewmodelChams, category: CategoryId): number
	local settingsLink = self._settingsLink
	if not settingsLink then
		return 0
	end
	local value = settingsLink:OnKey(category .. "MaterialOpts"):Peek("reflectance")
	if type(value) ~= "number" then
		return 0
	end
	return value
end

ViewmodelChams._categoryStyle = LPH_NO_VIRTUALIZE(function(self: ViewmodelChams, category: CategoryId): chamsSession.Style
	return {
		material = self:_categoryMaterial(category),
		color = self:_categoryColor(category),
		transparency = self:_categoryTransparency(category),
		reflectance = self:_categoryReflectance(category),
	}
end)

ViewmodelChams._applyPartTransparency = LPH_NO_VIRTUALIZE(
	function(self: ViewmodelChams, part: BasePart, category: CategoryId): ()
		if localLookController.IsThirdPerson() then
			return
		end
		if isViewmodelHiddenPart(part) then
			return
		end
		if self._session.usesOverlay(part) then
			return
		end
		part.Transparency = self:_categoryTransparency(category)
	end
)

function ViewmodelChams._bindPartVisibility(self: ViewmodelChams, part: BasePart, category: CategoryId): ()
	local existing = self._visConns[part]
	if existing then
		existing:Disconnect()
	end
	self._visConns[part] = part:GetPropertyChangedSignal("Transparency"):Connect(function(): ()
		if not self._session.has(part) then
			return
		end
		self:_applyPartTransparency(part, category)
	end)
end

function ViewmodelChams._unbindPartVisibility(self: ViewmodelChams, part: BasePart): ()
	local conn = self._visConns[part]
	if conn then
		conn:Disconnect()
		self._visConns[part] = nil
	end
end

ViewmodelChams._applyPart = LPH_NO_VIRTUALIZE(
	function(self: ViewmodelChams, part: BasePart, category: CategoryId, style: chamsSession.Style): ()
		if not part.Parent then
			return
		end
		self._session.apply(part, style)
		self:_bindPartVisibility(part, category)
		self:_applyPartTransparency(part, category)
	end
)

function ViewmodelChams._restorePart(self: ViewmodelChams, part: BasePart): ()
	self:_unbindPartVisibility(part)
	self._session.restore(part)
end

ViewmodelChams._applyCategory = LPH_NO_VIRTUALIZE(function(self: ViewmodelChams, category: CategoryId): ()
	local parts = self._parts[category]
	if self:_categoryEnabled(category) then
		local style = self:_categoryStyle(category)
		for i = 1, #parts do
			local part = parts[i]
			if part.Parent then
				self:_applyPart(part, category, style)
			end
		end
	else
		for i = 1, #parts do
			self:_restorePart(parts[i])
		end
	end
end)

function ViewmodelChams._refreshColor(self: ViewmodelChams, category: CategoryId): ()
	if not self:_categoryEnabled(category) then
		return
	end
	local parts = self._parts[category]
	local style = self:_categoryStyle(category)
	for i = 1, #parts do
		local part = parts[i]
		if part.Parent then
			self._session.apply(part, style)
			self:_applyPartTransparency(part, category)
		end
	end
end

function ViewmodelChams._onDescendantAdded(self: ViewmodelChams, desc: Instance): ()
	if desc:IsA("BasePart") then
		local cat = classifyPart(desc)
		if not cat then
			return
		end
		local parts = self._parts[cat]
		parts[#parts + 1] = desc :: BasePart
		if self:_categoryEnabled(cat) then
			self:_applyPart(desc :: BasePart, cat, self:_categoryStyle(cat))
		end
	else
		self._session.onDescendantAdded(desc)
	end
end

function ViewmodelChams._rebuildParts(self: ViewmodelChams, model: Model?): ()
	local arms: { BasePart } = {}
	local sleeves: { BasePart } = {}
	local gloves: { BasePart } = {}
	local weapon: { BasePart } = {}
	if model then
		for _, desc in next, model:QueryDescendants("Instance") do
			local cat = classifyPart(desc)
			if cat == "arms" then
				arms[#arms + 1] = desc :: BasePart
			elseif cat == "sleeves" then
				sleeves[#sleeves + 1] = desc :: BasePart
			elseif cat == "gloves" then
				gloves[#gloves + 1] = desc :: BasePart
			elseif cat == "weapon" then
				weapon[#weapon + 1] = desc :: BasePart
			end
		end
	end
	self._parts.arms = arms
	self._parts.sleeves = sleeves
	self._parts.gloves = gloves
	self._parts.weapon = weapon
end

function ViewmodelChams._onViewmodelChanged(self: ViewmodelChams, vm: any): ()
	self._session.restoreAll()

	if self._vmJanitor then
		self._vmJanitor:Destroy()
		self._vmJanitor = nil
	end

	local model = vm and vm.Model
	self:_rebuildParts(model)

	if not model then
		return
	end

	self._vmJanitor = Janitor.new()

	for i = 1, #CATEGORY_ORDER do
		self:_applyCategory(CATEGORY_ORDER[i])
	end

	self._vmJanitor:Add(
		model.DescendantAdded:Connect(function(desc: Instance): ()
			self:_onDescendantAdded(desc)
		end),
		"Disconnect"
	)

	self._vmJanitor:Add(
		model.DescendantRemoving:Connect(function(desc: Instance): ()
			if desc:IsA("BasePart") and self._session.has(desc :: BasePart) then
				self:_restorePart(desc :: BasePart)
			end
		end),
		"Disconnect"
	)
end

function ViewmodelChams.Enable(self: ViewmodelChams): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local janitor = Janitor.new()
	self._activeJanitor = janitor

	janitor:Add(sub(viewmodelState._viewmodel, function(vm: any): ()
		self:_onViewmodelChanged(vm)
	end))

	janitor:Add(sub(localLookController.thirdPerson, function(active: boolean): ()
		if active then
			self._session.setHidden(true)
		else
			self._session.setHidden(false)
			self:_onViewmodelChanged(peek(viewmodelState._viewmodel))
		end
	end))
	if localLookController.IsThirdPerson() then
		self._session.setHidden(true)
	end

	local settingsLink = self._settingsLink
	if settingsLink then
		for i = 1, #CATEGORY_ORDER do
			local cat: CategoryId = CATEGORY_ORDER[i]
			local picker: any = settingsLink:Get(cat .. "Color")
			local materialEl: any = settingsLink:OnKey(cat .. "MaterialOpts"):Get("material")
			local reflectanceEl: any = settingsLink:OnKey(cat .. "MaterialOpts"):Get("reflectance")
			local enabledEl: any = settingsLink:Get(cat)

			janitor:Add(picker:OnUpdate(function(): ()
				self:_refreshColor(cat)
			end))

			janitor:Add(materialEl:OnChange(function(): ()
				self:_applyCategory(cat)
			end))

			janitor:Add(reflectanceEl:OnChange(function(): ()
				self:_applyCategory(cat)
			end))

			janitor:Add(enabledEl:OnChange(function(): ()
				self:_applyCategory(cat)
			end))
		end
	end

	self:_onViewmodelChanged(peek(viewmodelState._viewmodel))
end

function ViewmodelChams.Disable(self: ViewmodelChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self._session.restoreAll()
	self._session.setHidden(false)
	for part, conn in next, self._visConns do
		conn:Disconnect()
		self._visConns[part] = nil
	end
	self._parts = { arms = {}, sleeves = {}, gloves = {}, weapon = {} }

	if localLookController.IsThirdPerson() then
		local vm = peek(viewmodelState._viewmodel)
		if vm then
			vm.Hidden = false
		end
	end

	if self._vmJanitor then
		self._vmJanitor:Destroy()
		self._vmJanitor = nil
	end

	if self._activeJanitor then
		self._activeJanitor:Destroy()
		self._activeJanitor = nil
	end
end

function ViewmodelChams.Destroy(self: ViewmodelChams): ()
	self:Disable()
	self._session.destroy()
	BaseFeature.Destroy(self)
end

export type ViewmodelChams =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_activeJanitor: Janitor.Janitor?,
			_vmJanitor: Janitor.Janitor?,
			_parts: { [CategoryId]: { BasePart } },
			_visConns: { [BasePart]: RBXScriptConnection },
			_session: chamsSession.Session,
			_settingsLink: gameUi.Linker?,
			_categoryEnabled: (ViewmodelChams, CategoryId) -> boolean,
			_categoryMaterial: (ViewmodelChams, CategoryId) -> Enum.Material,
			_categoryColor: (ViewmodelChams, CategoryId) -> Color3,
			_categoryTransparency: (ViewmodelChams, CategoryId) -> number,
			_categoryReflectance: (ViewmodelChams, CategoryId) -> number,
			_categoryStyle: (ViewmodelChams, CategoryId) -> chamsSession.Style,
			_applyPartTransparency: (ViewmodelChams, BasePart, CategoryId) -> (),
			_bindPartVisibility: (ViewmodelChams, BasePart, CategoryId) -> (),
			_unbindPartVisibility: (ViewmodelChams, BasePart) -> (),
			_applyPart: (ViewmodelChams, BasePart, CategoryId, chamsSession.Style) -> (),
			_restorePart: (ViewmodelChams, BasePart) -> (),
			_applyCategory: (ViewmodelChams, CategoryId) -> (),
			_refreshColor: (ViewmodelChams, CategoryId) -> (),
			_onDescendantAdded: (ViewmodelChams, Instance) -> (),
			_rebuildParts: (ViewmodelChams, Model?) -> (),
			_onViewmodelChanged: (ViewmodelChams, any) -> (),
		},
		ViewmodelChams
	))
	& BaseFeature.BaseFeature

return ViewmodelChams
