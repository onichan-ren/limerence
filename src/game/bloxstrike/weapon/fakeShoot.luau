local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Players = cloneref(game:GetService("Players")) :: Players

local RapidFire = require("@game/bloxstrike/feature/ragebot/RapidFire")

local fakeShoot = {
	_ready = false,
	_refs = {} :: {
		CameraController: any?,
		Router: any?,
		resolveFireAnimationNames: any?,
		startRechargeTimer: any?,
		applyActiveRecoilProfile: any?,
		CreateTracer: any?,
		Camera: any?,
		CreateImpact: any?,
		kickCamera: any?,
		BreakGlass: any?,
		CreateMarker: any?,
	},
}

local function findUpvalueByName(fn: any, targetName: string): any?
	for _, value in next, debug.getupvalues(fn) do
		if type(value) == "function" then
			local info = debug.getinfo(value)
			if info and info.name == targetName then
				return value
			end
		end
	end
	return nil
end

function fakeShoot.bind(shootFn: any): ()
	if fakeShoot._ready then
		return
	end
	if type(shootFn) ~= "function" then
		return
	end
	local refs = fakeShoot._refs
	for _, value in next, debug.getupvalues(shootFn) do
		if type(value) == "table" then
			if rawget(value, "updateCameraFOV") then
				refs.CameraController = value
			elseif rawget(value, "broadcastRouter") then
				refs.Router = value
			end
		end
	end
	refs.CameraController = refs.CameraController or debug.getupvalue(shootFn, 9)
	refs.Router = refs.Router or debug.getupvalue(shootFn, 10)
	refs.resolveFireAnimationNames = findUpvalueByName(shootFn, "resolveFireAnimationNames") or debug.getupvalue(shootFn, 12)
	refs.startRechargeTimer = findUpvalueByName(shootFn, "startRechargeTimer") or debug.getupvalue(shootFn, 13)
	refs.applyActiveRecoilProfile = findUpvalueByName(shootFn, "applyActiveRecoilProfile") or debug.getupvalue(shootFn, 15)
	refs.Camera = debug.getupvalue(shootFn, 19)
	refs.CreateTracer = debug.getupvalue(shootFn, 20)
	refs.CreateImpact = findUpvalueByName(shootFn, "CreateImpact") or debug.getupvalue(shootFn, 22)
	refs.BreakGlass = findUpvalueByName(shootFn, "BreakGlass") or debug.getupvalue(shootFn, 26)
	refs.CreateMarker = findUpvalueByName(shootFn, "CreateMarker") or debug.getupvalue(shootFn, 27)
	refs.kickCamera = findUpvalueByName(shootFn, "GetWeaponCameraKick") or debug.getupvalue(shootFn, 28)
	fakeShoot._ready = true
end

function fakeShoot.getViewTick(): number?
	local router = fakeShoot._refs.Router
	if router and type(router.broadcastRouter) == "function" then
		return router.broadcastRouter("GetRemoteViewTick")
	end
	return nil
end

local function resolveFireRate(props: any, fireMode: string): number
	local fireModes = props.FireModes
	if fireModes then
		local modeCfg = (fireMode == "Secondary" and fireModes.Secondary or fireModes.Primary or fireModes.Primary)
		if modeCfg and modeCfg.FireRate then
			return modeCfg.FireRate
		end
	end
	return props.FireRate or 0.1
end

local resolveMuzzlePart = LPH_NO_VIRTUALIZE(function(weapon: any, interactables: Instance): BasePart?
	local part: Instance?
	if weapon.Properties.ShootingOptions == "Dual" then
		if weapon.ShootingHand == "Left" then
			part = interactables:FindFirstChild("MuzzlePartL")
		else
			part = interactables:FindFirstChild("MuzzlePartR")
		end
	else
		part = interactables:FindFirstChild("MuzzlePart")
	end
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end)

local function applyState(weapon: any): ()
	weapon.ShootRequestTick = tick()
	weapon.CurrentReloadIdentity = nil
	weapon.IsInspecting = false
	weapon.IsInspectFadingOut = false
	weapon.IsReloading = false
	weapon.IsShooting = not RapidFire.IsEnabled()
	weapon.HasPendingChargeRequest = false
	weapon.IsChargeFiring = false
	weapon.ChargeStartTick = 0
	weapon.CurrentWalkSpeedOverride = nil
	weapon.RechargeStartTime = Workspace:GetServerTimeNow()

	if weapon.ChargeThread then
		if coroutine.status(weapon.ChargeThread) ~= "dead" then
			task.cancel(weapon.ChargeThread)
		end
		weapon.ChargeThread = nil
	end
	if weapon.ChargeShootConnection and weapon.ChargeShootConnection.Connected then
		weapon.ChargeShootConnection:Disconnect()
		weapon.ChargeShootConnection = nil
	end
end

local emitBulletVfx = LPH_NO_VIRTUALIZE(function(refs: any, weapon: any, muzzlePart: BasePart?, bullet: any): ()
	local muzzlePos = muzzlePart and muzzlePart.Position
	local tracerStart = bullet.TracerOrigin or muzzlePos
	if refs.CreateTracer and tracerStart and bullet.Direction then
		local lastHit = bullet.Hits and bullet.Hits[#bullet.Hits]
		local distance: number
		if lastHit and lastHit.Position then
			distance = (lastHit.Position - tracerStart).Magnitude
		else
			distance = (weapon.Properties.Range or 500) :: number
		end
		setthreadidentity(2)
		refs.CreateTracer(distance, tracerStart, bullet.Direction)
	end

	if refs.Camera and muzzlePart then
		local muzzleType: string
		if weapon.Properties.HasSuppressor and weapon.IsSuppressed then
			muzzleType = "Suppressor"
		else
			muzzleType = weapon.Properties.MuzzleType
		end
		setthreadidentity(2)
		refs.Camera(muzzlePart, muzzleType)
	end

	setthreadidentity(8)
	if not refs.CreateImpact or not bullet.Hits then
		return
	end
	local exitFlag = false
	for _, hit in next, bullet.Hits do
		local instance = hit.Instance
		if not instance then
			continue
		end
		local ancestor = instance:FindFirstAncestorOfClass("Model")
		local hitPlayer = ancestor and Players:GetPlayerFromCharacter(ancestor) ~= nil
		if hitPlayer then
			refs.CreateImpact(
				instance,
				"Blood Splatter",
				hit.Position,
				hit.Normal,
				hit.Exit,
				false,
				true,
				nil,
				exitFlag,
				nil,
				false
			)
		else
			if not hit.Exit then
				exitFlag = true
			end
			refs.CreateImpact(instance, hit.Material, hit.Position, hit.Normal, hit.Exit, false, true)
			local parent = instance.Parent
			local parentGlass = parent and parent:HasTag("BreakableGlass") or false
			local instGlass = instance:HasTag("BreakableGlass")
			if refs.BreakGlass and parentGlass and not hit.Exit then
				setthreadidentity(2)
				refs.BreakGlass(instance, hit.Position, bullet.Direction)
				setthreadidentity(8)
			elseif refs.CreateMarker and not instGlass and not parentGlass then
				setthreadidentity(2)
				refs.CreateMarker(instance, "Bullet", hit.Position, hit.Normal)
				setthreadidentity(8)
			end
		end
	end
end)

fakeShoot.fire = LPH_NO_VIRTUALIZE(function(weapon: any, bullets: { any }, fireMode: string?): boolean
	if not fakeShoot._ready or not weapon then
		return false
	end
	local refs = fakeShoot._refs
	local mode = fireMode or "Primary"

	local props = weapon.Properties
	if not props then
		return false
	end

	local viewmodel = weapon.Viewmodel
	if not viewmodel or not viewmodel.Model then
		return false
	end

	local interactables = viewmodel.Model:FindFirstChild("Interactables")
	if not interactables then
		return false
	end
	weapon.Rounds -= 1

	local fireRate = resolveFireRate(props, mode)

	applyState(weapon)

	local bullet = weapon.Bullet
	if bullet and type(bullet._updateShotSpread) == "function" then
		bullet._updateShotSpread(bullet, props.AimingOptions, weapon.IsSniperScoped == true)
	end

	local muzzleSuffix = (not props.HasSuppressor or weapon.IsSuppressed) and "Shoot" or "NoSuppressorShoot"
	local charSuffix = (not weapon.IsAiming or props.AimingOptions ~= "AutomaticScope") and "Shoot" or "AimShoot"

	local vmAnim: string?, charAnim: string? = nil, nil
	if refs.resolveFireAnimationNames then
		vmAnim, charAnim = refs.resolveFireAnimationNames(weapon, muzzleSuffix, charSuffix, mode)
	end

	if
		charAnim
		and props.MuzzleType ~= "ShotGun"
		and weapon.CharacterAnimator
		and weapon.CharacterAnimator.adjustAnimationSpeed
	then
		weapon.CharacterAnimator:adjustAnimationSpeed(charAnim, fireRate)
	end

	if refs.startRechargeTimer then
		refs.startRechargeTimer(weapon)
	end

	if refs.applyActiveRecoilProfile then
		refs.applyActiveRecoilProfile(weapon, mode)
	end

	if refs.CameraController and refs.CameraController.toWeaponFirePosition then
		refs.CameraController.toWeaponFirePosition()
	end

	local muzzlePart = resolveMuzzlePart(weapon, interactables)

	for _, bullet in next, bullets do
		emitBulletVfx(refs, weapon, muzzlePart, bullet)
	end

	local cameraShake = viewmodel.Model:FindFirstChild("CameraShake")
	if refs.kickCamera and cameraShake then
		refs.kickCamera(cameraShake)
	end

	if weapon.Recoil then
		weapon.Recoil.Time = (weapon.Recoil.Time or 0) + fireRate
	end

	local wasSniperScoped = weapon.IsAiming == true and props.AimingOptions == "SniperScope"
	if wasSniperScoped and type(weapon.unscope) == "function" then
		weapon.unscope(weapon, true)
	end

	if vmAnim and viewmodel.Animation and viewmodel.Animation.play then
		viewmodel.Animation:play(vmAnim)
	end
	if charAnim and weapon.CharacterAnimator and weapon.CharacterAnimator.play then
		weapon.CharacterAnimator:play(charAnim)
	end

	if weapon.ShootDelayThread then
		if coroutine.status(weapon.ShootDelayThread) ~= "dead" then
			task.cancel(weapon.ShootDelayThread)
		end
		weapon.ShootDelayThread = nil
	end
	local shootRequestTick = weapon.ShootRequestTick
	local rapidFire = RapidFire.IsEnabled()
	local effectiveDelay = (rapidFire and 0 or fireRate)
	weapon.ShootDelayThread = task.delay(effectiveDelay, function()
		if weapon.IsDestroyed then
			return
		end
		weapon.IsShooting = false
		weapon.ShootDelayThread = nil

		if weapon.IsEquipped ~= true then
			return
		end
		if
			wasSniperScoped
			and shootRequestTick == weapon.ShootRequestTick
			and (weapon.Rounds or 0) > 0
			and type(weapon.scope) == "function"
		then
			weapon.scope(weapon, true)
		end
	end)

	return true
end)

return fakeShoot
