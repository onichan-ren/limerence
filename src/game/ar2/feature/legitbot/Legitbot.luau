local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local ScopeController = require("@feature/ui/scope/ScopeController")
local ClientState = require("@game/ar2/client/clientState")
local clientApi = require("@game/ar2/client/clientApi")
local WeaponController = require("@game/ar2/weapon/WeaponController")
local ModuleController = require("@game/ar2/module/ModuleController")
local UniversalLegitbot = require("@game/universal/feature/combat/legitbot/Legitbot")
local bulletRedirection = require("@game/ar2/feature/legitbot/bulletRedirection")

local peek = Charm.peek

local function isLocalInAir(): boolean
	local humanoid = clientApi.GetHumanoid()
	if not humanoid then
		return false
	end
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
end

local localPlayerModule: any = nil
local function getCharacterObject(): any
	if not localPlayerModule then
		local module = ModuleController.GetModule("LocalPlayer")
		localPlayerModule = module and module.module
	end
	local getter = localPlayerModule and localPlayerModule.get
	local arLocalPlayer = getter and getter()
	return arLocalPlayer and arLocalPlayer.Character or nil
end

local function isLocalSprinting(): boolean
	local character = getCharacterObject()
	return character ~= nil and character.MoveState == "Running"
end

local function isScopedIn(): boolean
	local character = getCharacterObject()
	return character ~= nil and character.Zooming == true
end

local Workspace = cloneref(game:GetService("Workspace"))
local effects = Workspace:FindFirstChild("Effects")

local _raycastParams = RaycastParams.new()

local shouldFilter = LPH_NO_VIRTUALIZE(function(instance: BasePart): boolean
	if instance:HasTag("Water Part") then
		return true
	end

	if instance:HasTag("Bullets Penetrate") then
		return true
	end

	if instance:HasTag("World Mesh") then
		return true
	end

	if instance.Transparency == 1 and instance.CanCollide == false then
		return true
	end

	return false
end)

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
			return true
		end,
		getLocalTeam = function(): string?
			return nil
		end,
		getEquippedWeapon = function(): any?
			return WeaponController.GetEquippedWeapon()
		end,
		canShoot = function(): boolean
			return WeaponController.CanShoot()
		end,
		canFire = function(): boolean
			return WeaponController.CanFire()
		end,
		getLocalReloading = function(): boolean
			local weapon = WeaponController.GetEquippedWeapon()
			return weapon ~= nil and weapon.Reloading == true
		end,
		getLocalOutOfAmmo = function(): boolean
			local weapon = WeaponController.GetEquippedWeapon()
			return weapon ~= nil and weapon.Reloading ~= true and not WeaponController.CanShoot()
		end,
		getLocalOnCooldown = function(): boolean
			return WeaponController.CanShoot() and not WeaponController.CanFire()
		end,

		gameRaycast = LPH_NO_VIRTUALIZE(
			function(origin: Vector3, target: Vector3, ignore: { Instance }): RaycastResult?
				_raycastParams.FilterType = Enum.RaycastFilterType.Exclude
				ignore[#ignore + 1] = effects
				_raycastParams.FilterDescendantsInstances = ignore

				return recursiveRaycast(origin, target - origin, _raycastParams)
			end
		),

		getLocalInAir = isLocalInAir,
		getLocalSprinting = isLocalSprinting,
		isScopedIn = isScopedIn,

		setBulletRedirectionActive = bulletRedirection.setActive,
		setBulletRedirectionChance = bulletRedirection.setChance,
		setBulletRedirectionTarget = bulletRedirection.setTarget,

		bulletCreatedSignal = WeaponController.shotFired,

		uiOpts = {
			targettingConditions = {
				"While In Air",
				"While Reloading",
				"While Out Of Ammo",
				"While On Cooldown",
				"While Sprinting",
				"Wait For Scope",
			},
			defaultTargettingConditions = { "While On Cooldown", "While In Air" },
			showBlindThreshold = false,
			showSmokeThreshold = false,
			showAutowall = false,
			showRcs = false,
			showTrigger = true,
			showTriggerWaitForScope = true,
			showAimFirstBulletDelay = true,
			showTriggerFirstBulletDelay = true,
			showBulletRedirection = true,
			showManipulation = true,
			showMaxDistance = true,
		},
	}

	local legitbot = UniversalLegitbot.new(link, {
		targettingLink = opts.targettingLink,
		aimLink = opts.aimLink,
		triggerLink = opts.triggerLink,
		rcsLink = opts.rcsLink,
		visualsLink = opts.visualsLink,
		bulletRedirectionLink = opts.bulletRedirectionLink,
		game = game,
	})

	local manipulationLink = opts.bulletRedirectionLink:OnKey("manipulation")
	manipulationLink:Submenu("opts", "Manipulation")
	local manipulationOpts = manipulationLink:OnKey("opts")
	manipulationOpts:Slider("originOffset", "Origin Offset", 6.9, 0, 15, 0.1, nil, "st"):SetTip({
		title = "Origin Offset",
		body = "How far shots can start away from you to reach around cover.",
	})
	manipulationOpts:Slider("hitOffset", "Hit Offset", 6.4, 0, 15, 0.1, nil, "st"):SetTip({
		title = "Hit Offset",
		body = "How far the landing point can shift off the target to reach around cover.",
	})

	legitbot:Track(ScopeController.OnChange("bulletRedirection.manipulation", function(v: any): ()
		bulletRedirection.setManipulationActive(v == true)
	end))
	legitbot:Track(ScopeController.OnChange("bulletRedirection.manipulation.opts.originOffset", function(v: any): ()
		bulletRedirection.setManipulationOriginOffset(v or 6.9)
	end))
	legitbot:Track(ScopeController.OnChange("bulletRedirection.manipulation.opts.hitOffset", function(v: any): ()
		bulletRedirection.setManipulationHitOffset(v or 6.4)
	end))

	return legitbot
end

export type Legitbot = UniversalLegitbot.Legitbot

return Legitbot
