local Charm = require("@pkg/Charm")
local ModuleController = require("@game/ar2/module/ModuleController")
local NetworkController = require("@game/ar2/network/NetworkController")
local ClientState = require("@game/ar2/client/clientState")
local ballistics = require("@game/ar2/weapon/ballistics")
local worldRaycast = require("@game/ar2/weapon/worldRaycast")
local originSolver = require("@game/ar2/weapon/originSolver")
local manipScan = require("@game/ar2/weapon/manipScan")
local boxOcclusion = require("@game/universal/feature/combat/ragebot/boxOcclusion")
local hook = require("@share/hook")

local RunService = cloneref(game:GetService("RunService"))
local Workspace = cloneref(game:GetService("Workspace"))

local peek = Charm.peek

local bulletRedirection = {}

local _manipLevelAtom = Charm.atom(nil :: number?)
local _manipBarActive = false
local _manipConnection
local _manipClock = 0
local MANIP_INTERVAL = 0.05

bulletRedirection.manipLevel = _manipLevelAtom

local DEFAULT_GRAVITY = 196.2
local AIRBORNE_VELOCITY_EPS = 3

local VEL_SMOOTH_RATE = 18
local VEL_DT_MAX = 0.2
local VEL_TELEPORT_SPEED = 400

local _chance = 100
local _target
local _active = false
local _manipActive = false
local _manipOriginOffset = 6.9
local _manipHitOffset = 6.4
local _impactHooked = false
local _manipOrigin: Vector3?
local _manipHit: Vector3?
local updateImpactHook
local _accelConnection
local _gravityConnection
local _rawVelocity
local _velPrevPos
local _velPrevClock = 0
local _airborne = false
local _gravity = DEFAULT_GRAVITY
local _targetCharacter
local _targetHumanoid
local _targetHrp
local _targetPart
local _targetOffset

local _bullets
local _globals

local _manipIgnore = {}
local _redirectIgnore = {}

local function predictAim(shooterPos: Vector3, targetPos: Vector3, speed: number, gravity: number): Vector3
	local velocity = _rawVelocity or (_target.player and _target.player:GetVelocity()) or Vector3.zero
	return (ballistics.predictAimPosition(shooterPos, targetPos, velocity, _airborne, _gravity, speed, gravity))
end

local function onHeartbeat()
	if not (_active and _target and _target.player) then
		return
	end

	local character = _target.player:GetCharacter()
	if character ~= _targetCharacter then
		_targetCharacter = character
		_targetHumanoid = character and character:FindFirstChildOfClass("Humanoid")
		_targetHrp = character and character:FindFirstChild("HumanoidRootPart")
		_velPrevPos = nil
		_rawVelocity = nil
	end

	if not _targetHrp then
		return
	end

	local now = os.clock()
	local hrpPos = _targetHrp.Position
	local currentVelocity = _rawVelocity or Vector3.zero

	if _velPrevPos then
		local dt = now - _velPrevClock
		if dt > 1e-4 then
			if dt > VEL_DT_MAX then
				currentVelocity = Vector3.zero
			else
				local instant = (hrpPos - _velPrevPos) / dt
				if instant.Magnitude > VEL_TELEPORT_SPEED then
					currentVelocity = Vector3.zero
				else
					local alpha = 1 - math.exp(-dt * VEL_SMOOTH_RATE)
					currentVelocity = currentVelocity + (instant - currentVelocity) * alpha
				end
			end
		end
	end

	_velPrevPos = hrpPos
	_velPrevClock = now
	_rawVelocity = currentVelocity

	local state = _targetHumanoid and _targetHumanoid:GetState()
	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		_airborne = true
	elseif state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then
		_airborne = false
	else
		_airborne = math.abs(currentVelocity.Y) > AIRBORNE_VELOCITY_EPS
	end
end

local updateManipBar = LPH_NO_VIRTUALIZE(function()
	if not (_active and _target and _target.player and _target.position) then
		if peek(_manipLevelAtom) ~= nil then
			_manipLevelAtom(nil)
		end
		return
	end

	local now = os.clock()
	if now - _manipClock < MANIP_INTERVAL then
		return
	end
	_manipClock = now

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local origin = camera.CFrame.Position
	local targetPos = _target.position

	local ignore = _manipIgnore
	table.clear(ignore)
	local localChar = peek(ClientState.character)
	if localChar then
		ignore[#ignore + 1] = localChar
	end
	local targetCharacter = _target.player:GetCharacter()
	if targetCharacter then
		ignore[#ignore + 1] = targetCharacter
	end

	local _, level = originSolver.solveOrigin(origin, targetPos, ignore)
	_manipLevelAtom(level)
end)

local function liveTargetPos(): Vector3?
	if _targetPart and _targetPart.Parent and _targetOffset then
		return _targetPart.CFrame:PointToWorldSpace(_targetOffset)
	end
	return _target and _target.position
end

local function computeRedirect(character: any, weapon: any, origin: Vector3): (Vector3?, Vector3?)
	if peek(ClientState.thirdPerson) then
		local head = peek(ClientState.parts).Head :: BasePart?
		if head and head.Parent then
			origin = head.Position
		end
	end

	local targetPos = liveTargetPos()
	if not targetPos then
		return nil, nil
	end

	local speed = weapon.FireConfig.MuzzleVelocity * _globals.MuzzleVelocityMod
	local gravity = _globals.ProjectileGravity

	local predictedPosition = predictAim(origin, targetPos, speed, gravity)

	local predictedMagnitude = predictedPosition.Magnitude
	if predictedMagnitude ~= predictedMagnitude or predictedMagnitude == math.huge then
		return nil, nil
	end

	local newOrigin = origin

	local ignore = _redirectIgnore
	table.clear(ignore)
	if character and character.Instance then
		ignore[#ignore + 1] = character.Instance
	end
	local targetCharacter = _target.player:GetCharacter()
	if targetCharacter then
		ignore[#ignore + 1] = targetCharacter
	end

	if _manipActive then
		boxOcclusion.reset()
		local solvedOrigin, solvedHit =
			manipScan.solve(origin, predictedPosition, ignore, _manipOriginOffset, _manipHitOffset)
		if not (solvedOrigin and solvedHit) then
			return nil, nil
		end
		newOrigin = solvedOrigin
		predictedPosition = solvedHit
		_manipOrigin = solvedOrigin
		_manipHit = solvedHit
	elseif not worldRaycast.clearLineOfSight(origin, targetPos, ignore) then
		return nil, nil
	end

	local newDirection = predictedPosition - newOrigin
	local magnitude = newDirection.Magnitude
	if magnitude > 1e-4 and magnitude < math.huge then
		return newOrigin, newDirection.Unit
	end

	return nil, nil
end

local function ensureHook()
	if not _accelConnection then
		_accelConnection = RunService.Heartbeat:Connect(onHeartbeat)
	end

	if not _gravityConnection then
		_gravity = Workspace.Gravity
		_gravityConnection = Workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
			_gravity = Workspace.Gravity
		end)
	end

	local old
	old = hook.add(
		_bullets.module.Fire,
		LPH_NO_VIRTUALIZE(function(self, character, camera, weapon, origin, direction, ...)
			if
				_active
				and _target
				and _target.player
				and weapon
				and (_chance >= 100 or math.random(1, 100) <= _chance)
			then
				local newOrigin, newDirection = computeRedirect(character, weapon, origin)
				if newOrigin and newDirection then
					return old(self, character, camera, weapon, newOrigin, newDirection, ...)
				end
			end

			return old(self, character, camera, weapon, origin, direction, ...)
		end)
	)
end

local function restoreHook()
	if _bullets and _bullets.module then
		hook.restore(_bullets.module.Fire)
	end

	if _accelConnection then
		_accelConnection:Disconnect()
		_accelConnection = nil
	end

	if _gravityConnection then
		_gravityConnection:Disconnect()
		_gravityConnection = nil
	end
end

function bulletRedirection.setActive(state: boolean)
	if state then
		if not _bullets then
			_bullets = ModuleController.GetModule("Bullets")
		end
		if not _globals then
			local globals = ModuleController.GetModule("Globals")
			_globals = globals and globals.module
		end
		if not _bullets or not _bullets.module or not _globals then
			return
		end
	end

	if _active == state then
		return
	end

	_active = state
	if state then
		ensureHook()
	else
		_target = nil
		_rawVelocity = nil
		_velPrevPos = nil
		_airborne = false
		_targetCharacter = nil
		_targetHumanoid = nil
		_targetHrp = nil
		_targetPart = nil
		_targetOffset = nil
		_manipOrigin = nil
		_manipHit = nil
		restoreHook()
	end
	updateImpactHook()
end

function bulletRedirection.setTarget(target: any)
	_target = target

	local part = target and target.part
	if part then
		_targetPart = part
		_targetOffset = part.CFrame:PointToObjectSpace(target.position or part.Position)
	else
		_targetPart = nil
		_targetOffset = nil
	end

	if not target then
		_rawVelocity = nil
		_velPrevPos = nil
		_airborne = false
		_targetCharacter = nil
		_targetHumanoid = nil
		_targetHrp = nil
	end
end

function bulletRedirection.setChance(chance: number)
	_chance = math.clamp(chance, 0, 100)
end

function bulletRedirection.setManipulationActive(state: boolean)
	_manipActive = state == true
	if not _manipActive then
		_manipOrigin = nil
		_manipHit = nil
	end
	updateImpactHook()
end

function bulletRedirection.setManipulationOriginOffset(offset: number)
	_manipOriginOffset = offset
end

function bulletRedirection.setManipulationHitOffset(offset: number)
	_manipHitOffset = offset
end

function bulletRedirection.setManipBarActive(state: boolean)
	if _manipBarActive == (state == true) then
		return
	end
	_manipBarActive = state == true

	if _manipBarActive then
		if not _manipConnection then
			_manipConnection = RunService.Heartbeat:Connect(updateManipBar)
		end
	else
		if _manipConnection then
			_manipConnection:Disconnect()
			_manipConnection = nil
		end
		_manipLevelAtom(nil)
	end
end

local IMPACT_SEND_PACKET = "Bullet Impact"

local onBulletImpact = LPH_NO_VIRTUALIZE(function(shotId, weaponId, serverTime, pellet, hitPart, posObf, t7)
	if not (_manipActive and _target and _target.player) then
		return
	end

	local aimPart = _targetPart
	if not (aimPart and aimPart.Parent) then
		return
	end

	local origin = _manipOrigin
	local hitPos = _manipHit
	if not (origin and hitPos) then
		return
	end

	if typeof(t7) ~= "table" or typeof(t7[2]) ~= "Vector3" then
		return
	end
	local segmentLength = t7[2].Magnitude
	if segmentLength < 1e-4 then
		return
	end

	local toHit = hitPos - origin
	local dist = toHit.Magnitude
	if dist < 1e-4 then
		return
	end
	local segment = (toHit / dist) * segmentLength
	local rayOrigin = hitPos - segment

	local cf = aimPart.CFrame
	local size = aimPart.Size
	local newPosObf =
		Vector3.new(hitPos.X * size.X * shotId, hitPos.Y * size.Y * shotId, hitPos.Z * size.Z * shotId)
	local newT7 = {
		cf:PointToObjectSpace(rayOrigin),
		cf:VectorToObjectSpace(segment),
		cf:PointToObjectSpace(hitPos),
	}

	return shotId, weaponId, serverTime, pellet, aimPart, newPosObf, newT7
end)

function updateImpactHook()
	local want = _active and _manipActive
	if want == _impactHooked then
		return
	end
	if want then
		NetworkController.hookSend(IMPACT_SEND_PACKET, onBulletImpact)
	else
		NetworkController.restoreSend(IMPACT_SEND_PACKET, onBulletImpact)
	end
	_impactHooked = want
end

return bulletRedirection
