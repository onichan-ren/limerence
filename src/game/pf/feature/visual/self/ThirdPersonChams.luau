local RunService = cloneref(game:GetService("RunService")) :: RunService
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local localThirdPerson = require("@game/pf/thirdperson/localThirdPerson")
local CustomCharacter = require("@game/pf/feature/misc/CustomCharacter")
local chamsSession = require("@game/universal/feature/visual/chams/chamsSession")

local peek = Charm.peek

local MATERIALS: { string } = { "ForceField", "Neon", "Glass" }

type CategoryId = "body" | "attachments"

local CATEGORY_ORDER: { CategoryId } = { "body", "attachments" }
local CATEGORY_LABEL: { [CategoryId]: string } = {
	body = "Body",
	attachments = "Attachments",
}
local CATEGORY_TIP: { [CategoryId]: string } = {
	body = "Recolors your character body.",
	attachments = "Recolors your weapon and its attachments.",
}
local CATEGORY_DEFAULTS: { [CategoryId]: { material: string, color: Color3 } } = {
	body = { material = "Neon", color = Color3.fromRGB(120, 200, 255) },
	attachments = { material = "Neon", color = Color3.fromRGB(120, 200, 235) },
}

type CategoryState = {
	enabled: boolean,
	material: Enum.Material,
	reflectance: number,
	colorLink: any,
}

local ThirdPersonChams = {}
ThirdPersonChams.__index = ThirdPersonChams

setmetatable(ThirdPersonChams, { __index = BaseFeature })

function ThirdPersonChams.new(link: gameUi.Linker): ThirdPersonChams
	local self = BaseFeature.new() :: any
	setmetatable(self, ThirdPersonChams)

	local chamsToggle = link:Toggle("thirdPersonChams", "Character Chams", false):SetTip({
		title = "Character Chams",
		body = "Recolors your third person body and weapon.",
	})
	link:Extra(chamsToggle, "thirdPersonChamsSettings", "Submenu", "Character Chams")
	local settingsLink = link:OnKey("thirdPersonChamsSettings")
	self._settingsLink = settingsLink

	self._enabled = false
	self._janitor = Janitor.new()
	self._cats = {} :: { [CategoryId]: CategoryState }
	self._parts = { body = {}, attachments = {} } :: { [CategoryId]: { BasePart } }
	self._session = chamsSession.new()
	self._scratch = { material = Enum.Material.Neon, color = Color3.new(1, 1, 1), transparency = 0, reflectance = 0 } :: chamsSession.Style
	self._dirty = false

	self._bodyModel = nil :: Instance?
	self._weaponModel = nil :: Instance?
	self._modelJanitor = nil :: Janitor.Janitor?

	for i = 1, #CATEGORY_ORDER do
		local cat: CategoryId = CATEGORY_ORDER[i]
		local defaults = CATEGORY_DEFAULTS[cat]
		local catToggle = settingsLink:Toggle(cat, CATEGORY_LABEL[cat], true):SetTip({
			title = CATEGORY_LABEL[cat],
			body = CATEGORY_TIP[cat],
		})
		settingsLink:Extra(catToggle, cat .. "Color", "Colorpicker", "Color", defaults.color, 0)
		local materialOptsKey = cat .. "MaterialOpts"
		settingsLink:Extra(catToggle, materialOptsKey, "Submenu", "Material")
		local materialLink = settingsLink:OnKey(materialOptsKey)
		materialLink:Dropdown("material", "Material", MATERIALS, defaults.material):SetTip({
			title = "Material",
			body = "Surface look used for this part group.",
		})
		materialLink:Slider("reflectance", "Reflectance", 0, 0, 1, 0.05):SetTip({
			title = "Reflectance",
			body = "How shiny this part group looks.",
		})

		local catState: CategoryState = {
			enabled = settingsLink:Peek(cat) == true,
			material = (Enum.Material :: any)[materialLink:Peek("material")] or Enum.Material.Neon,
			reflectance = materialLink:Peek("reflectance") or 0,
			colorLink = settingsLink:Get(cat .. "Color"),
		}
		self._cats[cat] = catState

		self:Track(settingsLink:Get(cat):OnChange(function(value: boolean): ()
			catState.enabled = value == true
			if catState.enabled then
				self._dirty = true
			else
				self:_restoreParts(self._parts[cat])
			end
		end))
		self:Track(materialLink:Get("material"):OnChange(function(value: string): ()
			catState.material = (Enum.Material :: any)[value] or Enum.Material.Neon
			self._dirty = true
		end))
		self:Track(materialLink:Get("reflectance"):OnChange(function(value: number): ()
			catState.reflectance = type(value) == "number" and value or 0
			self._dirty = true
		end))
	end

	self:Track(link:Get("thirdPersonChams"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	return self
end

function ThirdPersonChams._rebuild(self: ThirdPersonChams, bodyModel: Instance?, weaponModel: Instance?): ()
	self._bodyModel = bodyModel
	self._weaponModel = weaponModel

	local body = {}
	if bodyModel then
		for _, descendant in next, bodyModel:QueryDescendants("BasePart") do
			if self._session.isOverlay(descendant) then
				continue
			end
			if not (weaponModel and descendant:IsDescendantOf(weaponModel)) then
				body[#body + 1] = descendant
			end
		end
	end
	self._parts.body = body

	local attach = {}
	if weaponModel then
		for _, descendant in next, weaponModel:QueryDescendants("BasePart") do
			if self._session.isOverlay(descendant) then
				continue
			end
			attach[#attach + 1] = descendant
		end
	end
	self._parts.attachments = attach
	self._dirty = true

	local modelJanitor = self._modelJanitor
	if modelJanitor then
		modelJanitor:Cleanup()
		if bodyModel then
			modelJanitor:Add(
				bodyModel.DescendantAdded:Connect(function(desc: Instance): ()
					self:_onDescendantAdded(desc)
				end),
				"Disconnect"
			)
		end
		if weaponModel then
			modelJanitor:Add(
				weaponModel.DescendantAdded:Connect(function(desc: Instance): ()
					self:_onDescendantAdded(desc)
				end),
				"Disconnect"
			)
		end
	end
end

function ThirdPersonChams._onDescendantAdded(self: ThirdPersonChams, desc: Instance): ()
	if not self._enabled or self._session.isOverlay(desc) then
		return
	end
	self._session.onDescendantAdded(desc)
end

ThirdPersonChams._categoryStyle = LPH_NO_VIRTUALIZE(function(self: ThirdPersonChams, catState: CategoryState): chamsSession.Style
	local colorLink = catState.colorLink
	local scratch = self._scratch
	scratch.material = catState.material
	scratch.color = colorLink:GetColor()
	scratch.transparency = colorLink:GetTransparency()
	scratch.reflectance = catState.reflectance
	return scratch
end)

ThirdPersonChams._applyGroup = LPH_NO_VIRTUALIZE(function(self: ThirdPersonChams, parts: { BasePart }, style: chamsSession.Style): ()
	for i = 1, #parts do
		local part = parts[i]
		if part.Parent then
			self._session.apply(part, style)
		end
	end
end)

function ThirdPersonChams._restoreParts(self: ThirdPersonChams, parts: { BasePart }): ()
	for i = 1, #parts do
		self._session.restore(parts[i])
	end
end

ThirdPersonChams._step = LPH_NO_VIRTUALIZE(function(self: ThirdPersonChams): ()
	local bodyModel = peek(CustomCharacter.visibleModel) or localThirdPerson.getCharacterModel()
	local weaponModel = localThirdPerson.getWeaponModel()
	if bodyModel ~= self._bodyModel or weaponModel ~= self._weaponModel then
		self:_rebuild(bodyModel, weaponModel)
	end

	self._dirty = false

	for i = 1, #CATEGORY_ORDER do
		local cat: CategoryId = CATEGORY_ORDER[i]
		local catState = self._cats[cat]
		if catState.enabled then
			self:_applyGroup(self._parts[cat], self:_categoryStyle(catState))
		end
	end
end)

function ThirdPersonChams._restore(self: ThirdPersonChams): ()
	self._session.restoreAll()
end

function ThirdPersonChams.Enable(self: ThirdPersonChams): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._dirty = true

	local modelJanitor = Janitor.new()
	self._modelJanitor = modelJanitor
	self._janitor:Add(modelJanitor, "Destroy")

	for i = 1, #CATEGORY_ORDER do
		local catState = self._cats[CATEGORY_ORDER[i]]
		self._janitor:Add((catState.colorLink :: any):OnUpdate(function(): ()
			self._dirty = true
		end))
	end

	self._janitor:Add(
		RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
			self:_step()
		end)),
		"Disconnect"
	)
	self._janitor:Add(function(): ()
		self:_restore()
		self._bodyModel = nil
		self._weaponModel = nil
		self._modelJanitor = nil
		self._parts = { body = {}, attachments = {} }
	end, true)
end

function ThirdPersonChams.Disable(self: ThirdPersonChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function ThirdPersonChams.Destroy(self: ThirdPersonChams): ()
	self:Disable()
	self._session.destroy()
	BaseFeature.Destroy(self)
end

export type ThirdPersonChams =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_settingsLink: gameUi.Linker,
			_cats: { [CategoryId]: CategoryState },
			_parts: { [CategoryId]: { BasePart } },
			_session: chamsSession.Session,
			_scratch: chamsSession.Style,
			_dirty: boolean,
			_bodyModel: Instance?,
			_weaponModel: Instance?,
			_modelJanitor: Janitor.Janitor?,
			_rebuild: (ThirdPersonChams, Instance?, Instance?) -> (),
			_onDescendantAdded: (ThirdPersonChams, Instance) -> (),
			_categoryStyle: (ThirdPersonChams, CategoryState) -> chamsSession.Style,
			_applyGroup: (ThirdPersonChams, { BasePart }, chamsSession.Style) -> (),
			_restoreParts: (ThirdPersonChams, { BasePart }) -> (),
			_step: (ThirdPersonChams) -> (),
			_restore: (ThirdPersonChams) -> (),
		},
		ThirdPersonChams
	))
	& BaseFeature.BaseFeature

return ThirdPersonChams
