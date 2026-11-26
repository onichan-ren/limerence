local RunService = cloneref(game:GetService("RunService")) :: RunService
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/overkill/module/ModuleController")
local clientState = require("@game/overkill/client/clientState")
local customCharacterOpts = require("@game/overkill/feature/visual/self/customCharacterOpts")
local chamsSession = require("@game/universal/feature/visual/chams/chamsSession")

local peek = Charm.peek
local sub = Charm.subscribe

local MATERIALS: { string } = {
	"ForceField",
	"Neon",
}


local DEFAULT_COLOR = Color3.fromRGB(145, 190, 215)
local DEFAULT_ATTACHMENT_COLOR = Color3.fromRGB(168, 168, 168)
local DEFAULT_MATERIAL = "Neon"

local EXCLUDED_PART_NAMES: { [string]: true } = {
	HumanoidRootPart = true,
	HeadCollider = true,
	BoundingBody = true,
}

type ClothingEntry = {
	template: string,
	propName: string,
	conn: RBXScriptConnection?,
}

local function isClothing(inst: Instance): boolean
	local className = inst.ClassName
	if className == "Shirt" or className == "Pants" then
		return true
	end
	return false
end

local function isExcludedPart(part: BasePart): boolean
	if EXCLUDED_PART_NAMES[part.Name] then
		return true
	end
	if string.find(part.Name, "Hitbox") then
		return true
	end
	return false
end

local function shouldPatchPart(part: Instance): boolean
	if not part:IsA("BasePart") then
		return false
	end
	local base = part :: BasePart
	return not isExcludedPart(base)
end

local CharacterChams = {}
CharacterChams.__index = CharacterChams

setmetatable(CharacterChams, { __index = BaseFeature })

function CharacterChams.new(link: gameUi.Linker): CharacterChams
	local self = BaseFeature.new() :: any
	setmetatable(self, CharacterChams)

	self._enabled = false
	self._activeJanitor = nil :: Janitor.Janitor?
	self._characterJanitor = nil :: Janitor.Janitor?
	self._customJanitor = nil :: Janitor.Janitor?
	self._vmcJanitor = nil :: Janitor.Janitor?
	self._vmc = nil :: any
	self._viewModelModule = nil :: any
	self._session = chamsSession.new({
		lockAppearance = true,
		skipTransparency = true,
	})
	self._parts = setmetatable({}, { __mode = "k" }) :: any
	self._hiddenClothing = {} :: { [Instance]: ClothingEntry }
	self._settingsLink = nil :: gameUi.Linker?
	self._targetMaterial = Enum.Material.Neon
	self._targetColor = DEFAULT_COLOR
	self._targetAttachmentColor = DEFAULT_ATTACHMENT_COLOR

	local chamsToggle = link:Toggle("characterChams", "Character Chams", false):SetTip({
		title = "Character Chams",
		body = "Recolors your third-person character body. Only visible when you are in third person.",
	})
	link:Extra(chamsToggle, "characterChamsSettings", "Submenu", "Character Chams")
	local settingsLink = link:OnKey("characterChamsSettings")
	self._settingsLink = settingsLink

	settingsLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0):SetTip({
		title = "Color",
		body = "Body cham color.",
	})
	settingsLink:Dropdown("material", "Material", MATERIALS, DEFAULT_MATERIAL):SetTip({
		title = "Material",
		body = "Material applied to your character and weapon parts.",
	})
	local attachmentsToggle = settingsLink:Toggle("attachments", "Attachments", true):SetTip({
		title = "Attachments",
		body = "Also recolors your third-person weapon model.",
	})
	settingsLink:Extra(attachmentsToggle, "attachmentsColor", "Colorpicker", "Color", DEFAULT_ATTACHMENT_COLOR, 0)

	self:Track(link:Get("characterChams"):OnChange(function(state: boolean): ()
		if state then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Get("characterChams"):Peek() then
		self:Enable()
	end

	return self
end

function CharacterChams._material(self: CharacterChams): Enum.Material
	local settingsLink = self._settingsLink
	local name = DEFAULT_MATERIAL
	if settingsLink then
		name = settingsLink:Peek("material") or name
	end
	return (Enum.Material :: any)[name] or Enum.Material.Neon
end

function CharacterChams._color(self: CharacterChams): Color3
	local settingsLink = self._settingsLink
	if not settingsLink then
		return DEFAULT_COLOR
	end
	return (settingsLink:Get("color") :: any):GetColor()
end

function CharacterChams._attachmentColor(self: CharacterChams): Color3
	local settingsLink = self._settingsLink
	if not settingsLink then
		return DEFAULT_ATTACHMENT_COLOR
	end
	return (settingsLink:Get("attachmentsColor") :: any):GetColor()
end

function CharacterChams._attachmentsEnabled(self: CharacterChams): boolean
	local settingsLink = self._settingsLink
	if not settingsLink then
		return false
	end
	return settingsLink:Peek("attachments") == true
end

function CharacterChams._recomputeTargets(self: CharacterChams): ()
	self._targetMaterial = self:_material()
	self._targetColor = self:_color()
	self._targetAttachmentColor = self:_attachmentColor()
end

CharacterChams._styleFor = LPH_NO_VIRTUALIZE(function(self: CharacterChams, attachment: boolean): chamsSession.Style
	return {
		material = self._targetMaterial,
		color = attachment and self._targetAttachmentColor or self._targetColor,
		transparency = 0,
		reflectance = 0,
	}
end)

function CharacterChams._applyPart(self: CharacterChams, part: BasePart, attachment: boolean?): ()
	if self._parts[part] ~= nil or not shouldPatchPart(part) then
		return
	end
	local isAttachment = attachment == true
	self._parts[part] = isAttachment
	self._session.apply(part, self:_styleFor(isAttachment))
end

function CharacterChams._restorePart(self: CharacterChams, part: BasePart): ()
	if self._parts[part] == nil then
		return
	end
	self._parts[part] = nil
	self._session.restore(part)
end

function CharacterChams._hideClothing(self: CharacterChams, inst: Instance): ()
	if self._hiddenClothing[inst] then
		return
	end
	local propName: string
	local template: string
	if inst.ClassName == "Shirt" then
		propName = "ShirtTemplate"
		template = (inst :: any).ShirtTemplate
		;(inst :: any).ShirtTemplate = ""
	else
		propName = "PantsTemplate"
		template = (inst :: any).PantsTemplate
		;(inst :: any).PantsTemplate = ""
	end

	local conn = inst:GetPropertyChangedSignal(propName):Connect(function(): ()
		if not self._hiddenClothing[inst] then
			return
		end
		if (inst :: any)[propName] ~= "" then
			(inst :: any)[propName] = ""
		end
	end)

	self._hiddenClothing[inst] = { template = template, propName = propName, conn = conn }
end

function CharacterChams._restoreClothing(self: CharacterChams, inst: Instance): ()
	local entry = self._hiddenClothing[inst]
	if not entry then
		return
	end
	self._hiddenClothing[inst] = nil
	if entry.conn then
		entry.conn:Disconnect()
	end
	(inst :: any)[entry.propName] = entry.template
end

function CharacterChams._releaseClothing(self: CharacterChams, inst: Instance): ()
	local entry = self._hiddenClothing[inst]
	if not entry then
		return
	end
	self._hiddenClothing[inst] = nil
	if entry.conn then
		entry.conn:Disconnect()
	end
end

function CharacterChams._restoreAllClothing(self: CharacterChams): ()
	for inst in next, self._hiddenClothing do
		self:_restoreClothing(inst)
	end
end

function CharacterChams._refreshAppearance(self: CharacterChams): ()
	self:_recomputeTargets()
	for part, attachment in next, self._parts do
		self._session.apply(part, self:_styleFor(attachment))
	end
end

function CharacterChams._restoreAll(self: CharacterChams): ()
	self._session.restoreAll()
	table.clear(self._parts)
	self:_restoreAllClothing()
end

function CharacterChams._watchModel(self: CharacterChams, model: Instance, janitor: Janitor.Janitor, attachment: boolean?): ()
	janitor:Add(function(): ()
		local clothing: { Instance } = {}
		for inst in next, self._hiddenClothing do
			if inst:IsDescendantOf(model) then
				clothing[#clothing + 1] = inst
			end
		end
		for i = 1, #clothing do
			self:_restoreClothing(clothing[i])
		end

		local parts: { BasePart } = {}
		for part in next, self._parts do
			if part:IsDescendantOf(model) then
				parts[#parts + 1] = part
			end
		end
		for i = 1, #parts do
			self:_restorePart(parts[i])
		end
	end, true)

	for _, desc in next, model:QueryDescendants("Instance") do
		if isClothing(desc) then
			self:_hideClothing(desc)
		elseif shouldPatchPart(desc) then
			self:_applyPart(desc :: BasePart, attachment)
		end
	end

	janitor:Add(
		model.DescendantAdded:Connect(function(desc: Instance): ()
			if isClothing(desc) then
				self:_hideClothing(desc)
			elseif desc:IsA("BasePart") then
				self:_applyPart(desc :: BasePart, attachment)
			else
				self._session.onDescendantAdded(desc)
			end
		end),
		"Disconnect"
	)

	janitor:Add(
		model.DescendantRemoving:Connect(function(desc: Instance): ()
			if isClothing(desc) then
				self:_releaseClothing(desc)
			elseif desc:IsA("BasePart") and self._parts[desc] ~= nil then
				self:_restorePart(desc :: BasePart)
			end
		end),
		"Disconnect"
	)
end

function CharacterChams._onCharacterChanged(self: CharacterChams, character: Model?): ()
	if self._characterJanitor then
		self._characterJanitor:Destroy()
		self._characterJanitor = nil
	end

	if not character then
		return
	end

	local charJanitor = Janitor.new()
	self._characterJanitor = charJanitor
	self:_watchModel(character, charJanitor)
end

function CharacterChams._onCustomModelChanged(self: CharacterChams, model: Model?): ()
	if self._customJanitor then
		self._customJanitor:Destroy()
		self._customJanitor = nil
	end

	if not model then
		return
	end

	local customJanitor = Janitor.new()
	self._customJanitor = customJanitor
	self:_watchModel(model, customJanitor)
end

CharacterChams._resolveVmc = LPH_NO_VIRTUALIZE(function(self: CharacterChams): any?
	local viewModel = self._viewModelModule
	if not viewModel then
		viewModel = ModuleController.GetModule("viewModel")
		self._viewModelModule = viewModel
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
	if type(vmc) ~= "table" or vmc.isLocal or vmc.destroying then
		return nil
	end
	local gunModel = vmc.gunModel
	if typeof(gunModel) ~= "Instance" or gunModel.Parent == nil then
		return nil
	end
	return vmc
end)

function CharacterChams._clearVmc(self: CharacterChams): ()
	self._vmc = nil
	if self._vmcJanitor then
		self._vmcJanitor:Destroy()
		self._vmcJanitor = nil
	end
end

CharacterChams._step = LPH_NO_VIRTUALIZE(function(self: CharacterChams): ()
	if not self:_attachmentsEnabled() then
		if self._vmc then
			self:_clearVmc()
		end
		return
	end

	local vmc = self:_resolveVmc()
	if vmc == self._vmc then
		return
	end

	self:_clearVmc()
	if not vmc then
		return
	end
	self._vmc = vmc

	local janitor = Janitor.new()
	self._vmcJanitor = janitor

	local gunModel = vmc.gunModel :: Instance
	self:_watchModel(gunModel, janitor, true)

	local attachments = vmc.attachments
	if type(attachments) == "table" then
		for _, info in next, attachments do
			local folder = info.attachment
			if typeof(folder) == "Instance" and not folder:IsDescendantOf(gunModel) then
				self:_watchModel(folder, janitor, true)
			end
		end
	end
end)

function CharacterChams.Enable(self: CharacterChams): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local janitor = Janitor.new()
	self._activeJanitor = janitor

	self:_recomputeTargets()

	janitor:Add(sub(clientState.character, function(character: Model?): ()
		self:_onCharacterChanged(character)
	end))

	janitor:Add(sub(customCharacterOpts.modelAtom, function(model: Model?): ()
		self:_onCustomModelChanged(model)
	end))

	local settingsLink = self._settingsLink
	if settingsLink then
		local picker: any = settingsLink:Get("color")
		local attachmentPicker: any = settingsLink:Get("attachmentsColor")
		local materialEl: any = settingsLink:Get("material")

		janitor:Add(picker:OnUpdate(function(): ()
			self:_refreshAppearance()
		end))

		janitor:Add(attachmentPicker:OnUpdate(function(): ()
			self:_refreshAppearance()
		end))

		janitor:Add(materialEl:OnChange(function(): ()
			self:_refreshAppearance()
		end))
	end

	self._viewModelModule = ModuleController.GetModule("viewModel")

	janitor:Add(
		RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
			self:_step()
		end)),
		"Disconnect"
	)

	janitor:Add(function(): ()
		self:_clearVmc()
	end, true)

	self:_onCharacterChanged(peek(clientState.character))
	self:_onCustomModelChanged(peek(customCharacterOpts.modelAtom))
end

function CharacterChams.Disable(self: CharacterChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self:_restoreAll()
	self:_clearVmc()

	if self._characterJanitor then
		self._characterJanitor:Destroy()
		self._characterJanitor = nil
	end

	if self._customJanitor then
		self._customJanitor:Destroy()
		self._customJanitor = nil
	end

	if self._activeJanitor then
		self._activeJanitor:Destroy()
		self._activeJanitor = nil
	end
end

function CharacterChams.Destroy(self: CharacterChams): ()
	self:Disable()
	self._session.destroy()
	BaseFeature.Destroy(self)
end

export type CharacterChams =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_activeJanitor: Janitor.Janitor?,
			_characterJanitor: Janitor.Janitor?,
			_customJanitor: Janitor.Janitor?,
			_vmcJanitor: Janitor.Janitor?,
			_vmc: any,
			_viewModelModule: any,
			_session: chamsSession.Session,
			_parts: { [BasePart]: boolean },
			_hiddenClothing: { [Instance]: ClothingEntry },
			_settingsLink: gameUi.Linker?,
			_targetMaterial: Enum.Material,
			_targetColor: Color3,
			_targetAttachmentColor: Color3,
			_styleFor: (CharacterChams, boolean) -> chamsSession.Style,
			_applyPart: (CharacterChams, BasePart, boolean?) -> (),
			_restorePart: (CharacterChams, BasePart) -> (),
			_resolveVmc: (CharacterChams) -> any?,
			_clearVmc: (CharacterChams) -> (),
			_step: (CharacterChams) -> (),
		},
		CharacterChams
	))
	& BaseFeature.BaseFeature

return CharacterChams
