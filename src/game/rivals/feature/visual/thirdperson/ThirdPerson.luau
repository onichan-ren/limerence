local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local clientState = require("@game/rivals/client/clientState")
local viewmodelState = require("@game/rivals/viewmodel/viewmodelState")
local WeaponController = require("@game/rivals/weapon/WeaponController")

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local RunService = cloneref(game:GetService("RunService")) :: RunService

local peek = Charm.peek
local sub = Charm.subscribe

local isHideable = LPH_NO_VIRTUALIZE(function(instance: Instance): boolean
	return instance:IsA("BasePart")
		or instance:IsA("Decal")
		or instance:IsA("Beam")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Trail")
end)

local buildViewmodelParts = LPH_NO_VIRTUALIZE(function(viewmodel: any): { any }
	local parts: { any } = {}
	local model = viewmodel and rawget(viewmodel, "Model")
	if not model then
		return parts
	end
	for _, v in next, model:QueryDescendants("Instance") do
		if isHideable(v) then
			parts[#parts + 1] = v
		end
	end
	return parts
end)

local applyTransparency = LPH_NO_VIRTUALIZE(function(parts: { any }, modifier: number): ()
	for i = 1, #parts do
		parts[i].LocalTransparencyModifier = modifier
	end
end)

local ThirdPerson = {}
ThirdPerson.__index = ThirdPerson

setmetatable(ThirdPerson, { __index = BaseFeature })

local function getLocalFighter(): any?
	return WeaponController.GetLocalFighter()
end

local forceShown = function(): boolean
	return false
end

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
	self._fighter = nil
	self._fighterOriginal = nil
	self._viewmodel = nil
	self._viewmodelParts = {}
	self._modelConn = nil

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

function ThirdPerson._verifyVisibility(_self: ThirdPerson, fighter: any): ()
	local entity = fighter and rawget(fighter, "Entity")
	local visibility = entity and rawget(entity, "Visibility")
	if not visibility then
		return
	end
	setthreadidentity(2)
	visibility._Verify(visibility, true)
	setthreadidentity(8)
end

function ThirdPerson._showBody(self: ThirdPerson): ()
	local fighter = getLocalFighter()
	if type(fighter) ~= "table" then
		return
	end
	if self._fighter ~= fighter then
		self._fighter = fighter
		self._fighterOriginal = rawget(fighter, "IsActuallyFirstPerson")
	end
	rawset(fighter, "IsActuallyFirstPerson", forceShown)
	self:_verifyVisibility(fighter)
end

function ThirdPerson._setViewmodel(self: ThirdPerson, viewmodel: any): ()
	if self._viewmodel == viewmodel then
		return
	end
	if self._modelConn then
		self._modelConn:Disconnect()
		self._modelConn = nil
	end
	if self._viewmodel then
		applyTransparency(self._viewmodelParts, 0)
	end
	self._viewmodel = viewmodel
	self._viewmodelParts = buildViewmodelParts(viewmodel)

	local model = viewmodel and rawget(viewmodel, "Model")
	if model then
		self._modelConn = model.DescendantAdded:Connect(function(descendant: Instance): ()
			if isHideable(descendant) then
				local added: any = descendant
				local parts = self._viewmodelParts
				parts[#parts + 1] = added
				added.LocalTransparencyModifier = 1
			end
		end)
	end
end

function ThirdPerson._restoreBody(self: ThirdPerson): ()
	local fighter = self._fighter
	if type(fighter) == "table" then
		rawset(fighter, "IsActuallyFirstPerson", self._fighterOriginal)
		self:_verifyVisibility(fighter)
	end
	self._fighter = nil
	self._fighterOriginal = nil
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
			if not peek(clientState.alive) then
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

	self:_showBody()
	self._janitor:Add(sub(clientState.character, function(character: Instance?): ()
		filterList[1] = character :: Instance
		params.FilterDescendantsInstances = filterList
		if self._enabled then
			self:_showBody()
		end
	end))

	self:_setViewmodel(peek(viewmodelState._viewmodel))
	self._janitor:Add(sub(viewmodelState._viewmodel, function(viewmodel: any): ()
		self:_setViewmodel(viewmodel)
	end))
	self._janitor:Add(
		RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
			if self._viewmodel then
				applyTransparency(self._viewmodelParts, 1)
			end
		end)),
		"Disconnect"
	)
	self._janitor:Add(function(): ()
		if self._modelConn then
			self._modelConn:Disconnect()
			self._modelConn = nil
		end
		if self._viewmodel then
			applyTransparency(self._viewmodelParts, 0)
		end
		self._viewmodel = nil
		self._viewmodelParts = {}
	end)
end

function ThirdPerson.Disable(self: ThirdPerson): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self._janitor:Cleanup()

	self:_restoreBody()

	local camera = self._camera
	if camera then
		hook.restoreProperty(camera, "CFrame")
		hook.restoreInstance(camera)
	end
	self._camera = nil
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
		_fighter: any?,
		_fighterOriginal: any?,
		_viewmodel: any?,
		_viewmodelParts: { any },
		_modelConn: RBXScriptConnection?,
	},
	ThirdPerson
)) & BaseFeature.BaseFeature

return ThirdPerson
