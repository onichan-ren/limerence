local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local clientState = require("@game/mvsd/client/clientState")
local PlayerController = require("@feature/player/PlayerController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local Camera = Workspace.CurrentCamera

local peek = Charm.peek
local sub = Charm.subscribe

local MODES = { "Legit", "Rage" }
local MODE_RAGE = "Rage"

local TWO_PI = math.pi * 2
local MAX_DT = 0.05
local DEFAULT_MODE = MODES[1]
local DEFAULT_MAX_ANGLE = 180
local DEFAULT_SMOOTHNESS = 25
local SNAP_RATE = 160
local SOFT_RATE = 5
local SOLVE_INTERVAL = 0.05
local ANGLE_STEP = 10
local DEFAULT_RAD_PER_PIXEL = 0.005
local MIN_RAD_PER_PIXEL = 0.0005
local MAX_RAD_PER_PIXEL = 0.05
local GAIN_MIN_PIXELS = 2
local GAIN_MIN_RATIO = 0.05
local GAIN_MAX_RATIO = 20

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local filterCharacter: Model? = nil
local filter: { Instance } = {}

local RotationPeek = {}
RotationPeek.__index = RotationPeek

setmetatable(RotationPeek, { __index = BaseFeature })

local wrapAngle = LPH_NO_VIRTUALIZE(function(angle: number): number
	return (angle + math.pi) % TWO_PI - math.pi
end)

local cameraYaw = LPH_NO_VIRTUALIZE(function(): number
	local look = Camera.CFrame.LookVector
	return math.atan2(-look.X, -look.Z)
end)

local bodyYaw = LPH_NO_VIRTUALIZE(function(hrp: BasePart): number
	local look = hrp.CFrame.LookVector
	return math.atan2(-look.X, -look.Z)
end)

local syncFilter = LPH_NO_VIRTUALIZE(function(): ()
	local character = peek(clientState.character)
	if character == filterCharacter then
		return
	end
	filterCharacter = character
	table.clear(filter)
	if character then
		filter[1] = character
	end
	params.FilterDescendantsInstances = filter
end)

local findTarget = LPH_NO_VIRTUALIZE(function(cameraPosition: Vector3, cameraLook: Vector3): BasePart?
	local localMatch = peek(clientState.matchId)
	if localMatch == nil then
		return nil
	end

	local localTeam = peek(clientState.team)
	local best: BasePart? = nil
	local bestDot = -1

	for _, data in next, PlayerController.GetAll() do
		local target = data :: any
		if not target:IsAlive() then
			continue
		end
		if peek(target.matchId) ~= localMatch or target:GetTeam() == localTeam then
			continue
		end

		local part = target:GetParts().Head or peek(target.hrp)
		if not part or not part:IsA("BasePart") then
			continue
		end

		local offset = part.Position - cameraPosition
		local distance = offset.Magnitude
		if distance < 0.001 then
			continue
		end

		local dot = offset:Dot(cameraLook) / distance
		if dot > bestDot then
			bestDot = dot
			best = part
		end
	end

	return best
end)

local solveYaw = LPH_NO_VIRTUALIZE(
	function(pivot: Vector3, radius: number, targetPart: BasePart, fromYaw: number, maxAngle: number): number?
		local targetPosition = targetPart.Position
		local targetModel = targetPart.Parent

		for offset = 0, maxAngle, ANGLE_STEP do
			local sides = 2
			if offset == 0 then
				sides = 1
			end

			for side = 1, sides do
				local delta = offset
				if side == 2 then
					delta = -offset
				end

				local yaw = fromYaw + math.rad(delta)
				local origin = pivot + Vector3.new(math.sin(yaw), 0, math.cos(yaw)) * radius
				local hit = Workspace:Raycast(origin, targetPosition - origin, params)
				if not hit or (targetModel and hit.Instance:IsDescendantOf(targetModel)) then
					return yaw
				end
			end
		end

		return nil
	end
)

function RotationPeek.new(link: gameUi.Linker): RotationPeek
	local self = BaseFeature.new() :: any
	setmetatable(self, RotationPeek)

	link:Toggle("rotationPeek", "Rotation Peek", false):SetTip({
		title = "Rotation Peek",
		body = "Turns you back first around cover, picking the side that opens up a shot.",
	})
	local peekLink = link:OnKey("rotationPeek")
	peekLink:Submenu("opts", "Rotation Peek")
	local optionsLink = peekLink:OnKey("opts")

	optionsLink:Dropdown("mode", "Mode", MODES, DEFAULT_MODE):SetTip({
		title = "Mode",
		body = "Legit turns your view so your body follows. Rage turns your body only and leaves your view alone.",
	})
	optionsLink:Slider("maxAngle", "Max Angle", DEFAULT_MAX_ANGLE, 20, 180, 5, nil, " deg"):SetTip({
		title = "Max Angle",
		body = "Furthest it will turn you from where you already face.",
	})
	optionsLink:Slider("smoothness", "Smoothness", DEFAULT_SMOOTHNESS, 0, 100, 1, nil, "%"):SetTip({
		title = "Smoothness",
		body = "How gradually you turn into the angle.",
	})

	self._mode = DEFAULT_MODE
	self._maxAngle = DEFAULT_MAX_ANGLE
	self._smoothness = DEFAULT_SMOOTHNESS
	self._yaw = 0
	self._targetYaw = nil :: number?
	self._solvedAt = 0
	self._gain = DEFAULT_RAD_PER_PIXEL
	self._lastPixels = 0
	self._lastCameraYaw = 0
	self._heldHumanoid = nil :: Humanoid?
	self._autoRotate = true
	self._activeJanitor = nil :: Janitor.Janitor?

	self:Track(link:Get("rotationPeek"):OnChange(function(value: boolean): ()
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("rotationPeek.opts.mode", function(value: string): ()
		self._mode = value
		self._targetYaw = nil
		self._solvedAt = 0
		self._lastPixels = 0
		self:_syncControl()
	end))
	self:Track(link:Watch("rotationPeek.opts.maxAngle", function(value: number): ()
		self._maxAngle = value
	end))
	self:Track(link:Watch("rotationPeek.opts.smoothness", function(value: number): ()
		self._smoothness = value
	end))

	self:Track(function(): ()
		self:_setEnabled(false)
	end)

	if link:Peek("rotationPeek") then
		self:_setEnabled(true)
	end

	return self
end

function RotationPeek._releaseHumanoid(self: RotationPeek): ()
	local humanoid = self._heldHumanoid
	if not humanoid then
		return
	end
	self._heldHumanoid = nil
	humanoid.AutoRotate = self._autoRotate
end

function RotationPeek._claimHumanoid(self: RotationPeek, humanoid: Humanoid?): ()
	local held: Humanoid? = self._heldHumanoid
	if humanoid == held then
		return
	end
	self:_releaseHumanoid()
	if not humanoid then
		return
	end
	self._heldHumanoid = humanoid
	self._autoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false
end

function RotationPeek._syncControl(self: RotationPeek): ()
	if self._activeJanitor and self._mode == MODE_RAGE then
		self:_claimHumanoid(peek(clientState.humanoid))
	else
		self:_releaseHumanoid()
	end
end

local tick = LPH_NO_VIRTUALIZE(function(self: any, dt: number): ()
	if not peek(clientState.alive) then
		self._targetYaw = nil
		self._lastPixels = 0
		return
	end

	local hrp = peek(clientState.hrp)
	local head = peek(clientState.parts).Head :: BasePart?
	if not hrp or not head then
		return
	end

	local facing = bodyYaw(hrp)
	local now = os.clock()

	if now - self._solvedAt >= SOLVE_INTERVAL then
		self._solvedAt = now
		syncFilter()

		local cameraCFrame = Camera.CFrame
		local target = findTarget(cameraCFrame.Position, cameraCFrame.LookVector)
		if target then
			local size = head.Size
			local pivot = head.Position + Vector3.new(0, size.Y * 0.5, 0)
			self._targetYaw = solveYaw(pivot, size.Z * 0.5, target, facing, self._maxAngle)
		else
			self._targetYaw = nil
		end
	end

	local targetYaw = self._targetYaw
	if not targetYaw then
		return
	end

	local step = math.min(dt, MAX_DT)
	local rate = SNAP_RATE + (SOFT_RATE - SNAP_RATE) * (self._smoothness * 0.01)
	local alpha = 1 - math.exp(-step * rate)

	if self._mode == MODE_RAGE then
		self._yaw = wrapAngle(self._yaw + wrapAngle(targetYaw - self._yaw) * alpha)
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, self._yaw, 0)
		return
	end

	local yaw = cameraYaw()
	local applied = self._lastPixels
	if math.abs(applied) >= GAIN_MIN_PIXELS then
		local ratio = wrapAngle(yaw - self._lastCameraYaw) / (-applied * self._gain)
		if ratio > GAIN_MIN_RATIO and ratio < GAIN_MAX_RATIO then
			self._gain = math.clamp(self._gain * (0.7 + 0.3 * ratio), MIN_RAD_PER_PIXEL, MAX_RAD_PER_PIXEL)
		end
	end

	local pixels = -wrapAngle(targetYaw - facing) * alpha / self._gain
	self._lastPixels = pixels
	self._lastCameraYaw = yaw
	mousemoverel(pixels, 0)
end)

function RotationPeek._setEnabled(self: RotationPeek, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end
		local janitor = Janitor.new()
		self._activeJanitor = janitor

		local hrp = peek(clientState.hrp)
		self._yaw = hrp and bodyYaw(hrp) or 0
		self._targetYaw = nil
		self._solvedAt = 0
		self._lastPixels = 0
		self._lastCameraYaw = cameraYaw()

		janitor:Add(sub(clientState.humanoid, function(): ()
			self:_syncControl()
		end))
		janitor:Add(
			RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
				tick(self, dt)
			end)),
			"Disconnect"
		)

		self:_syncControl()
	else
		local janitor = self._activeJanitor
		if not janitor then
			return
		end
		self._activeJanitor = nil
		janitor:Destroy()
		self:_releaseHumanoid()
	end
end

function RotationPeek.Destroy(self: RotationPeek): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type RotationPeek =
	typeof(setmetatable(
		{} :: {
			_mode: string,
			_maxAngle: number,
			_smoothness: number,
			_yaw: number,
			_targetYaw: number?,
			_solvedAt: number,
			_gain: number,
			_lastPixels: number,
			_lastCameraYaw: number,
			_heldHumanoid: Humanoid?,
			_autoRotate: boolean,
			_activeJanitor: Janitor.Janitor?,
		},
		RotationPeek
	))
	& BaseFeature.BaseFeature

return RotationPeek
