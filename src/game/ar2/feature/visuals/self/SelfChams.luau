local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local clientState = require("@game/ar2/client/clientState")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local InsertService = cloneref(game:GetService("InsertService")) :: InsertService

local peek = Charm.peek
local sub = Charm.subscribe

local MATERIALS: { string } = {
	"ForceField",
	"Neon",
	"Glass",
}

local ARM_NAMES: { [string]: true } = {
	LeftHand = true,
	LeftLowerArm = true,
	LeftUpperArm = true,
	RightHand = true,
	RightLowerArm = true,
	RightUpperArm = true,
}

local EXCLUDED_PART_NAMES: { [string]: true } = {
	HumanoidRootPart = true,
}

local CLOTHING_CLASSES: { [string]: true } = {
	Shirt = true,
	Pants = true,
	ShirtGraphic = true,
}

export type SelfChamsScope = "arm" | "equipped" | "body"

export type SelfChamsProps = {
	key: string,
	label: string,
	tip: string,
	scope: SelfChamsScope,
	color: Color3,
	material: string,
}

type MeshEntry = {
	textureId: string,
	vertexColor: Vector3?,
}

type PatchEntry = {
	material: Enum.Material,
	color: Color3,
	transparency: number,
	reflectance: number,
	usePartColor: boolean?,
	textureId: string,
	overlays: { Instance },
	meshes: { [Instance]: MeshEntry },
	usesOverlay: boolean?,
	overlayPart: BasePart?,
}

local overlayParts: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isOverlay(inst: Instance): boolean
	local className = inst.ClassName
	return className == "SurfaceAppearance" or className == "Texture" or className == "Decal"
end

local function inReticle(inst: Instance): boolean
	local current: Instance? = inst.Parent
	while current do
		if current.Name == "Reticle" then
			return true
		end
		current = current.Parent
	end
	return false
end

local SCOPE_PRIORITY: { [SelfChamsScope]: number } = {
	equipped = 0,
	body = 1,
	arm = 2,
}

local function matchesScope(character: Model, inst: Instance, scope: SelfChamsScope, firstPerson: boolean): boolean
	if not inst:IsA("BasePart") then
		return false
	end

	local part = inst :: BasePart
	if part.Transparency >= 1 or EXCLUDED_PART_NAMES[part.Name] or overlayParts[part] then
		return false
	end

	local isEquipped = false
	local isArm = false
	local current: Instance? = part
	while current and current ~= character do
		if current.Name == "Equipped" then
			isEquipped = true
			break
		end
		if ARM_NAMES[current.Name] then
			isArm = true
		end
		current = current.Parent
	end

	if not current then
		return false
	end

	if scope == "equipped" then
		return isEquipped
	elseif scope == "arm" then
		return not isEquipped and isArm
	end
	return not isEquipped and not (firstPerson and isArm)
end

local claimedParts: { [BasePart]: any } = {}
local activeInstances: { [any]: true } = {}

local function reapplyAll(character: Model?): ()
	if not character then
		return
	end

	local appliable: { any } = {}
	for inst in next, activeInstances do
		if inst:_canApply() then
			appliable[#appliable + 1] = inst
		end
	end

	table.sort(appliable, function(a: any, b: any): boolean
		return SCOPE_PRIORITY[a._scope] > SCOPE_PRIORITY[b._scope]
	end)

	for _, inst in next, appliable do
		inst:_applyCharacter(character)
	end
end

local SelfChams = {}
SelfChams.__index = SelfChams

setmetatable(SelfChams, { __index = BaseFeature })

function SelfChams.new(link: gameUi.Linker, props: SelfChamsProps): SelfChams
	local self = BaseFeature.new() :: any
	setmetatable(self, SelfChams)

	self._enabled = false
	self._scope = props.scope
	self._activeJanitor = nil :: Janitor.Janitor?
	self._characterJanitor = nil :: Janitor.Janitor?
	self._patched = {} :: { [BasePart]: PatchEntry }
	self._clothing = {} :: { [Instance]: Instance }
	self._firstPerson = false
	self._settleToken = 0

	local chamsToggle = link:Toggle(props.key, props.label, false):SetTip({
		title = props.label,
		body = props.tip,
	})
	local chamsLink = link:OnKey(props.key)
	chamsLink:Extra(chamsToggle, "color", "Colorpicker", "Color", props.color, 0)
	chamsLink:Extra(chamsToggle, "opts", "Submenu", props.label .. " Options")
	local optsLink = chamsLink:OnKey("opts")
	optsLink:Dropdown("material", "Material", MATERIALS, props.material):SetTip({
		title = "Material",
		body = "Material applied to recolored parts.",
	})
	optsLink:Slider("reflectance", "Reflectance", 0, 0, 1, 0.05):SetTip({
		title = "Reflectance",
		body = "How reflective the recolored parts look.",
	})

	self._colorLink = chamsLink:Get("color")
	self._materialLink = optsLink:Get("material")
	self._reflectanceLink = optsLink:Get("reflectance")

	self:Track(link:Get(props.key):OnChange(function(state: boolean): ()
		if state then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek(props.key) then
		self:Enable()
	end

	return self
end

function SelfChams._material(self: SelfChams): Enum.Material
	local name = self._materialLink:Peek() or "Neon"
	return (Enum.Material :: any)[name] or Enum.Material.Neon
end

function SelfChams._color(self: SelfChams): Color3
	return (self._colorLink :: any):GetColor()
end

function SelfChams._transparency(self: SelfChams): number
	return (self._colorLink :: any):GetTransparency()
end

function SelfChams._reflectance(self: SelfChams): number
	local value = self._reflectanceLink:Peek()
	if type(value) ~= "number" then
		return 0
	end
	return value
end

function SelfChams._stripTextures(_: SelfChams, part: BasePart, entry: PatchEntry): ()
	if part:IsA("MeshPart") then
		entry.textureId = (part :: MeshPart).TextureID
		part.TextureID = ""
	elseif part:IsA("PartOperation") then
		entry.usePartColor = (part :: PartOperation).UsePartColor;
		(part :: PartOperation).UsePartColor = true
	end

	for _, child in next, part:GetChildren() do
		if isOverlay(child) then
			if inReticle(child) then
				continue
			end
			entry.overlays[#entry.overlays + 1] = child
			child.Parent = nil
		elseif child:IsA("FileMesh") then
			local meshEntry: MeshEntry = { textureId = child.TextureId }
			child.TextureId = ""
			if child:IsA("SpecialMesh") then
				local mesh = child :: SpecialMesh
				meshEntry.vertexColor = mesh.VertexColor
				mesh.VertexColor = Vector3.new(1, 1, 1)
			end
			entry.meshes[child] = meshEntry
		end
	end
end

function SelfChams._applyPart(self: SelfChams, part: BasePart): ()
	if self._patched[part] then
		return
	end

	local owner = claimedParts[part]
	if owner and owner ~= self then
		if SCOPE_PRIORITY[self._scope] <= SCOPE_PRIORITY[owner._scope] then
			return
		end
		owner:_restorePart(part)
	end

	local entry: PatchEntry = {
		material = part.Material,
		color = part.Color,
		transparency = part.Transparency,
		reflectance = part.Reflectance,
		textureId = "",
		overlays = {},
		meshes = {},
	}

	local specialMesh = (not part:IsA("MeshPart")) and part:FindFirstChildOfClass("SpecialMesh") or nil
	if specialMesh and (specialMesh :: SpecialMesh).MeshId ~= "" then
		entry.usesOverlay = true
		self._patched[part] = entry
		claimedParts[part] = self
		part.Transparency = 1
		self:_buildOverlay(part, (specialMesh :: SpecialMesh).MeshId, (specialMesh :: SpecialMesh).Scale, entry)
		return
	elseif self._scope == "arm" and part:IsA("MeshPart") and (part :: MeshPart).MeshId ~= "" then
		entry.usesOverlay = true
		self._patched[part] = entry
		claimedParts[part] = self
		part.Transparency = 1
		self:_buildOverlay(part, (part :: MeshPart).MeshId, nil, entry)
		return
	end

	self:_stripTextures(part, entry)
	self._patched[part] = entry
	claimedParts[part] = self

	part.Material = self:_material()
	part.Color = self:_color()
	part.Transparency = self:_transparency()
	part.Reflectance = self:_reflectance()
end

function SelfChams._buildOverlay(self: SelfChams, part: BasePart, meshId: string, scale: Vector3?, entry: PatchEntry): ()
	task.spawn(function(): ()
		local ok, overlay = pcall(function(): BasePart
			return InsertService:CreateMeshPartAsync(meshId, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
		end)
		if not ok or not overlay then
			if self._patched[part] == entry then
				part.Transparency = entry.transparency
			end
			return
		end
		if self._patched[part] ~= entry or not part.Parent then
			overlay:Destroy()
			return
		end

		overlay.Size = scale and overlay.Size * scale or part.Size
		overlay.CanCollide = false
		overlay.CanQuery = false
		overlay.CanTouch = false
		overlay.Massless = true
		overlay.Reflectance = self:_reflectance()
		overlay.Material = self:_material()
		overlay.Color = self:_color()
		overlay.Transparency = self:_transparency()
		overlayParts[overlay] = true

		local weld = Instance.new("Weld")
		weld.Part0 = part
		weld.Part1 = overlay
		weld.Parent = overlay

		overlay.CFrame = part.CFrame
		overlay.Parent = part

		entry.overlayPart = overlay
	end)
end

function SelfChams._restorePart(self: SelfChams, part: BasePart): ()
	local entry = self._patched[part]
	if not entry then
		return
	end
	self._patched[part] = nil
	if claimedParts[part] == self then
		claimedParts[part] = nil
	end

	local overlay = entry.overlayPart
	if overlay then
		overlayParts[overlay] = nil
		overlay:Destroy()
		entry.overlayPart = nil
	end

	if entry.usesOverlay then
		part.Transparency = entry.transparency
		return
	end

	part.Material = entry.material
	part.Color = entry.color
	part.Transparency = entry.transparency
	part.Reflectance = entry.reflectance
	if part:IsA("MeshPart") then
		(part :: MeshPart).TextureID = entry.textureId
	elseif part:IsA("PartOperation") and entry.usePartColor ~= nil then
		(part :: PartOperation).UsePartColor = entry.usePartColor
	end

	for _, overlay in next, entry.overlays do
		overlay.Parent = part
	end

	for mesh, meshEntry in next, entry.meshes do
		(mesh :: any).TextureId = meshEntry.textureId
		if meshEntry.vertexColor then
			(mesh :: any).VertexColor = meshEntry.vertexColor
		end
	end
end

function SelfChams._refreshStyle(self: SelfChams): ()
	local material = self:_material()
	local color = self:_color()
	local transparency = self:_transparency()
	local reflectance = self:_reflectance()
	for part, entry in next, self._patched do
		local overlay = entry.overlayPart
		if overlay then
			overlay.Material = material
			overlay.Color = color
			overlay.Transparency = transparency
			overlay.Reflectance = reflectance
		elseif not entry.usesOverlay then
			part.Material = material
			part.Color = color
			part.Transparency = transparency
			part.Reflectance = reflectance
		end
	end
end

function SelfChams._restoreAll(self: SelfChams): ()
	local parts: { BasePart } = {}
	for part in next, self._patched do
		parts[#parts + 1] = part
	end
	for _, part in next, parts do
		self:_restorePart(part)
	end
end

function SelfChams._stripClothing(self: SelfChams, clothing: Instance): ()
	local parent = clothing.Parent
	if not parent then
		return
	end
	self._clothing[clothing] = parent
	clothing.Parent = nil
end

function SelfChams._restoreClothing(self: SelfChams): ()
	for clothing, parent in next, self._clothing do
		clothing.Parent = parent
	end
	table.clear(self._clothing)
end

function SelfChams._canApply(self: SelfChams): boolean
	return self._scope ~= "arm" or self._firstPerson
end

function SelfChams._applyCharacter(self: SelfChams, character: Model?): ()
	if not character or not self:_canApply() then
		return
	end

	for _, desc in next, character:QueryDescendants("BasePart") do
		if matchesScope(character, desc, self._scope, self._firstPerson) then
			self:_applyPart(desc :: BasePart)
		end
	end
end

function SelfChams._wantsOverlay(self: SelfChams, part: BasePart): boolean
	if part:IsA("MeshPart") then
		return self._scope == "arm" and (part :: MeshPart).MeshId ~= ""
	end
	local specialMesh = part:FindFirstChildOfClass("SpecialMesh")
	return specialMesh ~= nil and (specialMesh :: SpecialMesh).MeshId ~= ""
end

function SelfChams._reconcile(self: SelfChams, character: Model): ()
	if not self:_canApply() then
		return
	end

	for _, desc in next, character:QueryDescendants("BasePart") do
		if not matchesScope(character, desc, self._scope, self._firstPerson) then
			continue
		end

		local part = desc :: BasePart
		local entry = self._patched[part]
		if not entry then
			self:_applyPart(part)
		elseif self:_wantsOverlay(part) and (not entry.usesOverlay or not entry.overlayPart) then
			self:_restorePart(part)
			self:_applyPart(part)
		end
	end
end

function SelfChams._queueSettleRefresh(self: SelfChams): ()
	self._settleToken += 1
	local token = self._settleToken
	task.delay(0.2, function(): ()
		if not self._enabled or self._settleToken ~= token then
			return
		end
		local character = peek(clientState.character)
		if character then
			self:_reconcile(character)
		end
	end)
end

function SelfChams._onCharacterChanged(self: SelfChams, character: Model?): ()
	self:_restoreAll()
	self:_restoreClothing()

	if self._characterJanitor then
		self._characterJanitor:Destroy()
		self._characterJanitor = nil
	end

	if not character then
		return
	end

	local janitor = Janitor.new()
	self._characterJanitor = janitor

	if self._scope == "body" and not self._firstPerson then
		for _, child in next, character:GetChildren() do
			if CLOTHING_CLASSES[child.ClassName] then
				self:_stripClothing(child)
			end
		end
	end

	self:_applyCharacter(character)

	janitor:Add(
		character.DescendantAdded:Connect(function(desc: Instance): ()
			if matchesScope(character, desc, self._scope, self._firstPerson) then
				if self:_canApply() then
					self:_applyPart(desc :: BasePart)
				end
			elseif isOverlay(desc) then
				local parent = desc.Parent
				local entry = parent and self._patched[parent :: BasePart]
				if entry and not entry.usesOverlay and not inReticle(desc) then
					entry.overlays[#entry.overlays + 1] = desc
					desc.Parent = nil
				end
			elseif desc:IsA("FileMesh") then
				local parent = desc.Parent
				local part = parent and parent:IsA("BasePart") and parent :: BasePart
				local entry = part and self._patched[part]
				if entry and not entry.usesOverlay then
					if
						desc:IsA("SpecialMesh")
						and (desc :: SpecialMesh).MeshId ~= ""
						and not (part :: BasePart):IsA("MeshPart")
					then
						self:_restorePart(part :: BasePart)
						self:_applyPart(part :: BasePart)
					else
						local meshEntry: MeshEntry = { textureId = (desc :: FileMesh).TextureId };
						(desc :: FileMesh).TextureId = ""
						if desc:IsA("SpecialMesh") then
							local mesh = desc :: SpecialMesh
							meshEntry.vertexColor = mesh.VertexColor
							mesh.VertexColor = Vector3.new(1, 1, 1)
						end
						entry.meshes[desc] = meshEntry
					end
				end
			elseif self._scope == "body" and not self._firstPerson and CLOTHING_CLASSES[desc.ClassName] and desc.Parent == character then
				self:_stripClothing(desc)
			end

			if desc:IsA("BasePart") or desc:IsA("FileMesh") or isOverlay(desc) then
				self:_queueSettleRefresh()
			end
		end),
		"Disconnect"
	)

	janitor:Add(
		character.DescendantRemoving:Connect(function(desc: Instance): ()
			if desc:IsA("BasePart") and self._patched[desc] then
				self:_restorePart(desc :: BasePart)
			end
		end),
		"Disconnect"
	)
end

function SelfChams.Enable(self: SelfChams): ()
	if self._enabled then
		return
	end
	self._enabled = true
	activeInstances[self] = true

	local janitor = Janitor.new()
	self._activeJanitor = janitor

	if self._scope == "arm" or self._scope == "body" then
		local camerasModule = ModuleController.GetModule("Cameras")
		local camera = camerasModule and camerasModule.module:GetCamera("Character")

		self._firstPerson = self._scope == "arm"

		if camera then
			self._firstPerson = camera.FirstPerson == true and not peek(clientState.thirdPerson)

			janitor:Add(
				RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
					local firstPerson = camera.FirstPerson == true and not peek(clientState.thirdPerson)
					if firstPerson == self._firstPerson then
						return
					end

					self._firstPerson = firstPerson
					self:_restoreAll()

					if self._scope == "body" then
						local character = peek(clientState.character)
						if firstPerson then
							self:_restoreClothing()
						elseif character then
							for _, child in next, character:GetChildren() do
								if CLOTHING_CLASSES[child.ClassName] then
									self:_stripClothing(child)
								end
							end
						end
					end

					reapplyAll(peek(clientState.character))
				end)),
				"Disconnect"
			)
		end
	end

	janitor:Add(sub(clientState.character, function(character: Model?): ()
		self:_onCharacterChanged(character)
	end))

	janitor:Add(self._colorLink:OnUpdate(function(): ()
		self:_refreshStyle()
	end))

	janitor:Add(self._materialLink:OnChange(function(): ()
		self:_refreshStyle()
	end))

	janitor:Add(self._reflectanceLink:OnChange(function(): ()
		self:_refreshStyle()
	end))

	self:_onCharacterChanged(peek(clientState.character))
end

function SelfChams.Disable(self: SelfChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	activeInstances[self] = nil

	self:_restoreAll()
	self:_restoreClothing()
	self._firstPerson = false

	if self._characterJanitor then
		self._characterJanitor:Destroy()
		self._characterJanitor = nil
	end

	if self._activeJanitor then
		self._activeJanitor:Destroy()
		self._activeJanitor = nil
	end

	reapplyAll(peek(clientState.character))
end

function SelfChams.Destroy(self: SelfChams): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type SelfChams =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_scope: SelfChamsScope,
			_activeJanitor: Janitor.Janitor?,
			_characterJanitor: Janitor.Janitor?,
			_patched: { [BasePart]: PatchEntry },
			_clothing: { [Instance]: Instance },
			_firstPerson: boolean,
			_settleToken: number,
			_colorLink: any,
			_materialLink: any,
			_reflectanceLink: any,
		},
		SelfChams
	))
	& BaseFeature.BaseFeature

return SelfChams
