local RunService = cloneref(game:GetService("RunService")) :: RunService
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local ModuleController = require("@game/pf/module/ModuleController")
local WeaponController = require("@game/pf/weapon/WeaponController")
local clientState = require("@game/pf/client/clientState")

local peek = Charm.peek

local MATERIALS: { string } = { "ForceField", "Neon", "Glass" }

type CategoryId = "weapon" | "arms" | "sleeves"

local CATEGORY_ORDER: { CategoryId } = { "weapon", "arms", "sleeves" }
local CATEGORY_LABEL: { [CategoryId]: string } = {
	weapon = "Weapon",
	arms = "Arms",
	sleeves = "Sleeves",
}
local CATEGORY_DEFAULTS: { [CategoryId]: { material: string, color: Color3 } } = {
	weapon = { material = "Neon", color = Color3.fromRGB(120, 200, 255) },
	arms = { material = "Neon", color = Color3.fromRGB(145, 190, 215) },
	sleeves = { material = "Neon", color = Color3.fromRGB(120, 200, 235) },
}

local SLEEVES_FOLDER = "Sleeves"

type CategoryState = {
	enabled: boolean,
	material: Enum.Material,
	reflectance: number,
	colorLink: any,
}

local ViewmodelChams = {}
ViewmodelChams.__index = ViewmodelChams

setmetatable(ViewmodelChams, { __index = BaseFeature })

local function isUnder(inst: Instance, name: string): boolean
	local parent = inst.Parent
	while parent do
		if parent.Name == name then
			return true
		end
		parent = parent.Parent
	end
	return false
end

function ViewmodelChams.new(link: gameUi.Linker): ViewmodelChams
	local self = BaseFeature.new() :: any
	setmetatable(self, ViewmodelChams)

	local chamsToggle = link:Toggle("viewmodelChams", "Viewmodel Chams", false):SetTip({
		title = "Viewmodel Chams",
		body = "Recolors your first-person arms and weapon.",
	})
	link:Extra(chamsToggle, "viewmodelChamsSettings", "Submenu", "Viewmodel Chams")
	local settingsLink = link:OnKey("viewmodelChamsSettings")
	self._settingsLink = settingsLink

	self._enabled = false
	self._janitor = Janitor.new()
	self._cats = {} :: { [CategoryId]: CategoryState }
	self._parts = { weapon = {}, arms = {}, sleeves = {} } :: { [CategoryId]: { BasePart } }
	self._orig = setmetatable({}, { __mode = "k" }) :: any
	self._dirty = false
	self._wasThirdPerson = false

	self._leftArm = nil :: Instance?
	self._rightArm = nil :: Instance?
	self._weaponModel = nil :: Instance?

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
			body = "Surface look used for this part group.",
		})
		materialLink:Slider("reflectance", "Reflectance", 0, 0, 1, 0.05):SetTip({
			title = "Reflectance",
			body = "How shiny this part group looks.",
		})

		local catState: CategoryState = {
			enabled = settingsLink:Peek(cat) == true,
			material = Enum.Material[materialLink:Peek("material")] or Enum.Material.Neon,
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
			catState.material = Enum.Material[value] or Enum.Material.Neon
			self._dirty = true
		end))
		self:Track(materialLink:Get("reflectance"):OnChange(function(value: number): ()
			catState.reflectance = type(value) == "number" and value or 0
			self._dirty = true
		end))
	end

	self:Track(link:Get("viewmodelChams"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	return self
end

function ViewmodelChams._rebuildWeapon(self: ViewmodelChams, model: Instance?): ()
	self._weaponModel = model
	local parts = {}
	if model then
		for _, descendant in next, model:QueryDescendants("BasePart") do
			parts[#parts + 1] = descendant
		end
	end
	self._parts.weapon = parts
	self._dirty = true
end

function ViewmodelChams._rebuildArms(self: ViewmodelChams, left: Instance?, right: Instance?): ()
	self._leftArm = left
	self._rightArm = right
	local arms = {}
	local sleeves = {}
	for _, model in next, { left, right } do
		if model then
			for _, descendant in next, model:QueryDescendants("BasePart") do
				if isUnder(descendant, SLEEVES_FOLDER) then
					sleeves[#sleeves + 1] = descendant
				else
					arms[#arms + 1] = descendant
				end
			end
		end
	end
	self._parts.arms = arms
	self._parts.sleeves = sleeves
	self._dirty = true
end

function ViewmodelChams._strip(_self: ViewmodelChams, part: BasePart): any
	local info = {
		color = part.Color,
		material = part.Material,
		reflectance = part.Reflectance,
		transparency = part.Transparency,
		texId = nil :: string?,
		meshTex = {} :: { [Instance]: string },
		detached = {} :: { { inst: Instance, parent: Instance } },
	}
	if part:IsA("MeshPart") then
		info.texId = part.TextureID
		part.TextureID = ""
	end
	for _, child in next, part:GetChildren() do
		if child:IsA("Decal") or child:IsA("Texture") or child:IsA("SurfaceAppearance") then
			info.detached[#info.detached + 1] = { inst = child, parent = part }
			child.Parent = nil
		elseif child:IsA("SpecialMesh") then
			info.meshTex[child] = child.TextureId
			child.TextureId = ""
		end
	end
	return info
end

ViewmodelChams._applyGroup = LPH_NO_VIRTUALIZE(function(
	self: ViewmodelChams,
	parts: { BasePart },
	color: Color3,
	material: Enum.Material,
	reflectance: number,
	transparency: number
): ()
	local orig = self._orig
	for _, part in next, parts do
		if part.Parent then
			local info = orig[part]
			if info == nil then
				info = self:_strip(part)
				orig[part] = info
			end
			part.Color = color
			part.Material = material
			part.Reflectance = reflectance
			if info.transparency < 1 then
				part.Transparency = transparency
			end
		end
	end
end)

function ViewmodelChams._restorePart(_self: ViewmodelChams, part: BasePart, info: any): ()
	if part.Parent then
		part.Color = info.color
		part.Material = info.material
		part.Reflectance = info.reflectance
		part.Transparency = info.transparency
	end
	if info.texId ~= nil and part:IsA("MeshPart") then
		part.TextureID = info.texId
	end
	for mesh, tid in next, info.meshTex do
		mesh.TextureId = tid
	end
	for _, detached in next, info.detached do
		if detached.inst and detached.parent then
			detached.inst.Parent = detached.parent
		end
	end
end

function ViewmodelChams._restoreParts(self: ViewmodelChams, parts: { BasePart }): ()
	local orig = self._orig
	for _, part in next, parts do
		local info = orig[part]
		if info then
			self:_restorePart(part, info)
			orig[part] = nil
		end
	end
end

local _characterInterface: any = nil

local function getCharacterObject(): any?
	local CharacterInterface = _characterInterface or ModuleController.GetModule("CharacterInterface")
	if not CharacterInterface then
		return nil
	end
	_characterInterface = CharacterInterface
	return CharacterInterface.getCharacterObject()
end

ViewmodelChams._step = LPH_NO_VIRTUALIZE(function(self: ViewmodelChams): ()
	if peek(clientState.thirdPerson) then
		if next(self._orig) then
			self:_restore()
		end
		self._wasThirdPerson = true
		return
	end
	if self._wasThirdPerson then
		self._wasThirdPerson = false
		self._dirty = true
	end

	local co = getCharacterObject()
	if co then
		local left, right = co:getArmModels()
		if left ~= self._leftArm or right ~= self._rightArm then
			self:_rebuildArms(left, right)
		end
	elseif self._leftArm then
		self:_rebuildArms(nil, nil)
	end

	local firearm = WeaponController.GetWeapon()
	local model = nil
	if firearm and WeaponController.GetWeaponType() == "Firearm" then
		model = firearm:getWeaponModel()
	end
	if model ~= self._weaponModel then
		self:_rebuildWeapon(model)
	end

	if not self._dirty then
		return
	end
	self._dirty = false

	for i = 1, #CATEGORY_ORDER do
		local cat: CategoryId = CATEGORY_ORDER[i]
		local catState = self._cats[cat]
		if catState.enabled then
			self:_applyGroup(
				self._parts[cat],
				catState.colorLink:GetColor(),
				catState.material,
				catState.reflectance,
				catState.colorLink:GetTransparency()
			)
		end
	end
end)

function ViewmodelChams._restore(self: ViewmodelChams): ()
	for part, info in next, self._orig do
		self:_restorePart(part, info)
	end
	self._orig = setmetatable({}, { __mode = "k" }) :: any
end

function ViewmodelChams.Enable(self: ViewmodelChams): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._dirty = true

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
		self._weaponModel = nil
		self._leftArm = nil
		self._rightArm = nil
		self._parts = { weapon = {}, arms = {}, sleeves = {} }
	end, true)
end

function ViewmodelChams.Disable(self: ViewmodelChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function ViewmodelChams.Destroy(self: ViewmodelChams): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ViewmodelChams =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_settingsLink: gameUi.Linker,
			_cats: { [CategoryId]: CategoryState },
			_parts: { [CategoryId]: { BasePart } },
			_orig: any,
			_dirty: boolean,
			_wasThirdPerson: boolean,
			_leftArm: Instance?,
			_rightArm: Instance?,
			_weaponModel: Instance?,
			_rebuildWeapon: (ViewmodelChams, Instance?) -> (),
			_rebuildArms: (ViewmodelChams, Instance?, Instance?) -> (),
			_strip: (ViewmodelChams, BasePart) -> any,
			_applyGroup: (ViewmodelChams, { BasePart }, Color3, Enum.Material, number, number) -> (),
			_restorePart: (ViewmodelChams, BasePart, any) -> (),
			_restoreParts: (ViewmodelChams, { BasePart }) -> (),
			_step: (ViewmodelChams) -> (),
			_restore: (ViewmodelChams) -> (),
		},
		ViewmodelChams
	))
	& BaseFeature.BaseFeature

return ViewmodelChams
