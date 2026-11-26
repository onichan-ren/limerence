local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local ClientState = require("@game/pf/client/clientState")
local ModuleController = require("@game/pf/module/ModuleController")
local WeaponController = require("@game/pf/weapon/WeaponController")
local scopes = require("@game/pf/feature/scopes")
local bulletRedirection = require("@game/pf/feature/legitbot/bulletRedirection")
local pfBallistics = require("@game/pf/feature/ragebot/pfBallistics")
local Backtrack = require("@game/pf/feature/ragebot/Backtrack")
local UniversalLegitbot = require("@game/universal/feature/combat/legitbot/Legitbot")
local NetworkController = require("@game/pf/network/NetworkController")
local Signal = require("@pkg/Signal")

local peek = Charm.peek
local sub = Charm.subscribe

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local shouldFilter = LPH_NO_VIRTUALIZE(function(instance: BasePart): boolean
	return instance.Transparency == 1 and instance.CanCollide == false
end)

local sharedRaycastParams = RaycastParams.new()

local recursiveRaycast
recursiveRaycast = LPH_NO_VIRTUALIZE(
	function(origin: Vector3, direction: Vector3, params: RaycastParams): RaycastResult?
		local result = Workspace:Raycast(origin, direction, params)

		if not result then
			return
		end

		local instance = result.Instance

		if instance and shouldFilter(instance) then
			local position = result.Position

			params:AddToFilter(instance)
			return recursiveRaycast(position + result.Normal * 0.01, direction - (position - origin), params)
		end

		return result
	end
)

local fetchActiveWeapon = LPH_NO_VIRTUALIZE(function(co: any): any?
	local wc = co:getWeaponController()
	return wc and wc:getActiveWeapon()
end)

local readScopeStats = LPH_NO_VIRTUALIZE(function(weapon: any): (boolean, boolean)
	return weapon:getActiveAimStat("blackscope") == true,
		weapon:isBlackScoped() == true
end)

local Legitbot = {}

function Legitbot.new(
	link: gameUi.Linker,
	opts: {
		targettingLink: gameUi.Linker,
		aimLink: gameUi.Linker,
		triggerLink: gameUi.Linker,
		bulletRedirectionLink: gameUi.Linker,
		visualsLink: gameUi.Linker,
	}
): UniversalLegitbot.Legitbot
	local CharacterInterface = ModuleController.GetModule("CharacterInterface")
	local GameClock = ModuleController.GetModule("GameClock")

	local getCharacterObject = LPH_NO_VIRTUALIZE(function(): any?
		if not CharacterInterface then
			return nil
		end
		return CharacterInterface.getCharacterObject()
	end)

	local getActiveWeapon = LPH_NO_VIRTUALIZE(function(): any?
		local co = getCharacterObject()
		if not co then
			return nil
		end
		return fetchActiveWeapon(co)
	end)

	local isFirearm = LPH_NO_VIRTUALIZE(function(weapon: any?): boolean
		return weapon ~= nil and weapon:getWeaponType() == "Firearm"
	end)

	local predictAimPoint = LPH_NO_VIRTUALIZE(function(o: any): Vector3
		local aim = o.aimPoint
		local weapon = o.weapon
		if not isFirearm(weapon) then
			return aim
		end
		local speed = weapon:getWeaponStat("bulletspeed")
		if type(speed) ~= "number" or speed <= 0 then
			return aim
		end
		local origin = o.origin
		local gravity = WeaponController.GetGravity()
		if o.movementComp then
			local part = o.part
			local vel = part and part.AssemblyLinearVelocity
			if vel and (vel.X ~= 0 or vel.Y ~= 0 or vel.Z ~= 0) then
				local _, flight = pfBallistics.trajectory(origin, gravity, aim, speed)
				if flight and flight == flight and flight > 0 then
					aim += vel * flight
				end
			end
		end
		if o.bulletComp then
			local launch = pfBallistics.trajectory(origin, gravity, aim, speed)
			if launch and launch.X == launch.X then
				aim = origin + launch.Unit * (aim - origin).Magnitude
			end
		end
		return aim
	end)

	local fireWeapon = LPH_NO_VIRTUALIZE(function(weapon: any): ()
		if not isFirearm(weapon) then
			return
		end
		local id = getthreadidentity()
		setthreadidentity(8)
		weapon:shoot(true, 1)
		setthreadidentity(id)
	end)

	local stopFireWeapon = LPH_NO_VIRTUALIZE(function(): ()
		local weapon = getActiveWeapon()
		if not isFirearm(weapon) then
			return
		end
		local id = getthreadidentity()
		setthreadidentity(8)
		weapon:shoot(false)
		setthreadidentity(id)
	end)

	local bulletCreated = Signal.new()
	local newbulletsUnhook = NetworkController.HookOutbound(
		"newbullets",
		LPH_NO_VIRTUALIZE(function(): ()
			bulletCreated:Fire()
		end)
	)

	local game: UniversalLegitbot.GameOpts = {
		getLocalAlive = LPH_NO_VIRTUALIZE(function(): boolean
			if CharacterInterface then
				return CharacterInterface.isAlive() == true
			end
			return peek(ClientState.alive)
		end),
		getLocalTeam = function(): string?
			return peek(ClientState.team)
		end,
		getEquippedWeapon = getActiveWeapon,
		canShoot = LPH_NO_VIRTUALIZE(function(weapon: any): boolean
			return isFirearm(weapon) and weapon:getMagCount() > 0 and weapon:isReloading() ~= true
		end),
		canFire = LPH_NO_VIRTUALIZE(function(weapon: any): boolean
			if not isFirearm(weapon) or weapon:isEquipped() ~= true or weapon:getMagCount() <= 0 then
				return false
			end
			if not weapon:isState("chambered") and (not weapon:isState("chamberedReloading") or not weapon._canShoot) then
				return false
			end
			local now = GameClock.getTime()
			return now >= weapon._nextShot and now >= weapon._disableUntil
		end),
		fire = fireWeapon,
		stopFire = stopFireWeapon,
		getTargetingDisabled = LPH_NO_VIRTUALIZE(function(): boolean
			return not isFirearm(getActiveWeapon())
		end),
		isScopedIn = LPH_NO_VIRTUALIZE(function(): boolean
			local weapon = getActiveWeapon()
			if not isFirearm(weapon) then
				return false
			end
			local hasScope, scopedIn = readScopeStats(weapon)
			if not hasScope then
				return true
			end
			return scopedIn
		end),
		isAiming = function(): boolean
			return WeaponController.IsAiming()
		end,
		predictAimPoint = predictAimPoint,
		getLocalReloading = LPH_NO_VIRTUALIZE(function(): boolean
			local weapon = getActiveWeapon()
			return isFirearm(weapon) and weapon:isReloading() == true
		end),
		getLocalOutOfAmmo = LPH_NO_VIRTUALIZE(function(): boolean
			local weapon = getActiveWeapon()
			return isFirearm(weapon) and weapon:getMagCount() <= 0
		end),
		getLocalOnCooldown = LPH_NO_VIRTUALIZE(function(): boolean
			local weapon = getActiveWeapon()
			if not isFirearm(weapon) or weapon:isReloading() == true or weapon:getMagCount() <= 0 then
				return false
			end
			local now = GameClock.getTime()
			return now < weapon._nextShot or now < weapon._disableUntil
		end),
		getLocalSwitching = LPH_NO_VIRTUALIZE(function(): boolean
			local weapon = getActiveWeapon()
			return isFirearm(weapon) and weapon:isEquipped() ~= true
		end),
		getLocalInAir = LPH_NO_VIRTUALIZE(function(): boolean
			local co = getCharacterObject()
			return co ~= nil and co:isGrounded() ~= true
		end),
		getLocalSprinting = LPH_NO_VIRTUALIZE(function(): boolean
			local co = getCharacterObject()
			return co ~= nil and co:isSprinting() == true
		end),
		isPlayerBlocking = LPH_NO_VIRTUALIZE(function(player: any): boolean
			return peek(player.isEnemy) ~= true
		end),
		gameRaycast = LPH_NO_VIRTUALIZE(
			function(origin: Vector3, target: Vector3, ignore: { Instance }): RaycastResult?
				local raycastParams = sharedRaycastParams
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude
				raycastParams.FilterDescendantsInstances = ignore

				return recursiveRaycast(origin, target - origin, raycastParams)
			end
		),
		getAimPoint2d = LPH_NO_VIRTUALIZE(function(): Vector2
			return UserInputService:GetMouseLocation()
		end),
		setupScopes = scopes.build,
		subscribeWeaponChange = function(cb: (weapon: any?) -> ()): (() -> ())?
			local function emit(name: string): ()
				cb(name ~= "" and { Name = name } or nil)
			end
			emit(peek(WeaponController.state.weaponName))
			return sub(WeaponController.state.weaponName, emit)
		end,
		getBacktrackPosition = Backtrack.GetHistoricalPosition,
		getBacktrackFolder = Backtrack.GetFolder,
		setBulletRedirectionActive = bulletRedirection.setActive,
		setBulletRedirectionTarget = bulletRedirection.setTarget,
		setBulletRedirectionChance = bulletRedirection.setChance,
		bulletCreatedSignal = bulletCreated,
		uiOpts = {
			hitboxes = { "Head", "Torso", "Arms", "Legs" },
			targettingConditions = {
				"While Reloading",
				"While Out Of Ammo",
				"While On Cooldown",
				"While Switching",
				"Wait For Scope",
				"Wait For Aim",
				"While In Air",
				"While Sprinting",
			},
			defaultTargettingConditions = { "While On Cooldown", "While Switching", "While In Air" },
			showBlindThreshold = false,
			showSmokeThreshold = false,
			showAutowall = false,
			showRcs = false,
			showTrigger = true,
			showTriggerBullets = true,
			showTriggerWaitForScope = true,
			showTriggerWaitForAim = true,
			showHitChance = false,
			showMinDamage = false,
			showAimFirstBulletDelay = true,
			showTriggerFirstBulletDelay = true,
			showPrediction = true,
			showManipulation = false,
			showBulletRedirection = true,
		},
	}

	local instance = UniversalLegitbot.new(
		link,
		{
			targettingLink = opts.targettingLink,
			aimLink = opts.aimLink,
			triggerLink = opts.triggerLink,
			visualsLink = opts.visualsLink,
			bulletRedirectionLink = opts.bulletRedirectionLink,
			game = game,
		} :: any
	)
	instance:Track(newbulletsUnhook)
	return instance
end

export type Legitbot = UniversalLegitbot.Legitbot

return Legitbot
