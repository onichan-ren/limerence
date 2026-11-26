local RunService = cloneref(game:GetService("RunService")) :: RunService
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/overkill/module/ModuleController")
local clientState = require("@game/overkill/client/clientState")
local chamsSession = require("@game/universal/feature/visual/chams/chamsSession")

local peek = Charm.peek

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

local function classifyPart(part: Instance, gunModel: Model?, root: Model): CategoryId?
	if not part:IsA("BasePart") then
		return nil
	end
	local base = part :: BasePart
	if base.Name == "HumanoidRootPart" then
		return nil
	end
	if gunModel then
		local current: Instance? = base
		while current and current ~= root do
			if current == gunModel then
				return "weapon"
			end
			current = current.Parent
		end
	end
	return "arms"
end

local ViewmodelChams = {}
ViewmodelChams.__index = ViewmodelChams

setmetatable(ViewmodelChams, { __index = BaseFeature })

function ViewmodelChams.new(link: gameUi.Linker): ViewmodelChams
	local self = BaseFeature.new() :: any
	setmetatable(self, ViewmodelChams)

	self._enabled = false
	self._activeJanitor = nil :: Janitor.Janitor?
	self._modelJanitor = nil :: Janitor.Janitor?
	self._viewModel = nil :: any
	self._model = nil :: Model?
	self._gunModel = nil :: Model?
	self._parts = { arms = {}, weapon = {} } :: { [CategoryId]: { BasePart } }
	self._session = chamsSession.new({ overlayMeshParts = true })
	self._scratch = { material = Enum.Material.Neon, color = Color3.new(1, 1, 1), transparency = 0, reflectance = 0 } :: chamsSession.Style
	self._settingsLink = nil :: gameUi.Linker?
	self._optsLinks = {} :: { [CategoryId]: gameUi.Linker }
	self._colorEls = {} :: { [CategoryId]: any }

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
		self._colorEls[cat] = settingsLink:Get(cat .. "Color")
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
	local colorEl = self._colorEls[category]
	if not colorEl then
		return Color3.new(1, 1, 1)
	end
	return colorEl:GetColor()
end

function ViewmodelChams._categoryTransparency(self: ViewmodelChams, category: CategoryId): number
	local colorEl = self._colorEls[category]
	if not colorEl then
		return 0
	end
	return colorEl:GetTransparency()
end

function ViewmodelChams._categoryReflectance(self: ViewmodelChams, category: CategoryId): number
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
	local scratch = self._scratch
	scratch.material = self:_categoryMaterial(category)
	scratch.color = self:_categoryColor(category)
	scratch.transparency = self:_categoryTransparency(category)
	scratch.reflectance = self:_categoryReflectance(category)
	return scratch
end)

ViewmodelChams._resolveVmc = LPH_NO_VIRTUALIZE(function(self: ViewmodelChams): any?
	local viewModel = self._viewModel
	if not viewModel then
		viewModel = ModuleController.GetModule("viewModel")
		self._viewModel = viewModel
	end
	if not viewModel then
		return nil
	end
	local character = peek(clientState.character)
	if not character then
		return nil
	end
	local getEquipped = viewModel.getEquipped
	if type(getEquipped) ~= "function" then
		return nil
	end
	local vmc = getEquipped(character)
	if type(vmc) ~= "table" or not vmc.isLocal or vmc.destroying then
		return nil
	end
	local model = vmc.viewModel
	if typeof(model) ~= "Instance" or model.Parent == nil then
		return nil
	end
	return vmc
end)

function ViewmodelChams._onDescendantAdded(self: ViewmodelChams, desc: Instance): ()
	if not self._enabled then
		return
	end
	if desc:IsA("BasePart") then
		local model = self._model
		if not model then
			return
		end
		local cat = classifyPart(desc, self._gunModel, model)
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

function ViewmodelChams._rebuildParts(self: ViewmodelChams, model: Model?, gunModel: Model?): ()
	local arms: { BasePart } = {}
	local weapon: { BasePart } = {}
	if model then
		for _, desc in next, model:QueryDescendants("Instance") do
			local cat = classifyPart(desc, gunModel, model)
			if cat == "arms" then
				arms[#arms + 1] = desc :: BasePart
			elseif cat == "weapon" then
				weapon[#weapon + 1] = desc :: BasePart
			end
		end
	end
	self._parts.arms = arms
	self._parts.weapon = weapon

	local modelJanitor = self._modelJanitor
	if modelJanitor then
		modelJanitor:Cleanup()
		if model then
			modelJanitor:Add(
				model.DescendantAdded:Connect(function(desc: Instance): ()
					self:_onDescendantAdded(desc)
				end),
				"Disconnect"
			)
		end
	end
end

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

ViewmodelChams._step = LPH_NO_VIRTUALIZE(function(self: ViewmodelChams): ()
	local vmc = self:_resolveVmc()
	local model = vmc and vmc.viewModel or nil

	if model ~= self._model then
		self._session.restoreAll()
		self._model = model
		self._gunModel = vmc and vmc.gunModel or nil
		self:_rebuildParts(model, self._gunModel)
	end

	if not model then
		return
	end

	for i = 1, #CATEGORY_ORDER do
		self:_applyCategory(CATEGORY_ORDER[i])
	end
end)

function ViewmodelChams.Enable(self: ViewmodelChams): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._viewModel = ModuleController.GetModule("viewModel")

	local janitor = Janitor.new()
	self._activeJanitor = janitor

	local modelJanitor = Janitor.new()
	self._modelJanitor = modelJanitor
	janitor:Add(modelJanitor, "Destroy")

	janitor:Add(
		RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
			self:_step()
		end)),
		"Disconnect"
	)
	janitor:Add(function(): ()
		self._session.restoreAll()
		self._model = nil
		self._gunModel = nil
		self._modelJanitor = nil
		self._parts = { arms = {}, weapon = {} }
	end, true)
end

function ViewmodelChams.Disable(self: ViewmodelChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false

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
			_modelJanitor: Janitor.Janitor?,
			_viewModel: any,
			_model: Model?,
			_gunModel: Model?,
			_parts: { [CategoryId]: { BasePart } },
			_session: chamsSession.Session,
			_scratch: chamsSession.Style,
			_settingsLink: gameUi.Linker?,
			_optsLinks: { [CategoryId]: gameUi.Linker },
			_colorEls: { [CategoryId]: any },
			_categoryEnabled: (ViewmodelChams, CategoryId) -> boolean,
			_categoryMaterial: (ViewmodelChams, CategoryId) -> Enum.Material,
			_categoryColor: (ViewmodelChams, CategoryId) -> Color3,
			_categoryTransparency: (ViewmodelChams, CategoryId) -> number,
			_categoryReflectance: (ViewmodelChams, CategoryId) -> number,
			_categoryStyle: (ViewmodelChams, CategoryId) -> chamsSession.Style,
			_resolveVmc: (ViewmodelChams) -> any?,
			_onDescendantAdded: (ViewmodelChams, Instance) -> (),
			_rebuildParts: (ViewmodelChams, Model?, Model?) -> (),
			_applyCategory: (ViewmodelChams, CategoryId) -> (),
			_step: (ViewmodelChams) -> (),
		},
		ViewmodelChams
	))
	& BaseFeature.BaseFeature

return ViewmodelChams
