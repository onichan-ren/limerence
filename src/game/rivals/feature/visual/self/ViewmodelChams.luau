local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local viewmodelState = require("@game/rivals/viewmodel/viewmodelState")
local chamsSession = require("@game/universal/feature/visual/chams/chamsSession")

local peek = Charm.peek
local sub = Charm.subscribe

local MATERIALS: { string } = {
	"ForceField",
	"Neon",
	"Glass",
}


type CategoryId = "arms" | "weapon"

local CATEGORY_ORDER: { CategoryId } = { "arms", "weapon" }
local CATEGORY_LABEL: { [CategoryId]: string } = {
	arms = "Arms",
	weapon = "Weapon",
}
local CATEGORY_DEFAULTS: { [CategoryId]: { material: string, color: Color3 } } = {
	arms = { material = "Neon", color = Color3.fromRGB(195, 95, 95) },
	weapon = { material = "Neon", color = Color3.fromRGB(168, 168, 168) },
}

local ARM_NAMES: { [string]: true } = {
	LeftArm = true,
	RightArm = true,
	LeftArmWrapped = true,
	RightArmWrapped = true,
}

local function isInItemVisual(part: BasePart, root: Model): boolean
	local current = part.Parent
	while current and current ~= root do
		if current.Name == "ItemVisual" then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isUnderArm(part: BasePart, root: Model): boolean
	local current = part.Parent
	while current and current ~= root do
		if ARM_NAMES[current.Name] then
			return true
		end
		current = current.Parent
	end
	return false
end

local function classifyPart(part: Instance, root: Model): CategoryId?
	if not part:IsA("BasePart") then
		return nil
	end
	local base = part :: BasePart
	-- Arm cosmetics (fist skins, sleeves) are reparented under the arm parts, so
	-- they keep skin-specific names and live outside ItemVisual. Catch by ancestry.
	if ARM_NAMES[base.Name] or isUnderArm(base, root) then
		return "arms"
	end
	if isInItemVisual(base, root) then
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
	self._model = nil :: Model?
	self._parts = { arms = {}, weapon = {} } :: { [CategoryId]: { BasePart } }
	self._session = chamsSession.new({
		overlayMeshParts = true,
		skipTransparency = false,
		lockAppearance = true,
	})
	self._settingsLink = nil :: gameUi.Linker?
	self._optsLinks = {} :: { [CategoryId]: gameUi.Linker }

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
		self._optsLinks[cat] = materialLink
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
	local optsLink = self._optsLinks[category]
	local name = "Neon"
	if optsLink then
		name = optsLink:Peek("material") or name
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
	local optsLink = self._optsLinks[category]
	if not optsLink then
		return 0
	end
	local value = optsLink:Peek("reflectance")
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

ViewmodelChams._applyCategory = LPH_NO_VIRTUALIZE(function(self: ViewmodelChams, category: CategoryId): ()
	local parts = self._parts[category]
	if self:_categoryEnabled(category) then
		local style = self:_categoryStyle(category)
		for i = 1, #parts do
			local part = parts[i]
			if part.Parent then
				self._session.apply(part, style)
			end
		end
	else
		for i = 1, #parts do
			self._session.restore(parts[i])
		end
	end
end)

function ViewmodelChams._refreshCategory(self: ViewmodelChams, category: CategoryId): ()
	self:_applyCategory(category)
end

function ViewmodelChams._refreshAll(self: ViewmodelChams): ()
	for i = 1, #CATEGORY_ORDER do
		self:_applyCategory(CATEGORY_ORDER[i])
	end
end

function ViewmodelChams._onDescendantAdded(self: ViewmodelChams, desc: Instance): ()
	if not self._enabled then
		return
	end
	if desc:IsA("BasePart") then
		local model = self._model
		if not model then
			return
		end
		local cat = classifyPart(desc, model)
		if not cat then
			return
		end
		local parts = self._parts[cat]
		parts[#parts + 1] = desc :: BasePart
		if self:_categoryEnabled(cat) then
			self._session.apply(desc :: BasePart, self:_categoryStyle(cat))
		end
	else
		self._session.onDescendantAdded(desc)
	end
end

function ViewmodelChams._rebuildParts(self: ViewmodelChams, model: Model?): ()
	local arms: { BasePart } = {}
	local weapon: { BasePart } = {}
	if model then
		for _, desc in next, model:QueryDescendants("BasePart") do
			local cat = classifyPart(desc, model)
			if cat == "arms" then
				arms[#arms + 1] = desc :: BasePart
			elseif cat == "weapon" then
				weapon[#weapon + 1] = desc :: BasePart
			end
		end
	end
	self._parts.arms = arms
	self._parts.weapon = weapon
end

function ViewmodelChams._onViewmodelChanged(self: ViewmodelChams, vm: any): ()
	self._session.restoreAll()

	if self._vmJanitor then
		self._vmJanitor:Destroy()
		self._vmJanitor = nil
	end

	local model = vm and vm.Model or nil
	self._model = model
	self:_rebuildParts(model)

	if not model then
		return
	end

	self._vmJanitor = Janitor.new()

	self:_refreshAll()

	local addedJanitor = self._vmJanitor
	if addedJanitor then
		addedJanitor:Add(
			model.DescendantAdded:Connect(function(desc: Instance): ()
				self:_onDescendantAdded(desc)
			end),
			"Disconnect"
		)

		addedJanitor:Add(
			model.DescendantRemoving:Connect(function(desc: Instance): ()
				if desc:IsA("BasePart") then
					self._session.restore(desc :: BasePart)
				end
			end),
			"Disconnect"
		)
	end
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

	local settingsLink = self._settingsLink
	if settingsLink then
		for i = 1, #CATEGORY_ORDER do
			local cat: CategoryId = CATEGORY_ORDER[i]
			local picker: any = settingsLink:Get(cat .. "Color")
			local materialEl: any = settingsLink:OnKey(cat .. "MaterialOpts"):Get("material")
			local reflectanceEl: any = settingsLink:OnKey(cat .. "MaterialOpts"):Get("reflectance")
			local enabledEl: any = settingsLink:Get(cat)

			janitor:Add(picker:OnUpdate(function(): ()
				self:_refreshAll()
			end))

			janitor:Add(materialEl:OnChange(function(): ()
				self:_refreshCategory(cat)
			end))

			janitor:Add(reflectanceEl:OnChange(function(): ()
				self:_refreshCategory(cat)
			end))

			janitor:Add(enabledEl:OnChange(function(): ()
				self:_refreshCategory(cat)
			end))
		end
	end

	janitor:Add(function(): ()
		self._session.restoreAll()
		self._model = nil
		self._vmJanitor = nil
		self._parts = { arms = {}, weapon = {} }
	end, true)

	self:_onViewmodelChanged(peek(viewmodelState._viewmodel))
end

function ViewmodelChams.Disable(self: ViewmodelChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false

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
			_model: Model?,
			_parts: { [CategoryId]: { BasePart } },
			_session: chamsSession.Session,
			_settingsLink: gameUi.Linker?,
			_optsLinks: { [CategoryId]: gameUi.Linker },
			_categoryEnabled: (ViewmodelChams, CategoryId) -> boolean,
			_categoryMaterial: (ViewmodelChams, CategoryId) -> Enum.Material,
			_categoryColor: (ViewmodelChams, CategoryId) -> Color3,
			_categoryTransparency: (ViewmodelChams, CategoryId) -> number,
			_categoryReflectance: (ViewmodelChams, CategoryId) -> number,
			_categoryStyle: (ViewmodelChams, CategoryId) -> chamsSession.Style,
			_applyCategory: (ViewmodelChams, CategoryId) -> (),
			_refreshCategory: (ViewmodelChams, CategoryId) -> (),
			_refreshAll: (ViewmodelChams) -> (),
			_onDescendantAdded: (ViewmodelChams, Instance) -> (),
			_rebuildParts: (ViewmodelChams, Model?) -> (),
			_onViewmodelChanged: (ViewmodelChams, any) -> (),
		},
		ViewmodelChams
	))
	& BaseFeature.BaseFeature

return ViewmodelChams
