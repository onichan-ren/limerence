return LPH_JIT_MAX(function()
	local RunService = cloneref(game:GetService("RunService")) :: RunService
	local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
	local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
	local Players = cloneref(game:GetService("Players")) :: Players
	local camera = Workspace.CurrentCamera
	local Charm = require("@pkg/Charm")
	local React = require("@pkg/React")
	local BaseFeature = require("@game/BaseFeature")
	local gameUi = require("@game/gameUi")
	local ScopeController = require("@feature/ui/scope/ScopeController")
	local PlayerController = require("@feature/player/PlayerController")
	local legitbotApi = require("@game/universal/feature/combat/legitbot/legitbotApi")
	local legitbotState = require("@game/universal/feature/combat/legitbot/legitbotState")
	local legitbotUi = require("@game/universal/feature/combat/legitbot/legitbotUi")
	local fovVisualization = require("@game/universal/feature/combat/legitbot/fovVisualization")
	local hitboxParts = require("@game/universal/feature/combat/legitbot/hitboxParts")
	local prediction = require("@game/universal/feature/combat/prediction")
	local playerState = require("@feature/record/module/playerState")
	local uiState = require("@feature/ui/uiState")
	local screenProject = require("@share/screenProject")
	local cameraState = require("@share/cameraState")

	local peek = Charm.peek
	local subscribeToBinding = (React :: any).__subscribeToBinding

	local LocalPlayer = Players.LocalPlayer

	local HITBOX_PARTS = hitboxParts.HITBOX_PARTS
	local PART_TO_HITBOX = hitboxParts.PART_TO_HITBOX

	local USER_MOVE_THRESHOLD = 0.12
	local USER_MOVE_GRACE = 0.07
	local ASSIST_RELEASE_RATE = 14
	local ASSIST_RELEASE_MIN = 0.05
	local ASSIST_AWAY_COS = 0.5
	local ASSIST_AWAY_MIN_SPEED = 250
	local SELF_FEEDBACK_TOLERANCE = 0.25
	local SELF_SCALE_RATE = 0.2
	local SELF_SCALE_MAX = 4
	local SELF_SCALE_MIN_INJECT_SQ = 0.25

	local VELOCITY_SMOOTH_RATE = 30
	local DT_REFERENCE_FPS = 60
	local DT_CAP = 4 / DT_REFERENCE_FPS

	local TRIGGER_BURST_GRACE = 0.4

	local OS_NEAR = 0.08
	local OS_SETTLE_FRAC = 0.4
	local OS_MAX_VP = 0.12
	local OS_REFRACTORY = 0.3
	local OS_JITTER_RAD = 0.25
	local OS_AMOUNT_MAX_VP = 0.11
	local OS_MAG_FLOOR = 0.55
	local OS_SPEED_REF = 1.0
	local OS_DECAY_MIN = 6
	local OS_DECAY_MAX = 22
	local OS_SPEED_HI = 0.6
	local OS_SPEED_LO = 0.04
	local OS_FEELS: { [string]: { number } } = {
		Subtle = { 45, 24, 60, 55 },
		Natural = { 65, 38, 45, 68 },
		Heavy = { 90, 95, 30, 82 },
	}

	local RT_BUF_SIZE = 32
	local RT_VEL_RATE = 12
	local RT_DELAY_MAX = 0.26
	local RT_GAP = 0.15
	local RT_JUMP_SQ = 12 * 12
	local RT_EXTRAP_MAX = 24
	local RT_EXTRAP_SQ = RT_EXTRAP_MAX * RT_EXTRAP_MAX

	local DZ_MAX_VP = 0.025

	local EPSILON = 1e-4

	local EMPTY_VOXELS = {} :: { [Part]: any }
	local TRIGGER_IGNORE_SCRATCH = {} :: { Instance }

	local function applyOvershootFeel(cache: any): ()
		local preset = OS_FEELS[cache.aimOsFeel]
		local chance, amount, recovery, trigger
		if preset then
			chance, amount, recovery, trigger = preset[1], preset[2], preset[3], preset[4]
		else
			chance, amount, recovery, trigger =
				cache.aimOsChanceRaw, cache.aimOsAmountRaw, cache.aimOsRecoveryRaw, cache.aimOsTriggerRaw
		end
		cache.aimOsChance = chance / 100
		cache.aimOsAmount = amount / 100
		cache.aimOsDecay = OS_DECAY_MIN + (recovery / 100) * (OS_DECAY_MAX - OS_DECAY_MIN)
		cache.aimOsSpeedMin = OS_SPEED_HI - (trigger / 100) * (OS_SPEED_HI - OS_SPEED_LO)
	end

	local readConditionFlags = LPH_NO_VIRTUALIZE(
		function(
			v: { string }
		): (boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean)
			local whileReloading = false
			local whileOutOfAmmo = false
			local whileOnCooldown = false
			local whileSwitching = false
			local whileBlind = false
			local whileInAir = false
			local throughSmokes = false
			local waitForScope = false
			local whileSprinting = false
			local waitForAim = false
			local avoidDeflecting = false
			for _, item in next, v do
				if item == "While Reloading" then
					whileReloading = true
				elseif item == "While Out Of Ammo" then
					whileOutOfAmmo = true
				elseif item == "While On Cooldown" then
					whileOnCooldown = true
				elseif item == "While Switching" then
					whileSwitching = true
				elseif item == "While Blind" then
					whileBlind = true
				elseif item == "While In Air" then
					whileInAir = true
				elseif item == "Through Smokes" then
					throughSmokes = true
				elseif item == "Wait For Scope" then
					waitForScope = true
				elseif item == "While Sprinting" then
					whileSprinting = true
				elseif item == "Wait For Aim" then
					waitForAim = true
				elseif item == "Avoid Deflecting" then
					avoidDeflecting = true
				end
			end
			return whileReloading,
				whileOutOfAmmo,
				whileOnCooldown,
				whileSwitching,
				whileBlind,
				whileInAir,
				throughSmokes,
				waitForScope,
				whileSprinting,
				waitForAim,
				avoidDeflecting
		end
	)

	local AIM_FOV_COLOR = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(9, 255, 181)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(184, 246, 255)),
	})
	local AIM_FOV_OUTLINE_COLOR = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 144)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 247, 255)),
	})
	local AIM_FOV_TRANSPARENCY = 0.5
	local AIM_FOV_OUTLINE_TRANSPARENCY = 0

	local TRIGGER_FOV_COLOR = ColorSequence.new(Color3.fromRGB(255, 85, 88))
	local TRIGGER_FOV_OUTLINE_COLOR = ColorSequence.new(Color3.fromRGB(255, 85, 88))
	local TRIGGER_FOV_TRANSPARENCY = 0.5
	local TRIGGER_FOV_OUTLINE_TRANSPARENCY = 0

	local REDIRECTION_FOV_COLOR = ColorSequence.new(Color3.fromRGB(111, 0, 255))
	local REDIRECTION_FOV_OUTLINE_COLOR = ColorSequence.new(Color3.fromRGB(111, 0, 255))
	local REDIRECTION_FOV_TRANSPARENCY = 0.5
	local REDIRECTION_FOV_OUTLINE_TRANSPARENCY = 0

	export type PenetrationPickOpts = {
		enabled: boolean,
		penetration: number,
		maxRange: number,
	}

	export type GameOpts = {
		getLocalAlive: () -> boolean,
		getLocalTeam: () -> string?,
		getCanSkipTeamcheck: (() -> boolean)?,
		getEquippedWeapon: () -> any?,
		canShoot: (weapon: any) -> boolean,

		getLocalInAir: (() -> boolean)?,
		getLocalSprinting: (() -> boolean)?,
		getAimPoint2d: (() -> Vector2)?,
		getLocalReloading: (() -> boolean)?,
		getLocalOutOfAmmo: (() -> boolean)?,
		getLocalOnCooldown: (() -> boolean)?,
		getLocalSwitching: (() -> boolean)?,
		getTargetingDisabled: (() -> boolean)?,
		getFlashVisibility: (() -> number)?,
		isScopedIn: (() -> boolean)?,
		isAiming: (() -> boolean)?,
		getChargePercent: (() -> number?)?,
		getExtraTargets: (() -> { [any]: any })?,
		isPlayerDeflecting: ((player: any) -> boolean)?,

		predictDamage: ((
			cameraPos: Vector3,
			part: BasePart,
			weapon: any,
			isWallbang: boolean,
			player: Player?
		) -> number)?,
		estimateHitChance: ((cameraPos: Vector3, part: BasePart, weapon: any) -> number?)?,

		predictAimPoint: ((
			opts: {
				player: any,
				part: BasePart,
				hitbox: string?,
				weapon: any?,
				aimPoint: Vector3,
				origin: Vector3,
				bulletComp: boolean,
				movementComp: boolean,
			}
		) -> Vector3)?,

		getPenetrationOpts: ((weapon: any) -> PenetrationPickOpts?)?,
		reachThroughWalls: ((
			origin: Vector3,
			part: BasePart,
			pen: number,
			range: number,
			ignore: { Instance },
			trace: boolean?
		) -> boolean)?,
		beginPenetrationStep: (() -> ())?,

		gameRaycast: ((origin: Vector3, target: Vector3, ignore: { Instance }) -> RaycastResult?)?,

		isPlayerBlocking: ((player: any) -> boolean)?,
		isPlayerTriggerBlocked: ((player: any) -> boolean)?,

		fire: ((weapon: any) -> ())?,
		stopFire: (() -> ())?,

		canFire: ((weapon: any) -> boolean)?,

		getSmokeVoxels: (() -> { [Part]: any })?,
		lengthThroughSmoke: ((origin: Vector3, dirUnit: Vector3, dist: number, voxels: { [Part]: any }) -> number)?,

		getBacktrackPosition: ((player: Player, partName: string) -> Vector3?)?,
		getBacktrackFolder: (() -> Folder?)?,
		getIgnoreFolder: (() -> Folder?)?,
		getHitboxParts: ((hitboxName: string) -> { string }?)?,

		bulletCreatedSignal: any?,

		canRcs: ((weapon: any) -> boolean)?,
		setBulletRedirectionActive: ((state: boolean) -> ())?,
		setBulletRedirectionChance: ((chance: number) -> ())?,
		setBulletRedirectionTarget: ((target: any) -> ())?,
		computeRcsDelta: ((
			weapon: any,
			dt: number,
			verticalOnly: boolean,
			strength: number,
			camera: Camera
		) -> (number?, number?))?,

		setupScopes: (() -> ())?,
		subscribeWeaponChange: (((weapon: any?) -> ()) -> (() -> ())?)?,

		uiOpts: legitbotUi.UiOpts?,
	}


	local buildHitboxSet = LPH_NO_VIRTUALIZE(function(hitboxes: { string }): { [string]: boolean }
		local set: { [string]: boolean } = {}
		for _, name in next, hitboxes do
			set[name] = true
		end
		return set
	end)

	local buildHitboxSetMaybe = LPH_NO_VIRTUALIZE(function(hitboxes: any): { [string]: boolean }?
		if typeof(hitboxes) ~= "table" then
			return nil
		end
		return buildHitboxSet(hitboxes)
	end)

	local Legitbot = {}
	Legitbot.__index = Legitbot

	setmetatable(Legitbot, { __index = BaseFeature })

	function Legitbot.new(
		link: gameUi.Linker,
		opts: {
			targettingLink: gameUi.Linker,
			aimLink: gameUi.Linker,
			triggerLink: gameUi.Linker,
			rcsLink: gameUi.Linker?,
			visualsLink: gameUi.Linker,
			bulletRedirectionLink: gameUi.Linker,
			game: GameOpts,
		}
	): Legitbot
		local self = BaseFeature.new() :: any
		setmetatable(self, Legitbot)

		self._game = opts.game

		if opts.game.setupScopes then
			opts.game.setupScopes()
		end

		if opts.game.subscribeWeaponChange then
			local unsubscribe = opts.game.subscribeWeaponChange(function(weapon: any?): ()
				local name: string? = nil
				if weapon and type(weapon.Name) == "string" then
					name = weapon.Name
				end
				ScopeController.SetEquipped(name)
			end)
			if unsubscribe then
				self:Track(unsubscribe)
			end
		end

		self._visualsLink = opts.visualsLink

		local uiOpts = opts.game.uiOpts or ({} :: legitbotUi.UiOpts)
		self._uiOpts = uiOpts
		legitbotUi(
			link,
			opts.targettingLink,
			opts.aimLink,
			opts.triggerLink,
			opts.rcsLink,
			opts.visualsLink,
			opts.bulletRedirectionLink,
			uiOpts
		)

		self._targetBacktrack = false
		if opts.game.getBacktrackPosition then
			opts.targettingLink:Toggle("targetBacktrack", "Target Backtrack", false):SetTip({
				title = "Target Backtrack",
				body = "Aims at where enemies were when backtrack is enabled, not only where they are now.",
			})
			self:Track(opts.targettingLink:Get("targetBacktrack"):OnChange(function(v: boolean): ()
				self._targetBacktrack = v
			end))
		end

		self._maxDistanceSq = 0
		if uiOpts.showMaxDistance then
			local selectionLink = opts.targettingLink:OnKey("selection")
			selectionLink:Slider("maxDistance", "Max Distance", 0, 0, 2000, 10, nil, "st"):SetTip({
				title = "Max Distance",
				body = "Ignores enemies farther away than this. 0 means no limit.",
			})
			local function setMaxDistance(v: any): ()
				local n = tonumber(v) or 0
				self._maxDistanceSq = n * n
			end
			setMaxDistance(selectionLink:Peek("maxDistance"))
			self:Track(selectionLink:Get("maxDistance"):OnChange(setMaxDistance))
		end

		self._smoothingCurve = opts.aimLink:OnKey("smoothing"):Get("smoothingCurve")

		local showTrigger = (uiOpts.showTrigger ~= false)
		if showTrigger then
			self._magnetCurve = opts.triggerLink:OnKey("magnet"):OnKey("opts"):Get("pullStrengthCurve")
		end

		self._getAimPoint2d = opts.game.getAimPoint2d
		self._refX = 0
		self._refY = 0
		self._project = nil :: screenProject.Projector?
		self._lastMouseLocation = nil :: Vector2?

		self._lastUserMoveTime = 0
		self._pendingSelfDx = 0
		self._pendingSelfDy = 0
		self._selfScale = 1
		self._selfScaleInit = false
		self._velX = 0
		self._velY = 0
		self._userDx = 0
		self._userDy = 0

		self._osTarget = nil :: any?
		self._osX = 0
		self._osY = 0
		self._osRefractoryUntil = 0
		self._osSettled = true
		self._osPrevErr = 0

		self._rtTarget = nil :: any?
		self._rtBufX = table.create(RT_BUF_SIZE, 0)
		self._rtBufY = table.create(RT_BUF_SIZE, 0)
		self._rtBufZ = table.create(RT_BUF_SIZE, 0)
		self._rtBufT = table.create(RT_BUF_SIZE, 0)
		self._rtHead = 0
		self._rtCount = 0
		self._rtVelX = 0
		self._rtVelY = 0
		self._rtVelZ = 0

		self._lockedPlayer = nil :: any?
		self._lockedSince = 0
		self._firstSightAt = nil :: number?

		self._triggerOnTargetSince = nil :: number?
		self._triggerLastFireAt = nil :: number?
		self._triggerBurstLeft = nil :: number?
		self._triggerBurstAwaitReady = nil :: boolean?
		self._triggerBurstPlayer = nil :: any?
		self._triggerBurstSeenAt = nil :: number?
		self._triggerFiring = false
		self._triggerLatchedPlayer = nil :: any?
		self._triggerMagnetSince = nil :: number?
		self._triggerResetUntil = nil :: number?
		self._userFiredAt = nil :: number?

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.IgnoreWater = true
		raycastParams.RespectCanCollide = false
		self._raycastParams = raycastParams
		self._raycastFilter = {} :: { Instance }
		self._candidateBuf = {} :: { Candidate }
		self._hitboxListBuf = {} :: { { string }? }
		self._candidateCount = 0
		self._filterArg = {} :: { player: Player, weapon: any, scope: any }
		self._lastMaxFovRadiusPx = 0
		self._visCache = {} :: { [any]: VisCacheEntry }
		self._visCachePen = {} :: { [any]: VisCacheEntry }
		self._visEntryPool = {} :: { VisCacheEntry }
		self._visEntryCount = 0
		self._unionHitboxesCache = nil :: { string }?
		self._unionHitboxesKey = -1

		self._aimFovViz = fovVisualization.new()
		self._triggerFovViz = fovVisualization.new()
		self._bulletRedirectionFovViz = fovVisualization.new()

		self._aimFovOpts = {
			enabled = false,
			fov = 0,
			color = AIM_FOV_COLOR,
			outlineColor = AIM_FOV_OUTLINE_COLOR,
			transparency = 1,
			outlineTransparency = 1,
			rotation = 0,
			outlineRotation = 0,
		} :: fovVisualization.FovOpts
		self._triggerFovOpts = {
			enabled = false,
			fov = 0,
			color = TRIGGER_FOV_COLOR,
			outlineColor = TRIGGER_FOV_OUTLINE_COLOR,
			transparency = 1,
			outlineTransparency = 1,
			rotation = 0,
			outlineRotation = 0,
		} :: fovVisualization.FovOpts
		self._bulletRedirectionFovOpts = {
			enabled = false,
			fov = 0,
			color = REDIRECTION_FOV_COLOR,
			outlineColor = REDIRECTION_FOV_OUTLINE_COLOR,
			transparency = 1,
			outlineTransparency = 1,
			rotation = 0,
			outlineRotation = 0,
		} :: fovVisualization.FovOpts

		self._cache = {
			legitbotEnabled = false,
			aimEnabled = false,
			triggerEnabled = false,
			rcsEnabled = false,
			fovVizEnabled = false,
			fov = 30,
			bulletRedirectionEnabled = false,
			bulletRedirectionManipulation = false,
			bulletRedirectionChance = 100,
			bulletRedirectionAutowall = false,
			bulletRedirectionHitboxes = nil :: { string }?,
			bulletRedirectionHitboxSet = nil :: { [string]: boolean }?,
			bulletRedirectionFov = 30,
			bulletRedirectionFovVizEnabled = true,
			bulletRedirectionFovColor = REDIRECTION_FOV_COLOR,
			bulletRedirectionFovTransparency = REDIRECTION_FOV_TRANSPARENCY,
			bulletRedirectionFovRotation = 0,
			bulletRedirectionFovOutlineColor = REDIRECTION_FOV_OUTLINE_COLOR,
			bulletRedirectionFovOutlineTransparency = REDIRECTION_FOV_OUTLINE_TRANSPARENCY,
			bulletRedirectionFovOutlineRotation = 0,
			hitboxes = nil :: { string }?,
			hitboxSet = nil :: { [string]: boolean }?,
			conditions = nil :: { string }?,
			cnd_whileReloading = false,
			cnd_whileOutOfAmmo = false,
			cnd_whileOnCooldown = false,
			cnd_whileSwitching = false,
			cnd_whileBlind = false,
			cnd_whileInAir = false,
			cnd_throughSmokes = false,
			cnd_waitForScope = false,
			cnd_whileSprinting = false,
			cnd_waitForAim = false,
			cnd_avoidDeflecting = false,
			trg_waitForScope = false,
			trg_waitForAim = false,
			trg_waitForCharge = false,
			trg_chargeThreshold = 100,
			trg_avoidDeflecting = false,
			assistance = "Assisted",
			reactionTime = 0.130,
			switchDelay = 0.090,
			stickyTarget = false,
			smokeThreshold = 1.0,
			blindThreshold = 0.5,
			aimSensitivity = 0.5,
			aimOsEnabled = false,
			aimOsChance = 0.5,
			aimOsAmount = 0.5,
			aimOsDecay = OS_DECAY_MIN + 0.5 * (OS_DECAY_MAX - OS_DECAY_MIN),
			aimOsSpeedMin = OS_SPEED_HI - 0.5 * (OS_SPEED_HI - OS_SPEED_LO),
			aimOsFeel = "Natural",
			aimOsChanceRaw = 50,
			aimOsAmountRaw = 50,
			aimOsRecoveryRaw = 50,
			aimOsTriggerRaw = 50,
			aimHzEnabled = false,
			aimReactDelay = 0.5 * RT_DELAY_MAX,
			aimDeadzone = 0.5 * DZ_MAX_VP,
			aimClosestPoint = false,
			predictionEnabled = true,
			predictBulletComp = true,
			predictMovementComp = true,
			rcsStrength = 1.0,
			rcsVerticalOnly = false,
			triggerFov = 5,
			triggerHitboxes = nil :: { string }?,
			triggerHitboxSet = nil :: { [string]: boolean }?,
			triggerShotDelay = 0.130,
			aimFovVizEnabled = true,
			aimFovColor = AIM_FOV_COLOR,
			aimFovTransparency = AIM_FOV_TRANSPARENCY,
			aimFovRotation = 0,
			aimFovOutlineColor = AIM_FOV_OUTLINE_COLOR,
			aimFovOutlineTransparency = AIM_FOV_OUTLINE_TRANSPARENCY,
			aimFovOutlineRotation = 0,
			triggerFovVizEnabled = true,
			triggerFovColor = TRIGGER_FOV_COLOR,
			triggerFovTransparency = TRIGGER_FOV_TRANSPARENCY,
			triggerFovRotation = 0,
			triggerFovOutlineColor = TRIGGER_FOV_OUTLINE_COLOR,
			triggerFovOutlineTransparency = TRIGGER_FOV_OUTLINE_TRANSPARENCY,
			triggerFovOutlineRotation = 0,
			triggerAutowall = false,
			triggerHitChance = 65,
			triggerMinDamage = 0,
			triggerAutowallMinDamage = 0,
			triggerBullets = 5,
			triggerMode = "FOV",
			triggerMagnet = false,
			triggerMagnetReactionTime = 0.130,
			triggerFirstBulletDelay = 0,
			triggerResetDelay = 0,
			aimFirstBulletDelay = 0,
		}

		self._targetingConn = nil :: RBXScriptConnection?
		self._fovConn = nil :: RBXScriptConnection?
		self._rcsBound = false

		self:_subscribeSettings()

		-- i am feeling alot of emotions right now, and all of them are negative
		local cameraChangedConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			camera = Workspace.CurrentCamera
		end)

		self:Track(function()
			cameraChangedConnection:Disconnect()
		end)

		if opts.game.bulletCreatedSignal then
			local bulletConn = opts.game.bulletCreatedSignal:Connect(function(): ()
				local cache = self._cache
				if cache.triggerFirstBulletDelay <= 0 and cache.aimFirstBulletDelay <= 0 then
					return
				end
				local now = os.clock()
				if self._triggerLastFireAt and now - self._triggerLastFireAt < 0.1 then
					return
				end
				self._userFiredAt = now
			end)
			self:Track(function(): ()
				bulletConn:Disconnect()
			end)
		end

		return self
	end

	Legitbot._subscribeSettings = LPH_NO_VIRTUALIZE(function(self: Legitbot): ()
		local cache = self._cache
		local uiOpts = self._uiOpts
		local showTrigger = (uiOpts.showTrigger ~= false)
		local showRcs = (uiOpts.showRcs ~= false)
		local showAutowall = (uiOpts.showAutowall ~= false)
		local showBulletRedirection = (uiOpts.showBulletRedirection ~= false)

		local function recompute(): ()
			self:_recomputeActivations()
		end

		self:Track(ScopeController.OnChange("legitbot.enabled", function(v: any): ()
			cache.legitbotEnabled = v == true
			recompute()
		end))

		self:Track(ScopeController.OnChange("aim.enabled", function(v: any): ()
			cache.aimEnabled = v == true
			recompute()
		end))

		if showBulletRedirection then
			if uiOpts.showManipulation then
				self:Track(ScopeController.OnChange("bulletRedirection.manipulation", function(v: any): ()
					cache.bulletRedirectionManipulation = v == true
				end))
			end
			self:Track(ScopeController.OnChange("bulletRedirection.enabled", function(v: any): ()
				cache.bulletRedirectionEnabled = v == true
				recompute()
			end))

			self:Track(ScopeController.OnChange("bulletRedirection.hitboxes", function(v: any): ()
				cache.bulletRedirectionHitboxes = v
				cache.bulletRedirectionHitboxSet = buildHitboxSetMaybe(v)
				self._unionHitboxesCache = nil
				recompute()
			end))

			self:Track(ScopeController.OnChange("bulletRedirection.fov", function(v: any): ()
				cache.bulletRedirectionFov = v or 30
				recompute()
			end))

			self:Track(ScopeController.OnChange("bulletRedirection.chance", function(v: any): ()
				cache.bulletRedirectionChance = v or 100
				local setChance = self._game.setBulletRedirectionChance
				if setChance then
					setChance(cache.bulletRedirectionChance)
				end
			end))
			if showAutowall then
				self:Track(ScopeController.OnChange("bulletRedirection.autowall", function(v: any): ()
					cache.bulletRedirectionAutowall = v == true
				end))
			end
		end

		if showTrigger then
			self:Track(ScopeController.OnChange("trigger.enabled", function(v: any): ()
				cache.triggerEnabled = v == true
				self._triggerLatchedPlayer = nil
				self._triggerOnTargetSince = nil
				self._triggerBurstLeft = nil
				self._triggerBurstAwaitReady = nil
				self._triggerResetUntil = nil
				self._userFiredAt = nil
			end))
		end
		if showRcs then
			self:Track(ScopeController.OnChange("rcs.enabled", function(v: any): ()
				cache.rcsEnabled = v == true
				recompute()
			end))
		end
		self:Track(ScopeController.OnChange("visuals.fieldOfView", function(v: any): ()
			cache.fovVizEnabled = v == true
			recompute()
		end))

		self:Track(ScopeController.OnChange("aim.targeting.fov", function(v: any): ()
			cache.fov = v or 30
		end))
		self:Track(ScopeController.OnChange("targetting.selection.hitboxes", function(v: any): ()
			cache.hitboxes = v
			cache.hitboxSet = buildHitboxSetMaybe(v)
			self._unionHitboxesCache = nil
		end))
		self:Track(ScopeController.OnChange("targetting.conditions", function(v: any): ()
			if typeof(v) ~= "table" then
				return
			end
			cache.conditions = v
			cache.cnd_whileReloading, cache.cnd_whileOutOfAmmo, cache.cnd_whileOnCooldown, cache.cnd_whileSwitching, cache.cnd_whileBlind, cache.cnd_whileInAir, cache.cnd_throughSmokes, cache.cnd_waitForScope, cache.cnd_whileSprinting, cache.cnd_waitForAim, cache.cnd_avoidDeflecting =
				readConditionFlags(v)
		end))
		self:Track(ScopeController.OnChange("aim.engagement.assistance", function(v: any): ()
			cache.assistance = v or "Assisted"
		end))
		self:Track(ScopeController.OnChange("targetting.selection.reactionTime", function(v: any): ()
			cache.reactionTime = (v or 130) / 1000
		end))
		self:Track(ScopeController.OnChange("targetting.selection.switchDelay", function(v: any): ()
			cache.switchDelay = (v or 90) / 1000
		end))
		self:Track(ScopeController.OnChange("targetting.selection.stickyTarget", function(v: any): ()
			cache.stickyTarget = v == true
		end))
		self:Track(ScopeController.OnChange("targetting.conditions.opts.smokeThreshold", function(v: any): ()
			cache.smokeThreshold = (v or 100) / 100
		end))
		self:Track(ScopeController.OnChange("targetting.conditions.opts.blindThreshold", function(v: any): ()
			cache.blindThreshold = (v or 50) / 100
		end))
		self:Track(ScopeController.OnChange("aim.smoothing.sensitivity", function(v: any): ()
			cache.aimSensitivity = (v or 50) / 100
		end))
		self:Track(ScopeController.OnChange("aim.humanization.overshoot", function(v: any): ()
			cache.aimOsEnabled = v == true
		end))
		self:Track(ScopeController.OnChange("aim.humanization.overshoot.opts.feel", function(v: any): ()
			cache.aimOsFeel = v or "Natural"
			applyOvershootFeel(cache)
		end))
		self:Track(ScopeController.OnChange("aim.humanization.overshoot.opts.chance", function(v: any): ()
			cache.aimOsChanceRaw = v or 50
			applyOvershootFeel(cache)
		end))
		self:Track(ScopeController.OnChange("aim.humanization.overshoot.opts.amount", function(v: any): ()
			cache.aimOsAmountRaw = v or 50
			applyOvershootFeel(cache)
		end))
		self:Track(ScopeController.OnChange("aim.humanization.overshoot.opts.recovery", function(v: any): ()
			cache.aimOsRecoveryRaw = v or 50
			applyOvershootFeel(cache)
		end))
		self:Track(ScopeController.OnChange("aim.humanization.overshoot.opts.trigger", function(v: any): ()
			cache.aimOsTriggerRaw = v or 50
			applyOvershootFeel(cache)
		end))
		self:Track(ScopeController.OnChange("aim.humanization.tracking", function(v: any): ()
			cache.aimHzEnabled = v == true
		end))
		self:Track(ScopeController.OnChange("aim.humanization.tracking.opts.reaction", function(v: any): ()
			cache.aimReactDelay = ((v or 50) / 100) * RT_DELAY_MAX
		end))
		self:Track(ScopeController.OnChange("aim.humanization.tracking.opts.deadzone", function(v: any): ()
			cache.aimDeadzone = ((v or 50) / 100) * DZ_MAX_VP
		end))
		self:Track(ScopeController.OnChange("aim.targeting.closestPoint", function(v: any): ()
			cache.aimClosestPoint = v == true
		end))
		if uiOpts.showPrediction then
			self:Track(ScopeController.OnChange("aim.engagement.prediction", function(v: any): ()
				cache.predictionEnabled = v == true
			end))
			self:Track(
				ScopeController.OnChange("aim.engagement.prediction.opts.bulletCompensation", function(v: any): ()
					cache.predictBulletComp = v == true
				end)
			)
			self:Track(
				ScopeController.OnChange("aim.engagement.prediction.opts.movementCompensation", function(v: any): ()
					cache.predictMovementComp = v == true
				end)
			)
		end
		if showRcs then
			self:Track(ScopeController.OnChange("rcs.strength", function(v: any): ()
				cache.rcsStrength = (v or 100) / 100
			end))
			self:Track(ScopeController.OnChange("rcs.verticalOnly", function(v: any): ()
				cache.rcsVerticalOnly = v == true
			end))
		end
		if showTrigger then
			self:Track(ScopeController.OnChange("trigger.targeting.fov", function(v: any): ()
				cache.triggerFov = v or 5
			end))
			self:Track(ScopeController.OnChange("trigger.targeting.hitboxes", function(v: any): ()
				cache.triggerHitboxes = v
				cache.triggerHitboxSet = buildHitboxSetMaybe(v)
				self._unionHitboxesCache = nil
			end))
			self:Track(ScopeController.OnChange("trigger.targeting.mode", function(v: any): ()
				cache.triggerMode = v or "FOV"
			end))
			self:Track(ScopeController.OnChange("trigger.engagement.shotDelay", function(v: any): ()
				cache.triggerShotDelay = (v or 130) / 1000
			end))
			self:Track(ScopeController.OnChange("trigger.engagement.resetDelay", function(v: any): ()
				cache.triggerResetDelay = (v or 0) / 1000
			end))
			self:Track(ScopeController.OnChange("trigger.engagement.firstBulletDelay", function(v: any): ()
				cache.triggerFirstBulletDelay = (v or 0) / 1000
				self._userFiredAt = nil
			end))
			if uiOpts.showTriggerBullets ~= false then
				self:Track(ScopeController.OnChange("trigger.engagement.bullets", function(v: any): ()
					cache.triggerBullets = v
				end))
			else
				cache.triggerBullets = 0
			end
			if showAutowall then
				self:Track(ScopeController.OnChange("trigger.filters.autowall", function(v: any): ()
					cache.triggerAutowall = v == true
				end))
				self:Track(ScopeController.OnChange("trigger.filters.autowall.opts.minDamage", function(v: any): ()
					cache.triggerAutowallMinDamage = v or 0
				end))
			end
			if uiOpts.showHitChance ~= false then
				self:Track(ScopeController.OnChange("trigger.filters.hitChance", function(v: any): ()
					cache.triggerHitChance = v or 65
				end))
			else
				cache.triggerHitChance = 0
			end
			if uiOpts.showMinDamage ~= false then
				self:Track(ScopeController.OnChange("trigger.filters.minDamage", function(v: any): ()
					cache.triggerMinDamage = v or 0
				end))
			else
				cache.triggerMinDamage = 0
			end
			self:Track(ScopeController.OnChange("trigger.magnet", function(v: any): ()
				cache.triggerMagnet = v == true
				if not cache.triggerMagnet then
					self._triggerMagnetSince = nil
				end
			end))
			self:Track(ScopeController.OnChange("trigger.magnet.opts.reactionTime", function(v: any): ()
				cache.triggerMagnetReactionTime = (v or 130) / 1000
			end))
			if uiOpts.showTriggerWaitForScope then
				self:Track(ScopeController.OnChange("trigger.filters.waitForScope", function(v: any): ()
					cache.trg_waitForScope = v == true
				end))
			end
			if uiOpts.showTriggerWaitForAim then
				self:Track(ScopeController.OnChange("trigger.filters.waitForAim", function(v: any): ()
					cache.trg_waitForAim = v == true
				end))
			end
			if uiOpts.showTriggerAvoidDeflecting then
				self:Track(ScopeController.OnChange("trigger.filters.avoidDeflecting", function(v: any): ()
					cache.trg_avoidDeflecting = v == true
				end))
			end
			if uiOpts.showTriggerWaitForCharge then
				self:Track(ScopeController.OnChange("trigger.filters.waitForCharge", function(v: any): ()
					cache.trg_waitForCharge = v == true
				end))
				self:Track(ScopeController.OnChange("trigger.filters.waitForCharge.opts.charge", function(v: any): ()
					cache.trg_chargeThreshold = tonumber(v) or 100
				end))
			end
		end
		self:Track(ScopeController.OnChange("aim.engagement.firstBulletDelay", function(v: any): ()
			cache.aimFirstBulletDelay = (v or 0) / 1000
			self._userFiredAt = nil
		end))
		self:Track(ScopeController.OnChange("visuals.fieldOfView.opts.aim", function(v: any): ()
			cache.aimFovVizEnabled = v == true
			recompute()
		end))

		if showTrigger then
			self:Track(ScopeController.OnChange("visuals.fieldOfView.opts.triggerbot", function(v: any): ()
				cache.triggerFovVizEnabled = v == true
				recompute()
			end))
		end

		if showBulletRedirection then
			self:Track(ScopeController.OnChange("visuals.fieldOfView.opts.bulletRedirection", function(v: any): ()
				cache.bulletRedirectionFovVizEnabled = v == true
				recompute()
			end))
		end

		local visualsLink = self._visualsLink
		local function trackFovColorpickerColor(
			relKey: string,
			assign: (ColorSequence) -> (),
			_fallback: ColorSequence
		): ()
			local el = visualsLink:Get(relKey)
			if not el or not el._currentGradient then
				return
			end
			local binding = el._currentGradient
			assign((binding :: any):getValue())
			self:Track(subscribeToBinding(binding, assign))
		end

		trackFovColorpickerColor("fieldOfView.opts.aim.opts.color", function(c: ColorSequence): ()
			cache.aimFovColor = c
		end, AIM_FOV_COLOR)
		trackFovColorpickerColor("fieldOfView.opts.aim.opts.outlineColor", function(c: ColorSequence): ()
			cache.aimFovOutlineColor = c
		end, AIM_FOV_OUTLINE_COLOR)

		if showTrigger then
			trackFovColorpickerColor("fieldOfView.opts.triggerbot.opts.color", function(c: ColorSequence): ()
				cache.triggerFovColor = c
			end, TRIGGER_FOV_COLOR)
			trackFovColorpickerColor("fieldOfView.opts.triggerbot.opts.outlineColor", function(c: ColorSequence): ()
				cache.triggerFovOutlineColor = c
			end, TRIGGER_FOV_OUTLINE_COLOR)
		end

		if showBulletRedirection then
			trackFovColorpickerColor("fieldOfView.opts.bulletRedirection.opts.color", function(c: ColorSequence): ()
				cache.bulletRedirectionFovColor = c
			end, REDIRECTION_FOV_COLOR)
			trackFovColorpickerColor(
				"fieldOfView.opts.bulletRedirection.opts.outlineColor",
				function(c: ColorSequence): ()
					cache.bulletRedirectionFovOutlineColor = c
				end,
				REDIRECTION_FOV_OUTLINE_COLOR
			)
		end

		local function trackFovColorpickerTransparency(relKey: string, assign: (n: number) -> (), _fallback: number): ()
			local el = visualsLink:Get(relKey)
			if not el or not el._currentTransparency then
				return
			end
			local binding = el._currentTransparency
			assign((binding :: any):getValue())
			self:Track(subscribeToBinding(binding, assign))
		end

		trackFovColorpickerTransparency("fieldOfView.opts.aim.opts.color", function(n: number): ()
			cache.aimFovTransparency = n
		end, AIM_FOV_TRANSPARENCY)
		trackFovColorpickerTransparency("fieldOfView.opts.aim.opts.outlineColor", function(n: number): ()
			cache.aimFovOutlineTransparency = n
		end, AIM_FOV_OUTLINE_TRANSPARENCY)

		if showTrigger then
			trackFovColorpickerTransparency("fieldOfView.opts.triggerbot.opts.color", function(n: number): ()
				cache.triggerFovTransparency = n
			end, TRIGGER_FOV_TRANSPARENCY)
			trackFovColorpickerTransparency("fieldOfView.opts.triggerbot.opts.outlineColor", function(n: number): ()
				cache.triggerFovOutlineTransparency = n
			end, TRIGGER_FOV_OUTLINE_TRANSPARENCY)
		end

		if showBulletRedirection then
			trackFovColorpickerTransparency("fieldOfView.opts.bulletRedirection.opts.color", function(n: number): ()
				cache.bulletRedirectionFovTransparency = n
			end, REDIRECTION_FOV_TRANSPARENCY)
			trackFovColorpickerTransparency(
				"fieldOfView.opts.bulletRedirection.opts.outlineColor",
				function(n: number): ()
					cache.bulletRedirectionFovOutlineTransparency = n
				end,
				REDIRECTION_FOV_OUTLINE_TRANSPARENCY
			)
		end

		local function trackFovColorpickerRotation(relKey: string, assign: (n: number) -> ()): ()
			local el = visualsLink:Get(relKey)
			if not el or not el._currentRotation then
				return
			end
			local binding = el._currentRotation
			assign((binding :: any):getValue())
			self:Track(subscribeToBinding(binding, assign))
		end

		trackFovColorpickerRotation("fieldOfView.opts.aim.opts.color", function(n: number): ()
			cache.aimFovRotation = n
		end)
		trackFovColorpickerRotation("fieldOfView.opts.aim.opts.outlineColor", function(n: number): ()
			cache.aimFovOutlineRotation = n
		end)

		if showTrigger then
			trackFovColorpickerRotation("fieldOfView.opts.triggerbot.opts.color", function(n: number): ()
				cache.triggerFovRotation = n
			end)
			trackFovColorpickerRotation("fieldOfView.opts.triggerbot.opts.outlineColor", function(n: number): ()
				cache.triggerFovOutlineRotation = n
			end)
		end

		if showBulletRedirection then
			trackFovColorpickerRotation("fieldOfView.opts.bulletRedirection.opts.color", function(n: number): ()
				cache.bulletRedirectionFovRotation = n
			end)
			trackFovColorpickerRotation("fieldOfView.opts.bulletRedirection.opts.outlineColor", function(n: number): ()
				cache.bulletRedirectionFovOutlineRotation = n
			end)
		end
	end)

	function Legitbot._recomputeActivations(self: Legitbot): ()
		local c = self._cache

		local targetingActive = c.legitbotEnabled
		local fovActive = c.legitbotEnabled
			and c.fovVizEnabled
			and (c.aimFovVizEnabled or c.triggerFovVizEnabled or c.bulletRedirectionFovVizEnabled)
		local rcsActive = c.legitbotEnabled and c.rcsEnabled
		local bulletRedirectionActive = c.legitbotEnabled and c.bulletRedirectionEnabled

		self:_setTargetingActive(targetingActive)
		self:_setFovActive(fovActive)
		self:_setRcsActive(rcsActive)

		local setBulletRedirectionActive = self._game.setBulletRedirectionActive

		if setBulletRedirectionActive then
			setBulletRedirectionActive(bulletRedirectionActive)
		end
	end

	function Legitbot._setTargetingActive(self: Legitbot, active: boolean): ()
		if active then
			if not self._targetingConn then
				legitbotApi.SetValidTargetsProvider(function(): { legitbotApi.TargetSnapshot }
					return self:_buildTargetSnapshots()
				end)
				self._targetingConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
					self:_tick(dt)
				end))
			end
		else
			if self._targetingConn then
				self._targetingConn:Disconnect()
				self._targetingConn = nil
			end
			legitbotState.target(nil)
			legitbotState.targetPart(nil)
			legitbotApi.SetAimTarget(nil, nil, nil)
			legitbotApi.SetTriggerTarget(nil, nil, nil)
			legitbotApi.SetRedirectionTarget(nil)
			legitbotApi.SetBurstRemaining(nil)
			legitbotApi.SetValidTargetsProvider(nil)
			local setBulletRedirectionTarget = self._game.setBulletRedirectionTarget
			if setBulletRedirectionTarget then
				setBulletRedirectionTarget(nil)
			end
			self._candidateCount = 0
			self._lockedPlayer = nil
			self._firstSightAt = nil
			self._velX = 0
			self._velY = 0
			self._osTarget = nil
			self._osX = 0
			self._osY = 0
			self._osSettled = true
			self._osPrevErr = 0
			self._rtTarget = nil
			self._rtCount = 0
			self._pendingSelfDx = 0
			self._pendingSelfDy = 0
			self._triggerOnTargetSince = nil
			self._triggerLastFireAt = nil
			self._triggerBurstLeft = nil
			self._triggerBurstAwaitReady = nil
			self._triggerBurstPlayer = nil
			self._triggerBurstSeenAt = nil
			self._triggerLatchedPlayer = nil
			self._triggerMagnetSince = nil
			self._triggerResetUntil = nil
			self._userFiredAt = nil
		end
	end

	function Legitbot._setFovActive(self: Legitbot, active: boolean): ()
		if active then
			if not self._fovConn then
				self._fovConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
					self:_renderTick()
				end))
			end
		else
			if self._fovConn then
				self._fovConn:Disconnect()
				self._fovConn = nil
			end
			self._aimFovViz:Update({
				enabled = false,
				fov = 0,
				color = AIM_FOV_COLOR,
				outlineColor = AIM_FOV_OUTLINE_COLOR,
				transparency = 1,
				outlineTransparency = 1,
			})
			self._triggerFovViz:Update({
				enabled = false,
				fov = 0,
				color = TRIGGER_FOV_COLOR,
				outlineColor = TRIGGER_FOV_OUTLINE_COLOR,
				transparency = 1,
				outlineTransparency = 1,
			})
			self._bulletRedirectionFovViz:Update({
				enabled = false,
				fov = 0,
				color = REDIRECTION_FOV_COLOR,
				outlineColor = REDIRECTION_FOV_OUTLINE_COLOR,
				transparency = 1,
				outlineTransparency = 1,
			})
		end
	end

	function Legitbot._setRcsActive(self: Legitbot, active: boolean): ()
		if active then
			if not self._rcsBound then
				self._rcsConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(dt)
					self:_rcsTick(dt)
				end))
				self._rcsBound = true
			end
		else
			if self._rcsBound then
				self._rcsConn:Disconnect()
				self._rcsConn = nil
				self._rcsBound = false
			end
		end
	end

	local function clearAimState(self: Legitbot): ()
		legitbotState.target(nil)
		legitbotState.targetPart(nil)
		legitbotApi.SetAimTarget(nil, nil, nil)
		self._lockedPlayer = nil
		self._firstSightAt = nil
		self._velX = 0
		self._velY = 0
		self._rtCount = 0
	end

	local function clearRedirectionState(self: Legitbot): ()
		local _game = self._game
		if not _game then
			return
		end

		local setBulletRedirectionTarget = _game.setBulletRedirectionTarget

		if setBulletRedirectionTarget then
			setBulletRedirectionTarget(nil)
		end

		legitbotApi.SetRedirectionTarget(nil)
	end

	local scheduleTriggerReset = LPH_NO_VIRTUALIZE(function(self: Legitbot): ()
		local delay = self._cache.triggerResetDelay
		if delay > 0 then
			self._triggerResetUntil = os.clock() + delay
		else
			self._triggerResetUntil = nil
		end
	end)

	local function clearTriggerState(self: Legitbot, applyResetDelay: boolean?): ()
		self._triggerOnTargetSince = nil
		self._triggerBurstLeft = nil
		self._triggerBurstAwaitReady = nil
		self._triggerBurstPlayer = nil
		self._triggerBurstSeenAt = nil
		legitbotApi.SetTriggerTarget(nil, nil, nil)
		legitbotApi.SetBurstRemaining(nil)
		if self._triggerFiring and self._game.stopFire then
			self._game.stopFire()
		end
		self._triggerFiring = false
		if applyResetDelay then
			scheduleTriggerReset(self)
		end
	end

	local function clearAllState(self: Legitbot): ()
		clearAimState(self)
		clearTriggerState(self)
		clearRedirectionState(self)
		self._triggerMagnetSince = nil
	end

	type Candidate = {
		player: any,
		part: BasePart,
		character: Model,
		pixelDistSq: number,
		hitboxName: string,
		targetPosition: Vector3,
		rank: number?,
	}

	type VisCacheEntry = {
		ok: boolean,
		wallbang: boolean,
	}

	local unionHitboxes = LPH_NO_VIRTUALIZE(function(a: { string }?, b: { string }?, c: { string }?): { string }
		local seen: { [string]: boolean } = {}
		local out: { string } = {}

		-- what the fuck?
		-- well i guess this is more performant then a loop through varargs
		if a then
			for _, name in next, a do
				if not seen[name] then
					seen[name] = true
					out[#out + 1] = name
				end
			end
		end

		if b then
			for _, name in next, b do
				if not seen[name] then
					seen[name] = true
					out[#out + 1] = name
				end
			end
		end

		if c then
			for _, name in next, c do
				if not seen[name] then
					seen[name] = true
					out[#out + 1] = name
				end
			end
		end

		return out
	end)

	Legitbot._getUnionHitboxes = LPH_NO_VIRTUALIZE(
		function(
			self: Legitbot,
			aimHitboxes: { string }?,
			bulletRedirectionHitboxes: { string }?,
			triggerHitboxes: { string }?
		): { string }
			local key = (aimHitboxes and 1 or 0) + (bulletRedirectionHitboxes and 2 or 0) + (triggerHitboxes and 4 or 0)
			local cached = self._unionHitboxesCache
			if cached and self._unionHitboxesKey == key then
				return cached
			end
			local merged = unionHitboxes(aimHitboxes, bulletRedirectionHitboxes, triggerHitboxes)
			self._unionHitboxesCache = merged
			self._unionHitboxesKey = key
			return merged
		end
	)

	Legitbot._buildCandidates = function(self: Legitbot, hitboxes: { string }, maxFovRadiusPx: number): { Candidate }
		local game = self._game
		local localTeam = game.getLocalTeam()
		local cx = self._refX
		local cy = self._refY
		local maxFovSq = maxFovRadiusPx > 0 and maxFovRadiusPx * maxFovRadiusPx or math.huge

		local camCF = camera.CFrame
		local camPosX, camPosY, camPosZ, r00, r01, r02, r10, r11, r12, r20, r21, r22 = camCF:GetComponents()
		local lookX, lookY, lookZ = -r02, -r12, -r22
		local viewport = camera.ViewportSize
		local halfX = viewport.X * 0.5
		local halfY = viewport.Y * 0.5
		local focal = cameraState.GetFocalY()

		local maxDistSq = self._maxDistanceSq

		local candidates = self._candidateBuf
		local count = 0
		local function pushCandidate(
			playerData: any,
			part: BasePart,
			character: Model,
			pixelDistSq: number,
			hitboxName: string,
			targetPosition: Vector3,
			rank: number
		): ()
			count += 1
			local c = candidates[count]
			if not c then
				c = {} :: any
				candidates[count] = c
			end
			c.player = playerData
			c.part = part
			c.character = character
			c.pixelDistSq = pixelDistSq
			c.hitboxName = hitboxName
			c.targetPosition = targetPosition
			c.rank = rank
		end
		local hasFilters = legitbotApi.HasTargetFilters()
		local forced = legitbotApi.GetForcedTarget()
		local equippedWeapon = game.getEquippedWeapon()
		local equippedScope = peek(legitbotApi.state.activeScope)
		local filterArg = self._filterArg
		local backtrackGetter = game.getBacktrackPosition

		local getCanSkipTeamcheck = game.getCanSkipTeamcheck
		local canSkip = getCanSkipTeamcheck and getCanSkipTeamcheck() or false

		local extraTargets = game.getExtraTargets

		local getHitboxParts = game.getHitboxParts
		local hitboxLists = self._hitboxListBuf
		local hitboxCount = #hitboxes
		for i = 1, hitboxCount do
			local name = hitboxes[i]
			hitboxLists[i] = (getHitboxParts and getHitboxParts(name)) or HITBOX_PARTS[name]
		end

		local function processTarget(playerData: any): ()
			if not peek(playerData.alive) then
				return
			end

			local isBot = playerData.isBot == true
			local playerTeam = peek(playerData.team)

			if not canSkip and (localTeam and localTeam ~= "" and playerTeam == localTeam) then
				return
			end

			local rbxPlayer = playerData:GetPlayer()
			if forced and rbxPlayer ~= forced then
				return
			end
			if not forced and rbxPlayer and not isBot and playerState.ShouldSkip(rbxPlayer.UserId) then
				return
			end
			local rank = (not forced and rbxPlayer and not isBot) and playerState.GetRank(rbxPlayer.UserId) or 0
			if hasFilters and rbxPlayer and not isBot then
				filterArg.player = rbxPlayer
				filterArg.weapon = equippedWeapon
				filterArg.scope = equippedScope
				if not legitbotApi.RunTargetFilters(filterArg) then
					return
				end
			end

			local character = peek(playerData.character)
			if not character then
				return
			end

			local parts = peek(playerData.parts)
			if next(parts) == nil then
				return
			end
			for hi = 1, hitboxCount do
				local list = hitboxLists[hi]
				if not list then
					continue
				end
				local hitboxName = hitboxes[hi]
				for _, partName in next, list do
					local part = parts[partName]
					if not part then
						continue
					end

					local realPos = part.Position
					local rpx = realPos.X - camPosX
					local rpy = realPos.Y - camPosY
					local rpz = realPos.Z - camPosZ
					local depth = rpx * lookX + rpy * lookY + rpz * lookZ
					if
						depth > 0
						and (maxDistSq <= 0 or rpx * rpx + rpy * rpy + rpz * rpz <= maxDistSq)
					then
						local inv = focal / depth
						local rdx = halfX + (rpx * r00 + rpy * r10 + rpz * r20) * inv - cx
						local rdy = halfY - (rpx * r01 + rpy * r11 + rpz * r21) * inv - cy
						local pixelDistSq = rdx * rdx + rdy * rdy
						if pixelDistSq <= maxFovSq then
							pushCandidate(playerData, part, character, pixelDistSq, hitboxName, realPos, rank)
						end
					end

					if self._targetBacktrack and rbxPlayer and not isBot and backtrackGetter then
						local ghost = backtrackGetter(rbxPlayer, partName)
						if ghost then
							local gx = ghost.X - camPosX
							local gy = ghost.Y - camPosY
							local gz = ghost.Z - camPosZ
							local gdepth = gx * lookX + gy * lookY + gz * lookZ
							if
								gdepth > 0
								and (maxDistSq <= 0 or gx * gx + gy * gy + gz * gz <= maxDistSq)
							then
								local inv = focal / gdepth
								local gdx = halfX + (gx * r00 + gy * r10 + gz * r20) * inv - cx
								local gdy = halfY - (gx * r01 + gy * r11 + gz * r21) * inv - cy
								local gPixelDistSq = gdx * gdx + gdy * gdy
								if gPixelDistSq <= maxFovSq then
									pushCandidate(
										playerData,
										part,
										character,
										gPixelDistSq,
										hitboxName,
										ghost,
										rank
									)
								end
							end
						end
					end
				end
			end
		end

		for _, playerData in next, PlayerController.GetAll() do
			processTarget(playerData)
		end
		if extraTargets then
			for _, playerData in next, extraTargets() do
				processTarget(playerData)
			end
		end

		self._candidateCount = count
		return candidates
	end

	local acquireVisEntry = LPH_NO_VIRTUALIZE(function(self: Legitbot, ok: boolean, wallbang: boolean): VisCacheEntry
		local n = self._visEntryCount + 1
		self._visEntryCount = n
		local entry = self._visEntryPool[n]
		if entry then
			entry.ok = ok
			entry.wallbang = wallbang
			return entry
		end
		entry = { ok = ok, wallbang = wallbang }
		self._visEntryPool[n] = entry
		return entry
	end)

	Legitbot._queryCandidateVisibility = LPH_NO_VIRTUALIZE(
		function(
			self: Legitbot,
			candidate: Candidate,
			throughSmokes: boolean,
			smokeThreshold: number,
			voxels: { [Part]: any },
			hasVoxels: boolean,
			penetrationOpts: PenetrationPickOpts?
		): VisCacheEntry
			local _game = self._game
			local part = candidate.part
			local usePen = penetrationOpts ~= nil and penetrationOpts.enabled and penetrationOpts.penetration > 0
			local cacheTable: { [any]: VisCacheEntry } = (usePen and self._visCachePen or self._visCache)
			local cached = cacheTable[candidate]
			if cached then
				return cached
			end

			local cameraPos = camera.CFrame.Position
			local toTarget = candidate.targetPosition - cameraPos
			local distance = toTarget.Magnitude
			if distance < EPSILON then
				local entry = acquireVisEntry(self, true, false)
				cacheTable[candidate] = entry
				return entry
			end

			local localCharacter = LocalPlayer.Character
			local backtrackFolder = _game.getBacktrackFolder and _game.getBacktrackFolder() or nil
			local ignoreFolder = _game.getIgnoreFolder and _game.getIgnoreFolder() or nil
			local filter = self._raycastFilter
			table.clear(filter)
			if localCharacter then
				filter[#filter + 1] = localCharacter
			end
			filter[#filter + 1] = candidate.character
			if backtrackFolder then
				filter[#filter + 1] = backtrackFolder
			end
			if ignoreFolder then
				filter[#filter + 1] = ignoreFolder
			end

			local wallbang = false
			local result: RaycastResult?
			if _game.gameRaycast then
				result = _game.gameRaycast(cameraPos, candidate.targetPosition, filter)
			else
				self._raycastParams.FilterDescendantsInstances = filter
				result = workspace:Raycast(cameraPos, toTarget, self._raycastParams)
			end
			if result then
				wallbang = true
				local pen = penetrationOpts
				if pen and pen.enabled and pen.penetration > 0 and _game.reachThroughWalls then
					if not _game.reachThroughWalls(cameraPos, part, pen.penetration, pen.maxRange, filter, nil) then
						local blocked = acquireVisEntry(self, false, true)
						cacheTable[candidate] = blocked
						return blocked
					end
				else
					local blocked = acquireVisEntry(self, false, true)
					cacheTable[candidate] = blocked
					return blocked
				end
			end

			if hasVoxels and _game.lengthThroughSmoke then
				local unit = toTarget / distance
				local smokeLength = _game.lengthThroughSmoke(cameraPos, unit, distance, voxels)
				if smokeLength > 0 then
					if not throughSmokes then
						local blocked = acquireVisEntry(self, false, wallbang)
						cacheTable[candidate] = blocked
						return blocked
					end
					local fraction = math.clamp(smokeLength / distance, 0, 1)
					if fraction > smokeThreshold then
						local blocked = acquireVisEntry(self, false, wallbang)
						cacheTable[candidate] = blocked
						return blocked
					end
				end
			end

			local entry = acquireVisEntry(self, true, wallbang)
			cacheTable[candidate] = entry
			return entry
		end
	)

	Legitbot._pickVisible = LPH_NO_VIRTUALIZE(
		function(
			self: Legitbot,
			candidates: { Candidate },
			fovRadiusPx: number,
			hitboxSet: { [string]: boolean },
			throughSmokes: boolean,
			smokeThreshold: number,
			voxels: { [Part]: any },
			hasVoxels: boolean,
			playerFilter: any?,
			penetrationOpts: PenetrationPickOpts?,
			ignoreVisibility: boolean?,
			forTrigger: boolean?
		): (any?, BasePart?, number, boolean, Vector3?)
			if fovRadiusPx <= 0 then
				return nil, nil, 0, false, nil
			end

			local fovRadiusSq = fovRadiusPx * fovRadiusPx
			local isPlayerBlocking = self._game.isPlayerBlocking
			local avoidDeflecting = self._cache.cnd_avoidDeflecting
			if forTrigger then
				if self._game.isPlayerTriggerBlocked then
					isPlayerBlocking = self._game.isPlayerTriggerBlocked
				end
				avoidDeflecting = self._cache.trg_avoidDeflecting
			end
			local isPlayerDeflecting = avoidDeflecting and self._game.isPlayerDeflecting or nil
			local bestCandidate: Candidate? = nil
			local bestWallbang = false
			local bestDistSq = fovRadiusSq
			local bestRank = -1
			for i = 1, self._candidateCount do
				local c = candidates[i]
				if playerFilter and c.player ~= playerFilter then
					continue
				end
				if c.pixelDistSq > fovRadiusSq then
					continue
				end
				if not hitboxSet[c.hitboxName] then
					continue
				end
				if isPlayerBlocking and isPlayerBlocking(c.player) then
					continue
				end
				if isPlayerDeflecting and isPlayerDeflecting(c.player) then
					continue
				end

				local wallbang = false
				if not ignoreVisibility then
					local vis = self:_queryCandidateVisibility(
						c,
						throughSmokes,
						smokeThreshold,
						voxels,
						hasVoxels,
						penetrationOpts
					)
					if not vis.ok then
						continue
					end
					wallbang = vis.wallbang
				end

				local rank = c.rank or 0
				if rank > bestRank or (rank == bestRank and c.pixelDistSq <= bestDistSq) then
					bestCandidate = c
					bestWallbang = wallbang
					bestDistSq = c.pixelDistSq
					bestRank = rank
				end
			end

			if bestCandidate then
				local alignment = math.clamp(1 - math.sqrt(bestDistSq) / fovRadiusPx, 0, 1)
				return bestCandidate.player, bestCandidate.part, alignment, bestWallbang, bestCandidate.targetPosition
			end

			return nil, nil, 0, false, nil
		end
	)

	local closestBoxPointToRay = LPH_NO_VIRTUALIZE(
		function(boxCF: CFrame, halfSize: Vector3, origin: Vector3, dir: Vector3): Vector3
			local lo = boxCF:PointToObjectSpace(origin)
			local ld = boxCF:VectorToObjectSpace(dir)
			local hx, hy, hz = halfSize.X, halfSize.Y, halfSize.Z
			local mclamp = math.clamp

			local t = -(lo.X * ld.X + lo.Y * ld.Y + lo.Z * ld.Z)
			if t < 0 then
				t = 0
			end

			local qx, qy, qz = 0, 0, 0
			for _ = 1, 6 do
				qx = mclamp(lo.X + ld.X * t, -hx, hx)
				qy = mclamp(lo.Y + ld.Y * t, -hy, hy)
				qz = mclamp(lo.Z + ld.Z * t, -hz, hz)
				t = (qx - lo.X) * ld.X + (qy - lo.Y) * ld.Y + (qz - lo.Z) * ld.Z
				if t < 0 then
					t = 0
				end
			end

			return boxCF:PointToWorldSpace(Vector3.new(qx, qy, qz))
		end
	)

	local releaseAssist = LPH_NO_VIRTUALIZE(function(self: Legitbot, dt: number): ()
		local vx, vy = self._velX, self._velY
		if vx == 0 and vy == 0 then
			return
		end
		local k = math.exp(-dt * ASSIST_RELEASE_RATE)
		vx *= k
		vy *= k
		if vx * vx + vy * vy < ASSIST_RELEASE_MIN * ASSIST_RELEASE_MIN then
			vx = 0
			vy = 0
		end
		self._velX = vx
		self._velY = vy
		if vx ~= 0 or vy ~= 0 then
			mousemoverel(vx, vy)
			self._pendingSelfDx = vx
			self._pendingSelfDy = vy
		end
	end)

	Legitbot._aimAssistTick = function(
		self: Legitbot,
		_dt: number,
		candidates: { Candidate },
		aimFovRadiusPx: number,
		aimHitboxSet: { [string]: boolean },
		throughSmokes: boolean,
		smokeThreshold: number,
		voxels: { [Part]: any },
		hasVoxels: boolean
	): ()
		local game = self._game
		local cache = self._cache
		local now = os.clock()
		local hitboxes = cache.hitboxes
		local reactionTime = cache.reactionTime
		local switchDelay = cache.switchDelay
		local sticky = cache.stickyTarget

		if not hitboxes or #hitboxes == 0 then
			clearAimState(self)
			return
		end

		local lockedPart: BasePart? = nil
		local lockedAlignment = 0
		local lockedTarget: Vector3? = nil
		if self._lockedPlayer and self._lockedPlayer:IsAlive() then
			local _, lp, la, _, lt = self:_pickVisible(
				candidates,
				aimFovRadiusPx,
				aimHitboxSet,
				throughSmokes,
				smokeThreshold,
				voxels,
				hasVoxels,
				self._lockedPlayer,
				nil
			)
			lockedPart = lp
			lockedAlignment = la
			lockedTarget = lt
		end

		local bestPlayer, bestPart, bestAlignment, _, bestTarget = self:_pickVisible(
			candidates,
			aimFovRadiusPx,
			aimHitboxSet,
			throughSmokes,
			smokeThreshold,
			voxels,
			hasVoxels,
			nil,
			nil
		)

		local effectivePart: BasePart?
		local effectivePlayer: any?
		local effectiveAlignment = 0
		local effectiveTarget: Vector3? = nil

		if lockedPart then
			if
				not sticky
				and bestPlayer
				and bestPlayer ~= self._lockedPlayer
				and now - self._lockedSince >= switchDelay
			then
				self._lockedPlayer = bestPlayer
				self._lockedSince = now
				effectivePart = bestPart
				effectivePlayer = bestPlayer
				effectiveAlignment = bestAlignment
				effectiveTarget = bestTarget
			else
				effectivePart = lockedPart
				effectivePlayer = self._lockedPlayer
				effectiveAlignment = lockedAlignment
				effectiveTarget = lockedTarget
			end
		elseif sticky and self._lockedPlayer and self._lockedPlayer:IsAlive() then
			legitbotState.target(nil)
			legitbotState.targetPart(nil)
			self._velX = 0
			self._velY = 0
			return
		elseif bestPlayer then
			if self._lockedPlayer and now - self._lockedSince < switchDelay then
				legitbotState.target(nil)
				legitbotState.targetPart(nil)
				self._velX = 0
				self._velY = 0
				return
			end

			if not self._lockedPlayer then
				if not self._firstSightAt then
					self._firstSightAt = now
				end
				if now - self._firstSightAt < reactionTime then
					legitbotState.target(nil)
					legitbotState.targetPart(nil)
					self._velX = 0
					self._velY = 0
					return
				end
			end

			self._lockedPlayer = bestPlayer
			self._lockedSince = now
			self._firstSightAt = nil
			effectivePart = bestPart
			effectivePlayer = bestPlayer
			effectiveAlignment = bestAlignment
			effectiveTarget = bestTarget
		else
			clearAimState(self)
			return
		end

		if not effectivePart then
			return
		end

		local effectivePlayerInst = effectivePlayer and effectivePlayer:GetPlayer() or nil
		local effectiveHitbox = effectivePart and PART_TO_HITBOX[effectivePart.Name]
		legitbotState.target(effectivePlayerInst)
		legitbotState.targetPart(effectivePart)
		legitbotApi.SetAimTarget(effectivePlayerInst, effectivePart, effectiveHitbox)

		local activation = cache.assistance
		local assistedMovementOk = activation == "Always On" or now - self._lastUserMoveTime <= USER_MOVE_GRACE
		if not assistedMovementOk then
			releaseAssist(self, _dt)
			return
		end

		if cache.aimFirstBulletDelay > 0 then
			local firedAt = self._userFiredAt
			if not firedAt or now - firedAt < cache.aimFirstBulletDelay then
				self._velX = 0
				self._velY = 0
				return
			end
		end

		local basePos = effectiveTarget or effectivePart.Position
		local aimPoint
		if cache.aimHzEnabled and cache.aimReactDelay > 0 then
			local reset = self._rtCount == 0 or effectivePlayer ~= self._rtTarget
			if not reset then
				local ni = (self._rtHead - 1) % RT_BUF_SIZE + 1
				local pt = self._rtBufT[ni]
				local jx = basePos.X - self._rtBufX[ni]
				local jy = basePos.Y - self._rtBufY[ni]
				local jz = basePos.Z - self._rtBufZ[ni]
				local vdt = now - pt
				if vdt > RT_GAP or jx * jx + jy * jy + jz * jz > RT_JUMP_SQ then
					reset = true
				elseif vdt > EPSILON then
					local a = 1 - math.exp(-vdt * RT_VEL_RATE)
					self._rtVelX = self._rtVelX + (jx / vdt - self._rtVelX) * a
					self._rtVelY = self._rtVelY + (jy / vdt - self._rtVelY) * a
					self._rtVelZ = self._rtVelZ + (jz / vdt - self._rtVelZ) * a
				end
			end
			if reset then
				self._rtTarget = effectivePlayer
				self._rtVelX = 0
				self._rtVelY = 0
				self._rtVelZ = 0
				self._rtHead = 0
				self._rtCount = 0
			end
			local wi = self._rtHead + 1
			self._rtBufX[wi] = basePos.X
			self._rtBufY[wi] = basePos.Y
			self._rtBufZ[wi] = basePos.Z
			self._rtBufT[wi] = now
			self._rtHead = (self._rtHead + 1) % RT_BUF_SIZE
			if self._rtCount < RT_BUF_SIZE then
				self._rtCount = self._rtCount + 1
			end
			local targetT = now - cache.aimReactDelay
			local sx, sy, sz = basePos.X, basePos.Y, basePos.Z
			local count = self._rtCount
			local head = self._rtHead
			local newer = (head - 1) % RT_BUF_SIZE
			local found = false
			for i = 1, count - 1 do
				local older = (head - 1 - i) % RT_BUF_SIZE
				local ot = self._rtBufT[older + 1]
				if ot <= targetT then
					local oi = older + 1
					local nii = newer + 1
					local span = self._rtBufT[nii] - ot
					local f = span > EPSILON and (targetT - ot) / span or 0
					sx = self._rtBufX[oi] + (self._rtBufX[nii] - self._rtBufX[oi]) * f
					sy = self._rtBufY[oi] + (self._rtBufY[nii] - self._rtBufY[oi]) * f
					sz = self._rtBufZ[oi] + (self._rtBufZ[nii] - self._rtBufZ[oi]) * f
					found = true
					break
				end
				newer = older
			end
			if not found then
				local oldest = (head - count) % RT_BUF_SIZE + 1
				sx = self._rtBufX[oldest]
				sy = self._rtBufY[oldest]
				sz = self._rtBufZ[oldest]
			end
			local ex = self._rtVelX * cache.aimReactDelay
			local ey = self._rtVelY * cache.aimReactDelay
			local ez = self._rtVelZ * cache.aimReactDelay
			local emsq = ex * ex + ey * ey + ez * ez
			if emsq > RT_EXTRAP_SQ then
				local s = RT_EXTRAP_MAX / math.sqrt(emsq)
				ex = ex * s
				ey = ey * s
				ez = ez * s
			end
			aimPoint = Vector3.new(sx + ex, sy + ey, sz + ez)
		else
			aimPoint = basePos
		end
		if
			cache.predictionEnabled
			and game.predictAimPoint
			and (cache.predictBulletComp or cache.predictMovementComp)
		then
			aimPoint = game.predictAimPoint({
				player = effectivePlayer,
				part = effectivePart,
				hitbox = effectiveHitbox,
				weapon = game.getEquippedWeapon(),
				aimPoint = aimPoint,
				origin = camera.CFrame.Position,
				bulletComp = cache.predictBulletComp,
				movementComp = cache.predictMovementComp,
			})
		end
		if cache.aimClosestPoint and camera then
			local pointRay = camera:ViewportPointToRay(self._refX, self._refY, 0)
			local boxCF = CFrame.new(aimPoint) * effectivePart.CFrame.Rotation
			aimPoint = closestBoxPointToRay(boxCF, effectivePart.Size * 0.5, pointRay.Origin, pointRay.Direction)
		end
		if legitbotApi.HasAimTransforms() and effectivePlayerInst then
			aimPoint = legitbotApi.RunAimTransforms({
				player = effectivePlayerInst,
				part = effectivePart,
				hitbox = effectiveHitbox,
				weapon = game.getEquippedWeapon(),
				aimPoint = aimPoint,
			})
		end
		local screenPos = (self._project :: screenProject.Projector)(aimPoint)
		local dx = screenPos.X - self._refX
		local dy = screenPos.Y - self._refY

		local sensitivity = cache.aimSensitivity
		local smoothing = self._smoothingCurve:SampleNormalized(effectiveAlignment)
		local strength = math.clamp(sensitivity * (1 - smoothing), 0, 1)

		if strength <= 0 then
			self._velX = 0
			self._velY = 0
			return
		end

		local errMag = math.sqrt(dx * dx + dy * dy)

		local uDx, uDy = self._userDx, self._userDy
		local uMagSq = uDx * uDx + uDy * uDy
		if errMag > EPSILON and uMagSq > EPSILON then
			local uMag = math.sqrt(uMagSq)
			local along = (uDx * dx + uDy * dy) / errMag
			if -along > uMag * ASSIST_AWAY_COS and uMag > ASSIST_AWAY_MIN_SPEED * _dt then
				releaseAssist(self, _dt)
				return
			end
		end

		if cache.aimHzEnabled and cache.aimDeadzone > 0 then
			local dz = cache.aimDeadzone * camera.ViewportSize.Y
			if errMag < dz then
				local t = errMag / dz
				strength = strength * t * t * (3 - 2 * t)
			end
		end

		if cache.aimOsEnabled then
			local vpY = camera.ViewportSize.Y
			local near = vpY * OS_NEAR
			if effectivePlayer ~= self._osTarget then
				self._osTarget = effectivePlayer
				self._osSettled = true
				self._osPrevErr = errMag
			end
			local closeRate = (self._osPrevErr - errMag) / _dt
			self._osPrevErr = errMag
			if
				self._osSettled
				and errMag < near
				and closeRate > vpY * cache.aimOsSpeedMin
				and now >= self._osRefractoryUntil
				and math.random() < cache.aimOsChance
			then
				local inv = 1 / errMag
				local speedNorm = math.clamp(closeRate / (vpY * OS_SPEED_REF), 0, 1)
				local amountPx = cache.aimOsAmount * OS_AMOUNT_MAX_VP * vpY
				local mag = math.min(amountPx * (OS_MAG_FLOOR + (1 - OS_MAG_FLOOR) * speedNorm), vpY * OS_MAX_VP)
				local a = (math.random() - 0.5) * OS_JITTER_RAD
				local cosA, sinA = math.cos(a), math.sin(a)
				local ux, uy = dx * inv, dy * inv
				self._osX = (ux * cosA - uy * sinA) * mag
				self._osY = (ux * sinA + uy * cosA) * mag
				self._osRefractoryUntil = now + OS_REFRACTORY
				self._osSettled = false
			elseif errMag < near * OS_SETTLE_FRAC then
				self._osSettled = true
			end
		end

		local frameDelta = math.min(_dt, DT_CAP) * DT_REFERENCE_FPS
		local closureFactor = 1 - (1 - strength) ^ frameDelta

		local desiredX = dx * closureFactor
		local desiredY = dy * closureFactor

		local velRamp = 1 - math.exp(-_dt * VELOCITY_SMOOTH_RATE)
		self._velX = self._velX + (desiredX - self._velX) * velRamp
		self._velY = self._velY + (desiredY - self._velY) * velRamp

		local injX = 0
		local injY = 0
		if cache.aimOsEnabled and (self._osX ~= 0 or self._osY ~= 0) then
			local k = math.exp(-_dt * cache.aimOsDecay)
			local nx = self._osX * k
			local ny = self._osY * k
			injX = self._osX - nx
			injY = self._osY - ny
			self._osX = nx
			self._osY = ny
		end

		mousemoverel(self._velX + injX, self._velY + injY)

		self._pendingSelfDx = self._velX + injX
		self._pendingSelfDy = self._velY + injY
	end

	Legitbot._bulletRedirectionTick = function(
		self: Legitbot,
		_dt: number,
		candidates: { Candidate },
		redirectionFovRadiusPx: number,
		redirectionHitboxSet: { [string]: boolean },
		throughSmokes: boolean,
		smokeThreshold: number,
		voxels: { [Part]: any },
		hasVoxels: boolean
	): ()
		local cache = self._cache
		local hitboxes = cache.bulletRedirectionHitboxes

		if not hitboxes or #hitboxes == 0 then
			clearRedirectionState(self)
			return
		end

		local game = self._game
		local weapon = game.getEquippedWeapon() :: any
		local penOpts: PenetrationPickOpts? = nil
		if cache.bulletRedirectionAutowall and weapon and game.getPenetrationOpts then
			penOpts = game.getPenetrationOpts(weapon)
		end

		local bestPlayer, bestPart, _, _, bestTarget = self:_pickVisible(
			candidates,
			redirectionFovRadiusPx,
			redirectionHitboxSet,
			throughSmokes,
			smokeThreshold,
			voxels,
			hasVoxels,
			nil,
			penOpts,
			cache.bulletRedirectionManipulation
		)

		local effectivePart: BasePart? = bestPart
		local effectivePlayer: any? = bestPlayer
		local effectiveTarget: Vector3? = bestTarget

		if not effectivePart or not effectivePlayer then
			clearRedirectionState(self)
			return
		end

		local _game = self._game
		_game.setBulletRedirectionTarget({
			position = effectiveTarget or effectivePart.Position,
			player = effectivePlayer,
			part = effectivePart,
		})

		legitbotApi.SetRedirectionTarget(effectivePart)
	end

	Legitbot._isCrosshairOnPart = LPH_NO_VIRTUALIZE(function(self: Legitbot, part: BasePart, character: Model): boolean
		local cam = camera
		if not cam then
			return false
		end
		local origin
		local direction
		if self._getAimPoint2d then
			local pointRay = cam:ViewportPointToRay(self._refX, self._refY, 0)
			origin = pointRay.Origin
			direction = pointRay.Direction * 1000
		else
			origin = cam.CFrame.Position
			direction = cam.CFrame.LookVector * 1000
		end
		local params = self._cursorRayParams
		if not params then
			params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.IgnoreWater = true
			params.RespectCanCollide = false
			self._cursorRayParams = params
			self._cursorRayFilter = {}
		end
		local filter = self._cursorRayFilter :: { Instance }
		filter[1] = character
		params.FilterDescendantsInstances = filter
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then
			return false
		end
		local hitInstance = hit.Instance
		if not hitInstance then
			return false
		end
		if hitInstance == part then
			return true
		end
		local targetHitbox = PART_TO_HITBOX[part.Name]
		if not targetHitbox then
			return false
		end
		return PART_TO_HITBOX[hitInstance.Name] == targetHitbox
	end)

	Legitbot._triggerTick = function(
		self: Legitbot,
		_dt: number,
		candidates: { Candidate },
		triggerFovRadiusPx: number,
		triggerHitboxSet: { [string]: boolean },
		throughSmokes: boolean,
		smokeThreshold: number,
		voxels: { [Part]: any },
		hasVoxels: boolean
	): ()
		local game = self._game
		local cache = self._cache
		local hitboxes = cache.triggerHitboxes

		if not hitboxes or #hitboxes == 0 then
			clearTriggerState(self)
			self._triggerMagnetSince = nil
			return
		end

		local weapon = game.getEquippedWeapon() :: any
		local penOpts: PenetrationPickOpts? = nil
		if cache.triggerAutowall and weapon and game.getPenetrationOpts then
			penOpts = game.getPenetrationOpts(weapon)
		end

		local targetPlayer, part, trigAlign, pickWallbang, trigTarget = self:_pickVisible(
			candidates,
			triggerFovRadiusPx,
			triggerHitboxSet,
			throughSmokes,
			smokeThreshold,
			voxels,
			hasVoxels,
			nil,
			penOpts,
			nil,
			true
		)
		if not part then
			local burstLeft = self._triggerBurstLeft
			if burstLeft ~= nil and burstLeft > 0 then
				local seenAt = self._triggerBurstSeenAt
				if seenAt and os.clock() - seenAt < TRIGGER_BURST_GRACE then
					self._triggerMagnetSince = nil
					return
				end
			end
			self._triggerLatchedPlayer = nil
			clearTriggerState(self, self._triggerFiring)
			self._triggerMagnetSince = nil
			return
		end

		local rbxPlayer = targetPlayer and targetPlayer:GetPlayer() or nil
		local hitboxName: string? = part and PART_TO_HITBOX[part.Name]

		local latched = self._triggerLatchedPlayer
		if latched ~= nil and latched ~= targetPlayer then
			self._triggerLatchedPlayer = nil
			self._triggerOnTargetSince = nil
			self._triggerBurstLeft = nil
			self._triggerBurstAwaitReady = nil
			self._triggerBurstPlayer = nil
			self._triggerBurstSeenAt = nil
			latched = nil
		end

		if self._triggerBurstPlayer ~= nil and self._triggerBurstPlayer ~= targetPlayer then
			self._triggerOnTargetSince = nil
			self._triggerBurstLeft = nil
			self._triggerBurstAwaitReady = nil
			self._triggerBurstPlayer = nil
			self._triggerBurstSeenAt = nil
		end

		if cache.triggerMagnet then
			if not self._triggerMagnetSince then
				self._triggerMagnetSince = os.clock()
			end
		else
			self._triggerMagnetSince = nil
		end

		if not weapon or not game.canShoot(weapon) then
			clearTriggerState(self)
			return
		end

		local cameraPos = camera.CFrame.Position
		local hitP: number? = nil
		if game.estimateHitChance then
			hitP = game.estimateHitChance(cameraPos, part, weapon)
			if hitP ~= nil and hitP * 100 < cache.triggerHitChance then
				clearTriggerState(self)
				return
			end
		end

		local predictedDamage: number? = nil
		local isWallbang: boolean? = nil

		if pickWallbang and cache.triggerAutowallMinDamage > 0 and game.predictDamage then
			isWallbang = true
			predictedDamage = game.predictDamage(cameraPos, part, weapon, true, targetPlayer)
			local targetHealth = targetPlayer and peek(targetPlayer.health) or 0
			if predictedDamage < prediction.effectiveMinDamage(cache.triggerAutowallMinDamage, targetHealth) then
				clearTriggerState(self)
				return
			end
		elseif not pickWallbang and cache.triggerMinDamage > 0 and game.predictDamage then
			isWallbang = false
			predictedDamage = game.predictDamage(cameraPos, part, weapon, false, targetPlayer)
			local targetHealth = targetPlayer and peek(targetPlayer.health) or 0
			if predictedDamage < prediction.effectiveMinDamage(cache.triggerMinDamage, targetHealth) then
				clearTriggerState(self)
				return
			end
		end

		local nowMag = os.clock()
		local magnetReactionOk = self._triggerMagnetSince ~= nil
			and nowMag - self._triggerMagnetSince >= cache.triggerMagnetReactionTime

		if cache.triggerMagnet and magnetReactionOk and self._magnetCurve and camera then
			local strength = math.clamp((self._magnetCurve :: any):SampleNormalized(math.clamp(trigAlign, 0, 1)), 0, 1)
			if strength > EPSILON then
				local screenPos = (self._project :: screenProject.Projector)(trigTarget or part.Position)
				local dx = screenPos.X - self._refX
				local dy = screenPos.Y - self._refY
				local distSq = dx * dx + dy * dy
				if distSq > EPSILON * EPSILON then
					local frameDelta = math.min(_dt, DT_CAP) * DT_REFERENCE_FPS
					local closureFactor = 1 - (1 - strength) ^ frameDelta
					local mx = dx * closureFactor
					local my = dy * closureFactor
					mousemoverel(mx, my)
					self._pendingSelfDx += mx
					self._pendingSelfDy += my
					local mxmagSq = mx * mx + my * my
					if mxmagSq > USER_MOVE_THRESHOLD * USER_MOVE_THRESHOLD then
						self._lastUserMoveTime = os.clock()
					end
					if rbxPlayer then
						legitbotApi.NotifyMagnetPull({
							player = rbxPlayer,
							part = part,
							dx = mx,
							dy = my,
							strength = strength,
						})
					end
				end
			end
		end

		if cache.triggerMode == "On Hitbox" then
			local character = targetPlayer and peek(targetPlayer.character) or nil
			if not character or not self:_isCrosshairOnPart(part, character) then
				clearTriggerState(self)
				return
			end
		end

		local now = os.clock()
		local bulletCap = cache.triggerBullets
		local unlimited = bulletCap <= 0

		if self._triggerBurstLeft ~= nil then
			self._triggerBurstSeenAt = now
		end

		if latched ~= nil then
			local resetUntil = self._triggerResetUntil
			if resetUntil == nil or now < resetUntil then
				return
			end
			self._triggerLatchedPlayer = nil
			self._triggerResetUntil = nil
			self._triggerOnTargetSince = now
		end

		if self._triggerResetUntil and now < self._triggerResetUntil then
			return
		end

		legitbotApi.SetTriggerTarget(rbxPlayer, part, hitboxName)

		local canFire = game.canFire or game.canShoot

		if self._triggerBurstLeft ~= nil and self._triggerBurstLeft > 0 then
			local awaitReady = self._triggerBurstAwaitReady
			if awaitReady == false then
				if canFire(weapon) then
					return
				end
				self._triggerBurstAwaitReady = true
				return
			elseif awaitReady == true then
				if not canFire(weapon) then
					return
				end
				if legitbotApi.HasShotGates() then
					if
						not legitbotApi.RunShotGates({
							player = rbxPlayer,
							part = part,
							hitbox = hitboxName,
							weapon = weapon,
							predictedDamage = predictedDamage,
							hitChance = hitP,
							wallbang = isWallbang,
							burst = true,
						})
					then
						return
					end
				end
				if cache.triggerAutowall and penOpts and game.reachThroughWalls then
					local localCharacter = LocalPlayer.Character
					local enemyModel = part:FindFirstAncestorWhichIsA("Model")
					local ign = TRIGGER_IGNORE_SCRATCH
					table.clear(ign)
					if localCharacter then
						ign[1] = localCharacter
						if enemyModel then
							ign[2] = enemyModel
						end
					elseif enemyModel then
						ign[1] = enemyModel
					end
					game.reachThroughWalls(cameraPos, part, penOpts.penetration, penOpts.maxRange, ign, true)
				end
				if game.fire then
					game.fire(weapon)
				else
					mouse1click()
				end
				self._triggerFiring = true
				self._triggerBurstLeft = self._triggerBurstLeft - 1
				self._triggerLastFireAt = now
				legitbotApi.NotifyShotFired({
					player = rbxPlayer,
					part = part,
					hitbox = hitboxName,
					predictedDamage = predictedDamage,
					hitChance = hitP,
					wallbang = isWallbang,
					weapon = weapon,
					source = "triggerbot",
					burst = true,
				})
				legitbotApi.SetBurstRemaining(self._triggerBurstLeft)
				if self._triggerBurstLeft <= 0 then
					self._triggerBurstLeft = nil
					self._triggerBurstAwaitReady = nil
					self._triggerLatchedPlayer = targetPlayer
					scheduleTriggerReset(self)
					legitbotApi.SetBurstRemaining(nil)
					legitbotApi.SetTriggerTarget(nil, nil, nil)
				else
					self._triggerBurstAwaitReady = false
				end
				return
			end
		end

		local fireRequested = legitbotApi.ConsumeShotRequest()

		if not self._triggerOnTargetSince then
			self._triggerOnTargetSince = now
			if not fireRequested then
				return
			end
		end

		if not fireRequested and now - self._triggerOnTargetSince < cache.triggerShotDelay then
			return
		end

		if not fireRequested and cache.triggerFirstBulletDelay > 0 then
			local firedAt = self._userFiredAt
			if not firedAt then
				return
			end
			if now - firedAt < cache.triggerFirstBulletDelay then
				return
			end
		end

		if self._triggerLastFireAt and now - self._triggerLastFireAt < 0.01 then
			return
		end

		if legitbotApi.HasShotGates() then
			if
				not legitbotApi.RunShotGates({
					player = rbxPlayer,
					part = part,
					hitbox = hitboxName,
					weapon = weapon,
					predictedDamage = predictedDamage,
					hitChance = hitP,
					wallbang = isWallbang,
					burst = false,
				})
			then
				return
			end
		end

		if cache.triggerAutowall and penOpts and game.reachThroughWalls then
			local localCharacter = LocalPlayer.Character
			local enemyModel = part:FindFirstAncestorWhichIsA("Model")
			local ign = TRIGGER_IGNORE_SCRATCH
			table.clear(ign)
			if localCharacter then
				ign[1] = localCharacter
				if enemyModel then
					ign[2] = enemyModel
				end
			elseif enemyModel then
				ign[1] = enemyModel
			end
			game.reachThroughWalls(cameraPos, part, penOpts.penetration, penOpts.maxRange, ign, true)
		end

		if game.fire then
			game.fire(weapon)
		else
			mouse1click()
		end
		self._triggerFiring = true
		self._triggerLastFireAt = now
		legitbotApi.NotifyShotFired({
			player = rbxPlayer,
			part = part,
			hitbox = hitboxName,
			predictedDamage = predictedDamage,
			hitChance = hitP,
			wallbang = isWallbang,
			weapon = weapon,
			source = "triggerbot",
			burst = false,
		})
		if unlimited then
			self._triggerOnTargetSince = nil
		elseif bulletCap > 1 then
			self._triggerBurstLeft = bulletCap - 1
			self._triggerBurstAwaitReady = false
			self._triggerBurstPlayer = targetPlayer
			self._triggerBurstSeenAt = now
			legitbotApi.SetBurstRemaining(self._triggerBurstLeft)
		else
			self._triggerLatchedPlayer = targetPlayer
			scheduleTriggerReset(self)
			legitbotApi.SetTriggerTarget(nil, nil, nil)
		end
	end

	Legitbot._buildTargetSnapshots = LPH_NO_VIRTUALIZE(function(self: Legitbot): { legitbotApi.TargetSnapshot }
		local snapshots: { legitbotApi.TargetSnapshot } = {}
		local candidates = self._candidateBuf
		local maxFovRadiusPx = self._lastMaxFovRadiusPx
		local cameraPos = camera.CFrame.Position
		for i = 1, self._candidateCount do
			local c = candidates[i]
			local rbxPlayer = c.player and not c.player.isBot and c.player:GetPlayer()
			if rbxPlayer then
				local pixelDist = math.sqrt(c.pixelDistSq)
				snapshots[#snapshots + 1] = {
					player = rbxPlayer,
					part = c.part,
					hitbox = c.hitboxName,
					distance = (c.part.Position - cameraPos).Magnitude,
					pixelDist = pixelDist,
					alignment = (maxFovRadiusPx > 0 and math.clamp(1 - pixelDist / maxFovRadiusPx, 0, 1) or 0),
				}
			end
		end
		return snapshots
	end)

	Legitbot._tick = function(self: Legitbot, dt: number): ()
		local game = self._game
		local cache = self._cache

		if not game.getLocalAlive() then
			clearAllState(self)
			return
		end

		local weapon = game.getEquippedWeapon()
		if not weapon then
			clearAllState(self)
			return
		end

		local aimOn = cache.aimEnabled
		local bulletRedirectionOn = cache.bulletRedirectionEnabled
		local triggerOn = cache.triggerEnabled

		if cache.cnd_waitForScope or cache.trg_waitForScope then
			local scopedIn = game.isScopedIn ~= nil and game.isScopedIn() or false
			if cache.cnd_waitForScope and not scopedIn then
				aimOn = false
				bulletRedirectionOn = false
			end
			if cache.trg_waitForScope and not scopedIn then
				triggerOn = false
			end
		end

		if cache.cnd_waitForAim or cache.trg_waitForAim then
			local aiming = game.isAiming ~= nil and game.isAiming() or false
			if cache.cnd_waitForAim and not aiming then
				aimOn = false
				bulletRedirectionOn = false
			end
			if cache.trg_waitForAim and not aiming then
				triggerOn = false
			end
		end

		if triggerOn and cache.trg_waitForCharge and game.getChargePercent then
			local chargePercent = game.getChargePercent()
			if chargePercent ~= nil and chargePercent < cache.trg_chargeThreshold then
				triggerOn = false
			end
		end

		if game.getLocalReloading and not cache.cnd_whileReloading and game.getLocalReloading() then
			aimOn = false
			triggerOn = false
			bulletRedirectionOn = false
		end

		if game.getLocalOutOfAmmo and not cache.cnd_whileOutOfAmmo and game.getLocalOutOfAmmo() then
			aimOn = false
			triggerOn = false
			bulletRedirectionOn = false
		end

		if game.getLocalOnCooldown and not cache.cnd_whileOnCooldown and game.getLocalOnCooldown() then
			aimOn = false
			triggerOn = false
			bulletRedirectionOn = false
		end

		if game.getLocalSwitching and not cache.cnd_whileSwitching and game.getLocalSwitching() then
			aimOn = false
			triggerOn = false
			bulletRedirectionOn = false
		end

		if game.getLocalSprinting and game.getLocalSprinting() and not cache.cnd_whileSprinting then
			aimOn = false
			triggerOn = false
		end

		if game.getTargetingDisabled and game.getTargetingDisabled() then
			aimOn = false
			triggerOn = false
			bulletRedirectionOn = false
		end

		if peek(uiState.isOpen) then
			aimOn = false
		end

		if not aimOn and not triggerOn and not bulletRedirectionOn then
			clearAllState(self)
			return
		end

		if game.getFlashVisibility then
			local flashVisibility = game.getFlashVisibility()
			if flashVisibility > 0 then
				if not cache.cnd_whileBlind or flashVisibility > cache.blindThreshold then
					clearAllState(self)
					return
				end
			end
		end

		if game.getLocalInAir and game.getLocalInAir() and not cache.cnd_whileInAir then
			clearAllState(self)
			return
		end

		local getAimPoint2d = self._getAimPoint2d
		if getAimPoint2d then
			local refPoint = getAimPoint2d()
			self._refX = refPoint.X
			self._refY = refPoint.Y
		else
			local refViewport = camera.ViewportSize
			self._refX = refViewport.X * 0.5
			self._refY = refViewport.Y * 0.5
		end

		local rawDelta
		if getAimPoint2d and UserInputService.MouseBehavior == Enum.MouseBehavior.Default then
			local mouseLocation = UserInputService:GetMouseLocation()
			local lastLocation = self._lastMouseLocation
			rawDelta = lastLocation and mouseLocation - lastLocation or Vector2.zero
			self._lastMouseLocation = mouseLocation
		else
			rawDelta = UserInputService:GetMouseDelta()
			self._lastMouseLocation = nil
		end
		local pendingDx = self._pendingSelfDx
		local pendingDy = self._pendingSelfDy
		self._pendingSelfDx = 0
		self._pendingSelfDy = 0

		local injectedMagSq = pendingDx * pendingDx + pendingDy * pendingDy
		if injectedMagSq > SELF_SCALE_MIN_INJECT_SQ then
			local instantScale =
				math.clamp((rawDelta.X * pendingDx + rawDelta.Y * pendingDy) / injectedMagSq, 0, SELF_SCALE_MAX)
			if self._selfScaleInit then
				self._selfScale += (instantScale - self._selfScale) * SELF_SCALE_RATE
			else
				self._selfScale = instantScale
				self._selfScaleInit = true
			end
		end

		local scale = self._selfScale
		local userDx = rawDelta.X - scale * pendingDx
		local userDy = rawDelta.Y - scale * pendingDy
		self._userDx = userDx
		self._userDy = userDy

		local userMag = math.sqrt(userDx * userDx + userDy * userDy)
		local moveThreshold = USER_MOVE_THRESHOLD + math.sqrt(injectedMagSq) * SELF_FEEDBACK_TOLERANCE
		if userMag > moveThreshold then
			self._lastUserMoveTime = os.clock()
		end

		local throughSmokes = cache.cnd_throughSmokes
		local smokeThreshold = cache.smokeThreshold

		local aimHitboxes = aimOn and cache.hitboxes or nil
		local redirectionHitboxes = bulletRedirectionOn and cache.bulletRedirectionHitboxes or nil
		local triggerHitboxes = triggerOn and cache.triggerHitboxes or nil
		local hitboxes = self:_getUnionHitboxes(aimHitboxes, redirectionHitboxes, triggerHitboxes)
		if #hitboxes == 0 then
			clearAllState(self)
			return
		end

		if game.beginPenetrationStep then
			game.beginPenetrationStep()
		end
		table.clear(self._visCache)
		table.clear(self._visCachePen)
		self._visEntryCount = 0

		local aimFovRadiusPx = aimOn and cameraState.FovToPixels(cache.fov) or 0
		local redirectionFovRadiusPx = bulletRedirectionOn and cameraState.FovToPixels(cache.bulletRedirectionFov) or 0
		local triggerFovRadiusPx = triggerOn and cameraState.FovToPixels(cache.triggerFov) or 0
		local maxFovRadiusPx = math.max(aimFovRadiusPx, triggerFovRadiusPx, redirectionFovRadiusPx)

		local voxels: { [Part]: any } = (game.getSmokeVoxels and game.getSmokeVoxels()) or EMPTY_VOXELS
		local hasVoxels = next(voxels) ~= nil

		self._project = screenProject.make(camera, camera.ViewportSize)

		local candidates = self:_buildCandidates(hitboxes, maxFovRadiusPx)
		self._lastMaxFovRadiusPx = maxFovRadiusPx

		local aimHitboxSet = aimOn and cache.hitboxSet or nil
		local redirectionHitboxSet = bulletRedirectionOn and cache.bulletRedirectionHitboxSet or nil
		local triggerHitboxSet = triggerOn and cache.triggerHitboxSet or nil

		if aimOn and aimHitboxSet then
			self:_aimAssistTick(
				dt,
				candidates,
				aimFovRadiusPx,
				aimHitboxSet,
				throughSmokes,
				smokeThreshold,
				voxels,
				hasVoxels
			)
		else
			clearAimState(self)
		end

		if bulletRedirectionOn and redirectionHitboxSet then
			self:_bulletRedirectionTick(
				dt,
				candidates,
				redirectionFovRadiusPx,
				redirectionHitboxSet,
				throughSmokes,
				smokeThreshold,
				voxels,
				hasVoxels
			)
		else
			clearRedirectionState(self)
		end

		if triggerOn and triggerHitboxSet then
			self:_triggerTick(
				dt,
				candidates,
				triggerFovRadiusPx,
				triggerHitboxSet,
				throughSmokes,
				smokeThreshold,
				voxels,
				hasVoxels
			)
		else
			clearTriggerState(self)
			self._triggerMagnetSince = nil
		end
	end

	Legitbot._rcsTick = LPH_NO_VIRTUALIZE(function(self: Legitbot, dt: number): ()
		local game = self._game
		local cache = self._cache

		local weapon = game.getEquippedWeapon() :: any
		if not weapon then
			return
		end

		if not game.computeRcsDelta then
			return
		end

		if game.canRcs and not game.canRcs(weapon) then
			return
		end

		if not cache.rcsEnabled then
			return
		end

		local strength = cache.rcsStrength
		if strength <= 0 then
			return
		end

		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end

		local mouseDx, mouseDy = game.computeRcsDelta(weapon, dt, cache.rcsVerticalOnly, strength, cam)
		if not mouseDx or not mouseDy then
			return
		end

		mousemoverel(mouseDx, mouseDy)
		self._pendingSelfDx = self._pendingSelfDx + mouseDx
		self._pendingSelfDy = self._pendingSelfDy + mouseDy
	end)

	Legitbot._renderTick = LPH_NO_VIRTUALIZE(function(self: Legitbot): ()
		local cache = self._cache

		local center: Vector2? = nil
		local getAimPoint2d = self._getAimPoint2d
		if getAimPoint2d then
			center = getAimPoint2d()
		end

		local aimOpts = self._aimFovOpts
		aimOpts.center = center
		aimOpts.enabled = cache.aimFovVizEnabled
		aimOpts.fov = cache.fov
		aimOpts.color = cache.aimFovColor
		aimOpts.outlineColor = cache.aimFovOutlineColor
		aimOpts.transparency = cache.aimFovTransparency
		aimOpts.outlineTransparency = cache.aimFovOutlineTransparency
		aimOpts.rotation = cache.aimFovRotation
		aimOpts.outlineRotation = cache.aimFovOutlineRotation
		self._aimFovViz:Update(aimOpts)

		local triggerOpts = self._triggerFovOpts
		triggerOpts.center = center
		triggerOpts.enabled = cache.triggerFovVizEnabled
		triggerOpts.fov = cache.triggerFov
		triggerOpts.color = cache.triggerFovColor
		triggerOpts.outlineColor = cache.triggerFovOutlineColor
		triggerOpts.transparency = cache.triggerFovTransparency
		triggerOpts.outlineTransparency = cache.triggerFovOutlineTransparency
		triggerOpts.rotation = cache.triggerFovRotation
		triggerOpts.outlineRotation = cache.triggerFovOutlineRotation
		self._triggerFovViz:Update(triggerOpts)

		local redirectionOpts = self._bulletRedirectionFovOpts
		redirectionOpts.center = center
		redirectionOpts.enabled = cache.bulletRedirectionFovVizEnabled
		redirectionOpts.fov = cache.bulletRedirectionFov
		redirectionOpts.color = cache.bulletRedirectionFovColor
		redirectionOpts.outlineColor = cache.bulletRedirectionFovOutlineColor
		redirectionOpts.transparency = cache.bulletRedirectionFovTransparency
		redirectionOpts.outlineTransparency = cache.bulletRedirectionFovOutlineTransparency
		redirectionOpts.rotation = cache.bulletRedirectionFovRotation
		redirectionOpts.outlineRotation = cache.bulletRedirectionFovOutlineRotation
		self._bulletRedirectionFovViz:Update(redirectionOpts)
	end)

	function Legitbot.GetResolvedSettings(_self: Legitbot, scopeId: string?): { [string]: any }
		return ScopeController.GetResolvedSettings(scopeId)
	end

	function Legitbot.Destroy(self: Legitbot): ()
		self:_setTargetingActive(false)
		self:_setFovActive(false)
		self:_setRcsActive(false)
		self._aimFovViz:Destroy()
		self._triggerFovViz:Destroy()
		self._bulletRedirectionFovViz:Destroy()
		BaseFeature.Destroy(self)
	end

	export type Legitbot =
		typeof(setmetatable(
			{} :: {
				_game: GameOpts,
				_visualsLink: gameUi.Linker,
				_smoothingCurve: any,
				_magnetCurve: any,
				_uiOpts: legitbotUi.UiOpts,
				_getAimPoint2d: (() -> Vector2)?,
				_refX: number,
				_refY: number,
				_lastMouseLocation: Vector2?,
				_lastUserMoveTime: number,
				_pendingSelfDx: number,
				_pendingSelfDy: number,
				_selfScale: number,
				_selfScaleInit: boolean,
				_velX: number,
				_velY: number,
				_userDx: number,
				_userDy: number,
				_osTarget: any?,
				_osX: number,
				_osY: number,
				_osRefractoryUntil: number,
				_osSettled: boolean,
				_osPrevErr: number,
				_rtTarget: any?,
				_rtBufX: { number },
				_rtBufY: { number },
				_rtBufZ: { number },
				_rtBufT: { number },
				_rtHead: number,
				_rtCount: number,
				_rtVelX: number,
				_rtVelY: number,
				_rtVelZ: number,
				_raycastParams: RaycastParams,
				_raycastFilter: { Instance },
				_candidateBuf: { Candidate },
				_hitboxListBuf: { { string }? },
				_candidateCount: number,
				_lastMaxFovRadiusPx: number,
				_visCache: { [any]: VisCacheEntry },
				_visCachePen: { [any]: VisCacheEntry },
				_visEntryPool: { VisCacheEntry },
				_visEntryCount: number,
				_unionHitboxesCache: { string }?,
				_unionHitboxesKey: number,
				_cursorRayParams: RaycastParams?,
				_cursorRayFilter: { Instance }?,
				_lockedPlayer: any?,
				_lockedSince: number,
				_firstSightAt: number?,
				_triggerOnTargetSince: number?,
				_triggerLastFireAt: number?,
				_triggerBurstLeft: number?,
				_triggerBurstAwaitReady: boolean?,
				_triggerBurstPlayer: any?,
				_triggerBurstSeenAt: number?,
				_triggerFiring: boolean,
				_triggerLatchedPlayer: any?,
				_userFiredAt: number?,
				_triggerMagnetSince: number?,
				_triggerResetUntil: number?,
				_aimFovViz: fovVisualization.FovVisualization,
				_triggerFovViz: fovVisualization.FovVisualization,
				_bulletRedirectionFovViz: fovVisualization.FovVisualization,
				_aimFovOpts: fovVisualization.FovOpts,
				_triggerFovOpts: fovVisualization.FovOpts,
				_bulletRedirectionFovOpts: fovVisualization.FovOpts,
				_cache: any,
				_targetingConn: RBXScriptConnection?,
				_fovConn: RBXScriptConnection?,
				_rcsBound: boolean,
				_rcsConn: RBXScriptConnection?,
				_targetBacktrack: boolean,
				_maxDistanceSq: number,
			},
			Legitbot
		))
		& BaseFeature.BaseFeature

	return Legitbot
end)()
