local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local React = require("@pkg/React")
local Signal = require("@pkg/Signal")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local PlayerController = require("@feature/player/PlayerController")

local subscribeToBinding = (React :: any).__subscribeToBinding

local EMIT_PER_PART = 30
local DEFAULT_COLOR = Color3.fromRGB(17, 255, 156)
local DEFAULT_LIFETIME = 2

export type DeathParticlesOpts = {
	connect: (onKill: (player: Player, position: Vector3?) -> ()) -> Signal.Connection,
	resolveParts: ((player: any) -> { Vector3 }?)?,
}

local SIZE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.12),
	NumberSequenceKeypoint.new(1, 0.21),
})
local TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(1, 1),
})

local buildEmitter = LPH_NO_VIRTUALIZE(function(color: Color3, lifetime: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://3186494455"
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(lifetime)
	emitter.Size = SIZE
	emitter.Squash = NumberSequence.new(0)
	emitter.Transparency = TRANSPARENCY
	emitter.Speed = NumberRange.new(2, 2)
	emitter.RotSpeed = NumberRange.new(-360, 360)
	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Brightness = 10
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Drag = 5
	emitter.ZOffset = 1
	emitter.LockedToPart = false
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.Rate = 0
	emitter.Enabled = false
	return emitter
end)

local DeathParticles = {}
DeathParticles.__index = DeathParticles

setmetatable(DeathParticles, { __index = BaseFeature })

function DeathParticles.new(link: gameUi.Linker, opts: DeathParticlesOpts): DeathParticles
	local self = BaseFeature.new() :: any
	setmetatable(self, DeathParticles)

	self._enabled = false
	self._color = DEFAULT_COLOR
	self._lifetime = DEFAULT_LIFETIME
	self._resolveParts = opts.resolveParts

	local toggle = link:Toggle("deathParticles", "Death Particles", false):SetTip({
		title = "Death Particles",
		body = "Bursts a particle effect on players you kill.",
	})
	local dpLink = link:OnKey("deathParticles")
	dpLink:Extra(toggle, "opts", "Submenu", "Death Particle Options")
	local optsLink = dpLink:OnKey("opts")
	optsLink:Slider("lifetime", "Lifetime", DEFAULT_LIFETIME, 0.5, 10, 0.1, nil, "s"):SetTip({
		title = "Lifetime",
		body = "How long the particles last before fading.",
	})
	dpLink:Extra(toggle, "color", "Colorpicker", "Color", DEFAULT_COLOR)

	local colorLink = dpLink:Get("color")
	self._color = (colorLink._currentColor :: any):getValue() :: Color3
	self:Track(subscribeToBinding(colorLink._currentColor, function(value: Color3): ()
		self._color = value
	end))

	self._lifetime = optsLink:Peek("lifetime") or DEFAULT_LIFETIME
	self:Track(optsLink:Watch("lifetime", function(value: number): ()
		self._lifetime = value
	end))

	self:Track(toggle:OnChange(function(value: boolean): ()
		self._enabled = value
	end))

	local killConn = opts.connect(function(player: Player, position: Vector3?): ()
		self:_onKill(player, position)
	end)
	self:Track(function(): ()
		killConn:Disconnect()
	end)

	self._enabled = link:Peek("deathParticles") == true

	return self
end

function DeathParticles._onKill(self: DeathParticles, player: Player, position: Vector3?): ()
	if not self._enabled then
		return
	end

	local positions: { Vector3 } = {}
	if typeof(player) == "Instance" and player:IsA("Player") then
		local basePlayer = PlayerController.Get(player)
		if basePlayer then
			for _, part in next, (basePlayer :: any):GetParts() do
				if part:IsA("BasePart") then
					positions[#positions + 1] = part.Position
				end
			end
		end
	elseif self._resolveParts then
		local resolved = self._resolveParts(player)
		if resolved then
			for _, worldPosition in next, resolved do
				positions[#positions + 1] = worldPosition
			end
		end
	end
	if #positions == 0 and typeof(position) == "Vector3" then
		positions[#positions + 1] = position
	end
	if #positions == 0 then
		return
	end

	self:_burst(positions)
end

function DeathParticles._burst(self: DeathParticles, positions: { Vector3 }): ()
	local color = self._color
	local lifetime = self._lifetime

	for _, worldPosition in next, positions do
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = worldPosition
		attachment.Parent = Workspace.Terrain

		local emitter = buildEmitter(color, lifetime)
		emitter.Parent = attachment
		emitter:Emit(EMIT_PER_PART)
		task.delay(lifetime + 0.5, function(): ()
			attachment:Destroy()
		end)
	end
end

function DeathParticles.Destroy(self: DeathParticles): ()
	BaseFeature.Destroy(self)
end

export type DeathParticles =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_color: Color3,
			_lifetime: number,
			_resolveParts: ((player: any) -> { Vector3 }?)?,
		},
		DeathParticles
	))
	& BaseFeature.BaseFeature

return DeathParticles
