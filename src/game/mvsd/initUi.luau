local gameUi = require("@game/gameUi")
local loader = require("@loader/loader")
local PlayerController = require("@feature/player/PlayerController")
local AimIndicator = require("@game/universal/feature/combat/legitbot/AimIndicator")
local ShootOriginIndicator = require("@game/mvsd/feature/legitbot/ShootOriginIndicator")
local MvsdPlayer = require("@game/mvsd/player/MvsdPlayer")
local Esp = require("@game/mvsd/feature/visual/esp/Esp")
local SelfChams = require("@game/mvsd/feature/visual/self/SelfChams")
local Footsteps = require("@game/mvsd/feature/visual/self/Footsteps")
local Legitbot = require("@game/mvsd/feature/legitbot/Legitbot")
local Killall = require("@game/mvsd/feature/combat/killall/Killall")
local AutoPeek = require("@game/mvsd/feature/ragebot/AutoPeek")
local RotationPeek = require("@game/mvsd/feature/combat/peek/RotationPeek")
local AutoPeekRotation = require("@game/mvsd/feature/combat/peek/AutoPeekRotation")
local Backtrack = require("@game/mvsd/feature/ragebot/Backtrack")
local HitOverlay = require("@game/mvsd/feature/visual/hitoverlay/HitOverlay")
local Hitmarker = require("@game/mvsd/feature/visual/hitmarker/Hitmarker")
local Hitmarker3d = require("@game/mvsd/feature/visual/hitmarker/Hitmarker3d")
local Hitchams = require("@game/mvsd/feature/visual/hitchams/HitChams")
local Hitskeletons = require("@game/mvsd/feature/visual/hitskeletons/HitSkeletons")
local Hitsound = require("@game/mvsd/feature/visual/hitsound/Hitsound")
local HitEffect = require("@game/mvsd/feature/visual/hiteffect/HitEffect")
local DeathParticles = require("@game/mvsd/feature/visual/deathparticles/DeathParticles")
local HitLog = require("@game/mvsd/feature/visual/hitlog/Hitlog")
local Tracer = require("@game/mvsd/feature/visual/tracer/Tracer")
local Impact = require("@game/mvsd/feature/visual/impact/Impact")
local Removals = require("@game/mvsd/feature/visual/removals/Removals")
local WorldAmbience = require("@game/universal/feature/visual/world/WorldAmbience")
local AspectRatio = require("@game/universal/feature/visual/camera/AspectRatio")
local OverrideFov = require("@game/universal/feature/visual/camera/OverrideFov")
local CustomCrosshair = require("@game/universal/feature/visual/crosshair/CustomCrosshair")
local mvsdShootOrigin = require("@game/mvsd/feature/visual/crosshair/mvsdShootOrigin")
local gameCrosshair = require("@game/mvsd/feature/visual/crosshair/gameCrosshair")
local Radar = require("@game/mvsd/feature/visual/radar/Radar")
local CustomCharacter = require("@game/universal/feature/misc/CustomCharacter")
local Hud = require("@game/universal/feature/visual/hud/Hud")
local MusicHud = require("@game/universal/feature/visual/musichud/MusicHud")
local worldMapSource = require("@game/mvsd/feature/visual/world/worldMapSource")
local gameRegistry = require("@game/gameRegistry")
local FlashEsp = require("@game/mvsd/feature/visual/world/FlashEsp")
local shroudCooldownTracker = require("@game/mvsd/feature/visual/world/shroudCooldownTracker")
local AccountSpoofer = require("@game/universal/feature/misc/AccountSpoofer")
local PlayerSpoofer = require("@game/universal/feature/misc/PlayerSpoofer")
local AntiAfk = require("@game/universal/feature/misc/AntiAfk")
local StatsSpoofer = require("@game/mvsd/feature/misc/StatsSpoofer")
local AutoQueue = require("@game/mvsd/feature/misc/AutoQueue")
local AutoVoteMap = require("@game/mvsd/feature/misc/AutoVoteMap")
local Invisible = require("@game/mvsd/feature/misc/Invisible")
local MatchLagger = require("@game/mvsd/feature/misc/MatchLagger")
local Flight = require("@game/mvsd/feature/misc/Flight")
local FakeLag = require("@game/mvsd/feature/misc/FakeLag")
local Speed = require("@game/mvsd/feature/misc/Speed")
local AnimationChanger = require("@game/mvsd/feature/misc/AnimationChanger")
local AnimationPlayer = require("@game/mvsd/feature/misc/AnimationPlayer")
local SpectatorList = require("@game/mvsd/feature/misc/SpectatorList")

return function(): ()
	PlayerController.SetPlayerClass(MvsdPlayer)
	PlayerController.new()
	loader.addDestroyer(PlayerController.Destroy)

	shroudCooldownTracker.start()
	loader.addDestroyer(shroudCooldownTracker.stop)

	mvsdShootOrigin.Setup()
	loader.addDestroyer(mvsdShootOrigin.Destroy)

	local assistance = gameUi.Group("ASSISTANCE")

	local legitbot = gameUi.Tab(assistance, "Legitbot", "rifle")
	local legitbotLink = gameUi.ScopedSection(legitbot, "MAIN", 1, "legitbot")
	local targettingLink = gameUi.ScopedSection(legitbot, "TARGETTING", 1, "targetting")
	local aimLink = gameUi.ScopedSection(legitbot, "AIM", 1, "aim")
	local bulletRedirectionLink = gameUi.ScopedSection(legitbot, "BULLET REDIRECTION", 1, "bulletRedirection")
	local triggerLink = gameUi.ScopedSection(legitbot, "TRIGGER", 2, "trigger")
	local legitbotVisualsLink = gameUi.ScopedSection(legitbot, "VISUALS", 2, "visuals")

	legitbot:UseScope(true)
	gameUi.Mount(ShootOriginIndicator, legitbotVisualsLink)
	gameUi.Mount(AimIndicator, legitbotVisualsLink)
	gameUi.Mount(Legitbot, legitbotLink, {
		targettingLink = targettingLink,
		aimLink = aimLink,
		triggerLink = triggerLink,
		visualsLink = legitbotVisualsLink,
		bulletRedirectionLink = bulletRedirectionLink,
	})

	local backtrackLink = gameUi.Section(legitbot, "BACKTRACK", 2, "backtrack")
	gameUi.Mount(Backtrack, backtrackLink)

	local visuals = gameUi.Group("VISUALS")
	local players = gameUi.Tab(visuals, "Players", "person")
	local espLink = gameUi.Section(players, "PLAYER ESP", 1, "esp")
	gameUi.Mount(Esp, espLink, { previewLink = espLink })

	local selfEspLink = gameUi.Section(players, "SELF", 2, "selfEsp")
	gameUi.Mount(CustomCharacter, selfEspLink)
	gameUi.Mount(SelfChams, selfEspLink, {
		key = "characterChams",
		label = "Character Chams",
		tip = "Recolors your own character body.",
		scope = "body",
		color = Color3.fromRGB(145, 190, 215),
		material = "Neon",
	})
	gameUi.Mount(SelfChams, selfEspLink, {
		key = "weaponChams",
		label = "Weapon Chams",
		tip = "Recolors your own equipped weapon.",
		scope = "weapon",
		color = Color3.fromRGB(168, 168, 168),
		material = "Neon",
	})
	gameUi.Mount(Footsteps, selfEspLink)

	local effectsLink = gameUi.Section(players, "HIT FEEDBACK", 2, "effects")
	gameUi.Mount(DeathParticles, effectsLink)
	gameUi.Mount(Hitskeletons, effectsLink)
	gameUi.Mount(Hitmarker3d, effectsLink)
	gameUi.Mount(HitOverlay, effectsLink)
	gameUi.Mount(Hitmarker, effectsLink)
	gameUi.Mount(Hitchams, effectsLink)
	gameUi.Mount(Hitsound, effectsLink)
	gameUi.Mount(HitEffect, effectsLink)
	gameUi.Mount(HitLog, effectsLink)

	local world = gameUi.Tab(visuals, "World", "globe")
	local ambienceLink = gameUi.Section(world, "AMBIENCE", 1, "modulations")
	gameRegistry.mapSource = worldMapSource
	gameUi.Mount(WorldAmbience, ambienceLink, {
		mapSource = worldMapSource,
	})

	local worldEffectsLink = gameUi.Section(world, "EFFECTS", 2, "effects")
	gameUi.Mount(Tracer, worldEffectsLink)
	gameUi.Mount(Impact, worldEffectsLink)
	gameUi.Mount(Removals, worldEffectsLink)
	gameUi.Mount(FlashEsp, worldEffectsLink)

	local viewLink = gameUi.Section(world, "VIEW", 1, "overlay")
	gameUi.Mount(CustomCrosshair, viewLink, {
		setGameCrosshairHidden = gameCrosshair.SetHidden,
	})
	gameUi.Mount(SpectatorList, viewLink)
	gameUi.Mount(OverrideFov, viewLink)
	gameUi.Mount(AspectRatio, viewLink)
	gameUi.Mount(Radar, viewLink)
	gameUi.Mount(MusicHud, gameUi.SettingsHudSection("hud"))
	gameUi.Mount(Hud, viewLink)

	local other = gameUi.Group("OTHER")
	local misc = gameUi.Tab(other, "Misc", "bolt")

	local movementLink = gameUi.Section(misc, "MOVEMENT", 1, "movement")
	gameUi.Mount(AnimationChanger, movementLink)
	gameUi.Mount(AutoPeekRotation, movementLink)
	gameUi.Mount(AnimationPlayer, movementLink)
	--gameUi.Mount(RotationPeek, movementLink)
	gameUi.Mount(AutoPeek, movementLink)
	gameUi.Mount(FakeLag, movementLink)
	gameUi.Mount(Speed, movementLink)
	gameUi.Mount(Flight, movementLink)

	local spoofingLink = gameUi.Section(misc, "SPOOFING", 1, "spoofing")
	gameUi.Mount(AccountSpoofer, spoofingLink)
	gameUi.Mount(PlayerSpoofer, spoofingLink)
	gameUi.Mount(StatsSpoofer, spoofingLink)

	local matchmakingLink = gameUi.Section(misc, "MATCHMAKING", 2, "matchmaking")
	gameUi.Mount(AutoVoteMap, matchmakingLink)
	gameUi.Mount(AutoQueue, matchmakingLink)
	gameUi.Mount(AntiAfk, matchmakingLink)

	local exploitsLink = gameUi.Section(misc, "EXPLOITS", 2, "exploits")
	gameUi.Mount(MatchLagger, exploitsLink)
	gameUi.Mount(Invisible, exploitsLink)
	gameUi.Mount(Killall, exploitsLink)
end
