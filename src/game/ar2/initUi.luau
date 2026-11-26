local gameUi = require("@game/gameUi")
local loader = require("@loader/loader")
local WorldAmbience = require("@game/universal/feature/visual/world/WorldAmbience")
local AspectRatio = require("@game/universal/feature/visual/camera/AspectRatio")
local AimIndicator = require("@game/universal/feature/combat/legitbot/AimIndicator")
local PlayerController = require("@feature/player/PlayerController")
local Esp = require("@game/ar2/feature/visuals/esp/Esp")
local Tracer = require("@game/ar2/feature/visuals/tracer/Tracer")
local Legitbot = require("@game/ar2/feature/legitbot/Legitbot")
local Ragebot = require("@game/ar2/feature/ragebot/Ragebot")
local AntiAim = require("@game/ar2/feature/ragebot/AntiAim")
local Impact = require("@game/ar2/feature/visuals/impact/Impact")
local HitLog = require("@game/ar2/feature/visuals/hitlog/Hitlog")
local Hitsound = require("@game/ar2/feature/visuals/hitsound/Hitsound")
local Hitmarker = require("@game/ar2/feature/visuals/hitmarker/Hitmarker")
local Hitmarker3d = require("@game/ar2/feature/visuals/hitmarker/Hitmarker3d")
local DamageNumber3d = require("@game/ar2/feature/visuals/damagenumber3d/DamageNumber3d")
local Hitchams = require("@game/ar2/feature/visuals/hitchams/HitChams")
local Hitskeletons = require("@game/ar2/feature/visuals/hitskeletons/HitSkeletons")
local HitOverlay = require("@game/ar2/feature/visuals/hitoverlay/HitOverlay")
local HitEffect = require("@game/ar2/feature/visuals/hiteffect/HitEffect")
local Removals = require("@game/ar2/feature/visuals/removals/Removals")
local SoundRemovals = require("@game/ar2/feature/visuals/removals/SoundRemovals")
local AnimationRemovals = require("@game/ar2/feature/visuals/removals/AnimationRemovals")
local CustomScope = require("@game/ar2/feature/visuals/removescope/CustomScope")
local InteractHighlight = require("@game/ar2/feature/visuals/world/InteractHighlight")
local Zoom = require("@game/ar2/feature/visuals/zoom/Zoom")
local Freecam = require("@game/ar2/feature/visuals/freecam/Freecam")
local CorpseEsp = require("@game/ar2/feature/visuals/world/CorpseEsp")
local MapEsp = require("@game/ar2/feature/visuals/world/MapEsp")
local VehicleEsp = require("@game/ar2/feature/visuals/world/VehicleEsp")
local ZombieChams = require("@game/ar2/feature/visuals/world/ZombieChams")
local HideInventoryCharacter = require("@game/ar2/feature/visuals/world/HideInventoryCharacter")
local SelfChams = require("@game/ar2/feature/visuals/self/SelfChams")
local Footsteps = require("@game/ar2/feature/visuals/self/Footsteps")
local VehicleChams = require("@game/ar2/feature/visuals/self/VehicleChams")
local ViewmodelChanger = require("@game/ar2/feature/visuals/self/ViewmodelChanger")
local ShootWhileSprint = require("@game/ar2/feature/misc/ShootWhileSprint")
local AlwaysSprint = require("@game/ar2/feature/misc/AlwaysSprint")
local AimWhileSprint = require("@game/ar2/feature/misc/AimWhileSprint")
local NoFallStun = require("@game/ar2/feature/misc/NoFallStun")
local NoSwimLimits = require("@game/ar2/feature/misc/NoSwimLimits")
local InventoryMove = require("@game/ar2/feature/misc/InventoryMove")
local NoClip = require("@game/ar2/feature/misc/NoClip")
local MeleeAura = require("@game/ar2/feature/misc/MeleeAura")
local FakeLag = require("@game/ar2/feature/misc/FakeLag")
local InfiniteJump = require("@game/ar2/feature/misc/InfiniteJump")
local Spider = require("@game/ar2/feature/misc/Spider")
local InstantClimb = require("@game/ar2/feature/misc/InstantClimb")
local InstantVault = require("@game/ar2/feature/misc/InstantVault")
local SquadFriendly = require("@game/ar2/feature/misc/SquadFriendly")
local NoJumpCooldown = require("@game/ar2/feature/misc/NoJumpCooldown")
local NoFlinch = require("@game/ar2/feature/misc/NoFlinch")
local InstantReload = require("@game/ar2/feature/misc/InstantReload")
local InstantAim = require("@game/ar2/feature/misc/InstantAim")
local BurstFire = require("@game/ar2/feature/misc/BurstFire")
local BurstMelee = require("@game/ar2/feature/misc/BurstMelee")
local NoStagger = require("@game/ar2/feature/misc/NoStagger")
local AutoPing = require("@game/ar2/feature/misc/AutoPing")
local VehicleFly = require("@game/ar2/feature/misc/VehicleFly")
local VehicleMods = require("@game/ar2/feature/misc/VehicleMods")
local VehicleAura = require("@game/ar2/feature/misc/VehicleAura")
local InstantSearch = require("@game/ar2/feature/misc/InstantSearch")
local FastUse = require("@game/ar2/feature/misc/FastUse")
local UseWhileFalling = require("@game/ar2/feature/misc/UseWhileFalling")
local AutoLoot = require("@game/ar2/feature/misc/AutoLoot")
local InventoryController = require("@game/ar2/feature/inventory/InventoryController")
local FastRespawn = require("@game/ar2/feature/misc/FastRespawn")
local FreezeZombies = require("@game/ar2/feature/misc/FreezeZombies")
local ReduceRecoil = require("@game/ar2/feature/legitbot/ReduceRecoil")
local ManipBar = require("@game/ar2/feature/legitbot/ManipBar")
local StaffDetector = require("@game/ar2/feature/misc/StaffDetector")
local AccountSpoofer = require("@game/universal/feature/misc/AccountSpoofer")
local CustomCrosshair = require("@game/universal/feature/visual/crosshair/CustomCrosshair")
local Hud = require("@game/universal/feature/visual/hud/Hud")
local MusicHud = require("@game/universal/feature/visual/musichud/MusicHud")
local ar2MuzzleOrigin = require("@game/ar2/feature/visuals/crosshair/ar2MuzzleOrigin")

return function(): ()
	local ARPlayer = require("@game/ar2/player/ARPlayer")
	PlayerController.SetPlayerClass(ARPlayer)
	PlayerController.new()
	loader.addDestroyer(PlayerController.Destroy)

	require("@game/ar2/player/arPlayerDetail").Setup()

	ar2MuzzleOrigin.Setup()
	loader.addDestroyer(ar2MuzzleOrigin.Destroy)

	local assistance = gameUi.Group("ASSISTANCE")
	local ragebot = gameUi.Tab(assistance, "Ragebot", "aim")
	ragebot:UseScope(true)
	local aimbotLink = gameUi.ScopedSection(ragebot, "AIMBOT", 1, "arAimbot")
	local aimbotTargetingLink = gameUi.ScopedSection(ragebot, "TARGETING", 1, "arAimbotTargeting")
	local aimbotFiltersLink = gameUi.ScopedSection(ragebot, "FILTERS", 1, "arAimbotFilters")
	local aimbotPerformanceLink = gameUi.ScopedSection(ragebot, "PERFORMANCE", 1, "arAimbotPerformance")
	local aimbotVisualsLink = gameUi.Section(ragebot, "VISUALS", 1, "arAimbotVisuals")
	gameUi.Mount(Ragebot, aimbotLink, {
		targetingLink = aimbotTargetingLink,
		filtersLink = aimbotFiltersLink,
		performanceLink = aimbotPerformanceLink,
		visualsLink = aimbotVisualsLink,
	})

	local antiAimLink = gameUi.Section(ragebot, "ANTI AIM", 2, "arAntiAim")
	gameUi.Mount(AntiAim, antiAimLink)

	local weaponLink = gameUi.Section(ragebot, "WEAPON", 2, "arWeapon")
	gameUi.Mount(InstantReload, weaponLink)
	gameUi.Mount(InstantAim, weaponLink)
	gameUi.Mount(NoFlinch, weaponLink)
	gameUi.Mount(BurstFire, weaponLink)

	local meleeLink = gameUi.Section(ragebot, "MELEE", 2, "arMelee")
	gameUi.Mount(MeleeAura, meleeLink)
	gameUi.Mount(BurstMelee, meleeLink)

	local legitbot = gameUi.Tab(assistance, "Legitbot", "rifle")
	local legitbotLink = gameUi.ScopedSection(legitbot, "MAIN", 1, "legitbot")
	local targettingLink = gameUi.ScopedSection(legitbot, "TARGETTING", 1, "targetting")
	local aimLink = gameUi.ScopedSection(legitbot, "AIM", 1, "aim")
	local bulletRedirectionLink = gameUi.ScopedSection(legitbot, "BULLET REDIRECTION", 1, "bulletRedirection")
	local triggerLink = gameUi.ScopedSection(legitbot, "TRIGGER", 2, "trigger")
	-- local rcsLink = gameUi.ScopedSection(legitbot, "RECOIL CONTROL SYSTEM", 2, "rcs")
	local visualsLink = gameUi.ScopedSection(legitbot, "VISUALS", 2, "visuals")
	local weaponsLink = gameUi.ScopedSection(legitbot, "WEAPONS", 2, "weapons")

	legitbot:UseScope(true)
	gameUi.Mount(ManipBar, visualsLink)
	gameUi.Mount(AimIndicator, visualsLink)
	gameUi.Mount(Legitbot, legitbotLink, {
		targettingLink = targettingLink,
		aimLink = aimLink,
		triggerLink = triggerLink,
		-- rcsLink = rcsLink,
		visualsLink = visualsLink,
		bulletRedirectionLink = bulletRedirectionLink,
	})

	gameUi.Mount(ReduceRecoil, weaponsLink)

	local visuals = gameUi.Group("VISUALS")
	local visualsTab = gameUi.Tab(visuals, "Visuals", "terrain")
	local players = gameUi.Subtab(visualsTab, "Players", "person")
	local espLink = gameUi.Section(players, "PLAYER ESP", 1, "esp")
	gameUi.Mount(Esp, espLink, { previewLink = espLink })

	local effectsLink = gameUi.Section(players, "HIT FEEDBACK", 2, "effects")
	gameUi.Mount(DamageNumber3d, effectsLink)
	gameUi.Mount(Hitskeletons, effectsLink)
	gameUi.Mount(Hitmarker3d, effectsLink)
	gameUi.Mount(HitOverlay, effectsLink)
	gameUi.Mount(Hitmarker, effectsLink)
	gameUi.Mount(Hitchams, effectsLink)
	gameUi.Mount(Hitsound, effectsLink)
	gameUi.Mount(HitEffect, effectsLink)
	gameUi.Mount(HitLog, effectsLink)

	local selfEspLink = gameUi.Section(players, "SELF", 2, "selfEsp")
	gameUi.Mount(SelfChams, selfEspLink, {
		key = "attachmentChams",
		label = "Attachment Chams",
		tip = "Recolors your equipped weapon.",
		scope = "equipped",
		color = Color3.fromRGB(168, 168, 168),
		material = "Neon",
	})
	gameUi.Mount(SelfChams, selfEspLink, {
		key = "viewmodelChams",
		label = "Viewmodel Chams",
		tip = "Recolors your first-person arms.",
		scope = "arm",
		color = Color3.fromRGB(195, 95, 95),
		material = "Neon",
	})
	gameUi.Mount(SelfChams, selfEspLink, {
		key = "characterChams",
		label = "Character Chams",
		tip = "Recolors your third-person character body.",
		scope = "body",
		color = Color3.fromRGB(145, 190, 215),
		material = "Neon",
	})
	gameUi.Mount(VehicleChams, selfEspLink)
	gameUi.Mount(Footsteps, selfEspLink)

	local world = gameUi.Subtab(visualsTab, "World", "globe")

	local ambienceLink = gameUi.Section(world, "AMBIENCE", 1, "modulations")
	gameUi.Mount(WorldAmbience, ambienceLink)

	local worldEspLink = gameUi.Section(world, "WORLD ESP", 1, "worldEsp")
	gameUi.Mount(ZombieChams, worldEspLink)
	gameUi.Mount(VehicleEsp, worldEspLink)
	gameUi.Mount(CorpseEsp, worldEspLink)
	gameUi.Mount(MapEsp, worldEspLink)

	local viewLink = gameUi.Section(world, "VIEW", 2, "overlay")
	gameUi.Mount(InteractHighlight, viewLink)
	gameUi.Mount(CustomScope, viewLink)
	gameUi.Mount(ViewmodelChanger, viewLink)
	gameUi.Mount(CustomCrosshair, viewLink)
	gameUi.Mount(AspectRatio, viewLink)
	gameUi.Mount(MusicHud, gameUi.SettingsHudSection("hud"))
	gameUi.Mount(Freecam, viewLink)
	gameUi.Mount(Zoom, viewLink)
	gameUi.Mount(Hud, viewLink)

	local worldEffectsLink = gameUi.Section(world, "EFFECTS", 2, "effects")
	gameUi.Mount(Tracer, worldEffectsLink)
	gameUi.Mount(Impact, worldEffectsLink)
	local removalsHostLink = worldEffectsLink:WithPrefix("overlay")
	removalsHostLink:Options("removals", "Removals")
	local removalsLink = removalsHostLink:OnKey("removals")
	gameUi.Mount(HideInventoryCharacter, removalsLink)
	gameUi.Mount(Removals, removalsLink)
	gameUi.Mount(SoundRemovals, removalsLink)
	gameUi.Mount(AnimationRemovals, removalsLink)

	local other = gameUi.Group("OTHER")
	local misc = gameUi.Tab(other, "Misc", "bolt")

	local movementLink = gameUi.Section(misc, "MOVEMENT", 1, "movement")
	gameUi.Mount(ShootWhileSprint, movementLink)
	gameUi.Mount(AimWhileSprint, movementLink)
	gameUi.Mount(NoJumpCooldown, movementLink)
	gameUi.Mount(InventoryMove, movementLink)
	gameUi.Mount(NoSwimLimits, movementLink)
	gameUi.Mount(AlwaysSprint, movementLink)
	gameUi.Mount(InfiniteJump, movementLink)
	gameUi.Mount(InstantClimb, movementLink)
	gameUi.Mount(InstantVault, movementLink)
	gameUi.Mount(NoFallStun, movementLink)
	gameUi.Mount(NoStagger, movementLink)
	gameUi.Mount(FakeLag, movementLink)
	gameUi.Mount(NoClip, movementLink)
	gameUi.Mount(Spider, movementLink)

	local exploitsLink = gameUi.Section(misc, "EXPLOITS", 2, "exploits")
	gameUi.Mount(UseWhileFalling, exploitsLink)
	gameUi.Mount(FreezeZombies, exploitsLink)
	gameUi.Mount(InstantSearch, exploitsLink)
	gameUi.Mount(FastRespawn, exploitsLink)
	gameUi.Mount(FastUse, exploitsLink)

	local utilityLink = gameUi.Section(misc, "UTILITY", 2, "utility")
	gameUi.Mount(AutoLoot, utilityLink)

	utilityLink:Options("vehicle", "Vehicle")
	local vehicleLink = utilityLink:OnKey("vehicle")
	gameUi.Mount(VehicleMods, vehicleLink)
	gameUi.Mount(VehicleAura, vehicleLink)
	gameUi.Mount(VehicleFly, vehicleLink)

	local miscLink = gameUi.Section(misc, "MISC", 2, "misc")
	gameUi.Mount(SquadFriendly, miscLink)
	gameUi.Mount(AutoPing, miscLink)
	gameUi.Mount(StaffDetector, miscLink)

	local spoofingLink = gameUi.Section(misc, "SPOOFING", 2, "spoofing")
	gameUi.Mount(AccountSpoofer, spoofingLink)

	local inventory = gameUi.Tab(other, "Inventory", "karambit")
	InventoryController.Attach(inventory)
end
