local Players = cloneref(game:GetService("Players")) :: Players
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local LocalPlayer = Players.LocalPlayer

local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local loader = require("@loader/loader")
local PlayerController = require("@feature/player/PlayerController")
local UniversalPlayer = require("@game/universal/player/UniversalPlayer")
local localState = require("@game/universal/client/localState")
local universalAdapter = require("@game/universal/adapter/universalAdapter")
local universalBots = require("@game/universal/adapter/universalBots")
local universalEvents = require("@game/universal/adapter/universalEvents")
local Tracers = require("@game/universal/adapter/Tracers")
local Legitbot = require("@game/universal/feature/combat/legitbot/Legitbot")
local AimIndicator = require("@game/universal/feature/combat/legitbot/AimIndicator")
local Esp = require("@game/universal/feature/visual/esp/Esp")
local CustomCharacter = require("@game/universal/feature/misc/CustomCharacter")
local AspectRatio = require("@game/universal/feature/visual/camera/AspectRatio")
local OverrideFov = require("@game/universal/feature/visual/camera/OverrideFov")
local CustomCrosshair = require("@game/universal/feature/visual/crosshair/CustomCrosshair")
local Radar = require("@game/universal/feature/visual/radar/Radar")
local Footsteps = require("@game/universal/feature/visual/footsteps/Footsteps")
local Impact = require("@game/universal/feature/visual/impact/Impact")
local DeathParticles = require("@game/universal/feature/visual/deathparticles/DeathParticles")
local HitSkeletons = require("@game/universal/feature/visual/hitskeletons/HitSkeletons")
local Hitmarker3d = require("@game/universal/feature/visual/hitmarker3d/Hitmarker3d")
local HitOverlay = require("@game/universal/feature/visual/hitoverlay/HitOverlay")
local Hitmarker = require("@game/universal/feature/visual/hitmarker/Hitmarker")
local HitChams = require("@game/universal/feature/visual/hitchams/HitChams")
local Hitsound = require("@game/universal/feature/visual/hitsound/Hitsound")
local HitEffect = require("@game/universal/feature/visual/hiteffect/HitEffect")
local DamageLog = require("@game/universal/feature/visual/damagelog/DamageLog")
local AccountSpoofer = require("@game/universal/feature/misc/AccountSpoofer")
local PlayerSpoofer = require("@game/universal/feature/misc/PlayerSpoofer")
local Hud = require("@game/universal/feature/visual/hud/Hud")
local MusicHud = require("@game/universal/feature/visual/musichud/MusicHud")

local peek = Charm.peek

local gameConfigState: Charm.Atom<string>? = nil

local UNARMED_WEAPON = {}

local DEFAULT_LOCAL_IMPACT_COLOR = Color3.fromRGB(190, 186, 210)
local DEFAULT_ENEMY_IMPACT_COLOR = Color3.fromRGB(220, 130, 130)

local HITSOUND_PICKER_CONFIG = {
	assetType = "sounds",
	category = "hitsound",
	assignmentTypes = {
		{
			key = "hit",
			label = "Hit",
			icon = "scope_small",
			tip = "Play on body shots",
			extras = {
				{ type = "Slider", key = "volume", args = { "Volume", 0.5, 0, 5, 0.05 } :: { any } },
			},
		},
		{
			key = "headshot",
			label = "Headshot",
			icon = "skull_small",
			tip = "Play on headshots",
			extras = {
				{ type = "Slider", key = "volume", args = { "Volume", 0.5, 0, 5, 0.05 } :: { any } },
			},
		},
		{
			key = "kill",
			label = "Kill",
			icon = "grave_small",
			tip = "Play on lethal hits",
			extras = {
				{ type = "Slider", key = "volume", args = { "Volume", 0.5, 0, 5, 0.05 } :: { any } },
			},
		},
	},
	bundle = {
		urlPrefix = "https://limerence.biz/get/",
		title = "Downloading hitsounds",
		icon = "download",
		files = {
			"Primordial.wav",
			"Neverlose.wav",
			"Sparkle.wav",
			"Bubble.wav",
			"Rifk7.wav",
			"Rust.wav",
			"Osu.mp3",
		},
	},
}

local shouldFilter = LPH_NO_VIRTUALIZE(function(instance: BasePart): boolean
	return instance.Transparency == 1 and instance.CanCollide == false
end)

local sharedRaycastParams = RaycastParams.new()
sharedRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

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

local function isLocalInAir(): boolean
	local humanoid = peek(localState.humanoid)
	if not humanoid then
		return false
	end
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
end

local isLethalHit = LPH_NO_VIRTUALIZE(function(event: universalEvents.HitEvent): boolean
	if event.lethal ~= nil then
		return event.lethal
	end
	local player = event.player
	if player then
		local data = PlayerController.Get(player)
		return data ~= nil and not data:IsAlive()
	end
	return false
end)

local function buildGameOpts(): Legitbot.GameOpts
	local overrides = universalAdapter.overrides
	return {
		getLocalAlive = function(): boolean
			local resolver = overrides.resolveLocalAlive
			if resolver then
				return resolver()
			end
			return peek(localState.alive)
		end,
		getLocalTeam = function(): string?
			local resolver = overrides.resolveLocalTeam
			if resolver then
				return resolver()
			end
			return peek(localState.team)
		end,
		getCanSkipTeamcheck = function(): boolean
			local state = gameConfigState
			return state ~= nil and peek(state) == "None"
		end,
		getEquippedWeapon = function(): any
			local weapon = universalAdapter.GetEquippedWeapon()
			if weapon == nil then
				return UNARMED_WEAPON
			end
			return weapon
		end,
		canShoot = universalAdapter.CanShoot,
		canFire = function(weapon: any): boolean
			local fn = overrides.canFire
			if fn then
				return fn(weapon)
			end
			return universalAdapter.CanShoot(weapon)
		end,
		fire = function(weapon: any): ()
			local fn = overrides.fire
			if fn then
				fn(weapon)
			else
				mouse1click()
			end
		end,
		stopFire = function(): ()
			local fn = overrides.stopFire
			if fn then
				fn()
			end
		end,
		getHitboxParts = universalAdapter.GetHitboxParts,
		getLocalInAir = isLocalInAir,
		getExtraTargets = universalBots.GetAll,
		getAimPoint2d = function(): Vector2
			return UserInputService:GetMouseLocation()
		end,

		gameRaycast = LPH_NO_VIRTUALIZE(
			function(origin: Vector3, target: Vector3, ignore: { Instance }): RaycastResult?
				local raycastParams = sharedRaycastParams
				raycastParams.FilterDescendantsInstances = ignore

				return recursiveRaycast(origin, target - origin, raycastParams)
			end
		),

		subscribeWeaponChange = function(cb: (weapon: any?) -> ()): (() -> ())?
			cb(universalAdapter.GetEquippedWeapon())
			return Charm.subscribe(universalAdapter.equippedWeapon, cb)
		end,

		uiOpts = {
			targettingConditions = { "While In Air" },
			defaultTargettingConditions = {},
			showBlindThreshold = false,
			showSmokeThreshold = false,
			showAutowall = false,
			showRcs = false,
			showTrigger = true,
			showHitChance = false,
			showMinDamage = false,
			showAimFirstBulletDelay = false,
			showTriggerFirstBulletDelay = false,
			showManipulation = false,
			showTriggerBullets = false,
			showBulletRedirection = false,
			showMaxDistance = true,
		},
	}
end

return function(): ()
	PlayerController.SetPlayerClass(UniversalPlayer)
	PlayerController.new()
	loader.addDestroyer(PlayerController.Destroy)

	localState.setup()
	loader.addDestroyer(localState.Destroy)

	universalAdapter.setup()
	loader.addDestroyer(universalAdapter.Destroy)
	loader.addDestroyer(universalBots.Clear)

	local assistance = gameUi.Group("ASSISTANCE")

	local legitbot = gameUi.Tab(assistance, "Legitbot", "rifle")
	local legitbotLink = gameUi.ScopedSection(legitbot, "MAIN", 1, "legitbot")
	local targettingLink = gameUi.ScopedSection(legitbot, "TARGETTING", 1, "targetting")
	local aimLink = gameUi.ScopedSection(legitbot, "AIM", 1, "aim")
	local triggerLink = gameUi.ScopedSection(legitbot, "TRIGGER", 2, "trigger")
	local legitbotVisualsLink = gameUi.ScopedSection(legitbot, "VISUALS", 2, "visuals")

	legitbot:UseScope(true)
	gameUi.Mount(AimIndicator, legitbotVisualsLink)
	gameUi.Mount(Legitbot, legitbotLink, {
		targettingLink = targettingLink,
		aimLink = aimLink,
		triggerLink = triggerLink,
		visualsLink = legitbotVisualsLink,
		bulletRedirectionLink = triggerLink,
		game = buildGameOpts(),
	})

	local visuals = gameUi.Group("VISUALS")
	local players = gameUi.Tab(visuals, "Players", "person")
	local espLink = gameUi.Section(players, "PLAYER ESP", 1, "esp")
	gameUi.Mount(Esp, espLink, {
		previewLink = espLink,
		targetSource = universalBots,
		filter = function(basePlayer: any): boolean
			local filter = universalAdapter.overrides.espFilter
			if filter and filter(basePlayer:GetPlayer()) == false then
				return true
			end
			local config = gameConfigState
			if config and peek(config) == "Team Based" then
				local localTeam: string?
				local resolver = universalAdapter.overrides.resolveLocalTeam
				if resolver then
					localTeam = resolver()
				else
					localTeam = peek(localState.team)
				end
				return localTeam ~= nil and localTeam ~= "" and peek(basePlayer.team) == localTeam
			end
			return false
		end,
	})

	local selfLink = gameUi.Section(players, "SELF", 2, "self")
	gameUi.Mount(CustomCharacter, selfLink)
	gameUi.Mount(Footsteps, selfLink, {
		getCharacter = function(): Instance?
			return peek(localState.character)
		end,
		isAlive = function(): boolean
			return peek(localState.alive)
		end,
		getParts = function(): { [string]: Instance }
			return peek(localState.parts)
		end,
	})

	local effectsLink = gameUi.Section(players, "HIT FEEDBACK", 2, "effects")
	gameUi.Mount(DeathParticles, effectsLink, {
		connect = function(onKill: (player: Player, position: Vector3?) -> ())
			return universalEvents.kill:Connect(LPH_NO_VIRTUALIZE(function(event: universalEvents.KillEvent): ()
				local player = event.player
				if player then
					onKill(player, event.position)
				end
			end))
		end,
	})
	gameUi.Mount(HitSkeletons, effectsLink, {
		connectHit = function(handler: (player: Player) -> ())
			return universalEvents.hit:Connect(LPH_NO_VIRTUALIZE(function(event: universalEvents.HitEvent): ()
				local player = event.player
				if player then
					handler(player)
				end
			end))
		end,
	})
	gameUi.Mount(Hitmarker3d, effectsLink, {
		connect = function(emit: (position: Vector3, headshot: boolean) -> ())
			return universalEvents.hit:Connect(LPH_NO_VIRTUALIZE(function(event: universalEvents.HitEvent): ()
				local position = event.position
				if position then
					emit(position, event.headshot)
				end
			end))
		end,
	})
	gameUi.Mount(HitOverlay, effectsLink, {
		connect = function(emit: (headshot: boolean) -> ())
			return universalEvents.hit:Connect(LPH_NO_VIRTUALIZE(function(event: universalEvents.HitEvent): ()
				emit(event.headshot)
			end))
		end,
	})
	gameUi.Mount(Hitmarker, effectsLink, {
		connect = function(emit: (headshot: boolean) -> ())
			return universalEvents.hit:Connect(LPH_NO_VIRTUALIZE(function(event: universalEvents.HitEvent): ()
				emit(event.headshot)
			end))
		end,
	})
	gameUi.Mount(HitChams, effectsLink, {
		connectHit = function(handler: (player: Player) -> ())
			return universalEvents.hit:Connect(LPH_NO_VIRTUALIZE(function(event: universalEvents.HitEvent): ()
				local player = event.player
				if player then
					handler(player)
				end
			end))
		end,
	})
	gameUi.Mount(Hitsound, effectsLink, {
		pickerConfig = HITSOUND_PICKER_CONFIG,
		connect = function(play: (kind: string) -> ())
			return universalEvents.hit:Connect(LPH_NO_VIRTUALIZE(function(event: universalEvents.HitEvent): ()
				if event.headshot then
					play("headshot")
				elseif isLethalHit(event) then
					play("kill")
				else
					play("hit")
				end
			end))
		end,
	})
	gameUi.Mount(HitEffect, effectsLink, {
		connect = function(play: (kind: string, position: Vector3) -> ())
			return universalEvents.hit:Connect(LPH_NO_VIRTUALIZE(function(event: universalEvents.HitEvent): ()
				local position = event.position
				if not position then
					return
				end
				if event.headshot then
					play("headshot", position)
				elseif isLethalHit(event) then
					play("lethal", position)
				else
					play("hit", position)
				end
			end))
		end,
	})
	gameUi.Mount(DamageLog, effectsLink, {
		key = "hitLogs",
		label = "Hit Logs",
		tip = {
			title = "Hit Logs",
			body = "Shows a notification each time you hit an enemy, including the target and hitbox.",
		},
		connect = function(emit: (text: string) -> ())
			local connection = universalEvents.hit:Connect(function(event: universalEvents.HitEvent): ()
				local player = event.player
				if not player then
					return
				end
				local name = player.DisplayName ~= "" and player.DisplayName or player.Name
				local label = event.headshot and "head" or "body"
				if event.damage then
					emit(
						"Hit <hl>"
							.. name
							.. "</hl> in the <hl>"
							.. label
							.. "</hl> for <hl>"
							.. tostring(math.floor(event.damage + 0.5))
							.. "</hl>"
					)
				else
					emit("Hit <hl>" .. name .. "</hl> in the <hl>" .. label .. "</hl>")
				end
			end)
			return function()
				connection:Disconnect()
			end
		end,
	})

	local world = gameUi.Tab(visuals, "World", "globe")
	local worldEffectsLink = gameUi.Section(world, "EFFECTS", 1, "effects")
	gameUi.Mount(Tracers, worldEffectsLink)
	gameUi.Mount(Impact, worldEffectsLink, {
		rootKey = "bulletImpacts",
		rootLabel = "Bullet Impacts",
		sources = {
			{
				key = "localImpacts",
				label = "Local Impacts",
				defaultColor = DEFAULT_LOCAL_IMPACT_COLOR,
				body = "Draws impacts for your own shots.",
				connect = function(ctx: Impact.ImpactCtx)
					return universalEvents.shot:Connect(
						LPH_NO_VIRTUALIZE(function(event: universalEvents.ShotEvent): ()
							local player = event.player
							if player == nil or player == LocalPlayer then
								ctx.spawn({ event.target })
							end
						end)
					)
				end,
			},
			{
				key = "enemyImpacts",
				label = "Enemy Impacts",
				defaultColor = DEFAULT_ENEMY_IMPACT_COLOR,
				body = "Draws impacts for shots fired by other players.",
				connect = function(ctx: Impact.ImpactCtx)
					return universalEvents.shot:Connect(
						LPH_NO_VIRTUALIZE(function(event: universalEvents.ShotEvent): ()
							local player = event.player
							if player ~= nil and player ~= LocalPlayer then
								ctx.spawn({ event.target })
							end
						end)
					)
				end,
			},
		},
	})

	local viewLink = gameUi.Section(world, "VIEW", 2, "overlay")
	gameUi.Mount(CustomCrosshair, viewLink)
	gameUi.Mount(OverrideFov, viewLink)
	gameUi.Mount(AspectRatio, viewLink)
	gameUi.Mount(Radar, viewLink, {
		isTeammate = function(basePlayer: any): boolean
			local localTeam = peek(localState.team)
			return localTeam ~= "" and basePlayer:GetTeam() == localTeam
		end,
	})
	gameUi.Mount(MusicHud, gameUi.SettingsHudSection("hud"))
	gameUi.Mount(Hud, viewLink)

	local other = gameUi.Group("OTHER")
	local misc = gameUi.Tab(other, "Misc", "bolt")

	local spoofingLink = gameUi.Section(misc, "SPOOFING", 1, "spoofing")
	gameUi.Mount(AccountSpoofer, spoofingLink)
	gameUi.Mount(PlayerSpoofer, spoofingLink)

	local gameLink = gameUi.Section(misc, "GAME", 1, "game")
	gameLink:Dropdown("gameConfiguration", "Game Configuration", { "Team Based", "None" }, "Team Based"):SetTip({
		title = "Game Configuration",
		body = "Team Based treats players on your team as friendly, hiding them from the ESP and skipping them for aim assistance. None targets and shows everyone, for free for all games where everyone shares one team.",
	})
	gameConfigState = gameLink:Get("gameConfiguration")._state
end
