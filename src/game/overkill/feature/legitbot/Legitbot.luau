local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local ScopeController = require("@feature/ui/scope/ScopeController")
local ClientState = require("@game/overkill/client/clientState")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local botSource = require("@game/overkill/feature/training/botSource")
local bulletRedirection = require("@game/overkill/feature/legitbot/bulletRedirection")
local Backtrack = require("@game/overkill/feature/legitbot/BacktrackController")
local gunCategories = require("@game/overkill/weapon/gunCategories")
local scopes = require("@game/overkill/feature/legitbot/scopes")
local deflectPov = require("@game/overkill/feature/legitbot/deflectPov")
local targeting = require("@game/overkill/player/targeting")
local worldRaycast = require("@game/overkill/weapon/worldRaycast")
local UniversalLegitbot = require("@game/universal/feature/combat/legitbot/Legitbot")

local peek = Charm.peek
local sub = Charm.subscribe

local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local WEAPON = {}

local OVERKILL_HITBOX_PARTS = targeting.HITBOX_PARTS

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
	local game: UniversalLegitbot.GameOpts = {
		getLocalAlive = function(): boolean
			return peek(ClientState.alive)
		end,
		getLocalTeam = function(): string?
			return peek(ClientState.team)
		end,
		getEquippedWeapon = function(): any?
			if not gunCategories[peek(ClientState.weaponCategory)] then
				return nil
			end
			return WEAPON
		end,
		canShoot = LPH_NO_VIRTUALIZE(function(_weapon: any): boolean
			if peek(ClientState.isReloading) then
				return false
			end
			if peek(ClientState.magSize) <= 0 then
				return true
			end
			return peek(ClientState.ammo) > 0
		end),
		canFire = LPH_NO_VIRTUALIZE(function(_weapon: any): boolean
			return peek(ClientState.canFire)
		end),
		isAiming = function(): boolean
			return peek(ClientState.aiming)
		end,
		isScopedIn = LPH_NO_VIRTUALIZE(function(): boolean
			if peek(ClientState.weaponCategory) ~= "sniper_rifle" then
				return true
			end
			return peek(ClientState.aiming)
		end),
		getLocalReloading = function(): boolean
			return peek(ClientState.isReloading)
		end,
		getLocalOutOfAmmo = function(): boolean
			return peek(ClientState.magSize) > 0 and peek(ClientState.ammo) <= 0
		end,
		getLocalOnCooldown = function(): boolean
			if peek(ClientState.isReloading) then
				return false
			end
			if peek(ClientState.magSize) > 0 and peek(ClientState.ammo) <= 0 then
				return false
			end
			return not peek(ClientState.canFire)
		end,
		getLocalInAir = function(): boolean
			return peek(ClientState.inAir)
		end,
		getAimPoint2d = function(): Vector2
			return UserInputService:GetMouseLocation()
		end,
		getFlashVisibility = function(): number
			return 0
		end,
		getExtraTargets = botSource.GetAll,
		setupScopes = scopes.build,
		subscribeWeaponChange = function(cb: (weapon: any?) -> ()): (() -> ())?
			local function emit(name: string): ()
				cb(name ~= "" and { Name = name } or nil)
			end
			emit(peek(ClientState.weapon))
			return sub(ClientState.weapon, emit)
		end,
		isPlayerBlocking = LPH_NO_VIRTUALIZE(function(player: any): boolean
			if player.isBot then
				return false
			end
			local localMatch = peek(ClientState.matchId)
			if localMatch == nil then
				return true
			end
			if peek(player.matchId) ~= localMatch then
				return true
			end
			local localTeam = peek(ClientState.team)
			return localTeam ~= "" and peek(player.team) == localTeam
		end),
		isPlayerDeflecting = deflectPov.isPlayerDeflecting,
		getHitboxParts = function(hitboxName: string): { string }?
			return OVERKILL_HITBOX_PARTS[hitboxName]
		end,
		fire = function(_weapon: any): ()
			WeaponController.Fire()
		end,
		stopFire = function(): ()
			WeaponController.StopFire()
		end,
		setBulletRedirectionActive = bulletRedirection.setActive,
		setBulletRedirectionTarget = bulletRedirection.setTarget,
		setBulletRedirectionChance = bulletRedirection.setChance,
		getBacktrackPosition = Backtrack.GetHistoricalPosition,
		getBacktrackFolder = Backtrack.GetFolder,
		gameRaycast = worldRaycast.cast,
		uiOpts = {
			targettingConditions = {
				"While Reloading",
				"While Out Of Ammo",
				"While On Cooldown",
				"While In Air",
				"Wait For Aim",
				"Wait For Scope",
				"Avoid Deflecting",
			},
			defaultTargettingConditions = { "While On Cooldown", "While In Air", "Avoid Deflecting" },
			showBlindThreshold = false,
			showSmokeThreshold = false,
			showAutowall = false,
			showRcs = false,
			showTrigger = true,
			showTriggerBullets = true,
			showTriggerWaitForScope = true,
			showTriggerWaitForAim = true,
			showTriggerAvoidDeflecting = true,
			showHitChance = false,
			showMinDamage = false,
			showAimFirstBulletDelay = false,
			showTriggerFirstBulletDelay = false,
			showManipulation = false,
			showBulletRedirection = true,
		},
	}

	local legitbot = UniversalLegitbot.new(link, {
		targettingLink = opts.targettingLink,
		aimLink = opts.aimLink,
		triggerLink = opts.triggerLink,
		visualsLink = opts.visualsLink,
		bulletRedirectionLink = opts.bulletRedirectionLink,
		game = game,
	} :: any)

	opts.bulletRedirectionLink:Toggle("noSpread", "No Spread", false):SetTip({
		title = "No Spread",
		body = "Removes weapon spread so shots land exactly where they are sent.",
	})
	legitbot:Track(ScopeController.OnChange("bulletRedirection.noSpread", function(value: any): ()
		bulletRedirection.setNoSpread(value == true)
	end))

	return legitbot
end

export type Legitbot = UniversalLegitbot.Legitbot

return Legitbot
