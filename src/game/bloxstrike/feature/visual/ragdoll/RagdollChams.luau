local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local clientState = require("@game/bloxstrike/client/clientState")
local gamemodeState = require("@game/bloxstrike/gamemodeState")

local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService
local Players = cloneref(game:GetService("Players")) :: Players

local peek = Charm.peek

local MATERIALS: { string } = {
	"ForceField",
	"Neon",
}

local RAGDOLL_TAG = "Ragdoll"

type CategoryId = "enemy" | "friendly"

local CATEGORY_ORDER: { CategoryId } = { "enemy", "friendly" }
local CATEGORY_LABEL: { [CategoryId]: string } = {
	enemy = "Enemy",
	friendly = "Friendly",
}
local CATEGORY_DEFAULTS: { [CategoryId]: { material: string, color: Color3, enabled: boolean } } = {
	enemy = { material = "ForceField", color = Color3.fromRGB(195, 95, 95), enabled = true },
	friendly = { material = "ForceField", color = Color3.fromRGB(120, 175, 200), enabled = false },
}

type PatchEntry = {
	category: CategoryId,
	material: Enum.Material,
	color: Color3,
	transparency: number,
	textureId: string,
	overlays: { Instance },
}

type RagdollRecord = {
	janitor: Janitor.Janitor,
	category: CategoryId,
}

local function shouldPatchPart(inst: Instance): boolean
	if not inst:IsA("BasePart") then
		return false
	end
	return (inst :: BasePart).Transparency < 1
end

local function resolveCategory(ragdoll: Instance): CategoryId
	local player = Players:FindFirstChild(ragdoll.Name) :: Player?
	if not player then
		return "enemy"
	end
	local team = player.Team
	if not team then
		return "enemy"
	end
	local localTeam = peek(clientState.team)
	if localTeam and team.Name == localTeam and not gamemodeState.isDeathmatch() then
		return "friendly"
	end
	return "enemy"
end

local RagdollChams = {}
RagdollChams.__index = RagdollChams

setmetatable(RagdollChams, { __index = BaseFeature })

function RagdollChams.new(link: gameUi.Linker): RagdollChams
	local self = BaseFeature.new() :: any
	setmetatable(self, RagdollChams)

	self._enabled = false
	self._activeJanitor = nil :: Janitor.Janitor?
	self._ragdolls = {} :: { [Instance]: RagdollRecord }
	self._patched = {} :: { [BasePart]: PatchEntry }
	self._settingsLink = nil :: gameUi.Linker?

	local chamsToggle = link:Toggle("ragdollChams", "Ragdoll Chams", false):SetTip({
		title = "Ragdoll Chams",
		body = "Recolors ragdolls left behind when a player dies. Configurable per team.",
	})
	link:Extra(chamsToggle, "ragdollChamsSettings", "Submenu", "Ragdoll Chams")
	local settingsLink = link:OnKey("ragdollChamsSettings")
	self._settingsLink = settingsLink

	for i = 1, #CATEGORY_ORDER do
		local cat: CategoryId = CATEGORY_ORDER[i]
		local defaults = CATEGORY_DEFAULTS[cat]
		local catToggle = settingsLink:Toggle(cat, CATEGORY_LABEL[cat], defaults.enabled):SetTip({
			title = CATEGORY_LABEL[cat],
			body = "Enable chams for ragdolls of this team.",
		})
		settingsLink:Extra(catToggle, cat .. "Color", "Colorpicker", "Color", defaults.color, 0)
		local materialOptsKey = cat .. "MaterialOpts"
		settingsLink:Extra(catToggle, materialOptsKey, "Submenu", "Material")
		local materialLink = settingsLink:OnKey(materialOptsKey)
		materialLink:Dropdown("material", "Material", MATERIALS, defaults.material):SetTip({
			title = "Material",
			body = "Material applied to ragdolls of this team.",
		})
	end

	self:Track(link:Get("ragdollChams"):OnChange(function(state: boolean): ()
		if state then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Get("ragdollChams"):Peek() then
		self:Enable()
	end

	return self
end

function RagdollChams._categoryEnabled(self: RagdollChams, category: CategoryId): boolean
	local settingsLink = self._settingsLink
	if not settingsLink then
		return false
	end
	return settingsLink:Peek(category) == true
end

function RagdollChams._categoryMaterial(self: RagdollChams, category: CategoryId): Enum.Material
	local settingsLink = self._settingsLink
	local name = CATEGORY_DEFAULTS[category].material
	if settingsLink then
		name = settingsLink:OnKey(category .. "MaterialOpts"):Peek("material") or name
	end
	return (Enum.Material :: any)[name] or Enum.Material.ForceField
end

function RagdollChams._categoryColor(self: RagdollChams, category: CategoryId): Color3
	local settingsLink = self._settingsLink
	if not settingsLink then
		return CATEGORY_DEFAULTS[category].color
	end
	return (settingsLink:Get(category .. "Color") :: any):GetColor()
end

function RagdollChams._categoryTransparency(self: RagdollChams, category: CategoryId): number
	local settingsLink = self._settingsLink
	if not settingsLink then
		return 0
	end
	return (settingsLink:Get(category .. "Color") :: any):GetTransparency()
end

function RagdollChams._stripTextures(_: RagdollChams, part: BasePart, entry: PatchEntry): ()
	if part:IsA("MeshPart") then
		entry.textureId = (part :: MeshPart).TextureID
		part.TextureID = ""
	end

	for _, child: any in next, part:GetChildren() do
		local className = child.ClassName
		if className == "SurfaceAppearance" or className == "Texture" or className == "Decal" then
			entry.overlays[#entry.overlays + 1] = child
			child.Parent = nil
		end
	end
end

function RagdollChams._applyPart(
	self: RagdollChams,
	part: BasePart,
	category: CategoryId,
	material: Enum.Material?,
	color: Color3?,
	transparency: number?
): ()
	if self._patched[part] or not shouldPatchPart(part) then
		return
	end
	if not self:_categoryEnabled(category) then
		return
	end

	local entry: PatchEntry = {
		category = category,
		material = part.Material,
		color = part.Color,
		transparency = part.Transparency,
		textureId = "",
		overlays = {},
	}

	self:_stripTextures(part, entry)
	self._patched[part] = entry

	if material == nil then
		material = self:_categoryMaterial(category)
		color = self:_categoryColor(category)
		transparency = self:_categoryTransparency(category)
	end
	part.Material = material
	part.Color = color
	part.Transparency = transparency
end

function RagdollChams._restorePart(self: RagdollChams, part: BasePart): ()
	local entry = self._patched[part]
	if not entry then
		return
	end
	self._patched[part] = nil

	part.Material = entry.material
	part.Color = entry.color
	part.Transparency = entry.transparency
	if part:IsA("MeshPart") then
		(part :: MeshPart).TextureID = entry.textureId
	end

	for _, overlay in next, entry.overlays do
		overlay.Parent = part
	end
end

function RagdollChams._refreshCategory(self: RagdollChams, category: CategoryId): ()
	local enabled = self:_categoryEnabled(category)

	if enabled then
		local material = self:_categoryMaterial(category)
		local color = self:_categoryColor(category)
		local transparency = self:_categoryTransparency(category)

		for part, entry in next, self._patched do
			if entry.category == category then
				part.Material = material
				part.Color = color
				part.Transparency = transparency
			end
		end

		for ragdoll, record in next, self._ragdolls do
			if record.category == category and ragdoll.ClassName == "Model" then
				for _, desc in next, ragdoll:QueryDescendants("Instance") do
					if desc:IsA("BasePart") then
						self:_applyPart(desc :: BasePart, category, material, color, transparency)
					end
				end
			end
		end
	else
		local toRestore: { BasePart } = {}
		for part, entry in next, self._patched do
			if entry.category == category then
				toRestore[#toRestore + 1] = part
			end
		end
		for _, part in next, toRestore do
			self:_restorePart(part)
		end
	end
end

function RagdollChams._refreshColor(self: RagdollChams, category: CategoryId): ()
	local color = self:_categoryColor(category)
	local transparency = self:_categoryTransparency(category)
	for part, entry in next, self._patched do
		if entry.category == category then
			part.Color = color
			part.Transparency = transparency
		end
	end
end

function RagdollChams._attachRagdoll(self: RagdollChams, ragdoll: Instance): ()
	if ragdoll.ClassName ~= "Model" then
		return
	end
	if self._ragdolls[ragdoll] then
		return
	end

	local category: CategoryId = resolveCategory(ragdoll)
	local janitor = Janitor.new()
	local record: RagdollRecord = { janitor = janitor, category = category }
	self._ragdolls[ragdoll] = record

	local material = self:_categoryMaterial(category)
	local color = self:_categoryColor(category)
	local transparency = self:_categoryTransparency(category)

	for _, desc in next, ragdoll:QueryDescendants("Instance") do
		if desc:IsA("BasePart") then
			self:_applyPart(desc :: BasePart, category, material, color, transparency)
		end
	end

	janitor:Add(
		ragdoll.DescendantAdded:Connect(function(desc: Instance): ()
			if desc:IsA("BasePart") then
				self:_applyPart(desc :: BasePart, category, material, color, transparency)
			end
		end),
		"Disconnect"
	)

	janitor:Add(
		ragdoll.DescendantRemoving:Connect(function(desc: Instance): ()
			if desc:IsA("BasePart") and self._patched[desc] then
				self._patched[desc] = nil
			end
		end),
		"Disconnect"
	)
end

function RagdollChams._detachRagdoll(self: RagdollChams, ragdoll: Instance): ()
	local record = self._ragdolls[ragdoll]
	if not record then
		return
	end
	self._ragdolls[ragdoll] = nil
	record.janitor:Destroy()

	if ragdoll.ClassName == "Model" then
		for _, desc: any in next, ragdoll:QueryDescendants("Instance") do
			if desc:IsA("BasePart") and self._patched[desc] then
				self:_restorePart(desc :: BasePart)
			end
		end
	end
end

function RagdollChams._restoreAll(self: RagdollChams): ()
	local parts: { BasePart } = {}
	for part in next, self._patched do
		parts[#parts + 1] = part
	end
	for _, part in next, parts do
		self:_restorePart(part)
	end
end

function RagdollChams.Enable(self: RagdollChams): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local janitor = Janitor.new()
	self._activeJanitor = janitor

	janitor:Add(
		CollectionService:GetInstanceAddedSignal(RAGDOLL_TAG):Connect(function(inst: Instance): ()
			self:_attachRagdoll(inst)
		end),
		"Disconnect"
	)

	janitor:Add(
		CollectionService:GetInstanceRemovedSignal(RAGDOLL_TAG):Connect(function(inst: Instance): ()
			self:_detachRagdoll(inst)
		end),
		"Disconnect"
	)

	for _, inst in next, CollectionService:GetTagged(RAGDOLL_TAG) do
		self:_attachRagdoll(inst)
	end

	local settingsLink = self._settingsLink
	if settingsLink then
		for i = 1, #CATEGORY_ORDER do
			local cat: CategoryId = CATEGORY_ORDER[i]
			local picker: any = settingsLink:Get(cat .. "Color")
			local materialEl: any = settingsLink:OnKey(cat .. "MaterialOpts"):Get("material")
			local enabledEl: any = settingsLink:Get(cat)

			janitor:Add(picker:OnUpdate(function(): ()
				self:_refreshColor(cat)
			end))

			janitor:Add(materialEl:OnChange(function(): ()
				self:_refreshCategory(cat)
			end))

			janitor:Add(enabledEl:OnChange(function(): ()
				self:_refreshCategory(cat)
			end))
		end
	end
end

function RagdollChams.Disable(self: RagdollChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	for ragdoll, record in next, self._ragdolls do
		record.janitor:Destroy()
		self._ragdolls[ragdoll] = nil
	end

	self:_restoreAll()

	if self._activeJanitor then
		self._activeJanitor:Destroy()
		self._activeJanitor = nil
	end
end

function RagdollChams.Destroy(self: RagdollChams): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type RagdollChams =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_activeJanitor: Janitor.Janitor?,
			_ragdolls: { [Instance]: RagdollRecord },
			_patched: { [BasePart]: PatchEntry },
			_settingsLink: gameUi.Linker?,
		},
		RagdollChams
	))
	& BaseFeature.BaseFeature

return RagdollChams
