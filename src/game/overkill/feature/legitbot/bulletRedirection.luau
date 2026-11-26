return LPH_JIT_MAX(function()
	local Players = cloneref(game:GetService("Players")) :: Players
	local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
	local RunService = cloneref(game:GetService("RunService")) :: RunService

	local Charm = require("@pkg/Charm")
	local SessionController = require("@feature/session/SessionController")
	local ModuleController = require("@game/overkill/module/ModuleController")
	local clientState = require("@game/overkill/client/clientState")
	local Backtrack = require("@game/overkill/feature/legitbot/BacktrackController")
	local CommandController = require("@game/overkill/weapon/CommandController")
	local WeaponController = require("@game/overkill/weapon/WeaponController")
	local firePredict = require("@game/overkill/weapon/firePredict")
	local slotKeys = require("@game/overkill/weapon/slotKeys")

	local BTN_PRIMARY = 1

	local peek = Charm.peek

	local USER_ID = Players.LocalPlayer.UserId

	local SPOOF_NAME = "limerenceAimSpoof"
	local RESTORE_NAME = "limerenceAimRestore"
	local SPOOF_PRIORITY = Enum.RenderPriority.Input.Value - 1
	local RESTORE_PRIORITY = Enum.RenderPriority.Input.Value + 1

	local bulletRedirection = {}

	local cameraHandler: any = nil
	local clientModule: any = nil
	local items: any = nil

	local _redirectActive = false
	local _noSpread = false
	local _target: any? = nil
	local _chance = 100

	local _ragebotActive = false
	local _ragebotTarget: any? = nil

	local _spoofed = false
	local _origRotation: any = nil
	local _correctYaw = 0
	local _solvedServerTime: number? = nil
	local _bound = false
	local _predict = firePredict.new()

	local _shiftArmed = false
	local _shiftSec = 0
	local _backtrackFeatureActive = false
	local _transformUnregister: (() -> ())? = nil
	local _chargeNoWait = false
	local _chargeMaxHealth = 0
	local _chargeDump = false
	local _chargeHold = false
	local _chargeMinRelease = 0

	local _aimShiftCap = 0.38
	local _extraShiftTotal = 0

	local aimShiftCap = LPH_NO_VIRTUALIZE(function(): number
		if _aimShiftCap > 0 then
			return _aimShiftCap
		end
		local cap = 0.4 - SessionController.GetPing() / 1000
		return cap > 0 and cap or 0
	end)

	local _extraShift: { [string]: number } = {}

	local _f32 = buffer.create(4)

	local makeSpreadRng = LPH_NO_VIRTUALIZE(
		function(userId: number, serverTime: number, slot: number, bulletIndex: number): Random
			local v86 = math.floor((serverTime or 0) * 1000)
			local v87 = bit32.band(userId or 0, 1073741823)
			local v88 = bit32.band(v86, 65535)
			local v89 = bit32.band(slot or 0, 15)
			local v90 = bit32.band(bulletIndex or 0, 255)
			local seed = bit32.bxor(
				bit32.bxor(v87, bit32.lshift(v88, 8)),
				bit32.bxor(bit32.lshift(v89, 20), bit32.lshift(v90, 24))
			) % 2147483647
			return Random.new(seed)
		end
	)

	local dirToAngles = LPH_NO_VIRTUALIZE(function(dir: Vector3): (number, number)
		local pitch = math.asin(math.clamp(dir.Y, -1, 1))
		local yaw = math.atan2(-dir.X, -dir.Z)
		return pitch, yaw
	end)

	local serverFinalDir = LPH_NO_VIRTUALIZE(function(pitch: number, yaw: number, ctx: any): Vector3
		local base = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		local look = base.LookVector
		if ctx.baseSpread > 0 then
			local rng = makeSpreadRng(USER_ID, ctx.serverTime, ctx.slot, 1)
			local a = (rng:NextNumber() - 0.5) * ctx.baseSpread
			local b = (rng:NextNumber() - 0.5) * ctx.baseSpread
			look = (base * CFrame.Angles(a, b, 0)).LookVector
		end
		if ctx.dynSpread > 0 then
			local rng = makeSpreadRng(USER_ID, ctx.serverTime, ctx.slot, 1 + 128)
			local c = (rng:NextNumber() - 0.5) * ctx.dynSpread
			local e = (rng:NextNumber() - 0.5) * ctx.dynSpread
			look = (look * ctx.maxDistance + base.RightVector * c + base.UpVector * e).Unit
		end
		return look
	end)

	local solveAngles = LPH_NO_VIRTUALIZE(function(desiredDir: Vector3, ctx: any): (number, number)
		local targetPitch, targetYaw = dirToAngles(desiredDir)
		if ctx.baseSpread <= 0 and ctx.dynSpread <= 0 then
			return targetPitch, targetYaw
		end
		local pitch, yaw = targetPitch, targetYaw
		for _ = 1, 4 do
			local finalPitch, finalYaw = dirToAngles(serverFinalDir(pitch, yaw, ctx))
			pitch += targetPitch - finalPitch
			yaw += targetYaw - finalYaw
		end
		return pitch, yaw
	end)

	local function ensureRefs(): ()
		if not cameraHandler then
			cameraHandler = ModuleController.GetModule("cameraHandler")
		end
		if not clientModule then
			clientModule = ModuleController.GetModule("clientModule")
		end
		if not items then
			items = ModuleController.GetModule("items")
		end
	end

	local function equippedFiring(state: any): (any, number, any)
		local slot = state.equippedSlot or 1
		local keys = slotKeys[slot] or slotKeys[1]
		local weaponID = state[keys.weaponID]
		if not items or not items.all or weaponID == nil or weaponID == "" then
			return nil, slot, nil
		end
		local itemData = items.all[weaponID]
		local firing = itemData and itemData.stats and itemData.stats.firing
		return firing, slot, itemData
	end

	local function spreadContext(state: any): any
		local firing, slot, itemData = equippedFiring(state)
		if not firing then
			return nil
		end
		local serverTime = firePredict.estimateServerTime()
		if _shiftArmed and _shiftSec ~= 0 then
			serverTime -= _shiftSec
		end
		if not _chargeDump then
			serverTime -= _extraShiftTotal
		end
		buffer.writef32(_f32, 0, serverTime)
		serverTime = buffer.readf32(_f32, 0)
		local aiming = state.aiming == true
		if aiming and itemData.category == "sniper_rifle" then
			local aimStart = state.aimStartServerTime or 0
			aiming = aimStart > 0 and serverTime - aimStart >= 0.24
		end
		local baseSpread = 0
		local burstCount = firing.burstCount or 1
		local burstDelay = firing.burstDelay
		local multi = burstCount > 1 and (burstDelay == nil or burstDelay <= 0)
		if multi then
			baseSpread = firing.burstSpread or 0
		elseif not aiming or firing.aimingSpread == nil then
			baseSpread = firing.spread or 0
		else
			baseSpread = firing.aimingSpread
		end
		local dynSpread = 0
		if not multi and not firing.noSpread and not aiming then
			local inAir = (state.inAir or 0) > 0
			local n5 = 6.5
			if (state.slideTime or 0) > 0 then
				n5 += 0.6
			end
			if inAir then
				n5 += 1.5
			end
			if state.crouching == true and not inAir then
				n5 -= 1.5
			end
			if n5 < 0 then
				n5 = 0
			end
			dynSpread = n5
		end
		return {
			serverTime = serverTime,
			slot = slot,
			baseSpread = baseSpread,
			dynSpread = dynSpread,
			maxDistance = firing.maxDistance or 500,
		}
	end

	local spoof = LPH_NO_VIRTUALIZE(function(): ()
		_spoofed = false
		_shiftArmed = false
		_correctYaw = 0
		_solvedServerTime = nil
		if not _ragebotActive then
			_chargeDump = false
		end
		ensureRefs()
		if not (_redirectActive or _ragebotActive or _noSpread or Backtrack.IsEnabled()) then
			return
		end
		local simulation = clientModule and clientModule.localChickynoid and clientModule.localChickynoid.simulation
		local state = simulation and simulation.state
		if type(state) ~= "table" then
			_predict:reset()
			return
		end
		if _ragebotActive then
			if not WeaponController._firing and not _predict:willFire(state) then
				return
			end
		elseif not _predict:willFire(state) then
			return
		end
		if not cameraHandler then
			return
		end
		local rotation = cameraHandler.currentRotation
		if rotation == nil then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camCF = peek(clientState.fpCamera) or camera.CFrame

		if not _ragebotActive and Backtrack.IsEnabled() then
			local delaySec = Backtrack.GetDelaySeconds()
			if delaySec ~= 0 and Backtrack.RayHitsGhost(camCF.Position, camCF.LookVector) then
				_shiftArmed = true
				_shiftSec = delaySec
			end
		end

		local activeTarget: any? = nil
		if _ragebotActive then
			activeTarget = _ragebotTarget
		elseif _redirectActive then
			activeTarget = _target
		end
		local wantNoSpread = _noSpread or _ragebotActive

		local desiredDir: Vector3? = nil
		if activeTarget and activeTarget.position then
			if _ragebotActive or _chance >= 100 or math.random(1, 100) <= _chance then
				local targetPos = activeTarget.position :: Vector3
				local applyBacktrack = Backtrack.IsEnabled() and activeTarget.player and activeTarget.part
				if applyBacktrack and _ragebotActive then
					applyBacktrack = activeTarget.useBacktrack == true
				end
				local chargeShift = 0
				if not _chargeDump then
					chargeShift = _extraShiftTotal
					local cap = aimShiftCap()
					if chargeShift > cap then
						chargeShift = cap
					end
				end
				if applyBacktrack then
					local historical =
						Backtrack.GetHistoricalPosition(activeTarget.player:GetPlayer(), activeTarget.part.Name)
					if historical then
						targetPos = historical
						local delaySec = Backtrack.GetDelaySeconds()
						if delaySec ~= 0 then
							_shiftArmed = true
							_shiftSec = delaySec
						end
						if chargeShift > 0 then
							local shifted = Backtrack.GetPositionAt(
								activeTarget.player:GetPlayer(),
								activeTarget.part.Name,
								delaySec + chargeShift
							)
							if shifted then
								targetPos = shifted
							end
						end
					end
				elseif chargeShift > 0 and activeTarget.player and activeTarget.part then
					local shifted =
						Backtrack.GetPositionAt(activeTarget.player:GetPlayer(), activeTarget.part.Name, chargeShift)
					if shifted then
						targetPos = shifted
					end
				end
				local predict = activeTarget.predict
				if predict and not applyBacktrack then
					targetPos += predict
				end
				local delta = targetPos - camCF.Position
				if delta.Magnitude >= 1e-4 then
					desiredDir = delta.Unit
				end
			end
		end
		if not desiredDir then
			if wantNoSpread then
				desiredDir = camCF.LookVector
			else
				return
			end
		end
		local dir = desiredDir :: Vector3

		local pitch, yaw
		if wantNoSpread then
			local ctx = spreadContext(state)
			if ctx then
				pitch, yaw = solveAngles(dir, ctx)
				if ctx.baseSpread > 0 or ctx.dynSpread > 0 then
					_solvedServerTime = ctx.serverTime
				end
			else
				pitch, yaw = dirToAngles(dir)
			end
		else
			pitch, yaw = dirToAngles(dir)
		end

		_origRotation = rotation
		cameraHandler.currentRotation = Vector3.new(pitch, yaw, rotation.Z)
		_correctYaw = yaw - rotation.Y
		_spoofed = true
	end)

	local restore = LPH_NO_VIRTUALIZE(function(): ()
		if not _spoofed then
			return
		end
		if cameraHandler and _origRotation ~= nil then
			cameraHandler.currentRotation = _origRotation
		end
		_spoofed = false
		_origRotation = nil
	end)

	local function installTransform(): ()
		if _transformUnregister then
			return
		end
		_transformUnregister = CommandController.Register(
			LPH_NO_VIRTUALIZE(function(command: any): ()
				if type(command) ~= "table" then
					return
				end
				if _correctYaw ~= 0 then
					local x = command.x or 0
					local z = command.z or 0
					if x ~= 0 or z ~= 0 then
						local corrected = CFrame.fromEulerAnglesYXZ(0, -_correctYaw, 0) * Vector3.new(x, 0, z)
						command.x = corrected.X
						command.z = corrected.Z
					end
				end
				if _shiftArmed and bit32.band(command.buttons or 0, BTN_PRIMARY) ~= 0 then
					if type(command.serverTime) == "number" and _shiftSec ~= 0 then
						command.serverTime -= _shiftSec
					end
					_shiftArmed = false
				end
				local solvedSt = _solvedServerTime
				if solvedSt and bit32.band(command.buttons or 0, BTN_PRIMARY) ~= 0 then
					if type(command.serverTime) == "number" then
						local diff = command.serverTime - solvedSt
						if math.abs(diff) < 0.005 then
							command.serverTime = solvedSt
						end
					end
					_solvedServerTime = nil
				end
			end),
			100
		)
	end

	local function bind(): ()
		if _bound then
			return
		end
		installTransform()
		RunService:BindToRenderStep(SPOOF_NAME, SPOOF_PRIORITY, spoof)
		RunService:BindToRenderStep(RESTORE_NAME, RESTORE_PRIORITY, restore)
		_bound = true
	end

	local function unbind(): ()
		if not _bound then
			return
		end
		RunService:UnbindFromRenderStep(SPOOF_NAME)
		RunService:UnbindFromRenderStep(RESTORE_NAME)
		_bound = false
		_correctYaw = 0
		_solvedServerTime = nil
		_chargeDump = false
		_shiftArmed = false
		_shiftSec = 0
		restore()
		if _transformUnregister then
			_transformUnregister()
			_transformUnregister = nil
		end
	end

	local function refreshBinding(): ()
		if _redirectActive or _ragebotActive or _noSpread or _backtrackFeatureActive then
			bind()
		else
			unbind()
		end
	end

	function bulletRedirection.setActive(state: boolean): ()
		_redirectActive = state == true
		if not _redirectActive then
			_target = nil
		end
		refreshBinding()
	end

	function bulletRedirection.setBacktrackActive(state: boolean): ()
		_backtrackFeatureActive = state == true
		refreshBinding()
	end

	function bulletRedirection.setRagebotActive(state: boolean): ()
		_ragebotActive = state == true
		if not _ragebotActive then
			_ragebotTarget = nil
		end
		refreshBinding()
	end

	function bulletRedirection.setRagebotTarget(target: any?): ()
		_ragebotTarget = target
	end

	function bulletRedirection.SetTimeShift(id: string, seconds: number): ()
		if seconds ~= 0 then
			_extraShift[id] = seconds
		else
			_extraShift[id] = nil
		end
		local total = 0
		for _, shift in next, _extraShift do
			total += shift
		end
		_extraShiftTotal = total
	end

	function bulletRedirection.GetTimeShift(): number
		return _extraShiftTotal
	end

	function bulletRedirection.GetAimShift(): number
		local total = _extraShiftTotal
		local cap = aimShiftCap()
		if total > cap then
			total = cap
		end
		return total
	end

	function bulletRedirection.SetAimShiftCap(seconds: number): ()
		_aimShiftCap = seconds
	end

	function bulletRedirection.SetChargeNoWait(state: boolean): ()
		_chargeNoWait = state == true
	end

	function bulletRedirection.GetChargeNoWait(): boolean
		return _chargeNoWait
	end

	function bulletRedirection.SetChargeMaxHealth(value: number): ()
		_chargeMaxHealth = value
	end

	function bulletRedirection.SetChargeHold(state: boolean): ()
		_chargeHold = state == true
	end

	function bulletRedirection.GetChargeHold(): boolean
		return _chargeHold
	end

	function bulletRedirection.SetChargeMinRelease(seconds: number): ()
		_chargeMinRelease = seconds
	end

	function bulletRedirection.GetChargeMinRelease(): number
		return _chargeMinRelease
	end

	function bulletRedirection.GetChargeMaxHealth(): number
		return _chargeMaxHealth
	end

	function bulletRedirection.SetChargeDump(state: boolean): ()
		_chargeDump = state == true
	end

	function bulletRedirection.GetChargeDump(): boolean
		return _chargeDump
	end

	function bulletRedirection.isRagebotActive(): boolean
		return _ragebotActive
	end

	function bulletRedirection.setTarget(target: any?): ()
		_target = target
	end

	function bulletRedirection.setChance(chance: number): ()
		_chance = math.clamp(chance, 0, 100)
	end

	function bulletRedirection.setNoSpread(state: boolean): ()
		_noSpread = state == true
		refreshBinding()
	end

	function bulletRedirection.restore(): ()
		unbind()
	end

	return bulletRedirection
end)()
