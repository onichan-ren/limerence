local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local clientState = require("@game/op1/client/clientState")
local thirdPersonState = require("@game/op1/feature/visual/self/thirdPersonState")
local FakeCharacter = require("@game/op1/character/FakeCharacter")

local peek = Charm.peek

local RENDER_NAME = "LimerenceThirdPerson"
local RENDER_PRIORITY = Enum.RenderPriority.Last.Value + 3

local ThirdPerson = {}
ThirdPerson.__index = ThirdPerson

setmetatable(ThirdPerson, { __index = BaseFeature })

function ThirdPerson.new(link: gameUi.Linker): ThirdPerson
	local self = BaseFeature.new() :: any
	setmetatable(self, ThirdPerson)

	link:Toggle("thirdPerson", "Third Person", false):SetTip({
		title = "Third Person",
		body = "Shows a full body clone of you from behind.",
	})
	local thirdPersonLink = link:OnKey("thirdPerson")
	thirdPersonLink:Submenu("opts", "Third Person")
	local optionsLink = thirdPersonLink:OnKey("opts")
	optionsLink:Slider("distance", "Distance", 8, 2, 100, 0.5, nil, "st"):SetTip({
		title = "Distance",
		body = "How far behind the character the camera sits.",
	})
	optionsLink:Slider("shoulderX", "Shoulder X", 2, -4, 4, 0.1, nil, "st"):SetTip({
		title = "Shoulder X",
		body = "Shifts the camera left or right.",
	})
	optionsLink:Slider("shoulderY", "Shoulder Y", 0.5, -4, 4, 0.1, nil, "st"):SetTip({
		title = "Shoulder Y",
		body = "Shifts the camera up or down.",
	})
	self._enabled = false
	self._distance = optionsLink:Get("distance"):Peek() or 8
	self._shoulderX = optionsLink:Get("shoulderX"):Peek() or 2
	self._shoulderY = optionsLink:Get("shoulderY"):Peek() or 0.5
	self._bound = false

	self._raycastParams = RaycastParams.new()
	self._raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self._raycastParams.IgnoreWater = true
	self._filterScratch = {}

	self:Track(link:Get("thirdPerson"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(link:Watch("thirdPerson.opts.distance", function(value: number): ()
		self._distance = value or 8
	end))
	self:Track(link:Watch("thirdPerson.opts.shoulderX", function(value: number): ()
		self._shoulderX = value or 0
	end))
	self:Track(link:Watch("thirdPerson.opts.shoulderY", function(value: number): ()
		self._shoulderY = value or 0
	end))
	if link:Peek("thirdPerson") then
		self:Enable()
	end

	return self
end

function ThirdPerson._trackViewmodels(self: ThirdPerson, viewmodels: Instance?): ()
	self:_restoreViewmodels()
	self._viewmodels = viewmodels
	self._vmParts = {}
	if self._vmConn then
		self._vmConn:Disconnect()
		self._vmConn = nil
	end
	if not viewmodels then
		return
	end
	local parts = self._vmParts
	for _, descendant in next, viewmodels:QueryDescendants("BasePart") do
		parts[#parts + 1] = descendant
		descendant.LocalTransparencyModifier = 1
	end
	self._vmConn = viewmodels.DescendantAdded:Connect(function(descendant: Instance): ()
		if descendant:IsA("BasePart") then
			parts[#parts + 1] = descendant
			descendant.LocalTransparencyModifier = 1
		end
	end)
end

function ThirdPerson._restoreViewmodels(self: ThirdPerson): ()
	if self._vmParts then
		for _, part in next, self._vmParts do
			part.LocalTransparencyModifier = 0
		end
	end
	if self._vmConn then
		self._vmConn:Disconnect()
		self._vmConn = nil
	end
	self._vmParts = nil
	self._viewmodels = nil
end

function ThirdPerson._destroyFake(self: ThirdPerson): ()
	if self._fake then
		self._fake:Destroy()
		self._fake = nil
		thirdPersonState.clone(nil)
	end
	self._builtFor = nil
end

ThirdPerson._step = LPH_NO_VIRTUALIZE(function(self: ThirdPerson): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local cf = camera.CFrame
	local charObject = peek(clientState.charObject)
	local hrp = peek(clientState.hrp)

	if not charObject or not hrp then
		self:_restoreViewmodels()
		return
	end

	if charObject ~= self._builtFor then
		self:_destroyFake()
		local fake = FakeCharacter.new({ queryable = false, animate = false })
		if fake:Build() then
			self._fake = fake
			self._builtFor = charObject
			thirdPersonState.clone(fake)
			thirdPersonState.bump()
		else
			fake:Destroy()
		end
	end

	local values = charObject.values
	local viewmodels = values and values.viewmodels
	if viewmodels ~= self._viewmodels then
		self:_trackViewmodels(viewmodels)
	end

	local fake = self._fake
	if fake then
		fake:MirrorFrom(viewmodels, Vector3.zero)

		local equipped = values and values.equipped
		local slot = equipped and equipped.loadout_type
		if (slot == "primary" or slot == "secondary") and slot ~= fake:GetActiveSlot() then
			fake:SetEquippedSlot(slot)
			thirdPersonState.bump()
		end
	end

	local origin = cf.Position
	local offset = -cf.LookVector * self._distance + cf.RightVector * self._shoulderX + cf.UpVector * self._shoulderY
	local target = origin + offset

	local filter = self._filterScratch
	table.clear(filter)
	filter[#filter + 1] = camera

	if viewmodels then
		filter[#filter + 1] = viewmodels
	end

	local character = peek(clientState.character)
	if character then
		filter[#filter + 1] = character
	end

	local fakeModel = fake and fake:GetModel()
	if fakeModel then
		filter[#filter + 1] = fakeModel
	end

	self._raycastParams.FilterDescendantsInstances = filter

	local result = Workspace:Raycast(origin, offset, self._raycastParams)
	if result then
		target = result.Position + result.Normal * 0.2
	end

	local final = CFrame.new(target) * (cf - origin)
	camera.CFrame = final
end)

function ThirdPerson.Enable(self: ThirdPerson): ()
	if self._enabled then
		return
	end
	self._enabled = true
	thirdPersonState.active(true)

	RunService:BindToRenderStep(RENDER_NAME, RENDER_PRIORITY, LPH_NO_VIRTUALIZE(function(): ()
		self:_step()
	end))
	self._bound = true
end

function ThirdPerson.Disable(self: ThirdPerson): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	thirdPersonState.active(false)

	if self._bound then
		RunService:UnbindFromRenderStep(RENDER_NAME)
		self._bound = false
	end

	self:_restoreViewmodels()
	self:_destroyFake()
end

function ThirdPerson.Destroy(self: ThirdPerson): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ThirdPerson =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_distance: number,
			_shoulderX: number,
			_shoulderY: number,
			_raycastParams: RaycastParams,
			_filterScratch: { Instance },
			_bound: boolean,
			_viewmodels: Instance?,
			_vmParts: { BasePart }?,
			_vmConn: RBXScriptConnection?,
			_fake: FakeCharacter.FakeCharacter?,
			_builtFor: any,
			_step: (ThirdPerson) -> (),
			_trackViewmodels: (ThirdPerson, Instance?) -> (),
			_restoreViewmodels: (ThirdPerson) -> (),
			_destroyFake: (ThirdPerson) -> (),
			Enable: (ThirdPerson) -> (),
			Disable: (ThirdPerson) -> (),
		},
		ThirdPerson
	))
	& BaseFeature.BaseFeature

return ThirdPerson
