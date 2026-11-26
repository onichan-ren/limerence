local Players = cloneref(game:GetService("Players")) :: Players
local CoreGui = cloneref(game:GetService("CoreGui")) :: CoreGui
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local hook = require("@share/hook")
local ModuleController = require("@game/overkill/module/ModuleController")

local LocalPlayer = Players.LocalPlayer
local LOCAL_USER_ID = LocalPlayer.UserId

local ATTRIBUTE = "userid"
local RIG_TYPE = Enum.HumanoidRigType.R15

local R15_PARTS = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

local CLOTHING = { "Shirt", "Pants", "ShirtGraphic" }

local MenuAvatar = {}
MenuAvatar.__index = MenuAvatar

setmetatable(MenuAvatar, { __index = BaseFeature })

local function resolveUserId(value: string): number?
	local id = tonumber(value)
	if id then
		return id
	end
	local resolved = Players:GetUserIdFromNameAsync(value)
	if type(resolved) == "number" then
		return resolved
	end
	return nil
end

local function buildReference(userId: number): Model
	setthreadidentity(2)
	local description = Players:GetHumanoidDescriptionFromUserId(userId)
	local reference = Players:CreateHumanoidModelFromDescriptionAsync(description, RIG_TYPE)
	setthreadidentity(8)
	return reference
end

local transplant = LPH_NO_VIRTUALIZE(function(model: Model, reference: Model): ()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local modelChildren = model:GetChildren()
	local modelByName: { [string]: Instance } = {}
	for i = 1, #modelChildren do
		local child = modelChildren[i]
		modelByName[child.Name] = child
	end

	local referenceChildren = reference:GetChildren()
	local referenceByName: { [string]: Instance } = {}
	for i = 1, #referenceChildren do
		local child = referenceChildren[i]
		referenceByName[child.Name] = child
	end

	for i = 1, #R15_PARTS do
		local part = modelByName[R15_PARTS[i]]
		local source = referenceByName[R15_PARTS[i]]
		if part and source and part:IsA("MeshPart") and source:IsA("MeshPart") then
			part:ApplyMesh(source)
			part.TextureID = source.TextureID
			part.Color = source.Color

			local existingAppearance = part:FindFirstChildOfClass("SurfaceAppearance")
			if existingAppearance then
				existingAppearance:Destroy()
			end
			local sourceAppearance = source:FindFirstChildOfClass("SurfaceAppearance")
			if sourceAppearance then
				sourceAppearance:Clone().Parent = part
			end
		end
	end

	local head = modelByName.Head
	local sourceHead = referenceByName.Head
	if head and sourceHead then
		local headChildren = head:GetChildren()
		for i = 1, #headChildren do
			local child = headChildren[i]
			if child:IsA("Decal") or child:IsA("Texture") then
				child:Destroy()
			end
		end
		local sourceChildren = sourceHead:GetChildren()
		for i = 1, #sourceChildren do
			local child = sourceChildren[i]
			if child:IsA("Decal") or child:IsA("Texture") then
				child:Clone().Parent = head
			end
		end
	end

	for i = 1, #CLOTHING do
		local existing = model:FindFirstChildOfClass(CLOTHING[i])
		if existing then
			existing:Destroy()
		end
		local source = reference:FindFirstChildOfClass(CLOTHING[i])
		if source then
			source:Clone().Parent = model
		end
	end

	humanoid:RemoveAccessories()
	for i = 1, #referenceChildren do
		local accessory = referenceChildren[i]
		if accessory:IsA("Accessory") then
			local copy = accessory:Clone()
			local handle = copy:FindFirstChild("Handle") :: BasePart?
			local handleAttachment = handle and handle:FindFirstChildOfClass("Attachment")
			local bodyAttachment = handleAttachment
				and model:QueryDescendants(`Attachment #{handleAttachment.Name}`)[1] :: Attachment?
			if handle and handleAttachment and bodyAttachment then
				local bodyPart = bodyAttachment.Parent :: BasePart
				handle.CFrame = bodyPart.CFrame * bodyAttachment.CFrame * handleAttachment.CFrame:Inverse()
				local weld = Instance.new("Weld")
				weld.Name = "AccessoryWeld"
				weld.Part0 = handle
				weld.Part1 = bodyPart
				weld.C0 = handleAttachment.CFrame
				weld.C1 = bodyAttachment.CFrame
				weld.Parent = handle
				copy.Parent = model
			else
				humanoid:AddAccessory(copy)
			end
		end
	end
end)

function MenuAvatar.new(link: gameUi.Linker): MenuAvatar
	local self = BaseFeature.new() :: any
	setmetatable(self, MenuAvatar)

	self._enabled = false
	self._hooked = false
	self._getCharacter = nil :: any
	self._generation = 0
	self._reference = nil :: Model?
	self._realReference = nil :: Model?
	self._models = setmetatable({}, { __mode = "k" }) :: any
	self._janitor = Janitor.new()
	self._link = link

	self:Track(link:Watch("customCharacter", function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(link:Watch("customCharacter.opts.target", function(value: string): ()
		if self._enabled then
			self:_applyTarget(value)
		end
	end))

	if link:Peek("customCharacter") == true then
		self:Enable()
	end

	return self
end

function MenuAvatar._installHook(self: MenuAvatar): ()
	if self._hooked then
		return
	end
	local neuron = ModuleController.GetModule("neuron")
	if not neuron then
		return
	end
	self._hooked = true
	self._getCharacter = neuron.get_character

	local original
	original = hook.add(
		neuron.get_character,
		LPH_NO_VIRTUALIZE(function(selfArg: any, player: any, ...): any
			local result = original(selfArg, player, ...)
			if
				self._enabled
				and player == LocalPlayer
				and typeof(result) == "Instance"
				and result:GetAttribute(ATTRIBUTE) == nil
			then
				result:SetAttribute(ATTRIBUTE, LOCAL_USER_ID)
			end
			return result
		end)
	)
end

function MenuAvatar._reskin(self: MenuAvatar, model: Model, reference: Model?): ()
	if not reference then
		return
	end
	if not model:FindFirstChildOfClass("Humanoid") then
		return
	end
	task.spawn(function(): ()
		transplant(model, reference)
	end)
end

MenuAvatar._consider = LPH_NO_VIRTUALIZE(function(self: MenuAvatar, inst: Instance): ()
	if not inst:IsA("Model") then
		return
	end
	local attr = inst:GetAttribute(ATTRIBUTE)
	if attr == nil or tonumber(attr) ~= LOCAL_USER_ID then
		return
	end
	if self._models[inst] then
		return
	end
	local reference = self._reference
	if not reference then
		return
	end
	self._models[inst] = true
	self:_reskin(inst, reference)
end)

function MenuAvatar._scan(self: MenuAvatar): ()
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local containers = playerGui and { CoreGui, playerGui } or { CoreGui }
	for i = 1, #containers do
		local models = containers[i]:QueryDescendants("Model")
		for m = 1, #models do
			self:_consider(models[m])
		end
	end
end

function MenuAvatar._watchFx(self: MenuAvatar): ()
	local function bindFx(fx: Instance): ()
		self._janitor:Add(
			fx.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(inst: Instance): ()
				self:_consider(inst)
			end)),
			"Disconnect"
		)
		local children = fx:GetChildren()
		for i = 1, #children do
			self:_consider(children[i])
		end
	end

	local function bindWorld(world: Instance): ()
		local fx = world:FindFirstChild("FX")
		if fx then
			bindFx(fx)
		end
		self._janitor:Add(
			world.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(child: Instance): ()
				if child.Name == "FX" then
					bindFx(child)
				end
			end)),
			"Disconnect"
		)
	end

	local world = Workspace:FindFirstChild("World")
	if world then
		bindWorld(world)
	end
	self._janitor:Add(
		Workspace.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(child: Instance): ()
			if child.Name == "World" then
				bindWorld(child)
			end
		end)),
		"Disconnect"
	)
end

function MenuAvatar._applyTarget(self: MenuAvatar, value: string): ()
	local target = value:gsub("^%s+", ""):gsub("%s+$", "")
	if target == "" then
		return
	end

	self._generation += 1
	local generation = self._generation

	task.spawn(function(): ()
		local userId = resolveUserId(target)
		if not userId then
			return
		end
		local reference = buildReference(userId)
		if generation ~= self._generation or not self._enabled then
			reference:Destroy()
			return
		end
		if self._reference then
			self._reference:Destroy()
		end
		self._reference = reference
		self._models = setmetatable({}, { __mode = "k" })
		self:_scan()
	end)
end

function MenuAvatar.Enable(self: MenuAvatar): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self:_installHook()

	local connect = function(container: Instance): ()
		self._janitor:Add(
			container.DescendantAdded:Connect(LPH_NO_VIRTUALIZE(function(inst: Instance): ()
				self:_consider(inst)
			end)),
			"Disconnect"
		)
	end
	connect(CoreGui)
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		connect(playerGui)
	end
	self:_watchFx()

	if not self._realReference then
		task.spawn(function(): ()
			self._realReference = buildReference(LOCAL_USER_ID)
		end)
	end

	self:_applyTarget(self._link:Peek("customCharacter.opts.target") or "")
end

function MenuAvatar.Disable(self: MenuAvatar): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._generation += 1
	self._janitor:Cleanup()

	local reference = self._realReference
	local models = self._models
	self._models = setmetatable({}, { __mode = "k" })

	if self._reference then
		self._reference:Destroy()
		self._reference = nil
	end

	if reference then
		for model in next, models do
			if model.Parent then
				self:_reskin(model, reference)
			end
		end
	end
end

function MenuAvatar.Destroy(self: MenuAvatar): ()
	self:Disable()
	if self._hooked and self._getCharacter then
		hook.restore(self._getCharacter)
		self._hooked = false
	end
	if self._realReference then
		self._realReference:Destroy()
		self._realReference = nil
	end
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type MenuAvatar =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_hooked: boolean,
			_getCharacter: any,
			_generation: number,
			_reference: Model?,
			_realReference: Model?,
			_models: any,
			_janitor: Janitor.Janitor,
			_link: gameUi.Linker,
			_installHook: (MenuAvatar) -> (),
			_reskin: (MenuAvatar, Model, Model?) -> (),
			_consider: (MenuAvatar, Instance) -> (),
			_scan: (MenuAvatar) -> (),
			_watchFx: (MenuAvatar) -> (),
			_applyTarget: (MenuAvatar, string) -> (),
		},
		MenuAvatar
	))
	& BaseFeature.BaseFeature

return MenuAvatar
