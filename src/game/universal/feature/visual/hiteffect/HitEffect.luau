local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local HttpService = cloneref(game:GetService("HttpService")) :: HttpService

local React = require("@pkg/React")
local Signal = require("@pkg/Signal")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")

local subscribeToBinding = (React :: any).__subscribeToBinding

local DEFAULT_COLOR = Color3.fromRGB(200, 186, 160)

export type HitEffectOpts = {
	connect: (play: (kind: string, position: Vector3) -> ()) -> Signal.Connection,
}

local function readManifest(path: string): any
	if not isfile(path) then
		return nil
	end
	local raw = readfile(path)
	if type(raw) ~= "string" then
		return nil
	end
	local decoded: any = HttpService:JSONDecode(raw)
	if type(decoded) ~= "table" then
		return nil
	end
	return decoded
end

local function resolveImage(value: any): string?
	if type(value) ~= "string" or value == "" then
		return nil
	end
	if string.find(value, "^rbxasset") or string.find(value, "^http") then
		return value
	end
	if string.find(value, "^%d+$") then
		return `rbxassetid://{value}`
	end
	if isfile(value) and getcustomasset then
		local asset = getcustomasset(value)
		if type(asset) == "string" then
			return asset
		end
	end
	return value
end

local function buildNumberSequence(keypoints: any, fallback: number): NumberSequence
	if type(keypoints) ~= "table" or #keypoints == 0 then
		return NumberSequence.new(fallback)
	end
	local kps: { NumberSequenceKeypoint } = {}
	for _, kp in next, keypoints do
		if type(kp) == "table" then
			local t = tonumber(kp[1]) or 0
			local v = tonumber(kp[2]) or 0
			table.insert(kps, NumberSequenceKeypoint.new(math.clamp(t, 0, 1), v))
		end
	end
	if #kps < 2 then
		return NumberSequence.new(fallback)
	end
	return NumberSequence.new(kps)
end

local function buildColorSequence(keypoints: any): ColorSequence?
	if type(keypoints) ~= "table" or #keypoints < 2 then
		return nil
	end
	local kps: { ColorSequenceKeypoint } = {}
	for _, kp in next, keypoints do
		if type(kp) == "table" then
			local t = tonumber(kp[1]) or 0
			local r = tonumber(kp[2]) or 0
			local g = tonumber(kp[3]) or 0
			local b = tonumber(kp[4]) or 0
			table.insert(kps, ColorSequenceKeypoint.new(math.clamp(t, 0, 1), Color3.new(r, g, b)))
		end
	end
	if #kps < 2 then
		return nil
	end
	return ColorSequence.new(kps)
end

local function buildNumberRange(range: any, fallback: number): NumberRange
	if type(range) ~= "table" then
		return NumberRange.new(fallback)
	end
	local a = tonumber(range[1]) or fallback
	local b = tonumber(range[2]) or a
	return NumberRange.new(a, b)
end

local function enumOrNil(enumType: any, name: any): any?
	if type(name) ~= "string" then
		return nil
	end
	for _, item in next, enumType:GetEnumItems() do
		if item.Name == name then
			return item
		end
	end
	return nil
end

local applyParticle = LPH_NO_VIRTUALIZE(function(emitter: ParticleEmitter, p: any, color: ColorSequence): ()
	local texture = resolveImage(p.texture)
	if texture then
		emitter.Texture = texture
	end
	emitter.Color = buildColorSequence(p.color) or color
	emitter.Transparency = buildNumberSequence(p.transparency, 0)
	emitter.Size = buildNumberSequence(p.size, 1)
	if p.squash then
		emitter.Squash = buildNumberSequence(p.squash, 0)
	end
	emitter.Lifetime = buildNumberRange(p.lifetime, 1)
	emitter.Speed = buildNumberRange(p.speed, 5)
	emitter.RotSpeed = buildNumberRange(p.rotSpeed, 0)
	emitter.Rotation = buildNumberRange(p.rotation, 0)
	if type(p.spreadAngle) == "table" then
		emitter.SpreadAngle = Vector2.new(tonumber(p.spreadAngle[1]) or 0, tonumber(p.spreadAngle[2]) or 0)
	end
	if type(p.acceleration) == "table" then
		emitter.Acceleration = Vector3.new(
			tonumber(p.acceleration[1]) or 0,
			tonumber(p.acceleration[2]) or 0,
			tonumber(p.acceleration[3]) or 0
		)
	end
	if type(p.brightness) == "number" then
		emitter.Brightness = p.brightness
	end
	if type(p.lightEmission) == "number" then
		emitter.LightEmission = p.lightEmission
	end
	if type(p.lightInfluence) == "number" then
		emitter.LightInfluence = p.lightInfluence
	end
	if type(p.drag) == "number" then
		emitter.Drag = p.drag
	end
	if type(p.zOffset) == "number" then
		emitter.ZOffset = p.zOffset
	end
	if type(p.timeScale) == "number" then
		emitter.TimeScale = p.timeScale
	end
	if type(p.velocityInheritance) == "number" then
		emitter.VelocityInheritance = p.velocityInheritance
	end
	if type(p.lockedToPart) == "boolean" then
		emitter.LockedToPart = p.lockedToPart
	end

	local shape = enumOrNil(Enum.ParticleEmitterShape, p.shape)
	if shape then
		emitter.Shape = shape
	end
	local orientation = enumOrNil(Enum.ParticleOrientation, p.orientation)
	if orientation then
		emitter.Orientation = orientation
	end
	local emissionDirection = enumOrNil(Enum.NormalId, p.emissionDirection)
	if emissionDirection then
		emitter.EmissionDirection = emissionDirection
	end
	local flipbookLayout = enumOrNil(Enum.ParticleFlipbookLayout, p.flipbookLayout)
	if flipbookLayout then
		emitter.FlipbookLayout = flipbookLayout
	end
	local flipbookMode = enumOrNil(Enum.ParticleFlipbookMode, p.flipbookMode)
	if flipbookMode then
		emitter.FlipbookMode = flipbookMode
	end
	if type(p.flipbookFramerate) == "table" then
		emitter.FlipbookFramerate = buildNumberRange(p.flipbookFramerate, 1)
	end
	if type(p.flipbookStartRandom) == "boolean" then
		emitter.FlipbookStartRandom = p.flipbookStartRandom
	end
	if type(p.flipbookBlendFrames) == "boolean" then
		emitter.FlipbookBlendFrames = p.flipbookBlendFrames
	end

	emitter.Rate = 0
	emitter.Enabled = false
end)

local spawnEffect = LPH_NO_VIRTUALIZE(function(position: Vector3, manifest: any, color: ColorSequence): ()
	if not manifest or type(manifest.particles) ~= "table" then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain

	local longest = 0
	for _, p in next, manifest.particles do
		local emitter = Instance.new("ParticleEmitter")
		applyParticle(emitter, p, color)
		emitter.Parent = attachment
		local count = tonumber(p.emitCount) or 30
		emitter:Emit(count)
		local lifeMax = (type(p.lifetime) == "table" and tonumber(p.lifetime[2])) or 1
		if lifeMax > longest then
			longest = lifeMax
		end
	end

	task.delay(longest + 0.5, function()
		attachment:Destroy()
	end)
end)

local HitEffect = {}
HitEffect.__index = HitEffect

setmetatable(HitEffect, { __index = BaseFeature })

function HitEffect.new(link: gameUi.Linker, opts: HitEffectOpts): HitEffect
	local self = BaseFeature.new() :: any
	setmetatable(self, HitEffect)

	self._link = link
	self._enabled = false
	self._color = ColorSequence.new(DEFAULT_COLOR)
	self._connect = opts.connect
	self._connection = nil :: Signal.Connection?
	self._manifestCache = {} :: { [string]: any }

	local toggle = link:Toggle("hitEffect", "Hit Effect", false):SetTip({
		title = "Hit Effect",
		body = "Spawns a particle effect at the hit position on enemies.",
	})

	local pickerConfig = {
		assetType = "particles",
		category = "hitEffect",
		extensions = { "json" },
		assignmentTypes = {
			{
				key = "hit",
				label = "Hit",
				icon = "scope_small",
				tip = "Play on body shots",
			},
			{
				key = "headshot",
				label = "Headshot",
				icon = "skull_small",
				tip = "Play on headshots",
			},
			{
				key = "lethal",
				label = "Lethal",
				icon = "grave_small",
				tip = "Play on kill shots",
			},
		},
		bundle = {
			urlPrefix = "https://raw.githubusercontent.com/onichan-ren/limerence/main/assets/hiteffects/",
			title = "Downloading hit effects",
			icon = "download",
			files = {
				"Particles.json",
				"Sparkles.json",
				"Sparks.json",
				"Music.json",
				"Snow.json",
			},
		},
		previewImage = function(_source: any, _name: string, path: string): string?
			local manifest = readManifest(path)
			if not manifest then
				return nil
			end
			if type(manifest.preview) == "string" then
				return resolveImage(manifest.preview)
			end
			if
				type(manifest.particles) == "table"
				and manifest.particles[1]
				and type(manifest.particles[1].texture) == "string"
			then
				return resolveImage(manifest.particles[1].texture)
			end
			return nil
		end,
		previewBehavior = function(_source: any, _name: string, path: string): ()
			local camera = Workspace.CurrentCamera
			if not camera then
				return
			end
			local manifest = readManifest(path)
			if not manifest then
				return
			end
			local position = camera.CFrame.Position + camera.CFrame.LookVector * 8
			spawnEffect(position, manifest, self._color)
		end,
	}

	local picker = link:Extra(toggle, "hitEffectAsset", "AssetPicker", "Hit Effect", pickerConfig)
	link:Extra(toggle, "hitEffectColor", "Colorpicker", "Color", ColorSequence.new(DEFAULT_COLOR))

	self._picker = picker
	local colorLink = link:Get("hitEffectColor")
	self._color = (colorLink._currentGradient :: any):getValue() :: ColorSequence
	self:Track(subscribeToBinding(colorLink._currentGradient, function(value: ColorSequence): ()
		self._color = value
	end))

	local function setListening(value: boolean): ()
		self._enabled = value
		if self._connection then
			self._connection:Disconnect()
			self._connection = nil
		end
		if value then
			self._connection = self._connect(function(kind: string, position: Vector3): ()
				self:_play(kind, position)
			end)
		end
	end

	self:Track(toggle:OnChange(setListening))

	if toggle:Peek() then
		setListening(true)
	end

	return self
end

function HitEffect._play(self: HitEffect, kind: string, position: Vector3): ()
	if not self._enabled then
		return
	end
	local path = self._picker:GetAssignedPath(kind)
	if not path then
		return
	end
	local cache = self._manifestCache :: { [string]: any }
	local manifest = cache[path]
	if manifest == nil then
		manifest = readManifest(path) or false
		cache[path] = manifest
	end
	if not manifest then
		return
	end
	spawnEffect(position, manifest, self._color)
end

function HitEffect.Destroy(self: HitEffect): ()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	BaseFeature.Destroy(self)
end

export type HitEffect =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_picker: any,
			_enabled: boolean,
			_color: ColorSequence,
			_connect: (play: (kind: string, position: Vector3) -> ()) -> Signal.Connection,
			_connection: Signal.Connection?,
			_manifestCache: { [string]: any },
		},
		HitEffect
	))
	& BaseFeature.BaseFeature

return HitEffect
