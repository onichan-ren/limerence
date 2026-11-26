local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Charm = require("@pkg/Charm")
local instances = require("@share/instances")
local strings = require("@share/strings")
local characterDescription = require("@game/universal/feature/misc/characterDescription")

local peek = Charm.peek
local sub = Charm.subscribe

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local Workspace = cloneref(game:GetService("Workspace"))
local HttpService = game:GetService("HttpService")

local DEFAULT_RIG_TYPE = Enum.HumanoidRigType.R15
local CFRAME_IDENTITY = CFrame.identity

local function characterCreate(source: any, values: { [string]: string }, name: string): (string?, string?)
	local path = `{source._basePath}/{name}.json`
	if isfile(path) then
		return nil, "A character with that name already exists."
	end

	local userId: number? = nil
	local desc: HumanoidDescription? = nil
	local rawUser = values.userId
	if rawUser and rawUser ~= "" then
		local resolved, resolveErr = characterDescription.resolveUser(rawUser)
		if not resolved then
			return nil, resolveErr or "Could not find that user."
		end
		userId = resolved
		desc = characterDescription.fromUserId(resolved)
		if not desc then
			return nil, "Could not import that user id."
		end
	end

	if values.source == "User ID" then
		if not desc then
			return nil, "Enter a user id to import from."
		end
	else
		desc = desc or Instance.new("HumanoidDescription")
	end

	local manifest = characterDescription.serialize(desc :: HumanoidDescription)
	manifest.name = name
	if userId then
		manifest.userId = userId
	end

	local encodeOk, encoded = pcall(function(): string
		return HttpService:JSONEncode(manifest)
	end)
	if not encodeOk then
		return nil, "The character could not be encoded."
	end

	local writeOk = pcall(writefile, path, encoded)
	if not writeOk then
		return nil, "The character could not be saved."
	end
	return name
end

local function characterPreviewImage(_source: any, _name: string, path: string): string?
	if not isfile or not isfile(path) or not readfile then
		return nil
	end
	local readOk, contents = pcall(readfile, path)
	if not readOk or type(contents) ~= "string" then
		return nil
	end
	local decodeOk, manifest = pcall(function(): any
		return HttpService:JSONDecode(contents)
	end)
	if not decodeOk or type(manifest) ~= "table" then
		return nil
	end
	local userId = manifest.userId
	if type(userId) == "number" then
		return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
	end
	return nil
end

local function isHumanoidDescription(values: { [string]: string }): boolean
	return values.source == "Custom"
end

local function openEditor(source: any, values: { [string]: string }): ()
	local SubwindowController = require("@ui/subwindow/SubwindowController")
	local Colorpicker = require("@ui/window/element/colorpicker/Colorpicker")
	SubwindowController.OpenCharacterEditor({
		source = source,
		name = values.name,
		userInput = values.userId,
		colorpicker = Colorpicker,
	})
end

local function openEditorForExisting(source: any, name: string): ()
	local SubwindowController = require("@ui/subwindow/SubwindowController")
	local Colorpicker = require("@ui/window/element/colorpicker/Colorpicker")
	SubwindowController.OpenCharacterEditor({
		source = source,
		name = name,
		load = true,
		colorpicker = Colorpicker,
	})
end

local function buildCreatorFields(): { any }
	return {
		{ key = "source", label = "Source", kind = "select", options = { "User ID", "Custom" }, default = "User ID" },
		{ key = "userId", label = "User", placeholder = "User id or username", kind = "text" },
		{
			key = "editor",
			label = "Editor",
			kind = "button",
			buttonText = "Open editor",
			primary = true,
			visibleWhen = isHumanoidDescription,
			onClick = openEditor,
		},
	}
end

local CHARACTER_PICKER_CONFIG = {
	assetType = "characters",
	width = 244,
	extensions = { "json" },
	creator = {
		title = "New character",
		description = "Import an avatar from a user id or username, or build a custom character.",
		fields = buildCreatorFields(),
		create = characterCreate,
	},
	previewImage = characterPreviewImage,
	onEditAsset = openEditorForExisting,
}

export type JointModifier = (joint: Motor6D | AnimationConstraint, baseTransform: CFrame) -> CFrame

export type RootOffset = (realHumanoid: Humanoid?, fakeHumanoid: Humanoid, footPart: BasePart?) -> number

export type CustomCharacterOverlayOpts = {
	characterAtom: Charm.Atom<Model?>,
	partsAtom: Charm.Atom<{ [string]: Instance }>,
	aliveAtom: Charm.Atom<boolean>,
	isThirdPerson: () -> boolean,
	rigType: (Enum.HumanoidRigType | () -> Enum.HumanoidRigType)?,
	footPartName: string?,
	rootOffset: RootOffset?,
	jointModifiers: { [string]: JointModifier }?,
	modelAtom: Charm.Atom<Model?>?,
	visibleModelAtom: Charm.Atom<Model?>?,
	excludedRealAncestors: { [string]: true }?,
	excludedRealPredicate: ((instance: Instance) -> boolean)?,
}

local function r15RootOffset(realHumanoid: Humanoid?, fakeHumanoid: Humanoid, footPart: BasePart?): number
	if not realHumanoid then
		return 0
	end
	local footTerm = if footPart then footPart.Size.Y / 2 else 0
	return (realHumanoid.HipHeight - fakeHumanoid.HipHeight) + footTerm
end

local function r6RootOffset(): number
	return 0
end

local function jointChildPart(constraint: Motor6D | AnimationConstraint): BasePart?
	if constraint:IsA("Motor6D") then
		return constraint.Part1
	end
	local attachment = (constraint :: AnimationConstraint).Attachment1
	local part = attachment and attachment.Parent
	return if part and part:IsA("BasePart") then part :: BasePart else nil
end

local function jointSizeRatio(
	realConstraint: Motor6D | AnimationConstraint,
	fakeConstraint: Motor6D | AnimationConstraint
): Vector3
	local realPart = jointChildPart(realConstraint)
	local fakePart = jointChildPart(fakeConstraint)
	if not realPart or not fakePart then
		return Vector3.one
	end
	local realSize = realPart.Size
	local fakeSize = fakePart.Size
	return Vector3.new(
		if realSize.X ~= 0 then fakeSize.X / realSize.X else 1,
		if realSize.Y ~= 0 then fakeSize.Y / realSize.Y else 1,
		if realSize.Z ~= 0 then fakeSize.Z / realSize.Z else 1
	)
end

local folder: Folder? = nil
local function ensureFolder(): Folder
	if folder and folder:IsDescendantOf(Workspace) then
		return folder
	end
	folder = instances.new("Folder", {
		Parent = instances.ignore,
		Name = strings.randomSafe(8),
	}) :: Folder
	return folder :: Folder
end

local CustomCharacterOverlay = {}
CustomCharacterOverlay.__index = CustomCharacterOverlay

setmetatable(CustomCharacterOverlay, { __index = BaseFeature })

local function isExcludedReal(instance: Instance, excluded: { [string]: true }): boolean
	local current = instance.Parent
	while current do
		if excluded[current.Name] then
			return true
		end
		current = current.Parent
	end
	return false
end

function CustomCharacterOverlay.new(link: gameUi.Linker, opts: CustomCharacterOverlayOpts): CustomCharacterOverlay
	local self = BaseFeature.new() :: any
	setmetatable(self, CustomCharacterOverlay)

	self._opts = opts
	self._excludedRealAncestors = opts.excludedRealAncestors or {}
	self._excludedRealPredicate = opts.excludedRealPredicate
	self._enabled = false
	self._customConstraintInstances = {}
	self._constraintInstances = {}
	self._updateTransforms = {}
	self._sizeRatios = {}
	self._parts = {}
	self._fakeDecals = {}
	self._fakeDecalOriginal = {}
	self._fakeHidden = false
	self._realInstances = {}
	self._realHidden = false
	self._generation = 0

	link:Toggle("customCharacter", "Custom Character", false):SetTip({
		title = "Custom Character",
		body = "Replaces your character with a custom one.",
	})

	local featureLink = link:OnKey("customCharacter")

	local picker = featureLink:AssetPicker("character", "Character", CHARACTER_PICKER_CONFIG):SetTip({
		title = "Character",
		body = "Select or create a custom character.",
	})
	self._picker = picker

	self:Track(link:Get("customCharacter"):OnChange(function(state: boolean): ()
		if state then
			self:enable()
		else
			self:disable()
		end
	end))

	self:Track(picker:OnChange(function(): ()
		if self._enabled then
			self:_createOrUpdateModel()
		end
	end))

	if link:Get("customCharacter"):Peek() then
		self:enable()
	end

	return self
end

function CustomCharacterOverlay.enable(self: CustomCharacterOverlay)
	if self._enabled then
		return
	end

	self._enabled = true
	self:_createOrUpdateModel()

	local janitor = Janitor.new()
	self._activeJanitor = janitor

	janitor:Add(function()
		if self._customCharacterJanitor then
			self._customCharacterJanitor:Destroy()
			self._customCharacterJanitor = nil
		end

		if self._characterJanitor then
			self._characterJanitor:Destroy()
			self._characterJanitor = nil
		end
	end, true)

	janitor:Add(sub(self._opts.characterAtom, function(character: Model?): ()
		self:_onCharacterChanged(character)
	end))

	janitor:Add(
		RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function()
			self:_update()
		end)),
		"Disconnect"
	)

	janitor:Add(
		RunService.PreSimulation:Connect(LPH_NO_VIRTUALIZE(function()
			local parts = self._parts
			for _, part in next, parts do
				if part.CanCollide then
					part.CanCollide = false
				end
				if part.CanQuery then
					part.CanQuery = false
				end
			end
		end)),
		"Disconnect"
	)

	self:_onCharacterChanged(peek(self._opts.characterAtom))
end

function CustomCharacterOverlay.disable(self: CustomCharacterOverlay)
	if not self._enabled then
		return
	end

	self._enabled = false

	if self._customCharacterJanitor then
		self._customCharacterJanitor:Destroy()
		self._customCharacterJanitor = nil
	end

	if self._activeJanitor then
		self._activeJanitor:Destroy()
		self._activeJanitor = nil
	end

	if self._characterJanitor then
		self._characterJanitor:Destroy()
		self._characterJanitor = nil
	end

	local visibleModelAtom = self._opts.visibleModelAtom
	if visibleModelAtom then
		visibleModelAtom(nil)
	end
end

function CustomCharacterOverlay._createOrUpdateModel(self: CustomCharacterOverlay)
	local picker = self._picker
	if not picker then
		return
	end
	local path = picker:GetSelectedPath()

	if self._customCharacterJanitor then
		self._customCharacterJanitor:Destroy()
		self._customCharacterJanitor = nil
	end

	if not path then
		return
	end

	local customCharacterJanitor = Janitor.new()
	self._customCharacterJanitor = customCharacterJanitor

	self._generation += 1
	local generation = self._generation

	task.spawn(function()
		if not isfile(path) then
			return
		end
		local readOk, contents = pcall(readfile, path)
		if not readOk or type(contents) ~= "string" then
			return
		end
		local decodeOk, manifest = pcall(function(): any
			return HttpService:JSONDecode(contents)
		end)
		if not decodeOk or type(manifest) ~= "table" then
			return
		end

		local description = characterDescription.deserialize(manifest)
		local rigTypeOpt = self._opts.rigType
		local rigType = if type(rigTypeOpt) == "function" then rigTypeOpt() else rigTypeOpt or DEFAULT_RIG_TYPE
		local customCharacter = Players:CreateHumanoidModelFromDescriptionAsync(description, rigType)

		local modelAtom = self._opts.modelAtom
		local visibleModelAtom = self._opts.visibleModelAtom

		local function destroyModel()
			if modelAtom and peek(modelAtom) == customCharacter then
				modelAtom(nil)
			end
			if visibleModelAtom and peek(visibleModelAtom) == customCharacter then
				visibleModelAtom(nil)
			end
			customCharacter:Destroy()
		end

		local function destroyOwned()
			if self._customCharacter == customCharacter then
				table.clear(self._parts)
				table.clear(self._fakeDecals)
				table.clear(self._fakeDecalOriginal)
				table.clear(self._customConstraintInstances)
				table.clear(self._sizeRatios)
				self._customCharacter = nil
				self._fakeHumanoid = nil
				self._fakeRoot = nil
			end
			destroyModel()
		end

		if generation ~= self._generation or not self._enabled then
			destroyModel()
			return
		end

		customCharacterJanitor:Add(function()
			destroyOwned()
		end, true)

		local humanoid = customCharacter:WaitForChild("Humanoid", 5)

		humanoid.EvaluateStateMachine = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

		local animateScript = customCharacter:FindFirstChild("Animate")
		if animateScript then
			animateScript:Destroy()
		end

		local humanoidRootPart = customCharacter:WaitForChild("HumanoidRootPart", 5)
		humanoidRootPart.Anchored = true

		self._fakeHidden = true

		customCharacterJanitor:Add(
			customCharacter.DescendantAdded:Connect(function(instance: Instance)
				self:_processInstance(instance, false)
			end),
			"Disconnect"
		)

		for _, instance in customCharacter:QueryDescendants("Instance") do
			self:_processInstance(instance, false)
		end

		customCharacter.Parent = ensureFolder()

		self._customCharacter = customCharacter
		self._fakeHumanoid = humanoid
		self._fakeRoot = humanoidRootPart
		if modelAtom then
			modelAtom(customCharacter)
		end
	end)
end

function CustomCharacterOverlay._onCharacterChanged(self: CustomCharacterOverlay, character: Model?)
	if self._characterJanitor then
		self._characterJanitor:Destroy()
		self._characterJanitor = nil
	end

	if self._enabled then
		local customCharacter = self._customCharacter
		if not customCharacter or not customCharacter:IsDescendantOf(Workspace) then
			self:_createOrUpdateModel()
		end
	end

	if not character then
		return
	end

	local characterJanitor = Janitor.new()
	self._characterJanitor = characterJanitor

	characterJanitor:Add(function()
		self:_setRealHidden(false)
		table.clear(self._constraintInstances)
		table.clear(self._realInstances)
		table.clear(self._sizeRatios)
	end, true)

	characterJanitor:Add(
		character.DescendantAdded:Connect(function(instance: Instance)
			self:_processInstance(instance, true)
		end),
		"Disconnect"
	)

	characterJanitor:Add(
		character.DescendantRemoving:Connect(function(instance: Instance)
			(self._realInstances :: any)[instance] = nil
		end),
		"Disconnect"
	)

	for _, instance in character:QueryDescendants("Instance") do
		self:_processInstance(instance, true)
	end
end

function CustomCharacterOverlay._processInstance(
	self: CustomCharacterOverlay,
	instance: Instance,
	realCharacter: boolean
)
	if not realCharacter then
		if instance:IsA("BasePart") then
			local part = instance :: BasePart
			part.CanCollide = false
			part.CanQuery = false
			part.LocalTransparencyModifier = self._fakeHidden and 1 or 0
			table.insert(self._parts :: any, part)
		elseif instance:IsA("Decal") or instance:IsA("Texture") then
			local decal = instance :: Decal
			if (self._fakeDecalOriginal :: any)[decal] == nil then
				(self._fakeDecalOriginal :: any)[decal] = decal.Transparency
				table.insert(self._fakeDecals :: any, decal)
			end
			if self._fakeHidden then
				decal.Transparency = 1
			end
		end
	end

	local excludedPredicate = self._excludedRealPredicate
	if
		realCharacter
		and (instance:IsA("BasePart") or instance:IsA("Decal"))
		and not isExcludedReal(instance, self._excludedRealAncestors)
		and not (excludedPredicate and excludedPredicate(instance))
	then
		(self._realInstances :: any)[instance] = true
		if self._realHidden then
			(instance :: any).LocalTransparencyModifier = 1
		end
	end

	if not instance:IsA("AnimationConstraint") and not instance:IsA("Motor6D") then
		return
	end

	if realCharacter then
		(self._constraintInstances :: any)[instance.Name] = instance
	else
		(self._customConstraintInstances :: any)[instance.Name] = instance
	end
end

function CustomCharacterOverlay._setRealHidden(self: CustomCharacterOverlay, hidden: boolean)
	if hidden == self._realHidden then
		return
	end

	self._realHidden = hidden

	local modifier = hidden and 1 or 0
	for instance in next, self._realInstances :: any do
		instance.LocalTransparencyModifier = modifier
	end
end

function CustomCharacterOverlay._setFakeHidden(self: CustomCharacterOverlay, hidden: boolean)
	if hidden == self._fakeHidden then
		return
	end

	self._fakeHidden = hidden

	local modifier = hidden and 1 or 0
	for _, part in next, self._parts :: any do
		part.LocalTransparencyModifier = modifier
	end

	local originals = self._fakeDecalOriginal :: any
	for _, decal in next, self._fakeDecals :: any do
		decal.Transparency = hidden and 1 or (originals[decal] or 0)
	end
end

CustomCharacterOverlay._update = LPH_JIT_MAX(function(self: CustomCharacterOverlay)
	if not self._enabled and not self._customCharacter then
		return
	end

	local customCharacter = self._customCharacter

	if not customCharacter then
		return
	end

	local opts = self._opts
	local parts = peek(opts.partsAtom)
	local visibleModelAtom = opts.visibleModelAtom

	local fakeHumanoid = self._fakeHumanoid
	local fakeRoot = self._fakeRoot
	local footPart = parts[opts.footPartName or "LeftFoot"]

	local realCharacter = peek(opts.characterAtom)
	local realHumanoid = parts.Humanoid :: Humanoid?
	local realRoot = parts.HumanoidRootPart :: BasePart?
	local isAlive = peek(opts.aliveAtom)

	if not isAlive or not realCharacter or not realRoot then
		self:_setFakeHidden(true)
		self:_setRealHidden(false)
		if visibleModelAtom then
			visibleModelAtom(realCharacter)
		end
		if fakeRoot then
			fakeRoot.CFrame = CFrame.identity
		end
		return
	end

	local thirdPerson = opts.isThirdPerson()
	local canPosition = thirdPerson and realRoot ~= nil and fakeRoot ~= nil and fakeHumanoid ~= nil

	self:_setFakeHidden(not canPosition)
	self:_setRealHidden(canPosition)

	if visibleModelAtom then
		visibleModelAtom(canPosition and customCharacter or realCharacter)
	end

	if canPosition and realRoot and fakeRoot and fakeHumanoid then
		for instance in next, self._realInstances :: any do
			instance.LocalTransparencyModifier = 1
		end

		local offset = (opts.rootOffset or r15RootOffset)(realHumanoid, fakeHumanoid, footPart)
		fakeRoot.CFrame = realRoot.CFrame + Vector3.new(0, -offset, 0)

		local _customConstraintInstances = self._customConstraintInstances

		local transforms = self._updateTransforms
		table.clear(transforms)

		local sizeRatios = self._sizeRatios

		for name, realConstraint in next, self._constraintInstances :: any do
			local fakeConstraint = _customConstraintInstances[name]

			if fakeConstraint then
				local transform

				if realConstraint:IsA("Motor6D") then
					local part0 = realConstraint.Part0
					local part1 = realConstraint.Part1

					transform = (part0 and part1)
							and (part0.CFrame * realConstraint.C0):ToObjectSpace(part1.CFrame * realConstraint.C1)
						or realConstraint.Transform
				else
					transform = realConstraint.Transform
				end

				local ratio = sizeRatios[name]
				if ratio == nil then
					ratio = jointSizeRatio(realConstraint, fakeConstraint)
					sizeRatios[name] = ratio
				end

				local pos = transform.Position
				if pos.X ~= 0 or pos.Y ~= 0 or pos.Z ~= 0 then
					transform = transform.Rotation
						+ Vector3.new(pos.X * ratio.X, pos.Y * ratio.Y, pos.Z * ratio.Z)
				end

				fakeConstraint.Transform = transform
				transforms[fakeConstraint] = transform
			end
		end

		local jointModifiers = opts.jointModifiers
		if jointModifiers then
			for name, modifier in next, jointModifiers do
				local joint = _customConstraintInstances[name]
				if joint then
					joint.Transform = modifier(joint, transforms[joint] or CFRAME_IDENTITY)
				end
			end
		end
	end
end)

function CustomCharacterOverlay.Destroy(self: CustomCharacterOverlay): ()
	if self._activeJanitor then
		self._activeJanitor:Destroy()
		self._activeJanitor = nil
	end
	BaseFeature.Destroy(self)
end

CustomCharacterOverlay.r15RootOffset = r15RootOffset
CustomCharacterOverlay.r6RootOffset = r6RootOffset

export type CustomCharacterOverlay =
	typeof(setmetatable(
		{} :: {
			_opts: CustomCharacterOverlayOpts,
			_excludedRealAncestors: { [string]: true },
			_excludedRealPredicate: ((instance: Instance) -> boolean)?,
			_enabled: boolean,
			_activeJanitor: Janitor.Janitor?,
			_characterJanitor: Janitor.Janitor?,
			_customCharacterJanitor: Janitor.Janitor?,
			_customCharacter: Model?,
			_fakeHumanoid: Humanoid?,
			_fakeRoot: BasePart?,
			_parts: { BasePart },
			_realInstances: { [Instance]: true },
			_realHidden: boolean,
			_constraintInstances: { [string]: Motor6D | AnimationConstraint },
			_customConstraintInstances: { [string]: Motor6D | AnimationConstraint },
			_updateTransforms: { [Instance]: CFrame },
			_sizeRatios: { [string]: Vector3 },
			_picker: any,
			_generation: number,
		},
		CustomCharacterOverlay
	))
	& BaseFeature.BaseFeature

return CustomCharacterOverlay
