local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local clientState = require("@game/overkill/client/clientState")
local ModuleController = require("@game/overkill/module/ModuleController")
local antiAimState = require("@game/overkill/feature/antiaim/antiAimState")

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local RunService = cloneref(game:GetService("RunService")) :: RunService

local peek = Charm.peek
local sub = Charm.subscribe

local YAW_SYNC_NAME = "limerenceThirdPersonYaw"
local YAW_SYNC_PRIORITY = Enum.RenderPriority.Character.Value

local SKIP_PARTS = {
	HumanoidRootPart = true,
	HeadCollider = true,
	BoundingBody = true,
}

local buildBodyParts = LPH_NO_VIRTUALIZE(function(model: Instance?): ({ BasePart }, { Decal | Texture })
	local parts: { BasePart } = {}
	local decals: { Decal | Texture } = {}
	if not model then
		return parts, decals
	end
	for _, v in next, model:QueryDescendants("Instance") do
		if v:IsA("BasePart") then
			local name = v.Name
			if not SKIP_PARTS[name] and not string.find(name, "Hitbox") then
				parts[#parts + 1] = v
			end
		elseif v:IsA("Decal") or v:IsA("Texture") then
			decals[#decals + 1] = v
		end
	end
	return parts, decals
end)

local showBody = LPH_NO_VIRTUALIZE(function(parts: { BasePart }, decals: { Decal | Texture }, transparency: number): ()
	for i = 1, #parts do
		local part = parts[i]
		part.Transparency = transparency
		part.LocalTransparencyModifier = 0
	end
	for i = 1, #decals do
		decals[i].Transparency = transparency
	end
end)

local ThirdPerson = {}
ThirdPerson.__index = ThirdPerson

setmetatable(ThirdPerson, { __index = BaseFeature })

function ThirdPerson.new(link: gameUi.Linker): ThirdPerson
	local self = BaseFeature.new() :: any
	setmetatable(self, ThirdPerson)

	link:Toggle("thirdPerson", "Force Third Person", false):SetTip({
		title = "Force Third Person",
		body = "Pulls the camera back behind your character for a third-person view.",
	})
	local thirdPersonLink = link:OnKey("thirdPerson")
	thirdPersonLink:Submenu("opts", "Third Person Options")
	local optsLink = thirdPersonLink:OnKey("opts")
	optsLink:Slider("distance", "Distance", 8, 2, 100, 0.5, nil, "st"):SetTip({
		title = "Distance",
		body = "How far behind the character the camera sits.",
	})
	optsLink:Slider("shoulderX", "Shoulder X", 2, -4, 4, 0.1, nil, "st"):SetTip({
		title = "Shoulder X",
		body = "Shifts the camera left or right.",
	})
	optsLink:Slider("shoulderY", "Shoulder Y", 0.5, -4, 4, 0.1, nil, "st"):SetTip({
		title = "Shoulder Y",
		body = "Shifts the camera up or down.",
	})

	self._optsLink = optsLink
	self._distance = optsLink:Get("distance"):Peek()
	self._shoulderX = optsLink:Get("shoulderX"):Peek()
	self._shoulderY = optsLink:Get("shoulderY"):Peek()
	self._enabled = false
	self._janitor = Janitor.new()
	self._camera = nil
	self._cameraHandler = nil
	self._viewModel = nil
	self._character = nil
	self._bodyParts = {}
	self._bodyDecals = {}

	self:Track(link:Get("thirdPerson"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optsLink:Get("distance"):OnChange(function(value: number): ()
		self._distance = value
	end))
	self:Track(optsLink:Get("shoulderX"):OnChange(function(value: number): ()
		self._shoulderX = value
	end))
	self:Track(optsLink:Get("shoulderY"):OnChange(function(value: number): ()
		self._shoulderY = value
	end))

	return self
end

ThirdPerson._isActive = LPH_NO_VIRTUALIZE(function(self: ThirdPerson): boolean
	if not peek(clientState.alive) then
		return false
	end
	if peek(clientState.matchId) == nil then
		return false
	end
	local cameraHandler = self._cameraHandler
	if cameraHandler and cameraHandler.spectatingCharacter ~= nil then
		return false
	end
	return true
end)

function ThirdPerson._enterThirdPerson(self: ThirdPerson): ()
	if not self._enabled then
		return
	end
	local cameraHandler = self._cameraHandler
	if not cameraHandler or cameraHandler.thirdPersonDebug then
		return
	end
	setthreadidentity(2)
	local wasFirstPerson = cameraHandler.firstPerson
	cameraHandler.firstPerson = false
	cameraHandler:enterThirdPersonDebug()
	cameraHandler.firstPerson = wasFirstPerson
	setthreadidentity(8)
end

function ThirdPerson._restoreLocalViewmodel(self: ThirdPerson): ()
	local viewModel = self._viewModel
	if not viewModel then
		return
	end
	local character = peek(clientState.character)
	if not character then
		return
	end
	local vmc = viewModel.getEquipped(character)
	if vmc and vmc.isLocal and vmc.restoreVisibility then
		vmc:restoreVisibility()
	end
end

function ThirdPerson._exitThirdPerson(self: ThirdPerson): ()
	local cameraHandler = self._cameraHandler
	if not cameraHandler or not cameraHandler.thirdPersonDebug then
		return
	end
	setthreadidentity(2)
	cameraHandler:exitThirdPersonDebug()
	self:_restoreLocalViewmodel()
	setthreadidentity(8)
end

ThirdPerson._update = LPH_NO_VIRTUALIZE(function(self: ThirdPerson): ()
	if self._enabled and self:_isActive() then
		self:_enterThirdPerson()
		showBody(self._bodyParts, self._bodyDecals, 0)
	else
		self:_exitThirdPerson()
	end
end)

ThirdPerson._syncAntiAimYaw = LPH_NO_VIRTUALIZE(function(self: ThirdPerson): ()
	if not self._enabled or not self:_isActive() then
		return
	end

	local lookAngles = peek(antiAimState.lookAngles)
	if not lookAngles then
		return
	end

	local character = self._character
	if not character then
		return
	end
	local root = (character :: any).PrimaryPart :: BasePart?
	if not root then
		return
	end

	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, lookAngles.Y, 0)
end)

function ThirdPerson._setCharacter(self: ThirdPerson, character: Instance?): ()
	if self._character == character then
		return
	end
	self._character = character
	self._bodyParts, self._bodyDecals = buildBodyParts(character)
end

function ThirdPerson.Enable(self: ThirdPerson): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	self._camera = camera
	self._cameraHandler = ModuleController.GetModule("cameraHandler")
	self._viewModel = ModuleController.GetModule("viewModel")

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.RespectCanCollide = true

	local filterList = { peek(clientState.character) :: Instance, camera }
	params.FilterDescendantsInstances = filterList

	hook.addInstance(camera)
	hook.overrideProperty(
		camera,
		"CFrame",
		LPH_NO_VIRTUALIZE(function(value: CFrame): CFrame
			clientState.fpCamera(value)
			if not self:_isActive() then
				return value
			end
			local newValue = value * CFrame.new(self._shoulderX, self._shoulderY, self._distance)
			local origin = value.Position
			local direction = newValue.Position - origin
			local result = Workspace:Raycast(origin, direction, params)
			if result then
				newValue = value + (result.Position - origin)
			end
			return newValue
		end)
	)

	self:_setCharacter(peek(clientState.character))

	self._janitor:Add(sub(clientState.character, function(char: Instance?): ()
		filterList[1] = char :: Instance
		params.FilterDescendantsInstances = filterList
		if not self._enabled then
			return
		end
		self:_setCharacter(char)
	end))

	self._janitor:Add(
		RunService.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function(): ()
			self:_update()
		end)),
		"Disconnect"
	)

	RunService:BindToRenderStep(
		YAW_SYNC_NAME,
		YAW_SYNC_PRIORITY,
		LPH_NO_VIRTUALIZE(function(): ()
			self:_syncAntiAimYaw()
		end)
	)
	self._janitor:Add(function(): ()
		RunService:UnbindFromRenderStep(YAW_SYNC_NAME)
	end)

	self._janitor:Add(function(): ()
		self:_exitThirdPerson()
		self._character = nil
		self._bodyParts = {}
		self._bodyDecals = {}
	end)
end

function ThirdPerson.Disable(self: ThirdPerson): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	local camera = self._camera
	if camera then
		hook.restoreProperty(camera, "CFrame")
		hook.restoreInstance(camera)
	end
	clientState.fpCamera(nil)

	self._janitor:Cleanup()

	self._camera = nil
	self._cameraHandler = nil
	self._viewModel = nil
end

function ThirdPerson.Destroy(self: ThirdPerson): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ThirdPerson = typeof(setmetatable(
	{} :: {
		_optsLink: gameUi.Linker,
		_distance: number,
		_shoulderX: number,
		_shoulderY: number,
		_enabled: boolean,
		_janitor: Janitor.Janitor,
		_camera: Camera?,
		_cameraHandler: any,
		_viewModel: any,
		_character: Instance?,
		_bodyParts: { BasePart },
		_bodyDecals: { Decal | Texture },
		_isActive: (ThirdPerson) -> boolean,
		_enterThirdPerson: (ThirdPerson) -> (),
		_exitThirdPerson: (ThirdPerson) -> (),
		_restoreLocalViewmodel: (ThirdPerson) -> (),
		_update: (ThirdPerson) -> (),
		_syncAntiAimYaw: (ThirdPerson) -> (),
		_setCharacter: (ThirdPerson, Instance?) -> (),
	},
	ThirdPerson
)) & BaseFeature.BaseFeature

return ThirdPerson
