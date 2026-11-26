local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ClientState = require("@game/overkill/client/clientState")
local ModuleController = require("@game/overkill/module/ModuleController")
local MeleeAura = require("@game/overkill/feature/misc/MeleeAura")
local meleeShared = require("@game/overkill/feature/misc/meleeShared")
local firePredict = require("@game/overkill/weapon/firePredict")

local peek = Charm.peek

local STEP_NAME = "limerenceAlwaysBackstab"
local RESTORE_NAME = "limerenceAlwaysBackstabRestore"
local STEP_PRIORITY = Enum.RenderPriority.Input.Value - 2
local RESTORE_PRIORITY = Enum.RenderPriority.Input.Value + 1

local PRESS_GRACE = 0.2
local TAIL_MARGIN = 0.05

local AlwaysBackstab = {}
AlwaysBackstab.__index = AlwaysBackstab

setmetatable(AlwaysBackstab, { __index = BaseFeature })

local clientModule: any = nil
local eyeOrigin: any = nil
local cameraHandler: any = nil
local inputHandler: any = nil

local function ensureRefs(): ()
	if not clientModule then
		clientModule = ModuleController.GetModule("clientModule")
	end
	if not eyeOrigin then
		eyeOrigin = ModuleController.GetModule("eyeOrigin")
	end
	if not cameraHandler then
		cameraHandler = ModuleController.GetModule("cameraHandler")
	end
	if not inputHandler then
		inputHandler = ModuleController.GetModule("inputHandler")
	end
end

function AlwaysBackstab.new(link: gameUi.Linker): AlwaysBackstab
	local self = BaseFeature.new() :: any
	setmetatable(self, AlwaysBackstab)

	local toggle = link:Toggle("alwaysBackstab", "Always Backstab", false):SetTip({
		title = "Always Backstab",
		body = "Angles your own melee swings to land behind the target whenever the hit still connects, for the backstab bonus.",
	})

	self._enabled = false
	self._bound = false
	self._spoof = meleeShared.newRotationSpoof()
	self._cmdUnregister = nil :: (() -> ())?
	self._swingDeadline = 0
	self._swingWeak = false
	self._swingStep = nil :: number?
	self._lockYaw = nil :: number?
	self._lockPitch = nil :: number?

	self:Track(toggle:OnChange(function(value: boolean): ()
		if value then
			self:_enable()
		else
			self:_disable()
		end
	end))

	if link:Peek("alwaysBackstab") then
		self:_enable()
	end

	return self
end

function AlwaysBackstab._clearSwing(self: AlwaysBackstab): ()
	self._swingDeadline = 0
	self._swingStep = nil
	self._lockYaw = nil
	self._lockPitch = nil
end

function AlwaysBackstab._step(self: AlwaysBackstab): ()
	self._spoof.pending = false
	if not self._enabled or MeleeAura.IsEngaged() then
		return
	end
	if not peek(ClientState.alive) or peek(ClientState.weaponCategory) ~= "melee" then
		self:_clearSwing()
		return
	end

	ensureRefs()
	local localChickynoid = clientModule and clientModule.localChickynoid
	local simulation = localChickynoid and localChickynoid.simulation
	local state = simulation and simulation.state
	if type(state) ~= "table" or not cameraHandler then
		self:_clearSwing()
		return
	end
	if not inputHandler or type(inputHandler.IsPressed) ~= "function" then
		self:_clearSwing()
		return
	end

	local weaponId = peek(ClientState.weaponId)
	local melee = meleeShared.meleeStats(weaponId)
	if not melee then
		self:_clearSwing()
		return
	end

	local slot = state.equippedSlot or 1
	local est: number = firePredict.estimateServerTime()

	local pendingActive = (state.pendingMeleeSlot or 0) == slot
		and ((state.pendingMeleeHitDeadlineServerTime or 0) :: number) >= est
	local pressWeak = inputHandler:IsPressed("Shoot") == true and melee.weakCombo ~= nil
	local pressStrong = inputHandler:IsPressed("Aim") == true and melee.strongCombo ~= nil

	local isWeak
	local stepIndex
	if pendingActive then
		isWeak = state.pendingMeleeIsM1 ~= false
		stepIndex = state.pendingMeleeComboStep or 1
		self._swingWeak = isWeak
		self._swingStep = stepIndex
		self._swingDeadline = (state.pendingMeleeHitDeadlineServerTime or 0) + TAIL_MARGIN
	elseif pressWeak or pressStrong then
		isWeak = pressWeak
		self._swingWeak = isWeak
		self._swingStep = nil
		self._swingDeadline = math.max(self._swingDeadline, est + PRESS_GRACE)
	elseif (self._swingDeadline :: number) > 0 and est <= self._swingDeadline then
		isWeak = self._swingWeak
		stepIndex = self._swingStep
	else
		self:_clearSwing()
		return
	end

	local combo = isWeak and melee.weakCombo or melee.strongCombo
	if type(combo) ~= "table" or #combo == 0 then
		self:_clearSwing()
		return
	end
	if not stepIndex then
		stepIndex = (state["slot" .. slot .. "_comboIndex"] or 0) % #combo + 1
	end
	local step = combo[stepIndex] or combo[1]
	local size = step and step.hitboxSize
	if not size then
		return
	end
	local offset = step.hitboxOffset or CFrame.identity
	local reach = offset.Position.Magnitude + math.max(size.X, size.Y, size.Z) * 0.5
	if reach <= 0 then
		return
	end

	local eye = eyeOrigin.getAuthoritative(state)
	local part, owner = meleeShared.pickTarget(eye, reach + meleeShared.RANGE_MARGIN, false)
	if not part then
		return
	end

	local parts = peek(owner.parts)
	local hrp = parts["HumanoidRootPart"]
	if not hrp or not hrp:IsA("BasePart") then
		return
	end
	local facing = hrp.CFrame.LookVector

	local targetPos = part.CFrame.Position
	local dir = targetPos - eye
	if dir.Magnitude < 1e-4 then
		return
	end

	local pitch
	local yaw
	if
		self._lockYaw ~= nil
		and meleeShared.yawStillHits(eye, self._lockPitch :: number, self._lockYaw, targetPos, facing, size, offset)
	then
		pitch = self._lockPitch
		yaw = self._lockYaw
	else
		local basePitch = meleeShared.dirToAngles(dir.Unit)
		pitch, yaw = meleeShared.solveBackstab(eye, targetPos, facing, size, offset, basePitch)
	end
	if pitch == nil then
		return
	end

	self._lockPitch = pitch
	self._lockYaw = yaw
	self._spoof:apply(cameraHandler, pitch, yaw :: number)
end

function AlwaysBackstab._restoreRotation(self: AlwaysBackstab): ()
	self._spoof:restore(cameraHandler)
end

function AlwaysBackstab._enable(self: AlwaysBackstab): ()
	if self._enabled then
		return
	end
	self._enabled = true

	if not self._cmdUnregister then
		self._cmdUnregister = meleeShared.registerYawCorrection(self._spoof)
	end

	if not self._bound then
		self._bound = true
		RunService:BindToRenderStep(
			STEP_NAME,
			STEP_PRIORITY,
			LPH_NO_VIRTUALIZE(function(): ()
				self:_step()
			end)
		)
		RunService:BindToRenderStep(
			RESTORE_NAME,
			RESTORE_PRIORITY,
			LPH_NO_VIRTUALIZE(function(): ()
				self:_restoreRotation()
			end)
		)
	end
end

function AlwaysBackstab._disable(self: AlwaysBackstab): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._bound then
		self._bound = false
		RunService:UnbindFromRenderStep(STEP_NAME)
		RunService:UnbindFromRenderStep(RESTORE_NAME)
		self:_restoreRotation()
	end
	local unregister = self._cmdUnregister
	if unregister then
		unregister()
		self._cmdUnregister = nil
	end
	self._spoof.pending = false
	self:_clearSwing()
end

function AlwaysBackstab.Destroy(self: AlwaysBackstab): ()
	self:_disable()
	BaseFeature.Destroy(self)
end

export type AlwaysBackstab =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_bound: boolean,
			_spoof: meleeShared.RotationSpoof,
			_cmdUnregister: (() -> ())?,
			_swingDeadline: number,
			_swingWeak: boolean,
			_swingStep: number?,
			_lockYaw: number?,
			_lockPitch: number?,
			_clearSwing: (AlwaysBackstab) -> (),
			_step: (AlwaysBackstab) -> (),
			_restoreRotation: (AlwaysBackstab) -> (),
			_enable: (AlwaysBackstab) -> (),
			_disable: (AlwaysBackstab) -> (),
		},
		AlwaysBackstab
	))
	& BaseFeature.BaseFeature

return AlwaysBackstab
