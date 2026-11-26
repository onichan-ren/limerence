local BaseFeature = require("@game/BaseFeature")
local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local ModuleController = require("@game/pf/module/ModuleController")
local grenadeSim = require("@game/pf/grenade/grenadeSim")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Terrain = Workspace.Terrain

local peek = Charm.peek

local DEFAULT_PATH = Color3.fromRGB(145, 190, 215)
local DEFAULT_IMPACT = Color3.fromRGB(120, 200, 130)

local MAX_STEPS = 90
local MAX_POINTS = MAX_STEPS + 1

local LINE_WIDTH = 0.06
local PATH_TRANSPARENCY = 0.15
local IMPACT_SIZE = 0.06

local GrenadePrediction = {}
GrenadePrediction.__index = GrenadePrediction

setmetatable(GrenadePrediction, { __index = BaseFeature })

local _characterInterface: any = nil
local _cameraInterface: any = nil

local function characterInterface(): any?
	if not _characterInterface then
		_characterInterface = ModuleController.GetModule("CharacterInterface")
	end
	return _characterInterface
end

local function getActiveGrenade(): any?
	local character = characterInterface()
	if not character then
		return nil
	end
	local co = character.getCharacterObject()
	if not co then
		return nil
	end
	local wc = co:getWeaponController()
	local active = wc and wc:getActiveWeapon()
	if active and active.getWeaponType and active:getWeaponType() == "Grenade" then
		return active
	end
	return nil
end

local function getGameCamera(): any?
	if not _cameraInterface then
		_cameraInterface = ModuleController.GetModule("CameraInterface")
	end
	if not _cameraInterface then
		return nil
	end
	return _cameraInterface.getActiveCamera("MainCamera", true)
end

local function getRootVelocity(): Vector3
	local character = characterInterface()
	if not character then
		return Vector3.zero
	end
	local co = character.getCharacterObject()
	local root = co and co:getRootPart()
	local velocity = root and root.Velocity
	if typeof(velocity) == "Vector3" then
		return velocity
	end
	return Vector3.zero
end

function GrenadePrediction.new(link: gameUi.Linker): GrenadePrediction
	local self = BaseFeature.new() :: any
	setmetatable(self, GrenadePrediction)

	link:Toggle("grenadePrediction", "Grenade Prediction", false):SetTip({
		title = "Grenade Prediction",
		body = "Draws the predicted arc and landing point of the grenade you are holding.",
	})
	local masterLink = link:OnKey("grenadePrediction")
	masterLink:Submenu("opts", "Grenade Prediction Options")
	local optsLink = masterLink:OnKey("opts")
	optsLink:Colorpicker("pathColor", "Path Color", DEFAULT_PATH)
	optsLink:Colorpicker("impactColor", "Impact Color", DEFAULT_IMPACT)

	self._enabledLink = link:Get("grenadePrediction")
	self._pathColorLink = link:Get("grenadePrediction.opts.pathColor")
	self._impactColorLink = link:Get("grenadePrediction.opts.impactColor")

	self._pathColor = DEFAULT_PATH
	self._pathSeq = ColorSequence.new(DEFAULT_PATH)
	self._impactColor = DEFAULT_IMPACT

	local holder = instances.new("Part", {
		Name = "",
		Size = Vector3.new(0.05, 0.05, 0.05),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, Terrain) :: Part
	self._holder = holder

	self._attachments = {}
	self._beams = {}
	for i = 1, MAX_POINTS do
		self._attachments[i] = instances.new("Attachment", {}, holder) :: Attachment
	end
	for i = 1, MAX_STEPS do
		self._beams[i] = instances.new("Beam", {
			Attachment0 = self._attachments[i],
			Attachment1 = self._attachments[i + 1],
			Width0 = LINE_WIDTH,
			Width1 = LINE_WIDTH,
			FaceCamera = true,
			LightEmission = 1,
			LightInfluence = 0,
			Segments = 1,
			TextureMode = Enum.TextureMode.Stretch,
			Transparency = NumberSequence.new(PATH_TRANSPARENCY),
			Color = self._pathSeq,
			Enabled = false,
		}, holder) :: Beam
	end

	self._impact = instances.new("Part", {
		Name = "",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(IMPACT_SIZE, IMPACT_SIZE, IMPACT_SIZE),
		Material = Enum.Material.Neon,
		Color = DEFAULT_IMPACT,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
	}, Terrain) :: Part

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	self._params = params

	self._map = nil
	local function setMap(map: Instance?): ()
		self._map = map
		params.FilterDescendantsInstances = map and { map } or {}
	end
	setMap(Workspace:FindFirstChild("Map"))
	self._mapConns = {
		Workspace.ChildAdded:Connect(function(child: Instance): ()
			if child.Name == "Map" then
				setMap(child)
			end
		end),
		Workspace.ChildRemoved:Connect(function(child: Instance): ()
			if child == self._map then
				setMap(Workspace:FindFirstChild("Map"))
			end
		end),
	}

	local function hideAll(): ()
		for _, beam in next, self._beams do
			beam.Enabled = false
		end
		self._impact.Transparency = 1
	end

	self._conn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
		if not peek(self._enabledLink._state) then
			hideAll()
			return
		end
		local weapon = getActiveGrenade()
		if not weapon then
			hideAll()
			return
		end

		if not self._map then
			hideAll()
			return
		end

		local camObject = getGameCamera()
		if not camObject then
			hideAll()
			return
		end
		local cameraCF = camObject:getCFrame()
		if typeof(cameraCF) ~= "CFrame" then
			hideAll()
			return
		end
		local baseCF = camObject:getBaseCFrame()
		local base = (typeof(baseCF) == "CFrame") and baseCF.Position or cameraCF.Position

		local throwspeed = weapon:getWeaponStat("throwspeed")
		if type(throwspeed) ~= "number" then
			hideAll()
			return
		end
		local throwangle = weapon:getWeaponStat("throwangle")
		local fuse = weapon:getWeaponStat("fusetime")
		fuse = type(fuse) == "number" and fuse or 3

		local hand = base
		local mainPart = weapon._mainPart
		if typeof(mainPart) == "Instance" then
			hand = mainPart.Position
		end

		local origin = hand
		local handHit = Workspace:Raycast(base, hand - base, self._params)
		if handHit then
			origin = handHit.Position + handHit.Normal * 0.01
		end

		local cframe = cameraCF * CFrame.Angles(math.rad(throwangle or 0), 0, 0)
		local velocity = cframe.LookVector * throwspeed + getRootVelocity()

		local points = grenadeSim.simulate(origin, velocity, fuse, self._params)
		local count = #points

		local pathColor = self._pathColorLink:GetColor()
		if pathColor ~= self._pathColor then
			self._pathColor = pathColor
			self._pathSeq = ColorSequence.new(pathColor)
			for _, beam in next, self._beams do
				beam.Color = self._pathSeq
			end
		end
		local impactColor = self._impactColorLink:GetColor()
		if impactColor ~= self._impactColor then
			self._impactColor = impactColor
			self._impact.Color = impactColor
		end

		for i = 1, count do
			self._attachments[i].WorldPosition = points[i]
		end
		local beamCount = math.min(count - 1, MAX_STEPS)
		for i = 1, beamCount do
			self._beams[i].Enabled = true
		end
		for i = beamCount + 1, MAX_STEPS do
			self._beams[i].Enabled = false
		end

		self._impact.CFrame = CFrame.new(points[count])
		self._impact.Transparency = 0.25
	end))

	return self
end

function GrenadePrediction.Destroy(self: GrenadePrediction): ()
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	if self._mapConns then
		for _, conn in next, self._mapConns do
			conn:Disconnect()
		end
		self._mapConns = nil
	end
	if self._holder then
		self._holder:Destroy()
		self._holder = nil
	end
	if self._impact then
		self._impact:Destroy()
		self._impact = nil
	end
	BaseFeature.Destroy(self)
end

export type GrenadePrediction =
	typeof(setmetatable(
		{} :: {
			_enabledLink: any,
			_pathColorLink: any,
			_impactColorLink: any,
			_pathColor: Color3,
			_pathSeq: ColorSequence,
			_impactColor: Color3,
			_holder: Part?,
			_attachments: { Attachment },
			_beams: { Beam },
			_impact: Part?,
			_params: RaycastParams,
			_map: Instance?,
			_mapConns: { RBXScriptConnection }?,
			_conn: RBXScriptConnection?,
		},
		GrenadePrediction
	))
	& BaseFeature.BaseFeature

return GrenadePrediction
