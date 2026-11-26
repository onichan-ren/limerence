local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local Janitor = require("@pkg/Janitor")
local React = require("@pkg/React")

local subscribeToBinding = (React :: any).__subscribeToBinding

local DEFAULT_COLOR = Color3.fromRGB(80, 170, 255)
local DEFAULT_MATERIAL = Enum.Material.Neon
local GHOST_PART_TRANSPARENCY = 0.5
local HIDDEN_TRANSPARENCY = 1
local MIN_PHASE = 0.01
local FADE_TIME = 0.12
local TICK_SECONDS = 1 / 60
local MATERIAL_NAMES = { "Neon", "ForceField", "Glass" }
local SKIP_GHOST_PARTS = {
	HumanoidRootPart = true,
	HeadCollider = true,
	BoundingBody = true,
}

export type FakeLagOpts = {
	getCharacter: () -> Instance?,
	isAlive: () -> boolean,
	getRoot: () -> BasePart?,
	getParts: (() -> { [string]: Instance })?,
	setFrozen: ((frozen: boolean, depth: number?) -> ())?,
	freeze: ((root: BasePart, frozenCFrame: CFrame, dt: number) -> ())?,
	setGhost: ((frozenCFrame: CFrame?) -> ())?,
	tickMode: boolean?,
	getTick: (() -> number)?,
}

local FakeLag = {}
FakeLag.__index = FakeLag

setmetatable(FakeLag, { __index = BaseFeature })

function FakeLag.new(link: gameUi.Linker, opts: FakeLagOpts): FakeLag
	local self = BaseFeature.new() :: any
	setmetatable(self, FakeLag)

	self._getCharacter = opts.getCharacter
	self._isAlive = opts.isAlive
	self._getRoot = opts.getRoot
	self._getParts = opts.getParts
	self._setFrozen = opts.setFrozen
	self._freeze = opts.freeze
	self._setGhost = opts.setGhost
	self._tickMode = opts.tickMode == true
	self._getTick = opts.getTick

	link:Toggle("fakeLag", "Fake Lag", false):SetTip({
		title = "Fake Lag",
		body = "Freezes your position for others in short bursts so you are harder to hit.",
	})
	local lagLink = link:OnKey("fakeLag")
	lagLink:Submenu("opts", "Fake Lag")
	local optsLink = lagLink:OnKey("opts")

	if self._tickMode then
		self._downElement = optsLink:RangeSlider("down", "Down", 3, 6, 1, 24, 1, nil, "t")
		self._downElement:SetTip({
			title = "Down",
			body = "How many ticks each freeze holds. A random count is picked between the low and high values.",
		})
		self._upElement = optsLink:RangeSlider("up", "Up", 1, 3, 1, 24, 1, nil, "t")
		self._upElement:SetTip({
			title = "Up",
			body = "How many ticks you move normally between freezes. A random count is picked between the low and high values.",
		})
	else
		self._downElement = optsLink:RangeSlider("down", "Down Time", 80, 200, 0, 1000, 10, nil, "ms")
		self._downElement:SetTip({
			title = "Down Time",
			body = "How long each freeze lasts. A random time is picked between the low and high values.",
		})
		self._upElement = optsLink:RangeSlider("up", "Up Time", 40, 100, 0, 1000, 10, nil, "ms")
		self._upElement:SetTip({
			title = "Up Time",
			body = "How long you move normally between freezes. A random time is picked between the low and high values.",
		})
	end

	optsLink:Toggle("visualize", "Visualize", true):SetTip({
		title = "Visualize",
		body = "Shows a marker where you are frozen.",
	})
	local visualOpts = nil :: any
	local colorEl = nil :: any
	if not self._setGhost then
		local visLink = optsLink:OnKey("visualize")
		visLink:Submenu("visual", "Visualize")
		visualOpts = visLink:OnKey("visual")
		visualOpts:List("material", "Material", MATERIAL_NAMES, "Neon"):SetTip({
			title = "Material",
			body = "Material of the freeze marker.",
		})
		colorEl = visualOpts:Colorpicker("color", "Color", DEFAULT_COLOR, 0)
		colorEl:SetTip({
			title = "Color",
			body = "Color of the freeze marker.",
		})
	end

	self._visualize = true
	self._color = DEFAULT_COLOR
	self._material = DEFAULT_MATERIAL
	self._fadeAlpha = 0
	self._frozenStart = 0
	self._frozenDuration = 0
	self._phase = "moving"
	self._phaseEnd = 0
	self._frozenCFrame = nil :: CFrame?
	self._activeJanitor = nil :: Janitor.Janitor?
	self._folder = if self._setGhost then nil else instances.new("Folder", { Secure = true }, Workspace) :: Folder
	self._ghost = nil :: Model?
	self._ghostParts = {} :: { [string]: BasePart }
	self._ghostChar = nil :: Instance?

	self:Track(link:Get("fakeLag"):OnChange(function(value: boolean): ()
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("fakeLag.opts.visualize", function(value: boolean): ()
		self._visualize = value
		if value then
			local frozenCFrame = self._frozenCFrame
			if frozenCFrame then
				self:_setVisual(frozenCFrame)
			end
		else
			self:_setVisual(nil)
		end
	end))

	if visualOpts then
		self:Track(visualOpts:Watch("material", function(value: any): ()
			if type(value) ~= "string" then
				return
			end
			local material = (Enum.Material :: any)[value]
			if not material then
				return
			end
			self._material = material
			for _, part in next, self._ghostParts do
				part.Material = material
			end
		end))

		local function applyColor(value: Color3): ()
			self._color = value
			for _, part in next, self._ghostParts do
				part.Color = value
			end
		end
		applyColor((colorEl._currentColor :: any):getValue())
		self:Track(subscribeToBinding(colorEl._currentColor, applyColor))
	end

	return self
end

function FakeLag._parts(self: FakeLag): { [string]: Instance }
	if self._getParts then
		return self._getParts()
	end
	local map: { [string]: Instance } = {}
	local character = self._getCharacter()
	if character then
		for _, child in next, character:GetChildren() do
			if child:IsA("BasePart") then
				map[child.Name] = child
			end
		end
	end
	return map
end

function FakeLag._randomDuration(self: FakeLag, element: any): number
	local value = element:GetRandomValue()
	if self._tickMode then
		if type(value) == "number" and value >= 1 then
			return math.floor(value)
		end
		return 1
	end
	if type(value) == "number" and value > 0 then
		return value / 1000
	end
	return MIN_PHASE
end

function FakeLag._now(self: FakeLag): number
	if self._tickMode and self._getTick then
		return self._getTick()
	end
	return os.clock()
end

function FakeLag._buildGhost(self: FakeLag, character: Instance, parts: { [string]: Instance }): ()
	self:_destroyGhost()

	local model = instances.new("Model", { Secure = true }, self._folder) :: Model
	local ghostParts: { [string]: BasePart } = {}

	for name, inst in next, parts do
		if not inst:IsA("BasePart") then
			continue
		end
		if SKIP_GHOST_PARTS[name] or string.find(name, "Hitbox", 1, true) then
			continue
		end

		local clone = inst:Clone() :: BasePart
		for _, c in next, clone:GetChildren() do
			if c:IsA("SpecialMesh") then
				c.TextureId = ""
			else
				c:Destroy()
			end
		end
		if clone:IsA("MeshPart") then
			clone.TextureID = ""
		end

		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.CastShadow = false
		clone.Transparency = HIDDEN_TRANSPARENCY
		clone.Material = self._material
		clone.Color = self._color
		clone.Parent = model
		ghostParts[name] = clone
	end

	self._ghost = model
	self._ghostParts = ghostParts
	self._ghostChar = character
	self._fadeAlpha = 0
end

function FakeLag._showGhost(self: FakeLag, parts: { [string]: Instance }): ()
	local character = self._getCharacter()
	if not character then
		return
	end
	if self._ghostChar ~= character or not self._ghost then
		self:_buildGhost(character, parts)
	end

	for name, clone in next, self._ghostParts do
		local src = parts[name]
		if src and src:IsA("BasePart") then
			clone.CFrame = src.CFrame
		end
	end
end

function FakeLag._setVisual(self: FakeLag, frozenCFrame: CFrame?): ()
	local setGhost = self._setGhost
	if setGhost then
		setGhost(frozenCFrame)
		return
	end
	if frozenCFrame then
		self:_showGhost(self:_parts())
	end
end

function FakeLag._updateFade(self: FakeLag, dt: number): ()
	if not self._ghost then
		return
	end
	local target = 0
	if self._visualize and self._phase == "frozen" and self._frozenDuration > 0 then
		local remaining = 1 - (os.clock() - self._frozenStart) / self._frozenDuration
		target = math.clamp(remaining, 0, 1)
	end
	local alpha = self._fadeAlpha
	local step = dt / FADE_TIME
	if alpha < target then
		alpha = math.min(target, alpha + step)
	elseif alpha > target then
		alpha = math.max(target, alpha - step)
	else
		return
	end
	self._fadeAlpha = alpha
	local transparency = HIDDEN_TRANSPARENCY + (GHOST_PART_TRANSPARENCY - HIDDEN_TRANSPARENCY) * alpha
	for _, clone in next, self._ghostParts do
		clone.Transparency = transparency
	end
end

function FakeLag._destroyGhost(self: FakeLag): ()
	if self._ghost then
		self._ghost:Destroy()
		self._ghost = nil
	end
	self._ghostParts = {}
	self._ghostChar = nil
	self._fadeAlpha = 0
end

function FakeLag._release(self: FakeLag): ()
	self._frozenCFrame = nil
	self._phase = "moving"
	self._phaseEnd = 0
	self:_setVisual(nil)
	if self._setFrozen then
		self._setFrozen(false)
	end
end

function FakeLag._setEnabled(self: FakeLag, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end
		local janitor = Janitor.new()
		self._activeJanitor = janitor

		self._phase = "moving"
		self._phaseEnd = 0

		janitor:Add(
			RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
				local root = self._getRoot()
				if not self._isAlive() or not root or not root.Parent then
					self:_release()
					return
				end

				self:_updateFade(dt)

				local now = self:_now()
				if now >= self._phaseEnd then
					if self._phase == "frozen" then
						self._phase = "moving"
						self._phaseEnd = now + self:_randomDuration(self._upElement)
						self._frozenCFrame = nil
						self:_setVisual(nil)
						if self._setFrozen then
							self._setFrozen(false)
						end
					else
						local dur = self:_randomDuration(self._downElement)
						self._phase = "frozen"
						self._phaseEnd = now + dur
						self._frozenStart = os.clock()
						self._frozenDuration = self._tickMode and dur * TICK_SECONDS or dur
						self._frozenCFrame = root.CFrame
						if self._visualize then
							self:_setVisual(root.CFrame)
						end
						if self._setFrozen then
							self._setFrozen(true, dur)
						end
					end
				end

				local frozenCFrame = self._frozenCFrame
				if frozenCFrame then
					local freeze = self._freeze
					if freeze then
						freeze(root, frozenCFrame, dt)
					elseif not self._setFrozen then
						root.Anchored = true
						RunService.PreRender:Wait()
						root.Anchored = false
					end
				end
			end)),
			"Disconnect"
		)

		janitor:Add(function(): ()
			self:_release()
			self:_destroyGhost()
		end, true)
	else
		local janitor = self._activeJanitor
		if not janitor then
			return
		end
		self._activeJanitor = nil
		janitor:Destroy()
	end
end

function FakeLag.Destroy(self: FakeLag): ()
	self:_setEnabled(false)
	if self._folder then
		self._folder:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type FakeLag =
	typeof(setmetatable(
		{} :: {
			_getCharacter: () -> Instance?,
			_isAlive: () -> boolean,
			_getRoot: () -> BasePart?,
			_getParts: (() -> { [string]: Instance })?,
			_setFrozen: ((frozen: boolean, depth: number?) -> ())?,
			_freeze: ((root: BasePart, frozenCFrame: CFrame, dt: number) -> ())?,
			_setGhost: ((frozenCFrame: CFrame?) -> ())?,
			_setVisual: (FakeLag, CFrame?) -> (),
			_tickMode: boolean,
			_getTick: (() -> number)?,
			_now: (FakeLag) -> number,
			_visualize: boolean,
			_color: Color3,
			_material: Enum.Material,
			_fadeAlpha: number,
			_frozenStart: number,
			_frozenDuration: number,
			_phase: string,
			_phaseEnd: number,
			_frozenCFrame: CFrame?,
			_activeJanitor: Janitor.Janitor?,
			_folder: Folder?,
			_ghost: Model?,
			_ghostParts: { [string]: BasePart },
			_ghostChar: Instance?,
			_downElement: any,
			_upElement: any,
		},
		FakeLag
	))
	& BaseFeature.BaseFeature

return FakeLag
