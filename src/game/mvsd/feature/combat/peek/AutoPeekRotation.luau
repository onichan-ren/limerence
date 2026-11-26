local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local clientState = require("@game/mvsd/client/clientState")
local mouseLock = require("@game/universal/client/mouseLock")

local peek = Charm.peek

local MODES = { "Legit", "Rage" }
local SIDES = { "Automatic", "Left", "Right" }
local MODE_RAGE = "Rage"
local SIDE_LEFT = "Left"
local SIDE_RIGHT = "Right"
local CHARACTER_GROUP = "Character"

local TWO_PI = math.pi * 2
local MAX_DT = 0.05
local SOLVE_INTERVAL = 0.05
local RADIAL_RAYS = 16
local COVER_DISTANCE = 14
local SCAN_WIDTH = 5
local SWITCH_DELAY = 0.35
local MAX_TURN_SPEED = 720
local CAMERA_BONUS = 0.35
local USER_TURN = math.rad(25)
local SNAP_ANGLE = math.rad(2.5)
local RELEASE_ANGLE = math.rad(12)
local LOCK_INTERVAL = 0.12
local RESTORE_MISS = math.rad(3)
local RESTORE_DELAY = 0.07
local RESTORE_DELAY_SPAN = 0.11
local TURN_DELAY = 0.05
local TURN_DELAY_SPAN = 0.11
local RAMP_TIME = 0.13
local OVERSHOOT_MAX = math.rad(3.5)
local NOISE_STEP = 0.22
local NOISE_MIN = 0.78
local NOISE_MAX = 1.22
local VIEW_NOISE = 1.2
local DRIFT_PULL = 0.22
local SIDE_MARGIN = 0.12
local NORMAL_BIAS = 0.3
local ANGLE_EPSILON = math.rad(2)
local SNAP_RATE = 160
local SOFT_RATE = 5

local DEFAULT_MODE = MODES[1]
local DEFAULT_SIDE = SIDES[1]
local DEFAULT_SMOOTHNESS = 35

local DEFAULT_RAD_PER_PIXEL = 0.005
local MIN_RAD_PER_PIXEL = 0.0005
local MAX_RAD_PER_PIXEL = 0.05
local GAIN_MIN_PIXELS = 2
local GAIN_MIN_RATIO = 0.05
local GAIN_MAX_RATIO = 20

local DIRECTIONS = table.create(RADIAL_RAYS)
for i = 1, RADIAL_RAYS do
	local angle = (i - 1) * TWO_PI / RADIAL_RAYS
	DIRECTIONS[i] = Vector3.new(math.sin(angle), 0, math.cos(angle))
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local filterCharacter: Model? = nil
local filter: { Instance } = {}

local AutoPeekRotation = {}
AutoPeekRotation.__index = AutoPeekRotation

setmetatable(AutoPeekRotation, { __index = BaseFeature })

local wrapAngle = LPH_NO_VIRTUALIZE(function(angle: number): number
	return (angle + math.pi) % TWO_PI - math.pi
end)

local cameraYaw = LPH_NO_VIRTUALIZE(function(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 0
	end
	local look = camera.CFrame.LookVector
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

local canRun = LPH_NO_VIRTUALIZE(function(): boolean
	if not peek(clientState.alive) then
		return false
	end
	if UserInputService:GetFocusedTextBox() then
		return false
	end
	local humanoid = peek(clientState.humanoid)
	if not humanoid then
		return false
	end
	return not humanoid.PlatformStand and not humanoid.Sit
end)

local reach = LPH_NO_VIRTUALIZE(function(origin: Vector3, direction: Vector3): number
	local hit = Workspace:Raycast(origin, direction * COVER_DISTANCE, params)
	if not hit or hit.Instance.CollisionGroup == CHARACTER_GROUP then
		return COVER_DISTANCE
	end
	return hit.Distance
end)

local sideScore = LPH_NO_VIRTUALIZE(
	function(base: Vector3, tangent: Vector3, aim: Vector3, sign: number, fresh: boolean): number
		local direction = tangent * sign
		local hit = Workspace:Raycast(base, direction * SCAN_WIDTH, params)

		local clearance = SCAN_WIDTH
		if hit and hit.Instance.CollisionGroup ~= CHARACTER_GROUP then
			clearance = hit.Distance
		end

		local probe = base + direction * clearance
		local exposure = reach(probe, aim)

		local score = clearance / SCAN_WIDTH * 0.5 + exposure / COVER_DISTANCE * 0.5
		if fresh and direction:Dot(aim) > 0 then
			score += CAMERA_BONUS
		end

		return score
	end
)

local solve = LPH_NO_VIRTUALIZE(function(self: any, head: BasePart, now: number): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		self._targetYaw = nil
		return
	end

	local look = camera.CFrame.LookVector
	local aim = Vector3.new(look.X, 0, look.Z)
	if aim.Magnitude < 1e-3 then
		self._targetYaw = nil
		return
	end
	aim = aim.Unit

	local fresh = self._sideSign == 0
	local scanAim = self._scanAim
	if fresh or not scanAim then
		scanAim = aim
		self._scanAim = aim
	end

	syncFilter()

	local base = head.Position
	local nearest = math.huge
	local normal: Vector3? = nil

	for i = 1, RADIAL_RAYS do
		local direction = DIRECTIONS[i]
		local hit = Workspace:Raycast(base, direction * COVER_DISTANCE, params)
		if not hit or hit.Instance.CollisionGroup == CHARACTER_GROUP then
			continue
		end

		if hit.Distance >= nearest then
			continue
		end

		local flat = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
		if flat.Magnitude < 1e-3 then
			continue
		end
		nearest = hit.Distance
		normal = flat.Unit
	end

	local wall = normal
	if not wall then
		self._targetYaw = nil
		self._sideSign = 0
		self._scanAim = nil
		self._committedYaw = nil
		return
	end

	local tangent = Vector3.new(-wall.Z, 0, wall.X)

	local sign = 0
	local side = self._side
	if side == SIDE_LEFT then
		sign = -1
	elseif side == SIDE_RIGHT then
		sign = 1
	else
		local leftScore = sideScore(base, tangent, scanAim, -1, fresh)
		local rightScore = sideScore(base, tangent, scanAim, 1, fresh)

		local best = 1
		local bestScore = rightScore
		local otherScore = leftScore
		if leftScore > rightScore then
			best = -1
			bestScore = leftScore
			otherScore = rightScore
		end

		sign = self._sideSign
		if sign == 0 then
			sign = best
		elseif best ~= sign and bestScore >= otherScore + SIDE_MARGIN and now - self._lastSwitch >= SWITCH_DELAY then
			sign = best
		end
	end

	local rear = tangent * sign + wall * NORMAL_BIAS
	local flat = Vector3.new(rear.X, 0, rear.Z)
	if flat.Magnitude < 1e-3 then
		self._targetYaw = nil
		return
	end
	flat = flat.Unit

	local yaw = wrapAngle(math.atan2(flat.X, flat.Z))

	local previous = self._targetYaw
	if previous and math.abs(wrapAngle(yaw - previous)) < ANGLE_EPSILON then
		yaw = previous
	end

	if sign ~= self._sideSign then
		self._sideSign = sign
		self._lastSwitch = now
	end

	self._targetYaw = yaw
end)

local steerRage = LPH_NO_VIRTUALIZE(function(self: any, hrp: BasePart, dt: number, targetYaw: number): ()
	local yaw = targetYaw

	if self._smoothness > 0 then
		local step = math.min(dt, MAX_DT)
		local rate = SNAP_RATE + (SOFT_RATE - SNAP_RATE) * (self._smoothness * 0.01)
		local delta = wrapAngle(targetYaw - self._yaw) * (1 - math.exp(-step * rate))
		local limit = math.rad(MAX_TURN_SPEED) * step
		yaw = wrapAngle(self._yaw + math.clamp(delta, -limit, limit))
	end

	self._yaw = yaw
	hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
end)

local moveView = LPH_NO_VIRTUALIZE(
	function(self: any, dt: number, now: number, yaw: number, goalYaw: number, human: boolean): ()
		local step = math.min(dt, MAX_DT)
		local applied = self._lastPixels

		if math.abs(applied) >= GAIN_MIN_PIXELS then
			local ratio = wrapAngle(yaw - self._lastCameraYaw) / (-applied * self._gain)
			if ratio > GAIN_MIN_RATIO and ratio < GAIN_MAX_RATIO then
				self._gain = math.clamp(self._gain * (0.7 + 0.3 * ratio), MIN_RAD_PER_PIXEL, MAX_RAD_PER_PIXEL)
			end
		end

		local rate = SNAP_RATE + (SOFT_RATE - SNAP_RATE) * (self._smoothness * 0.01)
		local delta = wrapAngle(goalYaw - yaw) * (1 - math.exp(-step * rate))
		local drift = 0

		if human then
			local scale = math.clamp(self._speedScale + (math.random() - 0.5) * NOISE_STEP, NOISE_MIN, NOISE_MAX)
			self._speedScale = scale

			local ramp = math.clamp((now - self._turnStart) / RAMP_TIME, 0, 1)
			delta *= scale * ramp * ramp * (3 - 2 * ramp)

			drift = (math.random() - 0.5) * VIEW_NOISE - self._pitchDrift * DRIFT_PULL
			self._pitchDrift += drift
		end

		local limit = math.rad(MAX_TURN_SPEED) * step
		delta = math.clamp(delta, -limit, limit)

		local pixels = -delta / self._gain
		self._lastPixels = pixels
		self._lastCameraYaw = yaw
		self._appliedYaw += delta
		mousemoverel(pixels, drift)
	end
)

local beginTurn = LPH_NO_VIRTUALIZE(function(self: any, now: number, delta: number): ()
	self._turnAt = now + TURN_DELAY + math.random() * TURN_DELAY_SPAN
	self._turnStart = self._turnAt
	self._speedScale = 1
	self._pitchDrift = 0

	local overshoot = math.random() * OVERSHOOT_MAX
	if delta < 0 then
		overshoot = -overshoot
	end
	self._overshoot = overshoot
end)

local beginRestore = LPH_NO_VIRTUALIZE(function(self: any, now: number): boolean
	local origin = self._viewYaw
	if not self._restoreView or not origin then
		return false
	end

	self._restoring = true
	self._restoreYaw = wrapAngle(origin + (math.random() - 0.5) * RESTORE_MISS)
	self._restoreAt = now + RESTORE_DELAY + math.random() * RESTORE_DELAY_SPAN
	self._turnStart = self._restoreAt
	self._speedScale = 1
	return true
end)

local restoreView = LPH_NO_VIRTUALIZE(function(self: any, dt: number, yaw: number, now: number): ()
	if mouseLock.IsLocked() then
		self:_setLock(false)
		return
	end

	if now < self._restoreAt then
		self._lastPixels = 0
		return
	end

	local goalYaw = self._restoreYaw
	if not goalYaw or math.abs(wrapAngle(goalYaw - yaw)) <= SNAP_ANGLE then
		self._restoring = false
		self._restoreYaw = nil
		self._viewYaw = nil
		self._lastPixels = 0
		return
	end

	moveView(self, dt, now, yaw, goalYaw, true)
end)

local steerLegit = LPH_NO_VIRTUALIZE(function(self: any, dt: number, targetYaw: number?): ()
	local yaw = cameraYaw()
	local now = os.clock()

	if self._requireShiftLock then
		if not targetYaw or not mouseLock.IsLocked() then
			self._lastPixels = 0
			return
		end
		moveView(self, dt, now, yaw, targetYaw, true)
		return
	end

	if self._restoring then
		restoreView(self, dt, yaw, now)
		return
	end

	if not targetYaw then
		self._lastPixels = 0
		return
	end

	local committed = self._committedYaw
	if committed and math.abs(wrapAngle(targetYaw - committed)) < RELEASE_ANGLE then
		self._lastPixels = 0
		return
	end

	local offset = wrapAngle(targetYaw - yaw)
	if math.abs(offset) <= SNAP_ANGLE then
		self._lastPixels = 0
		self._committedYaw = targetYaw
		self._overshoot = 0
		self:_setLock(true)

		if not beginRestore(self, now) then
			self._viewYaw = nil
		end
		return
	end

	if not self._viewYaw then
		self._viewYaw = yaw
		beginTurn(self, now, offset)
	end

	self:_setLock(false)

	if now < self._turnAt then
		self._lastPixels = 0
		return
	end

	local goalYaw = targetYaw
	local overshoot = self._overshoot
	if overshoot ~= 0 then
		if math.abs(offset) > math.abs(overshoot) * 2 then
			goalYaw = wrapAngle(targetYaw + overshoot)
		else
			self._overshoot = 0
		end
	end

	moveView(self, dt, now, yaw, goalYaw, true)
end)

local tick = LPH_NO_VIRTUALIZE(function(self: any, dt: number): ()
	if not canRun() then
		self:_engage(false)
		return
	end

	local legit = self._mode ~= MODE_RAGE
	if (legit or self._onlyAiming) and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		if legit and self._engaged then
			local now = os.clock()
			if self._restoring or beginRestore(self, now) then
				steerLegit(self, dt, nil)
				if self._restoring then
					return
				end
			end
		end
		self:_engage(false)
		return
	end

	local head = peek(clientState.parts).Head :: BasePart?
	local hrp = peek(clientState.hrp)
	if not head or not hrp then
		self:_engage(false)
		return
	end

	self:_engage(true)

	local viewYaw = cameraYaw()
	local drift = wrapAngle(wrapAngle(viewYaw - self._trackedYaw) - self._appliedYaw)
	self._trackedYaw = viewYaw
	self._appliedYaw = 0
	self._userYaw = wrapAngle(self._userYaw + drift)
	if math.abs(self._userYaw) >= USER_TURN then
		self._userYaw = 0
		self._sideSign = 0
		self._scanAim = nil
		self._committedYaw = nil
	end

	local now = os.clock()
	if now - self._solvedAt >= SOLVE_INTERVAL then
		self._solvedAt = now
		solve(self, head, now)
	end

	local targetYaw = self._targetYaw

	if self._mode == MODE_RAGE then
		if targetYaw then
			steerRage(self, hrp, dt, targetYaw)
		end
		return
	end

	steerLegit(self, dt, targetYaw)
end)

function AutoPeekRotation.new(link: gameUi.Linker): AutoPeekRotation
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoPeekRotation)

	link:Toggle("autoPeekRotation", "Auto Peek Rotation", false):SetTip({
		title = "Auto Peek Rotation",
		body = "Turns you around cover so your shots come out past the edge while your body stays covered.",
	})
	local featureLink = link:OnKey("autoPeekRotation")
	featureLink:Submenu("opts", "Auto Peek Rotation")
	local optionsLink = featureLink:OnKey("opts")

	optionsLink:Dropdown("side", "Peek Side", SIDES, DEFAULT_SIDE):SetTip({
		title = "Peek Side",
		body = "Automatic picks the open edge for you, or force a side.",
	})
	optionsLink:Dropdown("mode", "Mode", MODES, DEFAULT_MODE):SetTip({
		title = "Mode",
		body = "Legit steers your view into the angle. Rage turns your body straight to it.",
	})
	optionsLink:Toggle("onlyAiming", "Only While Holding Aim", false):SetTip({
		title = "Only While Holding Aim",
		body = "Only turns you while you hold the aim button. Legit always waits for it.",
	})
	optionsLink:Toggle("requireShiftLock", "Require Shift Lock", false):SetTip({
		title = "Require Shift Lock",
		body = "Waits for shift lock instead of turning it on for you.",
	})
	optionsLink:Toggle("restoreView", "Restore View", false):SetTip({
		title = "Restore View",
		body = "Swings your view back to where you were looking once the turn lands.",
	})
	optionsLink:Slider("smoothness", "Smoothness", DEFAULT_SMOOTHNESS, 0, 100, 1, nil, "%"):SetTip({
		title = "Smoothness",
		body = "How gradually you settle into the angle. Zero turns instantly in Rage.",
	})

	self._mode = DEFAULT_MODE
	self._side = DEFAULT_SIDE
	self._smoothness = DEFAULT_SMOOTHNESS
	self._restoreView = false
	self._onlyAiming = false
	self._requireShiftLock = false

	self._targetYaw = nil :: number?
	self._sideSign = 0
	self._scanAim = nil :: Vector3?
	self._lastSwitch = 0
	self._solvedAt = 0
	self._yaw = 0
	self._trackedYaw = 0
	self._appliedYaw = 0
	self._userYaw = 0
	self._gain = DEFAULT_RAD_PER_PIXEL
	self._lastPixels = 0
	self._lastCameraYaw = 0
	self._engaged = false
	self._lockOwned = false
	self._lockWas = false
	self._lockAt = 0
	self._committedYaw = nil :: number?
	self._viewYaw = nil :: number?
	self._restoreYaw = nil :: number?
	self._restoreAt = 0
	self._restoring = false
	self._turnAt = 0
	self._turnStart = 0
	self._overshoot = 0
	self._speedScale = 1
	self._pitchDrift = 0
	self._heldHumanoid = nil :: Humanoid?
	self._autoRotate = true
	self._activeJanitor = nil :: Janitor.Janitor?

	self:Track(link:Get("autoPeekRotation"):OnChange(function(value: boolean): ()
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("autoPeekRotation.opts.mode", function(value: string): ()
		self:_engage(false)
		self._mode = value
	end))
	self:Track(link:Watch("autoPeekRotation.opts.side", function(value: string): ()
		self._side = value
		self._sideSign = 0
		self:_reset()
	end))
	self:Track(link:Watch("autoPeekRotation.opts.smoothness", function(value: number): ()
		self._smoothness = value
	end))
	self:Track(link:Watch("autoPeekRotation.opts.restoreView", function(value: boolean): ()
		self._restoreView = value
		self._restoring = false
		self._restoreYaw = nil
		self._viewYaw = nil
	end))
	self:Track(link:Watch("autoPeekRotation.opts.onlyAiming", function(value: boolean): ()
		self._onlyAiming = value
	end))
	self:Track(link:Watch("autoPeekRotation.opts.requireShiftLock", function(value: boolean): ()
		self:_engage(false)
		self._requireShiftLock = value
	end))
	self:Track(function(): ()
		self:_setEnabled(false)
	end)

	if link:Peek("autoPeekRotation") then
		self:_setEnabled(true)
	end

	return self
end

function AutoPeekRotation._reset(self: AutoPeekRotation): ()
	self._targetYaw = nil
	self._scanAim = nil
	self._solvedAt = 0
	self._lastPixels = 0
	self._appliedYaw = 0
	self._userYaw = 0
	self._committedYaw = nil
	self._viewYaw = nil
	self._restoreYaw = nil
	self._restoring = false
	self._overshoot = 0
	self._speedScale = 1
	self._pitchDrift = 0
end

function AutoPeekRotation._releaseHumanoid(self: AutoPeekRotation): ()
	local humanoid = self._heldHumanoid
	if not humanoid then
		return
	end
	self._heldHumanoid = nil
	humanoid.AutoRotate = self._autoRotate
end

function AutoPeekRotation._claimHumanoid(self: AutoPeekRotation, humanoid: Humanoid?): ()
	if humanoid == self._heldHumanoid then
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

function AutoPeekRotation._setLock(self: AutoPeekRotation, locked: boolean): ()
	if mouseLock.IsLocked() == locked then
		return
	end

	local now = os.clock()
	if now - self._lockAt < LOCK_INTERVAL then
		return
	end
	self._lockAt = now
	mouseLock.Set(locked)
end

function AutoPeekRotation._restoreLock(self: AutoPeekRotation): ()
	if not self._lockOwned then
		return
	end
	self._lockOwned = false
	self._lockAt = 0
	mouseLock.Set(self._lockWas)
end

function AutoPeekRotation._engage(self: AutoPeekRotation, active: boolean): ()
	if not active then
		if not self._engaged then
			return
		end
		self._engaged = false
		self:_releaseHumanoid()
		self:_restoreLock()
		self:_reset()
		return
	end

	if not self._engaged then
		self._engaged = true
		self._solvedAt = 0
		self._lastPixels = 0
		self._lastCameraYaw = cameraYaw()
		self._trackedYaw = self._lastCameraYaw
		self._lockWas = mouseLock.IsLocked()
		self._lockOwned = not self._requireShiftLock
		self._lockAt = 0
		local hrp = peek(clientState.hrp)
		self._yaw = hrp and bodyYaw(hrp) or 0
	end

	if self._mode == MODE_RAGE then
		self:_setLock(false)
		self:_claimHumanoid(peek(clientState.humanoid))
		return
	end

	self:_releaseHumanoid()
end

function AutoPeekRotation._setEnabled(self: AutoPeekRotation, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end

		local janitor = Janitor.new()
		self._activeJanitor = janitor
		self:_reset()
		self._sideSign = 0

		janitor:Add(
			RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
				tick(self, dt)
			end)),
			"Disconnect"
		)
		return
	end

	local janitor = self._activeJanitor
	if not janitor then
		return
	end
	self._activeJanitor = nil
	janitor:Destroy()
	self:_engage(false)
end

function AutoPeekRotation.Destroy(self: AutoPeekRotation): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type AutoPeekRotation =
	typeof(setmetatable(
		{} :: {
			_mode: string,
			_side: string,
			_smoothness: number,
			_restoreView: boolean,
			_onlyAiming: boolean,
			_requireShiftLock: boolean,
			_targetYaw: number?,
			_sideSign: number,
			_scanAim: Vector3?,
			_lastSwitch: number,
			_solvedAt: number,
			_yaw: number,
			_trackedYaw: number,
			_appliedYaw: number,
			_userYaw: number,
			_gain: number,
			_lastPixels: number,
			_lastCameraYaw: number,
			_engaged: boolean,
			_lockOwned: boolean,
			_lockWas: boolean,
			_lockAt: number,
			_committedYaw: number?,
			_viewYaw: number?,
			_restoreYaw: number?,
			_restoreAt: number,
			_restoring: boolean,
			_turnAt: number,
			_turnStart: number,
			_overshoot: number,
			_speedScale: number,
			_pitchDrift: number,
			_heldHumanoid: Humanoid?,
			_autoRotate: boolean,
			_activeJanitor: Janitor.Janitor?,
		},
		AutoPeekRotation
	))
	& BaseFeature.BaseFeature

return AutoPeekRotation
