local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService
local RunService = cloneref(game:GetService("RunService")) :: RunService

local BaseFeature = require("@game/BaseFeature")
local Janitor = require("@pkg/Janitor")
local gameUi = require("@game/gameUi")
local Charm = require("@pkg/Charm")

local peek = Charm.peek
local sub = Charm.subscribe

export type System = {
	key: string,
	label: string,
	color: Color3,
	staticPath: { string }?,
	staticPaths: { { string } }?,
	tag: string?,
	module: string?,
	registry: string?,
	field: string?,
	watch: boolean?,
	matchNames: { [string]: boolean }?,
	particles: boolean?,
	lighting: boolean?,
	parts: boolean?,
	images: boolean?,
}

export type ParticleColorsOpts = {
	rootKey: string,
	rootLabel: string,
	systems: { System },
	resolveStaticRoot: (() -> Instance?)?,
	resolveModule: ((name: string) -> any)?,
	watchRoot: (() -> Instance?)?,
}

local ParticleColors = {}
ParticleColors.__index = ParticleColors

setmetatable(ParticleColors, { __index = BaseFeature })

function ParticleColors.new(link: gameUi.Linker, opts: ParticleColorsOpts): ParticleColors
	local self = BaseFeature.new() :: any
	setmetatable(self, ParticleColors)

	self._opts = opts
	self._states = {}

	link:Options(opts.rootKey, opts.rootLabel)
	local root = link:OnKey(opts.rootKey)

	for _, config in next, opts.systems do
		root:Toggle(config.key, config.label .. " Particles", false):SetTip({
			title = config.label .. " Particles",
			body = "Recolors " .. string.lower(config.label) .. " particles. Use the color's alpha for transparency.",
		})
		local optsLink = root:OnKey(config.key)
		optsLink:Colorpicker("color", "Color", config.color, 0):SetTip({
			title = "Color",
			body = "Color and transparency applied to " .. string.lower(config.label) .. " particle emitters.",
		})

		local state = {
			config = config,
			enabled = false,
			colorEl = optsLink:Get("color"),
			janitor = Janitor.new(),
			originals = setmetatable({}, { __mode = "k" }) :: any,
		}
		self._states[config.key] = state

		self:Track(root:Get(config.key):OnChange(function(value: boolean): ()
			if value then
				self:EnableSystem(config.key)
			else
				self:DisableSystem(config.key)
			end
		end))
	end

	return self
end

local function applyEmitter(state: any, emitter: any): ()
	if state.originals[emitter] == nil then
		state.originals[emitter] = { kind = "particle", Color = emitter.Color, Transparency = emitter.Transparency }
	end
	emitter.Color = state.colorEl:GetGradient()
	emitter.Transparency = NumberSequence.new(state.colorEl:GetTransparency())
end

local function applySparkles(state: any, sparkles: any): ()
	if state.originals[sparkles] == nil then
		state.originals[sparkles] = { kind = "sparkles", Color = sparkles.SparkleColor }
	end
	sparkles.SparkleColor = state.colorEl:GetColor()
end

local function applyLight(state: any, light: Light): ()
	if state.originals[light] == nil then
		state.originals[light] = { kind = "light", Color = light.Color }
	end
	light.Color = state.colorEl:GetColor()
end

local function applyPart(state: any, part: BasePart): ()
	if state.originals[part] == nil then
		state.originals[part] = { kind = "part", Color = part.Color, Transparency = part.Transparency }
	end
	part.Color = state.colorEl:GetColor()
	local alpha = state.colorEl:GetTransparency()
	part.Transparency = alpha > 0 and alpha or state.originals[part].Transparency
end

local function applyImage(state: any, image: any): ()
	if state.originals[image] == nil then
		state.originals[image] = { kind = "image", Color = image.ImageColor3 }
	end
	image.ImageColor3 = state.colorEl:GetColor()
end

local applyDescendant = LPH_NO_VIRTUALIZE(function(state: any, descendant: Instance): ()
	if state.config.particles and (descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Trail")) then
		applyEmitter(state, descendant)
	elseif state.config.particles and descendant:IsA("Sparkles") then
		applySparkles(state, descendant)
	elseif state.config.lighting and descendant:IsA("Light") then
		applyLight(state, descendant)
	elseif state.config.parts and descendant:IsA("BasePart") then
		applyPart(state, descendant)
	elseif state.config.images and (descendant:IsA("ImageLabel") or descendant:IsA("ImageButton")) then
		applyImage(state, descendant)
	end
end)

local function applyModel(self: any, state: any, model: Instance?): ()
	if not model or not model:IsA("Instance") then
		return
	end
	for _, descendant in next, model:QueryDescendants("Instance") do
		applyDescendant(state, descendant)
	end
	state.janitor:Add(model.DescendantAdded:Connect(function(descendant: Instance): ()
		if state.enabled then
			applyDescendant(state, descendant)
		end
	end))
end

local matchesWatch = LPH_NO_VIRTUALIZE(function(state: any, descendant: Instance): boolean
	local names = state.config.matchNames
	if not names then
		return false
	end
	local node: Instance? = descendant
	local depth = 0
	while node and depth < 8 do
		if names[node.Name] then
			return true
		end
		node = node.Parent
		depth += 1
	end
	return false
end)

local function resolveStaticModel(self: any, path: { string }): Instance?
	local resolveRoot = self._opts.resolveStaticRoot
	local instance: Instance? = resolveRoot and resolveRoot() or nil
	for index = 1, #path do
		if not instance then
			return nil
		end
		instance = instance:FindFirstChild(path[index])
	end
	return instance
end

local function modelFromPart(self: any, state: any, part: Instance): Instance?
	local resolveModule = self._opts.resolveModule
	if not resolveModule then
		return nil
	end
	local module = resolveModule(state.config.module)
	if not module then
		return nil
	end
	local registry = rawget(module, state.config.registry)
	if type(registry) ~= "table" then
		return nil
	end
	local entry = registry[part]
	if type(entry) ~= "table" then
		return nil
	end
	return entry[state.config.field]
end

local function sweepExisting(self: any, state: any): ()
	for _, part in next, CollectionService:GetTagged(state.config.tag) do
		applyModel(self, state, modelFromPart(self, state, part))
	end
end

local function applyStatic(self: any, state: any): ()
	if state.config.staticPath then
		applyModel(self, state, resolveStaticModel(self, state.config.staticPath))
	end
	if state.config.staticPaths then
		for _, path in next, state.config.staticPaths do
			applyModel(self, state, resolveStaticModel(self, path))
		end
	end
end

local reapply = LPH_NO_VIRTUALIZE(function(state: any): ()
	local colorEl = state.colorEl
	local gradient = colorEl:GetGradient()
	local color = colorEl:GetColor()
	local alpha = colorEl:GetTransparency()
	local transparencySeq = NumberSequence.new(alpha)
	for instance, original in next, state.originals do
		if instance.Parent then
			if original.kind == "particle" then
				instance.Color = gradient
				instance.Transparency = transparencySeq
			elseif original.kind == "part" then
				instance.Color = color
				instance.Transparency = alpha > 0 and alpha or original.Transparency
			elseif original.kind == "sparkles" then
				instance.SparkleColor = color
			elseif original.kind == "image" then
				instance.ImageColor3 = color
			else
				instance.Color = color
			end
		end
	end
end)

local function isAnimated(state: any): boolean
	local anim = state.colorEl._animation
	return anim ~= nil and peek(anim) ~= "none"
end

local function syncAnimation(state: any): ()
	if state.enabled and isAnimated(state) then
		if not state.renderConn then
			state.renderConn = RunService.PreRender:Connect(function(): ()
				reapply(state)
			end)
		end
	else
		if state.renderConn then
			state.renderConn:Disconnect()
			state.renderConn = nil
		end
		if state.enabled then
			reapply(state)
		end
	end
end

local restore = LPH_NO_VIRTUALIZE(function(state: any): ()
	for instance, original in next, state.originals do
		if instance.Parent then
			if original.kind == "sparkles" then
				instance.SparkleColor = original.Color
			elseif original.kind == "image" then
				instance.ImageColor3 = original.Color
			else
				instance.Color = original.Color
				if original.kind ~= "light" then
					instance.Transparency = original.Transparency
				end
			end
		end
		state.originals[instance] = nil
	end
end)

function ParticleColors.EnableSystem(self: ParticleColors, key: string): ()
	local state = self._states[key]
	if not state or state.enabled then
		return
	end
	state.enabled = true

	if state.config.watch then
		local root = self._opts.watchRoot and self._opts.watchRoot() or nil
		if root then
			for _, descendant in next, root:QueryDescendants("Instance") do
				if matchesWatch(state, descendant) then
					applyDescendant(state, descendant)
				end
			end

			state.janitor:Add(root.DescendantAdded:Connect(LPH_NO_VIRTUALIZE(function(descendant: Instance): ()
				if not state.enabled or not matchesWatch(state, descendant) then
					return
				end
				task.defer(function(): ()
					if state.enabled and descendant.Parent then
						applyDescendant(state, descendant)
					end
				end)
			end)))
		end
	elseif state.config.staticPath or state.config.staticPaths then
		applyStatic(self, state)
	else
		sweepExisting(self, state)

		state.janitor:Add(
			CollectionService:GetInstanceAddedSignal(state.config.tag)
				:Connect(LPH_NO_VIRTUALIZE(function(part: Instance): ()
					task.defer(function(): ()
						if state.enabled then
							applyModel(self, state, modelFromPart(self, state, part))
						end
					end)
				end))
		)
	end

	state.janitor:Add(state.colorEl:OnColorChange(function(): ()
		reapply(state)
	end))
	state.janitor:Add(state.colorEl:OnTransparencyChange(function(): ()
		reapply(state)
	end))

	if state.colorEl._animation ~= nil then
		state.janitor:Add(sub(state.colorEl._animation, function(): ()
			syncAnimation(state)
		end))
	end
	state.janitor:Add(function(): ()
		if state.renderConn then
			state.renderConn:Disconnect()
			state.renderConn = nil
		end
	end)
	syncAnimation(state)
end

function ParticleColors.DisableSystem(self: ParticleColors, key: string): ()
	local state = self._states[key]
	if not state or not state.enabled then
		return
	end
	state.enabled = false

	state.janitor:Cleanup()
	restore(state)
end

function ParticleColors.Destroy(self: ParticleColors): ()
	for key in next, self._states do
		self:DisableSystem(key)
	end
	BaseFeature.Destroy(self)
end

export type ParticleColors =
	typeof(setmetatable(
		{} :: {
			_opts: ParticleColorsOpts,
			_states: any,
		},
		ParticleColors
	))
	& BaseFeature.BaseFeature

return ParticleColors
