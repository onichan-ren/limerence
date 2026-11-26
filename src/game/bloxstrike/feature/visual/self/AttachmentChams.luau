local Players = cloneref(game:GetService("Players")) :: Players
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local clientState = require("@game/bloxstrike/client/clientState")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local chamsSession = require("@game/universal/feature/visual/chams/chamsSession")

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

local MATERIALS: { string } = {
	"ForceField",
	"Neon",
}

local DEFAULT_COLOR = Color3.fromRGB(168, 168, 168)
local DEFAULT_MATERIAL = "Neon"

local CHARACTER_WEAPON_ROOTS: { [string]: true } = {
	WeaponModel = true,
	WeaponAttachments = true,
}

local SKIP_PART_NAMES: { [string]: true } = {
	MuzzlePartL = true,
	MuzzlePartR = true,
	MuzzlePart = true,
	RootPart = true,
	Hitbox = true,
	Insert = true,
	move = true,
}


local function isPlayerWeaponDebrisRoot(inst: Instance): boolean
	if not LocalPlayer then
		return false
	end
	local prefix = LocalPlayer.Name
	return inst.Name == prefix .. "_Weapon" or inst.Name == prefix .. "_WeaponAttachments"
end

local function isUnderWeaponRoot(part: BasePart): boolean
	local current: Instance? = part
	while current do
		if CHARACTER_WEAPON_ROOTS[current.Name] then
			local parent = current.Parent
			if parent and parent.ClassName == "Model" and parent:FindFirstChildOfClass("Humanoid") then
				return true
			end
		end
		if isPlayerWeaponDebrisRoot(current) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function shouldPatchPart(part: Instance): boolean
	if not part:IsA("BasePart") then
		return false
	end
	local base = part :: BasePart
	if base.Transparency >= 1 or SKIP_PART_NAMES[base.Name] then
		return false
	end
	return isUnderWeaponRoot(base)
end

local function collectWeaponRoots(character: Model?): { Instance }
	local roots: { Instance } = {}
	if character then
		local weaponModel = character:FindFirstChild("WeaponModel")
		local weaponAttachments = character:FindFirstChild("WeaponAttachments")
		if weaponModel then
			roots[#roots + 1] = weaponModel
		end
		if weaponAttachments then
			roots[#roots + 1] = weaponAttachments
		end
	end

	local debris = Workspace:FindFirstChild("Debris")
	if debris and LocalPlayer then
		local equipped = debris:FindFirstChild(LocalPlayer.Name .. "_Weapon")
		local attachments = debris:FindFirstChild(LocalPlayer.Name .. "_WeaponAttachments")
		if equipped then
			roots[#roots + 1] = equipped
		end
		if attachments then
			roots[#roots + 1] = attachments
		end
	end

	return roots
end

local AttachmentChams = {}
AttachmentChams.__index = AttachmentChams

setmetatable(AttachmentChams, { __index = BaseFeature })

function AttachmentChams.new(link: gameUi.Linker): AttachmentChams
	local self = BaseFeature.new() :: any
	setmetatable(self, AttachmentChams)

	self._enabled = false
	self._activeJanitor = nil :: Janitor.Janitor?
	self._rootsJanitor = nil :: Janitor.Janitor?
	self._session = chamsSession.new({
		overlayMeshParts = false,
		skipTransparency = false,
		lockAppearance = false,
		lockTransparency = false,
	})
	self._parts = setmetatable({}, { __mode = "k" }) :: any
	self._settingsLink = nil :: gameUi.Linker?

	local chamsToggle = link:Toggle("attachmentChams", "Attachment Chams", false):SetTip({
		title = "Attachment Chams",
		body = "Recolors your third-person weapon and holster models.",
	})
	link:Extra(chamsToggle, "attachmentChamsSettings", "Submenu", "Attachment Chams")
	local settingsLink = link:OnKey("attachmentChamsSettings")
	self._settingsLink = settingsLink

	settingsLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0):SetTip({
		title = "Color",
		body = "Weapon cham color and transparency.",
	})
	settingsLink:Dropdown("material", "Material", MATERIALS, DEFAULT_MATERIAL):SetTip({
		title = "Material",
		body = "Material applied to third-person weapon mesh parts.",
	})

	self:Track(link:Get("attachmentChams"):OnChange(function(state: boolean): ()
		if state then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Get("attachmentChams"):Peek() then
		self:Enable()
	end

	return self
end

function AttachmentChams._material(self: AttachmentChams): Enum.Material
	local settingsLink = self._settingsLink
	local name = DEFAULT_MATERIAL
	if settingsLink then
		name = settingsLink:Peek("material") or name
	end
	return Enum.Material[name] or Enum.Material.Neon
end

function AttachmentChams._color(self: AttachmentChams): Color3
	local settingsLink = self._settingsLink
	if not settingsLink then
		return DEFAULT_COLOR
	end
	return (settingsLink:Get("color") :: any):GetColor()
end

function AttachmentChams._transparency(self: AttachmentChams): number
	local settingsLink = self._settingsLink
	if not settingsLink then
		return 0
	end
	return (settingsLink:Get("color") :: any):GetTransparency()
end

AttachmentChams._style = LPH_NO_VIRTUALIZE(function(self: AttachmentChams): chamsSession.Style
	return {
		material = self:_material(),
		color = self:_color(),
		transparency = self:_transparency(),
		reflectance = 0,
	}
end)

function AttachmentChams._applyPart(self: AttachmentChams, part: BasePart, style: chamsSession.Style): ()
	if self._parts[part] ~= nil or not shouldPatchPart(part) then
		return
	end

	self._parts[part] = true
	self._session.apply(part, style)
end

function AttachmentChams._restorePart(self: AttachmentChams, part: BasePart): ()
	if self._parts[part] == nil then
		return
	end

	self._parts[part] = nil
	self._session.restore(part)
end

AttachmentChams._refreshAppearance = LPH_NO_VIRTUALIZE(function(self: AttachmentChams): ()
	local style = self:_style()
	for part in next, self._parts do
		self._session.apply(part, style)
	end
end)

function AttachmentChams._restoreAll(self: AttachmentChams): ()
	self._session.restoreAll()
	table.clear(self._parts)
end

AttachmentChams._patchRoot = LPH_NO_VIRTUALIZE(function(self: AttachmentChams, root: Instance): ()
	local style = self:_style()
	for _, desc in next, root:QueryDescendants("Instance") do
		if shouldPatchPart(desc) then
			self:_applyPart(desc :: BasePart, style)
		end
	end
end)

function AttachmentChams._bindRoot(self: AttachmentChams, root: Instance, janitor: Janitor.Janitor): ()
	self:_patchRoot(root)

	janitor:Add(
		root.DescendantAdded:Connect(function(desc: Instance): ()
			if shouldPatchPart(desc) then
				self:_applyPart(desc :: BasePart, self:_style())
			elseif not desc:IsA("BasePart") then
				self._session.onDescendantAdded(desc)
			end
		end),
		"Disconnect"
	)

	janitor:Add(
		root.DescendantRemoving:Connect(function(desc: Instance): ()
			if desc:IsA("BasePart") and self._parts[desc] ~= nil then
				self:_restorePart(desc :: BasePart)
			end
		end),
		"Disconnect"
	)
end

function AttachmentChams._rescan(self: AttachmentChams): ()
	self:_restoreAll()

	if self._rootsJanitor then
		self._rootsJanitor:Destroy()
		self._rootsJanitor = nil
	end

	local roots = collectWeaponRoots(peek(clientState.character))
	if #roots == 0 then
		return
	end

	local janitor = Janitor.new()
	self._rootsJanitor = janitor

	for _, root in next, roots do
		self:_bindRoot(root, janitor)
	end
end

function AttachmentChams.Enable(self: AttachmentChams): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local janitor = Janitor.new()
	self._activeJanitor = janitor

	local function scheduleRescan(): ()
		task.defer(function()
			if self._enabled then
				self:_rescan()
			end
		end)
	end

	janitor:Add(sub(clientState.character, scheduleRescan))
	janitor:Add(sub(loadoutState.currentEquipped, scheduleRescan))
	janitor:Add(sub(loadoutState.inventory, scheduleRescan))

	local debris = Workspace:FindFirstChild("Debris")
	if debris then
		janitor:Add(
			debris.ChildAdded:Connect(function(child: Instance): ()
				if isPlayerWeaponDebrisRoot(child) then
					scheduleRescan()
				end
			end),
			"Disconnect"
		)
	end

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

	scheduleRescan()
end

function AttachmentChams.Disable(self: AttachmentChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self:_restoreAll()

	if self._rootsJanitor then
		self._rootsJanitor:Destroy()
		self._rootsJanitor = nil
	end

	if self._activeJanitor then
		self._activeJanitor:Destroy()
		self._activeJanitor = nil
	end
end

function AttachmentChams.Destroy(self: AttachmentChams): ()
	self:Disable()
	self._session.destroy()
	BaseFeature.Destroy(self)
end

export type AttachmentChams =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_activeJanitor: Janitor.Janitor?,
			_rootsJanitor: Janitor.Janitor?,
			_session: chamsSession.Session,
			_parts: { [BasePart]: boolean },
			_settingsLink: gameUi.Linker?,
			_style: (AttachmentChams) -> chamsSession.Style,
			_applyPart: (AttachmentChams, BasePart, chamsSession.Style) -> (),
			_restorePart: (AttachmentChams, BasePart) -> (),
		},
		AttachmentChams
	))
	& BaseFeature.BaseFeature

return AttachmentChams
