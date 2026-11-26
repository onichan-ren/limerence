local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local clientState = require("@game/op1/client/clientState")
local UniversalLegitbot = require("@game/universal/feature/combat/legitbot/Legitbot")
local bulletRedirection = require("@game/op1/feature/legitbot/bulletRedirection")
local smokeRay = require("@game/op1/feature/legitbot/smokeRay")
local SmokeController = require("@game/op1/smoke/SmokeController")

local Workspace = cloneref(game:GetService("Workspace"))
local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer

local peek = Charm.peek

local function getEquipped(): any?
	local character = peek(clientState.charObject)
	return character and character.values and character.values.equipped
end

local function magCount(weapon: any): number
	if not weapon or not weapon.states or not weapon.states.mag then
		return 0
	end
	return weapon.states.mag:get()
end

local function isChambered(weapon: any): boolean
	return weapon ~= nil
		and weapon.states ~= nil
		and weapon.states.chambered ~= nil
		and weapon.states.chambered:get() == true
end

local function isRateReady(weapon: any): boolean
	if not weapon or not weapon.states or not weapon.states.firerate then
		return false
	end
	local firerate = weapon.states.firerate:get()
	return firerate == 0 or os.clock() - (weapon.last_shot or 0) > 1 / (firerate / 60)
end

local _raycastParams = RaycastParams.new()
_raycastParams.FilterType = Enum.RaycastFilterType.Exclude
_raycastParams.RespectCanCollide = true
_raycastParams.CollisionGroup = "char"

local Legitbot = {}

function Legitbot.new(
	link: gameUi.Linker,
	opts: {
		targettingLink: gameUi.Linker,
		aimLink: gameUi.Linker,
		triggerLink: gameUi.Linker,
		visualsLink: gameUi.Linker,
		bulletRedirectionLink: gameUi.Linker,
	}
): UniversalLegitbot.Legitbot
	local gameOpts: UniversalLegitbot.GameOpts = {
		getLocalAlive = function(): boolean
			return peek(clientState.alive)
		end,
		getLocalTeam = function(): string?
			return tostring(LocalPlayer:GetAttribute("Team") or "")
		end,
		getEquippedWeapon = getEquipped,
		canShoot = function(): boolean
			local weapon = getEquipped()
			return magCount(weapon) > 0 and isChambered(weapon)
		end,
		canFire = function(): boolean
			return isRateReady(getEquipped())
		end,
		getLocalOutOfAmmo = function(): boolean
			return magCount(getEquipped()) <= 0
		end,
		getLocalOnCooldown = function(): boolean
			local weapon = getEquipped()
			return magCount(weapon) > 0 and isChambered(weapon) and not isRateReady(weapon)
		end,

		gameRaycast = LPH_NO_VIRTUALIZE(
			function(origin: Vector3, target: Vector3, ignore: { Instance }): RaycastResult?
				local character = peek(clientState.charObject)
				if character and character.values then
					if character.instance then
						ignore[#ignore + 1] = character.instance
					end
					if character.values.viewmodels then
						ignore[#ignore + 1] = character.values.viewmodels
					end
				end

				_raycastParams.FilterDescendantsInstances = ignore

				return Workspace:Raycast(origin, target - origin, _raycastParams)
			end
		),

		setBulletRedirectionActive = bulletRedirection.setActive,
		setBulletRedirectionChance = bulletRedirection.setChance,
		setBulletRedirectionTarget = bulletRedirection.setTarget,

		getSmokeVoxels = SmokeController.GetVoxels,
		lengthThroughSmoke = smokeRay.lengthThroughSmoke,

		uiOpts = {
			targettingConditions = { "While Out Of Ammo", "While On Cooldown", "Through Smokes" },
			defaultTargettingConditions = { "While On Cooldown" },
			showBlindThreshold = false,
			showSmokeThreshold = true,
			showAutowall = false,
			showRcs = false,
			showTrigger = true,
			showAimFirstBulletDelay = true,
			showTriggerFirstBulletDelay = true,
			showBulletRedirection = true,
			showManipulation = false,
			showMaxDistance = false,
		},
	}

	local legitbot = UniversalLegitbot.new(link, {
		targettingLink = opts.targettingLink,
		aimLink = opts.aimLink,
		triggerLink = opts.triggerLink,
		visualsLink = opts.visualsLink,
		bulletRedirectionLink = opts.bulletRedirectionLink,
		game = gameOpts,
	})

	return legitbot
end

export type Legitbot = UniversalLegitbot.Legitbot

return Legitbot
