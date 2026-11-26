local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local MatchState = require("@game/rivals/client/matchState")
local PlayerController = require("@feature/player/PlayerController")

local peek = Charm.peek
local sub = Charm.subscribe

local MATERIALS: { string } = {
	"ForceField",
	"Neon",
}

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
	materialConn: RBXScriptConnection?,
	colorConn: RBXScriptConnection?,
}

type CorpseRecord = {
	janitor: Janitor.Janitor,
	category: CategoryId,
	character: Model,
}

type CategoryTarget = {
	material: Enum.Material,
	color: Color3,
	transparency: number,
}

local function shouldPatchPart(inst: Instance): boolean
	if not inst:IsA("BasePart") then
		return false
	end
	return (inst :: BasePart).Transparency < 1
end

local RagdollChams = {}
RagdollChams.__index = RagdollChams

setmetatable(RagdollChams, { __index = BaseFeature })

function RagdollChams.new(link: gameUi.Linker): RagdollChams
	local self = BaseFeature.new() :: any
	setmetatable(self, RagdollChams)

	self._enabled = false
	self._activeJanitor = nil :: Janitor.Janitor?
	self._corpses = {} :: { [any]: CorpseRecord }
	self._watchers = {} :: { [any]: Janitor.Janitor }
	self._patched = {} :: { [BasePart]: PatchEntry }
	self._settingsLink = nil :: gameUi.Linker?
	self._catTargets = {} :: { [CategoryId]: CategoryTarget }

	local chamsToggle = link:Toggle("ragdollChams", "Ragdoll Chams", false):SetTip({
		title = "Ragdoll Chams",
		body = "Recolors the bodies of players who die. Configurable per team.",
	})
	link:Extra(chamsToggle, "ragdollChamsSettings", "Submenu", "Ragdoll Chams")
	local settingsLink = link:OnKey("ragdollChamsSettings")
	self._settingsLink = settingsLink

	for i = 1, #CATEGORY_ORDER do
		local cat: CategoryId = CATEGORY_ORDER[i]
		local defaults = CATEGORY_DEFAULTS[cat]
		local catToggle = settingsLink:Toggle(cat, CATEGORY_LABEL[cat], defaults.enabled):SetTip({
			title = CATEGORY_LABEL[cat],
			body = "Enable chams for bodies of this team.",
		})
		settingsLink:Extra(catToggle, cat .. "Color", "Colorpicker", "Color", defaults.color, 0)
		local materialOptsKey = cat .. "MaterialOpts"
		settingsLink:Extra(catToggle, materialOptsKey, "Submenu", "Material")
		local materialLink = settingsLink:OnKey(materialOptsKey)
		materialLink:Dropdown("material", "Material", MATERIALS, defaults.material):SetTip({
			title = "Material",
			body = "Material applied to bodies of this team.",
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

function RagdollChams._resolveCategory(_: RagdollChams, basePlayer: any): CategoryId
	local teamId = peek(basePlayer.team)
	local localTeamId = peek(MatchState.teamId)
	if teamId ~= "" and localTeamId ~= "" and teamId == localTeamId then
		return "friendly"
	end
	return "enemy"
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

function RagdollChams._categoryTarget(self: RagdollChams, category: CategoryId): CategoryTarget
	local target = self._catTargets[category]
	if not target then
		target = {
			material = Enum.Material.ForceField,
			color = CATEGORY_DEFAULTS[category].color,
			transparency = 0,
		}
		self._catTargets[category] = target
	end
	return target
end

function RagdollChams._recomputeCategory(self: RagdollChams, category: CategoryId): ()
	local target = self:_categoryTarget(category)
	target.material = self:_categoryMaterial(category)
	target.color = self:_categoryColor(category)
	target.transparency = self:_categoryTransparency(category)
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

function RagdollChams._bindPart(self: RagdollChams, part: BasePart, entry: PatchEntry): ()
	local category = entry.category

	entry.materialConn = part:GetPropertyChangedSignal("Material"):Connect(LPH_NO_VIRTUALIZE(function(): ()
		if not self._patched[part] then
			return
		end
		local material = self:_categoryTarget(category).material
		if part.Material ~= material then
			part.Material = material
		end
	end))

	entry.colorConn = part:GetPropertyChangedSignal("Color"):Connect(LPH_NO_VIRTUALIZE(function(): ()
		if not self._patched[part] then
			return
		end
		local color = self:_categoryTarget(category).color
		if part.Color ~= color then
			part.Color = color
		end
	end))
end

function RagdollChams._applyPart(self: RagdollChams, part: BasePart, category: CategoryId): ()
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
		materialConn = nil,
		colorConn = nil,
	}

	self:_stripTextures(part, entry)
	self._patched[part] = entry

	part.Material = self:_categoryMaterial(category)
	part.Color = self:_categoryColor(category)
	part.Transparency = self:_categoryTransparency(category)

	self:_bindPart(part, entry)
end

function RagdollChams._restorePart(self: RagdollChams, part: BasePart): ()
	local entry = self._patched[part]
	if not entry then
		return
	end
	self._patched[part] = nil

	if entry.materialConn then
		entry.materialConn:Disconnect()
	end
	if entry.colorConn then
		entry.colorConn:Disconnect()
	end

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

RagdollChams._refreshCategory = LPH_NO_VIRTUALIZE(function(self: RagdollChams, category: CategoryId): ()
	self:_recomputeCategory(category)
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

		for _, record in next, self._corpses do
			if record.category == category then
				for _, desc in next, record.character:QueryDescendants("BasePart") do
					self:_applyPart(desc :: BasePart, category)
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
end)

RagdollChams._refreshColor = LPH_NO_VIRTUALIZE(function(self: RagdollChams, category: CategoryId): ()
	self:_recomputeCategory(category)
	local color = self:_categoryColor(category)
	local transparency = self:_categoryTransparency(category)
	for part, entry in next, self._patched do
		if entry.category == category then
			part.Color = color
			part.Transparency = transparency
		end
	end
end)

function RagdollChams._attachCorpse(self: RagdollChams, basePlayer: any): ()
	if self._corpses[basePlayer] then
		return
	end
	local character = peek(basePlayer.character)
	if not character or character.ClassName ~= "Model" then
		return
	end

	local category: CategoryId = self:_resolveCategory(basePlayer)
	local janitor = Janitor.new()
	self._corpses[basePlayer] = { janitor = janitor, category = category, character = character }

	for _, desc in next, character:QueryDescendants("BasePart") do
		self:_applyPart(desc :: BasePart, category)
	end

	janitor:Add(
		character.DescendantAdded:Connect(LPH_NO_VIRTUALIZE(function(desc: Instance): ()
			if desc:IsA("BasePart") then
				self:_applyPart(desc :: BasePart, category)
			end
		end)),
		"Disconnect"
	)
end

function RagdollChams._detachCorpse(self: RagdollChams, basePlayer: any): ()
	local record = self._corpses[basePlayer]
	if not record then
		return
	end
	self._corpses[basePlayer] = nil
	record.janitor:Destroy()

	for _, desc in next, record.character:QueryDescendants("BasePart") do
		if self._patched[desc] then
			self:_restorePart(desc :: BasePart)
		end
	end
end

function RagdollChams._watchPlayer(self: RagdollChams, basePlayer: any): ()
	if self._watchers[basePlayer] then
		return
	end
	local janitor = Janitor.new()
	self._watchers[basePlayer] = janitor

	local function evaluate(): ()
		if peek(basePlayer.alive) == false and peek(basePlayer.character) then
			self:_attachCorpse(basePlayer)
		else
			self:_detachCorpse(basePlayer)
		end
	end

	janitor:Add(sub(basePlayer.alive, evaluate))
	janitor:Add(sub(basePlayer.character, evaluate))
	evaluate()
end

function RagdollChams._unwatchPlayer(self: RagdollChams, basePlayer: any): ()
	self:_detachCorpse(basePlayer)
	local janitor = self._watchers[basePlayer]
	if janitor then
		self._watchers[basePlayer] = nil
		janitor:Destroy()
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

	for i = 1, #CATEGORY_ORDER do
		self:_recomputeCategory(CATEGORY_ORDER[i])
	end

	for _, basePlayer in next, PlayerController.GetAll() do
		self:_watchPlayer(basePlayer)
	end

	janitor:Add(
		PlayerController.playerAdded:Connect(function(basePlayer: any): ()
			self:_watchPlayer(basePlayer)
		end),
		"Disconnect"
	)
	janitor:Add(
		PlayerController.playerRemoving:Connect(function(basePlayer: any): ()
			self:_unwatchPlayer(basePlayer)
		end),
		"Disconnect"
	)

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

	for basePlayer, janitor in next, self._watchers do
		janitor:Destroy()
		self._watchers[basePlayer] = nil
	end
	for basePlayer, record in next, self._corpses do
		record.janitor:Destroy()
		self._corpses[basePlayer] = nil
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
			_corpses: { [any]: CorpseRecord },
			_watchers: { [any]: Janitor.Janitor },
			_patched: { [BasePart]: PatchEntry },
			_settingsLink: gameUi.Linker?,
			_catTargets: { [CategoryId]: CategoryTarget },
		},
		RagdollChams
	))
	& BaseFeature.BaseFeature

return RagdollChams
