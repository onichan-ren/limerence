local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local clientState = require("@game/rivals/client/clientState")
local chamsSession = require("@game/universal/feature/visual/chams/chamsSession")

local peek = Charm.peek
local sub = Charm.subscribe

local MATERIALS: { string } = {
	"ForceField",
	"Neon",
}


local DEFAULT_COLOR = Color3.fromRGB(145, 190, 215)
local DEFAULT_MATERIAL = "Neon"

local EXCLUDED_PART_NAMES: { [string]: true } = {
	HumanoidRootPart = true,
	HitboxHead = true,
	HitboxBody = true,
	HitboxHeadSmall = true,
	HitboxBodySmall = true,
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
	if part:GetAttribute("IgnoreVisibilityCheck") then
		return true
	end
	return false
end

local function shouldPatchPart(part: Instance): boolean
	if not part:IsA("BasePart") then
		return false
	end
	local base = part :: BasePart
	if base.Transparency >= 1 then
		return false
	end
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
	self._session = chamsSession.new({
		lockAppearance = true,
		skipTransparency = true,
	})
	self._parts = setmetatable({}, { __mode = "k" }) :: any
	self._hiddenClothing = {} :: { [Instance]: ClothingEntry }
	self._settingsLink = nil :: gameUi.Linker?
	self._targetMaterial = Enum.Material.Neon
	self._targetColor = DEFAULT_COLOR

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
		body = "Material applied to your character mesh parts.",
	})

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
	return Enum.Material[name] or Enum.Material.Neon
end

function CharacterChams._color(self: CharacterChams): Color3
	local settingsLink = self._settingsLink
	if not settingsLink then
		return DEFAULT_COLOR
	end
	return (settingsLink:Get("color") :: any):GetColor()
end

function CharacterChams._recomputeTargets(self: CharacterChams): ()
	self._targetMaterial = self:_material()
	self._targetColor = self:_color()
end

CharacterChams._styleFor = LPH_NO_VIRTUALIZE(function(self: CharacterChams): chamsSession.Style
	return {
		material = self._targetMaterial,
		color = self._targetColor,
		transparency = 0,
		reflectance = 0,
	}
end)

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

function CharacterChams._hideClothingInModel(self: CharacterChams, model: Model): ()
	for _, desc in next, model:QueryDescendants("Instance") do
		if isClothing(desc) then
			self:_hideClothing(desc)
		end
	end
end

function CharacterChams._applyPart(self: CharacterChams, part: BasePart): ()
	if self._parts[part] ~= nil or not shouldPatchPart(part) then
		return
	end
	self._parts[part] = true
	self._session.apply(part, self:_styleFor())
end

function CharacterChams._restorePart(self: CharacterChams, part: BasePart): ()
	if self._parts[part] == nil then
		return
	end
	self._parts[part] = nil
	self._session.restore(part)
end

function CharacterChams._refreshAppearance(self: CharacterChams): ()
	self:_recomputeTargets()
	local style = self:_styleFor()
	for part in next, self._parts do
		self._session.apply(part, style)
	end
end

function CharacterChams._restoreAll(self: CharacterChams): ()
	self._session.restoreAll()
	table.clear(self._parts)
	self:_restoreAllClothing()
end

function CharacterChams._patchModel(self: CharacterChams, model: Model): ()
	for _, desc in next, model:QueryDescendants("BasePart") do
		if shouldPatchPart(desc) then
			self:_applyPart(desc :: BasePart)
		end
	end
end

function CharacterChams._onCharacterChanged(self: CharacterChams, character: Model?): ()
	self:_restoreAll()

	if self._characterJanitor then
		self._characterJanitor:Destroy()
		self._characterJanitor = nil
	end

	if not character then
		return
	end

	self._characterJanitor = Janitor.new()
	self:_hideClothingInModel(character)
	self:_patchModel(character)

	local charJanitor = self._characterJanitor
	if charJanitor then
		charJanitor:Add(
			character.DescendantAdded:Connect(function(desc: Instance): ()
				if isClothing(desc) then
					self:_hideClothing(desc)
				elseif desc:IsA("BasePart") then
					self:_applyPart(desc :: BasePart)
				else
					self._session.onDescendantAdded(desc)
				end
			end),
			"Disconnect"
		)

		charJanitor:Add(
			character.DescendantRemoving:Connect(function(desc: Instance): ()
				if isClothing(desc) then
					self:_releaseClothing(desc)
				elseif desc:IsA("BasePart") and self._parts[desc] ~= nil then
					self:_restorePart(desc :: BasePart)
				end
			end),
			"Disconnect"
		)
	end
end

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

	local settingsLink = self._settingsLink
	if settingsLink then
		local picker: any = settingsLink:Get("color")
		local materialEl: any = settingsLink:Get("material")

		janitor:Add(picker:OnUpdate(function(): ()
			self:_refreshAppearance()
		end))

		janitor:Add(materialEl:OnChange(function(): ()
			self:_refreshAppearance()
		end))
	end

	self:_onCharacterChanged(peek(clientState.character))
end

function CharacterChams.Disable(self: CharacterChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self:_restoreAll()

	if self._characterJanitor then
		self._characterJanitor:Destroy()
		self._characterJanitor = nil
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
			_session: chamsSession.Session,
			_parts: { [BasePart]: boolean },
			_hiddenClothing: { [Instance]: ClothingEntry },
			_settingsLink: gameUi.Linker?,
			_targetMaterial: Enum.Material,
			_targetColor: Color3,
			_styleFor: (CharacterChams) -> chamsSession.Style,
			_applyPart: (CharacterChams, BasePart) -> (),
			_restorePart: (CharacterChams, BasePart) -> (),
		},
		CharacterChams
	))
	& BaseFeature.BaseFeature

return CharacterChams
