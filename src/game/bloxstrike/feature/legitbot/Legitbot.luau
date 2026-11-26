local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local ClientController = require("@game/bloxstrike/client/ClientController")
local ClientState = require("@game/bloxstrike/client/clientState")
local clientApi = require("@game/bloxstrike/client/clientApi")
local LoadoutState = require("@game/bloxstrike/loadout/loadoutState")
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
local GrenadeController = require("@game/bloxstrike/grenade/GrenadeController")
local Backtrack = require("@game/bloxstrike/feature/ragebot/Backtrack")
local UniversalLegitbot = require("@game/universal/feature/combat/legitbot/Legitbot")
local penetrationQuery = require("@game/bloxstrike/feature/legitbot/penetrationQuery")
local spreadHitChance = require("@game/bloxstrike/feature/legitbot/spreadHitChance")
local smokeRay = require("@game/bloxstrike/feature/legitbot/smokeRay")
local gamemodeState = require("@game/bloxstrike/gamemodeState")
local predictDamage = require("@game/bloxstrike/feature/legitbot/predictDamage")
local scopes = require("@game/bloxstrike/feature/scopes")
local bulletRedirection = require("@game/bloxstrike/feature/legitbot/bulletRedirection")
local InfinitePenetration = require("@game/bloxstrike/feature/ragebot/InfinitePenetration")

local peek = Charm.peek
local sub = Charm.subscribe

local RCS_CALIBRATION = 0.65

local function isLocalInAir(): boolean
	local charObj = ClientController.GetCharacterObject()
	if charObj and charObj.OnGround ~= nil then
		return charObj.OnGround == false
	end
	local humanoid = clientApi.GetHumanoid()
	if not humanoid then
		return false
	end
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
end

local function getPenetrationOpts(weapon: any): UniversalLegitbot.PenetrationPickOpts?
	if not weapon or not weapon.Properties then
		return nil
	end
	local props = weapon.Properties
	if InfinitePenetration.IsEnabled() then
		return {
			enabled = true,
			penetration = 999,
			maxRange = props.Range or 1200,
		}
	end
	local pen = props.Penetration or 0
	if pen <= 0 then
		return nil
	end
	return {
		enabled = true,
		penetration = pen,
		maxRange = props.Range or 1200,
	}
end

local function reachThroughWalls(
	origin: Vector3,
	targetPart: any,
	penetration: number,
	maxRange: number,
	ignoreRoots: { Instance },
	allowBacktrack: boolean?,
	targetPos: Vector3?
): boolean
	if InfinitePenetration.IsEnabled() then
		return true
	end
	return penetrationQuery.reachThroughWalls(
		origin,
		targetPart,
		penetration,
		maxRange,
		ignoreRoots,
		allowBacktrack,
		targetPos
	)
end

local computeRcsDelta = LPH_NO_VIRTUALIZE(
	function(weapon: any, _dt: number, verticalOnly: boolean, strength: number, cam: Camera): (number?, number?)
		local props = weapon.Properties
		if not props or props.Class ~= "Weapon" then
			return nil, nil
		end

		local rec = weapon.Recoil
		if not rec or not rec.Function then
			return nil, nil
		end

		local recoilCfg = props.Recoil
		if not recoilCfg then
			return nil, nil
		end

		if not weapon.IsShooting then
			return nil, nil
		end

		local cameraFov = cam.FieldOfView
		local effectiveStrength = strength * RCS_CALIBRATION

		local step = (rec.ActiveFireRate and rec.ActiveFireRate > 0 and rec.ActiveFireRate) or props.FireRate or 0.1
		local t = rec.Time or 0
		local t0 = math.max(0, t - step)
		local v1 = rec.Function(t0)
		local v2 = rec.Function(t)
		local delta = v2 - v1

		local scale = recoilCfg.Scale or 1
		local camScale = recoilCfg.CameraScale or 1
		local pitchRad = math.rad(delta.Y * scale * camScale * effectiveStrength)
		local yawRad = verticalOnly and 0 or (math.rad(delta.X * scale * camScale * effectiveStrength))

		local pixelsPerRad = cam.ViewportSize.Y * 0.5 / math.tan(math.rad(cameraFov * 0.5))
		local mouseDx = yawRad * pixelsPerRad
		local mouseDy = pitchRad * pixelsPerRad

		return mouseDx, mouseDy
	end
)

local Legitbot = {}

function Legitbot.new(
	link: gameUi.Linker,
	opts: {
		targettingLink: gameUi.Linker,
		aimLink: gameUi.Linker,
		triggerLink: gameUi.Linker,
		rcsLink: gameUi.Linker,
		visualsLink: gameUi.Linker,
		bulletRedirectionLink: gameUi.Linker,
	}
): UniversalLegitbot.Legitbot
	local game: UniversalLegitbot.GameOpts = {
		getLocalAlive = function(): boolean
			return peek(ClientState.alive)
		end,
		getCanSkipTeamcheck = function(): boolean
			return gamemodeState.isDeathmatch()
		end,
		getLocalTeam = function(): string?
			return ClientController.GetTeam()
		end,
		getEquippedWeapon = function(): any?
			return peek(LoadoutState.currentEquipped)
		end,
		canShoot = function(weapon: any): boolean
			return WeaponController.CanEngage(weapon)
		end,
		canFire = function(weapon: any): boolean
			return WeaponController.CanShoot(weapon)
		end,

		getLocalInAir = isLocalInAir,
		getLocalReloading = function(): boolean
			local weapon = peek(LoadoutState.currentEquipped)
			return weapon ~= nil and weapon.IsReloading == true
		end,
		getLocalOutOfAmmo = function(): boolean
			local weapon = peek(LoadoutState.currentEquipped)
			return weapon ~= nil and weapon.Rounds ~= nil and weapon.Rounds <= 0
		end,
		getLocalOnCooldown = function(): boolean
			local weapon = peek(LoadoutState.currentEquipped)
			return weapon ~= nil
				and weapon.IsReloading ~= true
				and weapon.Rounds ~= nil
				and weapon.Rounds > 0
				and weapon.IsShooting == true
		end,
		getFlashVisibility = function(): number
			return peek(ClientState.flashVisibility)
		end,

		predictDamage = predictDamage,
		estimateHitChance = spreadHitChance.estimateForPart,

		getPenetrationOpts = getPenetrationOpts,
		reachThroughWalls = reachThroughWalls,
		beginPenetrationStep = penetrationQuery.beginStep,

		getSmokeVoxels = GrenadeController.GetInternalSmokeVoxels,
		lengthThroughSmoke = smokeRay.lengthThroughSmoke,

		getBacktrackPosition = Backtrack.GetHistoricalPosition,
		getBacktrackFolder = Backtrack.GetFolder,

		setBulletRedirectionActive = bulletRedirection.setActive,
		setBulletRedirectionTarget = bulletRedirection.setTarget,
		setBulletRedirectionChance = bulletRedirection.setChance,

		bulletCreatedSignal = WeaponController.bulletCreated,
		computeRcsDelta = computeRcsDelta,

		setupScopes = scopes.build,
		subscribeWeaponChange = function(cb: (weapon: any?) -> ()): (() -> ())?
			cb(peek(LoadoutState.currentEquipped))
			local unsub = sub(LoadoutState.currentEquipped, cb)
			return unsub
		end,

		uiOpts = {
			targettingConditions = {
				"Through Smokes",
				"While Blind",
				"While In Air",
				"While Reloading",
				"While Out Of Ammo",
				"While On Cooldown",
			},
			defaultTargettingConditions = { "While On Cooldown", "While In Air" },
			showBlindThreshold = true,
			showSmokeThreshold = true,
			showAutowall = true,
			showRcs = true,
			showTrigger = true,
			showAimFirstBulletDelay = true,
			showTriggerFirstBulletDelay = true,
			showBulletRedirection = true,
		},
	}

	return UniversalLegitbot.new(link, {
		targettingLink = opts.targettingLink,
		aimLink = opts.aimLink,
		triggerLink = opts.triggerLink,
		rcsLink = opts.rcsLink,
		visualsLink = opts.visualsLink,
		bulletRedirectionLink = opts.bulletRedirectionLink,
		game = game,
	})
end

export type Legitbot = UniversalLegitbot.Legitbot

return Legitbot
