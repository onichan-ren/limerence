local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ClientState = require("@game/overkill/client/clientState")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local ModuleController = require("@game/overkill/module/ModuleController")
local meleeShared = require("@game/overkill/feature/misc/meleeShared")

local peek = Charm.peek

local STEP_NAME = "limerenceMeleeAura"
local RESTORE_NAME = "limerenceMeleeAuraRestore"
local STEP_PRIORITY = Enum.RenderPriority.Input.Value - 2
local RESTORE_PRIORITY = Enum.RenderPriority.Input.Value + 1

local TARGETING_OPTIONS: { string } = { "Closest Distance", "Lowest Health" }

local MeleeAura = {}
MeleeAura.__index = MeleeAura

setmetatable(MeleeAura, { __index = BaseFeature })

local engaged = false

local clientModule: any = nil
local eyeOrigin: any = nil
local cameraHandler: any = nil

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
end

function MeleeAura.IsEngaged(): boolean
	return engaged
end

function MeleeAura.new(link: gameUi.Linker): MeleeAura
	local self = BaseFeature.new() :: any
	setmetatable(self, MeleeAura)

	local toggle = link:Toggle("meleeAura", "Melee Aura", false):SetTip({
		title = "Melee Aura",
		body = "Automatically swings your melee at the nearest enemy in range, from any direction.",
	})
	local auraLink = link:OnKey("meleeAura")
	auraLink:Submenu("opts", "Melee Aura")
	local optsLink = auraLink:OnKey("opts")
	optsLink:Dropdown("targeting", "Targeting", TARGETING_OPTIONS, TARGETING_OPTIONS[1]):SetTip({
		title = "Targeting",
		body = "How the enemy in range is chosen.",
	})
	optsLink:Toggle("backstab", "Always Backstab", true):SetTip({
		title = "Always Backstab",
		body = "Angles the swing to land behind the target whenever the hit still connects, for the backstab bonus.",
	})
	optsLink:Toggle("heavy", "Heavy Swings", false):SetTip({
		title = "Heavy Swings",
		body = "Uses the slower secondary swing for far higher backstab damage. Falls back to normal swings on weapons without one.",
	})

	self._enabled = false
	self._bound = false
	self._aimPitch = 0
	self._aimYaw = 0
	self._shooting = false
	self._aiming = false
	self._spoof = meleeShared.newRotationSpoof()
	self._cmdUnregister = nil :: (() -> ())?
	self._targetingEl = optsLink:Get("targeting")
	self._backstabEl = optsLink:Get("backstab")
	self._heavyEl = optsLink:Get("heavy")

	self:Track(toggle:OnChange(function(value: boolean): ()
		if value then
			self:_enable()
		else
			self:_disable()
		end
	end))

	if link:Peek("meleeAura") then
		self:_enable()
	end

	return self
end

function MeleeAura._resolveAim(self: MeleeAura, eye: Vector3, targetPos: Vector3, facing: Vector3?, combo: any): ()
	local dir = targetPos - eye
	if dir.Magnitude < 1e-4 then
		return
	end
	dir = dir.Unit
	local pitchD, yawD = meleeShared.dirToAngles(dir)
	self._aimPitch = pitchD
	self._aimYaw = yawD

	if not self._backstabEl:Peek() or facing == nil or combo == nil then
		return
	end

	local step = combo[1]
	local size = step and step.hitboxSize
	if not size then
		return
	end
	local offset = (step and step.hitboxOffset) or CFrame.identity

	local pitch, yaw = meleeShared.solveBackstab(eye, targetPos, facing :: Vector3, size, offset, pitchD)
	if pitch ~= nil then
		self._aimPitch = pitch
		self._aimYaw = yaw :: number
	end
end

function MeleeAura._step(self: MeleeAura): ()
	self._spoof.pending = false
	if not self._enabled then
		self:_release()
		return
	end
	if not peek(ClientState.alive) or peek(ClientState.weaponCategory) ~= "melee" then
		self:_release()
		return
	end

	ensureRefs()
	local localChickynoid = clientModule and clientModule.localChickynoid
	local simulation = localChickynoid and localChickynoid.simulation
	local state = simulation and simulation.state
	if type(state) ~= "table" or not cameraHandler then
		self:_release()
		return
	end

	local weaponId = peek(ClientState.weaponId)
	local melee = meleeShared.meleeStats(weaponId)
	if not melee or not melee.weakCombo then
		self:_release()
		return
	end

	local heavy = self._heavyEl:Peek() == true and melee.strongCombo ~= nil
	local combo = heavy and melee.strongCombo or melee.weakCombo
	local reach = meleeShared.comboReach(weaponId .. (heavy and "_s" or "_w"), combo)
	if reach <= 0 then
		self:_release()
		return
	end

	local eye = eyeOrigin.getAuthoritative(state)
	local lowestHealth = (self._targetingEl:Peek() or TARGETING_OPTIONS[1]) == "Lowest Health"
	local part, owner = meleeShared.pickTarget(eye, reach + meleeShared.RANGE_MARGIN, lowestHealth)
	if not part then
		self:_release()
		return
	end

	local parts = peek(owner.parts)
	local hrp = parts["HumanoidRootPart"]
	local facing = (hrp and hrp:IsA("BasePart")) and hrp.CFrame.LookVector or nil
	self:_resolveAim(eye, part.CFrame.Position, facing, combo)
	self:_setShooting(not heavy)
	self:_setAiming(heavy)

	self._spoof:apply(cameraHandler, self._aimPitch, self._aimYaw)
end

function MeleeAura._restoreRotation(self: MeleeAura): ()
	self._spoof:restore(cameraHandler)
end

function MeleeAura._setShooting(self: MeleeAura, state: boolean): ()
	if state == self._shooting then
		return
	end
	self._shooting = state
	WeaponController.SetShooting(state)
end

function MeleeAura._setAiming(self: MeleeAura, state: boolean): ()
	if state == self._aiming then
		return
	end
	self._aiming = state
	WeaponController.SetAiming(state)
end

function MeleeAura._release(self: MeleeAura): ()
	self:_setShooting(false)
	self:_setAiming(false)
end

function MeleeAura._enable(self: MeleeAura): ()
	if self._enabled then
		return
	end
	self._enabled = true
	engaged = true

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

function MeleeAura._disable(self: MeleeAura): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	engaged = false

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
	self:_release()
end

function MeleeAura.Destroy(self: MeleeAura): ()
	self:_disable()
	BaseFeature.Destroy(self)
end

export type MeleeAura =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_bound: boolean,
			_aimPitch: number,
			_aimYaw: number,
			_shooting: boolean,
			_aiming: boolean,
			_spoof: meleeShared.RotationSpoof,
			_cmdUnregister: (() -> ())?,
			_targetingEl: any,
			_backstabEl: any,
			_heavyEl: any,
			_resolveAim: (MeleeAura, Vector3, Vector3, Vector3?, any) -> (),
			_step: (MeleeAura) -> (),
			_restoreRotation: (MeleeAura) -> (),
			_setShooting: (MeleeAura, boolean) -> (),
			_setAiming: (MeleeAura, boolean) -> (),
			_release: (MeleeAura) -> (),
			_enable: (MeleeAura) -> (),
			_disable: (MeleeAura) -> (),
		},
		MeleeAura
	))
	& BaseFeature.BaseFeature

return MeleeAura
