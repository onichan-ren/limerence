return LPH_JIT_MAX(function()
	local RunService = cloneref(game:GetService("RunService")) :: RunService
	local Players = cloneref(game:GetService("Players")) :: Players
	local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

	local Charm = require("@pkg/Charm")
	local BaseFeature = require("@game/BaseFeature")
	local gameUi = require("@game/gameUi")
	local ScopeController = require("@feature/ui/scope/ScopeController")
	local PlayerController = require("@feature/player/PlayerController")
	local ClientState = require("@game/bloxstrike/client/clientState")
	local ClientController = require("@game/bloxstrike/client/ClientController")
	local localLookController = require("@game/bloxstrike/client/localLookController")
	local LoadoutState = require("@game/bloxstrike/loadout/loadoutState")
	local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
	local NetworkController = require("@game/bloxstrike/network/NetworkController")
	local gamemodeState = require("@game/bloxstrike/gamemodeState")
	local fakeShoot = require("@game/bloxstrike/weapon/fakeShoot")
	local hitboxParts = require("@game/universal/feature/combat/legitbot/hitboxParts")
	local ragebotFov = require("@game/universal/feature/combat/ragebot/ragebotFov")
	local prediction = require("@game/universal/feature/combat/prediction")
	local spreadHitChance = require("@game/bloxstrike/feature/legitbot/spreadHitChance")
	local weaponSpreadState = require("@game/bloxstrike/client/weaponSpreadState")
	local predictDamage = require("@game/bloxstrike/feature/legitbot/predictDamage")
	local penetrationQuery = require("@game/bloxstrike/feature/legitbot/penetrationQuery")
	local bulletPenetrationRay = require("@game/bloxstrike/feature/legitbot/bulletPenetrationRay")
	local multipoint = require("@game/universal/feature/combat/ragebot/multipoint")
	local scopes = require("@game/bloxstrike/feature/scopes")
	local Backtrack = require("@game/bloxstrike/feature/ragebot/Backtrack")
	local InfinitePenetration = require("@game/bloxstrike/feature/ragebot/InfinitePenetration")
	local RapidFire = require("@game/bloxstrike/feature/ragebot/RapidFire")
	local ragebotApi = require("@game/bloxstrike/feature/ragebot/ragebotApi")
	local AutoStop = require("@game/bloxstrike/feature/ragebot/AutoStop")
	local playerState = require("@feature/record/module/playerState")
	local sessionState = require("@feature/session/sessionState")
	local MotionTracker = require("@game/bloxstrike/player/MotionTracker")
	local screenProject = require("@share/screenProject")

	local peek = Charm.peek
	local sub = Charm.subscribe

	local LocalPlayer = Players.LocalPlayer

	local HITBOX_PARTS = hitboxParts.HITBOX_PARTS

	local HITBOX_OPTIONS: { string } = { "Head", "Torso", "Arms", "Legs", "Feet" }
	local HITBOX_PRIORITY: { string } = { "Head", "Torso", "Arms", "Legs", "Feet" }
	local DEFAULT_HITBOXES: { string } = { "Head" }
	local SCAN_ORIGIN_OPTIONS: { string } = { "Camera", "Fair" }
	local TARGETING_OPTIONS: { string } = { "Closest To Crosshair", "Highest Damage" }

	type CandidatePoint = {
		player: any,
		part: BasePart,
		character: Model,
		aimPoint: Vector3,
		shotOrigin: Vector3,
		spoofed: boolean,
		wallbang: boolean,
		hitChance: number?,
		damage: number,
		source: string,
		targetInstance: Instance?,
		effectiveCF: CFrame,
		partSize: Vector3,
	}

	local function dprint(...: any): ()
		print("[ragebot]", ...)
	end

	local Ragebot = {}
	Ragebot.__index = Ragebot

	setmetatable(Ragebot, { __index = BaseFeature })

	local _instance: any = nil

	local originOffset = Vector3.zero

	function Ragebot.SetOriginOffset(offset: Vector3?): ()
		originOffset = offset or Vector3.zero
	end

	local SHIFT_VERTICES: { Vector3 } = {
		Vector3.new(0, 0, -1),
		Vector3.new(0, -1, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new(1, 0, 0),
	}

	local shiftOriginBuf: { Vector3 } = {}
	local shiftHitBuf: { Vector3 } = {}

	local altCFBuf: { CFrame } = table.create(8)
	local altInstBuf: { Instance } = table.create(8)
	local altSrcBuf: { string } = table.create(8)
	local poseSnapBuf: { { [string]: CFrame } } = table.create(8)

	local MAX_BACKTRACK_POSES = 5
	local POSE_MIN_SPACING = 0.05
	local POSE_MIN_MOVE_SQ = 0.35 * 0.35
	local ESCALATED_SCALE = 0.97
	local ESCALATED_INSET = 0.97
	local ESCALATION_SKIP_AT = 0.9
	local CACHE_VEL_SKIP_SQ = 4
	local RAY_BUDGET = 100
	local MAX_CROSSHAIR_SCANS = 4

	local fillShiftCandidates = LPH_NO_VIRTUALIZE(
		function(point: Vector3, toward: Vector3, offset: number, out: { Vector3 }): number
			out[1] = point
			if offset <= 0 then
				return 1
			end
			local dir = toward - point
			if dir.Magnitude < 1e-4 then
				return 1
			end
			local cf = CFrame.lookAt(point, toward) * CFrame.Angles(0, 0, math.rad(math.random(1, 90)))
			local n = 1
			for i = 1, #SHIFT_VERTICES do
				n += 1
				out[n] = cf * (SHIFT_VERTICES[i] * offset)
			end
			return n
		end
	)

	function Ragebot.new(
		link: gameUi.Linker,
		opts: {
			targetingLink: gameUi.Linker,
			filtersLink: gameUi.Linker,
			performanceLink: gameUi.Linker,
			visualsLink: gameUi.Linker,
		}
	): Ragebot
		local self = BaseFeature.new() :: any
		setmetatable(self, Ragebot)

		scopes.build()

		link:Toggle("enabled", "Enable Ragebot", false):SetTip({
			title = "Enable Ragebot",
			body = "Automatically fires at the best enemy you can hit. You still see your weapon shoot on screen.",
		})

		opts.targetingLink:Dropdown("targeting", "Targeting", TARGETING_OPTIONS, TARGETING_OPTIONS[1]):SetTip({
			title = "Targeting",
			body = "How the Ragebot chooses which enemy to shoot at.",
		})

		opts.targetingLink:Dropdown("scanOrigin", "Scan Origin", SCAN_ORIGIN_OPTIONS, SCAN_ORIGIN_OPTIONS[2]):SetTip({
			title = "Scan Origin",
			body = "Where shots and visibility checks start from.",
		})

		opts.targetingLink
			:Dropdown("hitboxes", "Hitboxes", HITBOX_OPTIONS, DEFAULT_HITBOXES)
			:SetMode("multi")
			:SetMin(1)
			:SetTip({
				title = "Hitboxes",
				body = "The hitboxes the Ragebot will scan and shoot at.",
			})

		opts.targetingLink:Toggle("extrapolation", "Extrapolation", false):SetTip({
			title = "Extrapolation",
			body = "Applies prediction to the enemy's position.",
		})

		local extrapolationLink = opts.targetingLink:OnKey("extrapolation")
		extrapolationLink:Submenu("opts", "Extrapolation")
		local extrapolationOpts = extrapolationLink:OnKey("opts")
		extrapolationOpts
			:Slider("lookahead", "Lookahead", 0, 0, 500, 5, nil, "ms")
			:SetTip({
				title = "Lookahead",
				body = "How far ahead in time to predict the enemy's position.",
			})
			:SetValueTextOverrides({ [0] = "Auto" })
		opts.targetingLink:Toggle("multipoint", "Multipoint", true):SetTip({
			title = "Multipoint",
			body = "Scans multiple points across each hitbox and aims at the best visible one.",
		})

		local multipointLink = opts.targetingLink:OnKey("multipoint")
		multipointLink:Submenu("opts", "Multipoint")
		local multipointOpts = multipointLink:OnKey("opts")
		multipointOpts:Dropdown("hitboxes", "Hitboxes", HITBOX_OPTIONS, HITBOX_OPTIONS):SetMode("multi"):SetTip({
			title = "Hitboxes",
			body = "Which hitboxes get multi-sample scanning. Hitboxes not listed here are scanned at their center only.",
		})
		multipointOpts:Slider("scale", "Scale", 70, 0, 100, 1, nil, "%"):SetTip({
			title = "Scale",
			body = "How far from the center of each hitbox extra aim points are tested.",
		})

		opts.targetingLink:Options("manipulation", "Manipulation")
		local manipLink = opts.targetingLink:OnKey("manipulation")
		manipLink:Toggle("enabled", "Enabled", false):SetTip({
			title = "Manipulation",
			body = "Shifts where your shots start and land to reach enemies behind cover.",
		})
		manipLink:Slider("originShift", "Origin Shift", 5, 1, 15, 1, nil, " studs"):SetTip({
			title = "Origin Shift",
			body = "Moves the apparent start point of your shots toward enemies.",
		})
		manipLink:Slider("hitShift", "Hit Shift", 1, 1, 15, 1, nil, " studs"):SetTip({
			title = "Hit Shift",
			body = "Offsets where your shots are registered on the target.",
		})

		local minDamageOverrides: { [number]: string } = { [0] = "Off" }
		for i = 1, 10 do
			minDamageOverrides[100 + i] = "+" .. tostring(i)
		end
		opts.filtersLink
			:Slider("minDamage", "Minimum Damage", 0, 0, 110, 1, nil, "hp")
			:SetValueTextOverrides(minDamageOverrides)
			:SetTip({
				title = "Minimum Damage",
				body = "Minimum predicted damage for direct shots. Values above 100 require lethal: 101 = target HP + 1, 110 = target HP + 10. Set to Off to disable.",
			})
		opts.filtersLink:Slider("hitChance", "Hit Chance", 65, 0, 100, 1, nil, "%"):SetTip({
			title = "Hit Chance",
			body = "Minimum estimated hit chance based on current spread. Shots below this are skipped.",
		})

		opts.filtersLink:Toggle("autowall", "Autowall", false):SetTip({
			title = "Autowall",
			body = "Allows shots through penetrable walls.",
		})

		local autowallLink = opts.filtersLink:OnKey("autowall")
		autowallLink:Submenu("opts", "Autowall")
		local autowallOpts = autowallLink:OnKey("opts")
		autowallOpts
			:Slider("minDamage", "Minimum Damage", 0, 0, 110, 1, nil, "hp")
			:SetValueTextOverrides(minDamageOverrides)
			:SetTip({
				title = "Minimum Damage",
				body = "For autowall shots only. Same scaling as Minimum Damage. Set to Off to skip the damage check on wallbangs.",
			})

		opts.performanceLink:Slider("tickRate", "Tick Rate", 120, 10, 240, 5, nil, " Hz"):SetTip({
			title = "Tick Rate",
			body = "How many times per second the Ragebot scans targets. Lower frees up FPS.",
		})
		opts.performanceLink:Slider("fovLimit", "FOV Limit", 180, 5, 180, 1, nil, "\194\176"):SetTip({
			title = "FOV Limit",
			body = "Only considers enemies within this cone around your camera look. 180\194\176 disables the FOV filter.",
		})
		--[[opts.performanceLink:Toggle("debug", "Debug", false):SetTip({
			title = "Debug",
			body = "Prints Ragebot diagnostics to the console.",
		})--]]

		self._cache = {
			enabled = false,
			hitboxes = DEFAULT_HITBOXES,
			hitboxSet = { Head = true },
			scanOrigin = "Fair",
			targeting = TARGETING_OPTIONS[1],
			multipoint = true,
			multipointScale = 0.7,
			multipointHitboxes = HITBOX_OPTIONS,
			multipointHitboxSet = { Head = true, Torso = true, Arms = true, Legs = true, Feet = true },
			manipEnabled = false,
			originShift = 5,
			hitShift = 1,
			hitChance = 65,
			minDamage = 0,
			autowall = false,
			zeusBot = false,
			autowallMinDamage = 0,
			noSpread = false,
			scanInterval = 1 / 120,
			maxDistance = 350,
			maxDistanceSq = 350 * 350,
			fovLimit = 180,
			cosFovHalf = -1,
			extrapolation = false,
			extrapolationLookaheadSec = 0.1,
			debug = false,
		}
		self._lastScanAt = 0
		self._dbgLastPrint = 0
		self._dbgPlayers = {} :: { [string]: string }

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.IgnoreWater = true
		raycastParams.RespectCanCollide = false
		self._raycastParams = raycastParams
		self._raycastFilter = {} :: { Instance }
		self._scoreIgnore = {} :: { Instance }
		self._sampleBuffer = table.create(15) :: { Vector3 }
		self._scoreBest = {
			player = nil :: any,
			part = nil :: any,
			character = nil :: any,
			aimPoint = Vector3.zero,
			shotOrigin = Vector3.zero,
			spoofed = false,
			wallbang = false,
			hitChance = nil :: number?,
			damage = 0,
			source = "current",
			targetInstance = nil :: Instance?,
			effectiveCF = CFrame.new(),
			partSize = Vector3.zero,
		}
		self._reachCache = setmetatable({}, { __mode = "k" }) :: any
		self._scorePool = {} :: { any }
		self._scoreBestCarried = {
			player = nil :: any,
			part = nil :: any,
			character = nil :: any,
			aimPoint = Vector3.zero,
			shotOrigin = Vector3.zero,
			spoofed = false,
			wallbang = false,
			hitChance = nil :: number?,
			damage = 0,
			source = "current",
			targetInstance = nil :: Instance?,
			effectiveCF = CFrame.new(),
			partSize = Vector3.zero,
		}
		self._lastShotAt = 0
		self._chanceRejects = 0

		self._tickConn = nil :: RBXScriptConnection?

		self:_subscribeSettings()

		self:Track(sub(LoadoutState.currentEquipped, function(weapon: any?): ()
			local name: string? = nil
			if weapon and type(weapon.Name) == "string" then
				name = weapon.Name
			end
			ScopeController.SetEquipped(name)
		end))
		local equipped = peek(LoadoutState.currentEquipped)
		ScopeController.SetEquipped(equipped and equipped.Name or nil)

		ragebotFov.attach(self, opts.visualsLink, {
			getEnabled = ragebotApi.IsEnabled,
			getFovLimit = function(): number
				return self._cache.fovLimit
			end,
		})

		_instance = self
		return self
	end

	function Ragebot._subscribeSettings(self: Ragebot): ()
		local cache = self._cache

		self:Track(ScopeController.OnChange("aimbot.enabled", function(v: any): ()
			cache.enabled = v == true
			ragebotApi.SetEnabled(cache.enabled)
			self:_setActive(cache.enabled)
		end))
		self:Track(ScopeController.OnChange("aimbotTargeting.targeting", function(v: any): ()
			cache.targeting = v or TARGETING_OPTIONS[1]
		end))
		self:Track(ScopeController.OnChange("aimbotTargeting.scanOrigin", function(v: any): ()
			cache.scanOrigin = v or "Camera"
		end))
		self:Track(ScopeController.OnChange("aimbotTargeting.hitboxes", function(v: any): ()
			local list = (type(v) == "table" and v or DEFAULT_HITBOXES)
			cache.hitboxes = list
			local set: { [string]: boolean } = {}
			for _, name in next, list do
				set[name] = true
			end
			cache.hitboxSet = set
		end))
		self:Track(ScopeController.OnChange("aimbotTargeting.multipoint", function(v: any): ()
			cache.multipoint = v == true
		end))
		self:Track(ScopeController.OnChange("aimbotTargeting.multipoint.opts.scale", function(v: any): ()
			cache.multipointScale = (v or 70) / 100
		end))
		self:Track(ScopeController.OnChange("aimbotTargeting.manipulation.enabled", function(v: any): ()
			cache.manipEnabled = v == true
		end))
		self:Track(ScopeController.OnChange("aimbotTargeting.manipulation.originShift", function(v: any): ()
			cache.originShift = v or 1
		end))
		self:Track(ScopeController.OnChange("aimbotTargeting.manipulation.hitShift", function(v: any): ()
			cache.hitShift = v or 1
		end))

		self:Track(ScopeController.OnChange("weaponr.zeusBot", function(v: any)
			cache.zeusBot = v
		end))

		self:Track(ScopeController.OnChange("aimbotTargeting.multipoint.opts.hitboxes", function(v: any): ()
			local list = (type(v) == "table" and v or HITBOX_OPTIONS)
			cache.multipointHitboxes = list
			local set: { [string]: boolean } = {}
			for _, name in next, list do
				set[name] = true
			end
			cache.multipointHitboxSet = set
		end))
		self:Track(ScopeController.OnChange("aimbotTargeting.extrapolation", function(v: any): ()
			cache.extrapolation = v == true
		end))
		self:Track(ScopeController.OnChange("aimbotTargeting.extrapolation.opts.lookahead", function(v: any): ()
			cache.extrapolationLookaheadSec = (v or 100) / 1000
		end))
		self:Track(ScopeController.OnChange("aimbotFilters.hitChance", function(v: any): ()
			cache.hitChance = v or 65
		end))
		self:Track(ScopeController.OnChange("aimbotFilters.minDamage", function(v: any): ()
			cache.minDamage = v or 0
		end))
		self:Track(ScopeController.OnChange("aimbotFilters.autowall", function(v: any): ()
			cache.autowall = v == true
		end))
		self:Track(ScopeController.OnChange("aimbotFilters.autowall.opts.minDamage", function(v: any): ()
			cache.autowallMinDamage = v or 0
		end))
		self:Track(ScopeController.OnChange("ragebot.noSpread", function(v: any): ()
			cache.noSpread = v == true
		end))
		self:Track(ScopeController.OnChange("aimbotPerformance.tickRate", function(v: any): ()
			local hz = v or 120
			if hz < 10 then
				hz = 10
			elseif hz > 240 then
				hz = 240
			end
			cache.scanInterval = 1 / hz
		end))
		self:Track(ScopeController.OnChange("aimbotPerformance.fovLimit", function(v: any): ()
			local fov = v or 180
			cache.fovLimit = fov
			cache.cosFovHalf = fov >= 180 and -1 or math.cos(math.rad(fov * 0.5))
		end))
		self:Track(ScopeController.OnChange("aimbotPerformance.debug", function(v: any): ()
			cache.debug = v == true
		end))
	end

	function Ragebot._dbgMark(self: Ragebot, player: any, reason: string): ()
		local rbxPlayer = player:GetPlayer()
		self._dbgPlayers[rbxPlayer and rbxPlayer.Name or tostring(player)] = reason
	end

	function Ragebot._dbgNoShot(self: Ragebot, reason: string): ()
		local now = os.clock()
		if now - self._dbgLastPrint < 1 then
			table.clear(self._dbgPlayers)
			return
		end
		self._dbgLastPrint = now
		dprint("no shot: " .. reason)
		for name, r in next, self._dbgPlayers do
			dprint("  " .. name .. ": " .. r)
		end
		table.clear(self._dbgPlayers)
	end

	function Ragebot._setActive(self: Ragebot, active: boolean): ()
		if active then
			if not self._tickConn then
				MotionTracker.Acquire()
				self._lastScanAt = 0
				self._lastShotAt = 0
				self._tickConn = RunService.Heartbeat:Connect(function(): ()
					local now = os.clock()
					if now - self._lastScanAt < self._cache.scanInterval then
						return
					end
					self._lastScanAt = now
					self:_tick()
				end)
			end
		else
			if self._tickConn then
				self._tickConn:Disconnect()
				self._tickConn = nil
				MotionTracker.Release()
			end
		end
	end

	local function getScanOriginPosition(scanOrigin: string): Vector3?
		local parts = peek(ClientState.parts)
		local hrp = parts.HumanoidRootPart :: BasePart
		if not hrp then
			return nil
		end
		if scanOrigin == "Fair" then
			return localLookController.GetRealCameraPosition()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			return camera.CFrame.Position - localLookController.GetViewOffset()
		end
		return hrp.Position
	end

	local function getPenetrationOpts(weapon: any): { penetration: number, maxRange: number }?
		if not weapon or not weapon.Properties then
			return nil
		end
		local props = weapon.Properties
		local pen = props.Penetration or 0
		if pen <= 0 then
			return nil
		end
		return {
			penetration = pen,
			maxRange = props.Range or 1200,
		}
	end

	local passesRange = LPH_NO_VIRTUALIZE(
		function(
			enemyPos: Vector3,
			originPos: Vector3,
			cameraPos: Vector3,
			cameraLook: Vector3,
			maxDistanceSq: number,
			cosFovHalf: number
		): boolean
			local dx = enemyPos.X - originPos.X
			local dy = enemyPos.Y - originPos.Y
			local dz = enemyPos.Z - originPos.Z
			local distSq = dx * dx + dy * dy + dz * dz
			if distSq > maxDistanceSq then
				return false
			end
			if cosFovHalf > -0.999 then
				local cdx = enemyPos.X - cameraPos.X
				local cdy = enemyPos.Y - cameraPos.Y
				local cdz = enemyPos.Z - cameraPos.Z
				local cMagSq = cdx * cdx + cdy * cdy + cdz * cdz
				if cMagSq < 1e-6 then
					return true
				end
				local cMag = math.sqrt(cMagSq)
				local dot = (cdx * cameraLook.X + cdy * cameraLook.Y + cdz * cameraLook.Z) / cMag
				if dot < cosFovHalf then
					return false
				end
			end
			return true
		end
	)

	function Ragebot._refreshRaycastFilter(self: Ragebot, character: Model): ()
		local filter = self._raycastFilter
		table.clear(filter)
		local localCharacter = LocalPlayer.Character
		if localCharacter then
			filter[#filter + 1] = localCharacter
		end
		filter[#filter + 1] = character
		local backtrackFolder = Backtrack.GetFolder()
		if backtrackFolder then
			filter[#filter + 1] = backtrackFolder
		end
		self._raycastParams.FilterDescendantsInstances = filter
	end

	Ragebot._isVisibleDirect = LPH_NO_VIRTUALIZE(
		function(self: Ragebot, origin: Vector3, aimPoint: Vector3, _character: Model): boolean
			local toTarget = aimPoint - origin
			if toTarget.Magnitude < 1e-3 then
				return true
			end
			local result = Workspace:Raycast(origin, toTarget, self._raycastParams)
			return result == nil
		end
	)

	Ragebot._anyHitboxVisible = LPH_NO_VIRTUALIZE(
		function(self: Ragebot, origin: Vector3, parts: any, character: Model): boolean
			local enabledSet = self._cache.hitboxSet
			for _, hitboxName in next, HITBOX_PRIORITY do
				if not enabledSet[hitboxName] then
					continue
				end
				local list = HITBOX_PARTS[hitboxName]
				if not list then
					continue
				end
				for _, partName in next, list do
					local part = parts[partName]
					if part and self:_isVisibleDirect(origin, (part :: BasePart).Position, character) then
						return true
					end
				end
			end
			return false
		end
	)

	Ragebot._anyHitboxPenetrable = LPH_NO_VIRTUALIZE(
		function(
			self: Ragebot,
			origin: Vector3,
			parts: any,
			penOpts: { penetration: number, maxRange: number },
			ignore: { Instance }
		): boolean
			local enabledSet = self._cache.hitboxSet
			for _, hitboxName in next, HITBOX_PRIORITY do
				if not enabledSet[hitboxName] then
					continue
				end
				local list = HITBOX_PARTS[hitboxName]
				if not list then
					continue
				end
				for _, partName in next, list do
					local part = parts[partName]
					if part then
						if
							penetrationQuery.reachThroughWalls(
								origin,
								part :: BasePart,
								penOpts.penetration,
								penOpts.maxRange,
								ignore,
								false
							)
						then
							return true
						end
						break
					end
				end
			end
			return false
		end
	)

	Ragebot._isReachable = LPH_NO_VIRTUALIZE(
		function(
			self: Ragebot,
			origin: Vector3,
			player: any,
			character: Model,
			penOpts: { penetration: number, maxRange: number }?,
			backtrackOn: boolean
		): boolean
			if InfinitePenetration.IsEnabled() then
				return true
			end

			local parts = peek(player.parts)
			local playerHrp = peek(player.hrp) :: BasePart?
			local playerHead = parts.Head :: BasePart?

			self:_refreshRaycastFilter(character)

			if playerHrp and self:_isVisibleDirect(origin, playerHrp.Position, character) then
				return true
			end
			if playerHead and self:_isVisibleDirect(origin, playerHead.Position, character) then
				return true
			end
			if self:_anyHitboxVisible(origin, parts, character) then
				return true
			end

			if backtrackOn then
				local rbxPlayer = player:GetPlayer()
				local ghostHrp = Backtrack.GetHistoricalPosition(rbxPlayer, "HumanoidRootPart")
				if ghostHrp and self:_isVisibleDirect(origin, ghostHrp, character) then
					return true
				end
				local ghostHead = Backtrack.GetHistoricalPosition(rbxPlayer, "Head")
				if ghostHead and self:_isVisibleDirect(origin, ghostHead, character) then
					return true
				end
			end

			if self._cache.autowall and penOpts then
				local ignore = self._scoreIgnore
				table.clear(ignore)
				local localCharacter = LocalPlayer.Character
				if localCharacter then
					ignore[#ignore + 1] = localCharacter
				end
				local backtrackFolder = Backtrack.GetFolder()
				if backtrackFolder then
					ignore[#ignore + 1] = backtrackFolder
				end
				if
					playerHrp
					and penetrationQuery.reachThroughWalls(
						origin,
						playerHrp,
						penOpts.penetration,
						penOpts.maxRange,
						ignore,
						false
					)
				then
					return true
				end
				if
					playerHead
					and penetrationQuery.reachThroughWalls(
						origin,
						playerHead,
						penOpts.penetration,
						penOpts.maxRange,
						ignore,
						false
					)
				then
					return true
				end
				if self:_anyHitboxPenetrable(origin, parts, penOpts, ignore) then
					return true
				end
			end

			return false
		end
	)

	local REACH_CACHE_TTL = 0.08
	local REACH_CACHE_EPS_SQ = 0.5 * 0.5

	Ragebot._cacheOccluded = LPH_NO_VIRTUALIZE(
		function(self: Ragebot, player: any, origin: Vector3, hrpPos: Vector3, clock: number): ()
			local rc = self._reachCache[player]
			if not rc then
				rc = {} :: any
				self._reachCache[player] = rc
			end
			rc.ox, rc.oy, rc.oz = origin.X, origin.Y, origin.Z
			rc.ex, rc.ey, rc.ez = hrpPos.X, hrpPos.Y, hrpPos.Z
			rc.t = clock
		end
	)

	Ragebot._scoreCandidates = function(
		self: Ragebot,
		origin: Vector3,
		player: any,
		character: Model,
		weapon: any,
		penOpts: { penetration: number, maxRange: number }?,
		spreadDeg: number?
	): CandidatePoint?
		local cache = self._cache
		local rbxPlayer = player:GetPlayer()
		local targetHealth = peek(player.health) or 0
		local parts = peek(player.parts)

		local ignoreWalls = InfinitePenetration.IsEnabled()
		local stripWalls = InfinitePenetration.IsMaxDamageEnabled()
		local playerHrp = peek(player.hrp) :: BasePart?
		local backtrackOn = Backtrack.IsEnabled()
		local shiftEnabled = cache.manipEnabled

		local canCacheReach = not ignoreWalls and not backtrackOn and not shiftEnabled
		local scanClock = os.clock()
		if canCacheReach and playerHrp then
			local rc = self._reachCache[player]
			if rc and scanClock - rc.t < REACH_CACHE_TTL then
				local hp = playerHrp.Position
				local dex, dey, dez = hp.X - rc.ex, hp.Y - rc.ey, hp.Z - rc.ez
				local dox, doy, doz = origin.X - rc.ox, origin.Y - rc.oy, origin.Z - rc.oz
				if
					dex * dex + dey * dey + dez * dez < REACH_CACHE_EPS_SQ
					and dox * dox + doy * doy + doz * doz < REACH_CACHE_EPS_SQ
				then
					local vel = MotionTracker.GetSmoothedVelocity(player)
					if not vel or vel:Dot(vel) < CACHE_VEL_SKIP_SQ then
						return nil
					end
				end
			end
		end

		local localCharacter = LocalPlayer.Character
		local ignore = self._scoreIgnore
		table.clear(ignore)
		if localCharacter then
			ignore[#ignore + 1] = localCharacter
		end
		local backtrackFolder = Backtrack.GetFolder()
		if backtrackFolder then
			ignore[#ignore + 1] = backtrackFolder
		end

		self:_refreshRaycastFilter(character)
		local extrapolationOffset: Vector3? = nil
		if cache.extrapolation then
			local lookahead = cache.extrapolationLookaheadSec
			if lookahead <= 0 then
				lookahead = (peek(sessionState.ping) or 0) / 1000
			end
			if lookahead > 0 then
				local vel = MotionTracker.GetSmoothedVelocity(player)
				if vel and vel.Magnitude > 0.01 then
					extrapolationOffset = vel * lookahead
				end
			end
		end

		local best = self._scoreBest
		local hasBest = false
		local enabledSet = cache.hitboxSet
		local mpSet = cache.multipointHitboxSet
		local hitChanceCheck = cache.hitChance > 0 and not cache.noSpread and spreadDeg ~= nil
		local hitChanceFraction = cache.hitChance * 0.01
		local effectiveMinDmgCurrent = (
			cache.minDamage > 0 and prediction.effectiveMinDamage(cache.minDamage, targetHealth) or 0
		)
		local effectiveMinDmgWallbang = (
			cache.autowallMinDamage > 0 and prediction.effectiveMinDamage(cache.autowallMinDamage, targetHealth) or 0
		)
		local sampleBuffer = self._sampleBuffer
		local dbg = cache.debug
		local visFail, penFail, chanceFail, dmgFail = 0, 0, 0, 0
		local dbgBestChance, dbgBestDmg = 0, 0
		local raysLeft = RAY_BUDGET
		local budgetOut = false

		local poseCount = 0
		if backtrackOn then
			poseCount = Backtrack.CollectSnapshots(rbxPlayer, poseSnapBuf, MAX_BACKTRACK_POSES, POSE_MIN_SPACING)
		end

		for _, hitboxName in next, HITBOX_PRIORITY do
			if not enabledSet[hitboxName] then
				continue
			end
			local list = HITBOX_PARTS[hitboxName]
			if not list then
				continue
			end
			local hitboxMultipoint = cache.multipoint and mpSet[hitboxName] == true
			local accepted = false

			for _, partName in next, list do
				local part = parts[partName]
				if not part then
					continue
				end

				local partCF = part.CFrame
				local altCount = 1
				altCFBuf[1] = partCF
				altInstBuf[1] = part
				altSrcBuf[1] = "current"

				if extrapolationOffset then
					altCount = 2
					altCFBuf[2] = partCF + extrapolationOffset
					altInstBuf[2] = part
					altSrcBuf[2] = "extrapolation"
				end

				if poseCount > 0 then
					local ghost = Backtrack.GetHistoricalPart(rbxPlayer, partName)
					if ghost then
						local lastPose = partCF.Position
						for pi = 1, poseCount do
							local cf = poseSnapBuf[pi][partName]
							if cf then
								local d = cf.Position - lastPose
								if d:Dot(d) >= POSE_MIN_MOVE_SQ then
									altCount += 1
									altCFBuf[altCount] = cf
									altInstBuf[altCount] = ghost
									altSrcBuf[altCount] = "backtrack"
									lastPose = cf.Position
								end
							end
						end
					end
				end

				local partSize = part.Size
				local partRadius = 0.5 * math.max(partSize.X, partSize.Y, partSize.Z)

				for ai = 1, altCount do
					local effectiveCF = altCFBuf[ai]
					local targetInstance = altInstBuf[ai]
					local source = altSrcBuf[ai]

					local hitP: number? = nil
					if hitChanceCheck then
						hitP = spreadHitChance.coneHitChance(
							origin,
							Vector3.zero,
							effectiveCF.Position,
							spreadDeg :: number,
							partRadius
						)
						if hitP < hitChanceFraction then
							chanceFail += 1
							if dbg and hitP > dbgBestChance then
								dbgBestChance = hitP
							end
							continue
						end
					end

					local penDone = false
					local escalate = hitboxMultipoint and ai == 1 and cache.multipointScale < ESCALATION_SKIP_AT

					for pass = 1, 2 do
						local passVisFail = 0
						local sampleCount: number
						if hitboxMultipoint then
							if pass == 1 then
								sampleCount = multipoint.samplePointsInto(
									sampleBuffer,
									effectiveCF,
									partSize,
									cache.multipointScale
								)
							else
								sampleCount = multipoint.samplePointsInto(
									sampleBuffer,
									effectiveCF,
									partSize,
									ESCALATED_SCALE,
									ESCALATED_INSET
								)
							end
						else
							sampleBuffer[1] = effectiveCF.Position
							sampleCount = 1
						end

						for si = 1, sampleCount do
							if raysLeft <= 0 then
								budgetOut = true
								break
							end
							local aimPoint = sampleBuffer[si]
							local shotOrigin = origin
							local spoofed = false
							local delta = aimPoint - origin
							local mag = delta.Magnitude
							if mag < 1e-4 then
								continue
							end

							local wallbang = false
							local walls = 0
							if ignoreWalls then
								if not stripWalls and penOpts then
									raysLeft -= 1
									walls = penetrationQuery.countWalls(
										origin,
										part,
										penOpts.penetration,
										penOpts.maxRange,
										ignore,
										nil
									)
									wallbang = walls > 0
								end
							else
								raysLeft -= 1
								local visible = self:_isVisibleDirect(origin, aimPoint, character)
								if not visible and shiftEnabled then
									local oc = fillShiftCandidates(origin, aimPoint, cache.originShift, shiftOriginBuf)
									local hc = fillShiftCandidates(aimPoint, origin, cache.hitShift, shiftHitBuf)
									local bestOff = math.huge
									local bo: Vector3? = nil
									local bh: Vector3? = nil
									for oi = 1, oc do
										local o = shiftOriginBuf[oi]
										for hi = 1, hc do
											if oi == 1 and hi == 1 then
												continue
											end
											if raysLeft <= 0 then
												break
											end
											local h = shiftHitBuf[hi]
											raysLeft -= 1
											if self:_isVisibleDirect(o, h, character) then
												local off = (o - origin).Magnitude + (h - aimPoint).Magnitude
												if off < bestOff then
													bestOff = off
													bo = o
													bh = h
												end
											end
										end
										if raysLeft <= 0 then
											break
										end
									end
									if bo then
										visible = true
										shotOrigin = bo
										aimPoint = bh :: Vector3
										spoofed = true
									end
								end
								if not visible then
									passVisFail += 1
									if not cache.autowall or not penOpts then
										visFail += 1
										continue
									end
									if penDone then
										continue
									end
									penDone = true
									if
										not penetrationQuery.reachThroughWalls(
											origin,
											part,
											penOpts.penetration,
											penOpts.maxRange,
											ignore,
											false,
											aimPoint
										)
									then
										penFail += 1
										continue
									end
									wallbang = true
									walls = penetrationQuery.countWalls(
										origin,
										part,
										penOpts.penetration,
										penOpts.maxRange,
										ignore,
										aimPoint
									)
									if walls < 1 then
										walls = 1
									end
								end
							end

							local damage = predictDamage(origin, part, weapon, walls, player)
							local minDmg = (wallbang and effectiveMinDmgWallbang or effectiveMinDmgCurrent)
							if minDmg > 0 and damage < minDmg then
								dmgFail += 1
								if dbg and damage > dbgBestDmg then
									dbgBestDmg = damage
								end
								continue
							end

							if not hasBest or damage > best.damage then
								if dbg and wallbang and penOpts then
									dprint(
										string.format(
											"accept wb part=%s aim=(%.2f, %.2f, %.2f) origin=(%.2f, %.2f, %.2f)",
											part.Name,
											aimPoint.X,
											aimPoint.Y,
											aimPoint.Z,
											origin.X,
											origin.Y,
											origin.Z
										)
									)
									penetrationQuery.reachThroughWalls(
										origin,
										part,
										penOpts.penetration,
										penOpts.maxRange,
										ignore,
										true,
										aimPoint
									)
								end
								hasBest = true
								best.player = player
								best.part = part
								best.character = character
								best.aimPoint = aimPoint
								best.shotOrigin = shotOrigin
								best.spoofed = spoofed
								best.wallbang = wallbang
								best.hitChance = hitP
								best.damage = damage
								best.source = source
								best.targetInstance = targetInstance
								best.effectiveCF = effectiveCF
								best.partSize = partSize
								accepted = true
							end
							if accepted then
								break
							end
						end
						if accepted or budgetOut then
							break
						end
						if pass == 1 and (not escalate or passVisFail == 0) then
							break
						end
					end
					if accepted or budgetOut then
						break
					end
				end
				if accepted or budgetOut then
					break
				end
			end

			if hasBest or budgetOut then
				break
			end
		end

		self._chanceRejects += chanceFail

		if not hasBest then
			if dbg then
				self:_dbgMark(
					player,
					string.format(
						"no point: vis=%d pen=%d chance=%d(best %.0f%%/need %d%%) dmg=%d(best %.1f)",
						visFail,
						penFail,
						chanceFail,
						dbgBestChance * 100,
						cache.hitChance,
						dmgFail,
						dbgBestDmg
					)
				)
			end
			if canCacheReach and playerHrp and not budgetOut and chanceFail == 0 and dmgFail == 0 then
				self:_cacheOccluded(player, origin, playerHrp.Position, scanClock)
			end
			return nil
		end
		if canCacheReach then
			self._reachCache[player] = nil
		end
		return best
	end

	local poolComparator = LPH_NO_VIRTUALIZE(function(a: any, b: any): boolean
		if a.rank ~= b.rank then
			return a.rank > b.rank
		end
		return a.distSq < b.distSq
	end)

	Ragebot._pickHighestDamage = LPH_NO_VIRTUALIZE(
		function(
			self: Ragebot,
			origin: Vector3,
			weapon: any,
			penOpts: { penetration: number, maxRange: number }?,
			spreadDeg: number?
		): (any?, Model?, CandidatePoint?)
			local cache = self._cache
			local localTeam = ClientController.GetTeam()
			local camera = Workspace.CurrentCamera
			local cameraCF = camera.CFrame
			local cameraPos = cameraCF.Position
			local cameraLook = cameraCF.LookVector
			local carried = self._scoreBestCarried
			local hasCarried = false
			local carriedRank = -1
			local bestPlayer: any? = nil
			local bestCharacter: Model? = nil

			local forcedRbxPlayer = ragebotApi.GetForcedTarget()
			local hasFilters = ragebotApi.HasTargetFilters()
			local hasPriorityActive = playerState.HasPriorityTargets()
			local isDeathmatch = gamemodeState.isDeathmatch()
			local now = tick()

			local props = weapon and weapon.Properties
			local weaponMaxDmg = math.huge
			if props then
				local rangeMod = props.RangeModifier or 1
				local damageTable = props.DamagePerPart
				if rangeMod <= 1 and damageTable then
					local maxBase = 0
					for _, v in next, damageTable do
						if type(v) == "number" and v > maxBase then
							maxBase = v
						end
					end
					if maxBase > 0 then
						weaponMaxDmg = maxBase
					end
				end
			end

			local pool = self._scorePool
			local count = 0
			for _, playerData in next, PlayerController.GetAll() do
				if not peek(playerData.alive) or peek(playerData.culled) then
					continue
				end

				if peek(playerData.invincible) then
					continue
				end

				local rbxPlayer = playerData:GetPlayer()
				if forcedRbxPlayer then
					if rbxPlayer ~= forcedRbxPlayer then
						continue
					end
				else
					local playerTeam = peek(playerData.team)
					if not isDeathmatch and (localTeam and localTeam ~= "" and playerTeam == localTeam) then
						continue
					end
				end
				if not forcedRbxPlayer and rbxPlayer and playerState.ShouldSkip(rbxPlayer.UserId) then
					continue
				end
				local rank = (not forcedRbxPlayer and rbxPlayer) and playerState.GetRank(rbxPlayer.UserId) or 0
				if ragebotApi.IsPlayerCovered(playerData, now) then
					if cache.debug then
						self:_dbgMark(playerData, "covered")
					end
					continue
				end
				local character = peek(playerData.character)
				if not character then
					continue
				end
				if hasFilters and rbxPlayer then
					if
						not ragebotApi.RunTargetFilters({ player = rbxPlayer, character = character, weapon = weapon })
					then
						if cache.debug then
							self:_dbgMark(playerData, "target filter")
						end
						continue
					end
				end
				local hrp = peek(playerData.hrp) :: BasePart?
				if not hrp then
					continue
				end
				local hrpPos = hrp.Position
				if not passesRange(hrpPos, origin, cameraPos, cameraLook, cache.maxDistanceSq, cache.cosFovHalf) then
					if cache.debug then
						self:_dbgMark(playerData, "range/FOV")
					end
					continue
				end

				local dx, dy, dz = hrpPos.X - origin.X, hrpPos.Y - origin.Y, hrpPos.Z - origin.Z
				count += 1
				local entry = pool[count]
				if not entry then
					entry = {}
					pool[count] = entry
				end
				entry.pd = playerData
				entry.char = character
				entry.rank = rank
				entry.distSq = dx * dx + dy * dy + dz * dz
			end

			if count == 0 then
				return nil, nil, nil
			end

			for i = #pool, count + 1, -1 do
				pool[i] = nil
			end

			table.sort(pool, poolComparator)

			for i = 1, count do
				local entry = pool[i]
				local rank = entry.rank
				if hasCarried and rank < carriedRank then
					break
				end
				local playerData = entry.pd
				local character = entry.char

				local candidate = self:_scoreCandidates(origin, playerData, character, weapon, penOpts, spreadDeg)
				if candidate then
					if
						not hasCarried
						or rank > carriedRank
						or (rank == carriedRank and candidate.damage > carried.damage)
					then
						hasCarried = true
						carriedRank = rank
						carried.player = candidate.player
						carried.part = candidate.part
						carried.character = candidate.character
						carried.aimPoint = candidate.aimPoint
						carried.shotOrigin = candidate.shotOrigin
						carried.spoofed = candidate.spoofed
						carried.wallbang = candidate.wallbang
						carried.hitChance = candidate.hitChance
						carried.damage = candidate.damage
						carried.source = candidate.source
						carried.targetInstance = candidate.targetInstance
						carried.effectiveCF = candidate.effectiveCF
						carried.partSize = candidate.partSize
						bestPlayer = playerData
						bestCharacter = character
					end
					if not hasPriorityActive then
						local targetHealth = peek(playerData.health) or 0
						if targetHealth > 0 and candidate.damage >= targetHealth then
							break
						end
						if candidate.damage >= weaponMaxDmg then
							break
						end
					end
				end
			end

			if not hasCarried then
				return nil, nil, nil
			end
			return bestPlayer, bestCharacter, carried
		end
	)

	Ragebot._pickClosestToCrosshair = LPH_NO_VIRTUALIZE(
		function(
			self: Ragebot,
			origin: Vector3,
			weapon: any,
			penOpts: { penetration: number, maxRange: number }?,
			spreadDeg: number?
		): (any?, Model?, CandidatePoint?)
			local cache = self._cache
			local localTeam = ClientController.GetTeam()
			local camera = Workspace.CurrentCamera
			local cameraCF = camera.CFrame
			local cameraPos = cameraCF.Position
			local cameraLook = cameraCF.LookVector
			local viewport = camera.ViewportSize
			local cx = viewport.X * 0.5
			local cy = viewport.Y * 0.5
			local vpX = viewport.X
			local vpY = viewport.Y
			local project = screenProject.make(camera, viewport)

			local forcedRbxPlayer = ragebotApi.GetForcedTarget()
			local hasFilters = ragebotApi.HasTargetFilters()
			local isDeathmatch = gamemodeState.isDeathmatch()
			local now = tick()

			local pool = self._scorePool
			local count = 0
			for _, playerData in next, PlayerController.GetAll() do
				if not peek(playerData.alive) or peek(playerData.culled) then
					continue
				end

				if peek(playerData.invincible) then
					continue
				end

				local rbxPlayer = playerData:GetPlayer()
				if forcedRbxPlayer then
					if rbxPlayer ~= forcedRbxPlayer then
						continue
					end
				else
					local playerTeam = peek(playerData.team)
					if not isDeathmatch and (localTeam and localTeam ~= "" and playerTeam == localTeam) then
						continue
					end
				end
				if not forcedRbxPlayer and rbxPlayer and playerState.ShouldSkip(rbxPlayer.UserId) then
					continue
				end
				local rank = (not forcedRbxPlayer and rbxPlayer) and playerState.GetRank(rbxPlayer.UserId) or 0
				if ragebotApi.IsPlayerCovered(playerData, now) then
					if cache.debug then
						self:_dbgMark(playerData, "covered")
					end
					continue
				end
				local character = peek(playerData.character)
				if not character then
					continue
				end
				if hasFilters and rbxPlayer then
					if
						not ragebotApi.RunTargetFilters({ player = rbxPlayer, character = character, weapon = weapon })
					then
						if cache.debug then
							self:_dbgMark(playerData, "target filter")
						end
						continue
					end
				end
				local parts = peek(playerData.parts)
				local centerPart = parts.UpperTorso or parts.Torso or parts.HumanoidRootPart or parts.Head
				if not centerPart then
					continue
				end
				local partPosition = (centerPart :: BasePart).Position
				if
					not passesRange(partPosition, origin, cameraPos, cameraLook, cache.maxDistanceSq, cache.cosFovHalf)
				then
					if cache.debug then
						self:_dbgMark(playerData, "range/FOV")
					end
					continue
				end
				local screenPos = project(partPosition)
				local distSq: number
				if
					screenPos.Z > 0
					and screenPos.X >= 0
					and screenPos.X <= vpX
					and screenPos.Y >= 0
					and screenPos.Y <= vpY
				then
					local dx = screenPos.X - cx
					local dy = screenPos.Y - cy
					distSq = dx * dx + dy * dy
				else
					local toPlayer = partPosition - cameraPos
					local mag = toPlayer.Magnitude
					if mag < 0.001 then
						continue
					end
					local dot = toPlayer.X / mag * cameraLook.X
						+ toPlayer.Y / mag * cameraLook.Y
						+ toPlayer.Z / mag * cameraLook.Z
					distSq = 1e9 + (1 - dot) * 1e6
				end
				count += 1
				local entry = pool[count]
				if not entry then
					entry = {}
					pool[count] = entry
				end
				entry.pd = playerData
				entry.char = character
				entry.rank = rank
				entry.distSq = distSq
			end

			if count == 0 then
				return nil, nil, nil
			end

			for i = #pool, count + 1, -1 do
				pool[i] = nil
			end

			table.sort(pool, poolComparator)

			local scanned = 0
			for i = 1, count do
				local entry = pool[i]
				local candidate = self:_scoreCandidates(origin, entry.pd, entry.char, weapon, penOpts, spreadDeg)
				if candidate then
					return entry.pd, entry.char, candidate
				end
				scanned += 1
				if scanned >= MAX_CROSSHAIR_SCANS then
					break
				end
			end

			return nil, nil, nil
		end
	)

	local function craftDirectHits(
		origin: Vector3,
		aimPoint: Vector3,
		direction: Vector3,
		hitInstance: Instance,
		material: string
	): { any }
		return {
			{
				Distance = (aimPoint - origin).Magnitude,
				Instance = hitInstance,
				Position = aimPoint,
				Normal = -direction,
				Material = material,
				Exit = false,
			},
		}
	end

	local rayHitsOBB = LPH_NO_VIRTUALIZE(
		function(origin: Vector3, direction: Vector3, cf: CFrame, size: Vector3): boolean
			local localOrigin = cf:PointToObjectSpace(origin)
			local localDir = cf:VectorToObjectSpace(direction)
			local hx, hy, hz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5
			local lx, ly, lz = localOrigin.X, localOrigin.Y, localOrigin.Z
			local dx, dy, dz = localDir.X, localDir.Y, localDir.Z

			local tMin: number = -math.huge
			local tMax: number = math.huge

			if math.abs(dx) < 1e-6 then
				if lx < -hx or lx > hx then
					return false
				end
			else
				local t1 = (-hx - lx) / dx
				local t2 = (hx - lx) / dx
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				if t1 > tMin then
					tMin = t1
				end
				if t2 < tMax then
					tMax = t2
				end
				if tMin > tMax then
					return false
				end
			end

			if math.abs(dy) < 1e-6 then
				if ly < -hy or ly > hy then
					return false
				end
			else
				local t1 = (-hy - ly) / dy
				local t2 = (hy - ly) / dy
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				if t1 > tMin then
					tMin = t1
				end
				if t2 < tMax then
					tMax = t2
				end
				if tMin > tMax then
					return false
				end
			end

			if math.abs(dz) < 1e-6 then
				if lz < -hz or lz > hz then
					return false
				end
			else
				local t1 = (-hz - lz) / dz
				local t2 = (hz - lz) / dz
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				if t1 > tMin then
					tMin = t1
				end
				if t2 < tMax then
					tMax = t2
				end
				if tMin > tMax then
					return false
				end
			end

			return tMax >= 0
		end
	)

	local castSpreadBulletHits = LPH_NO_VIRTUALIZE(
		function(origin: Vector3, direction: Vector3, range: number, penetration: number): ({ any }, Instance?)
			local ignore: { Instance } = {}
			local localCharacter = LocalPlayer.Character
			if localCharacter then
				ignore[1] = localCharacter
			end
			local maxDistance = range + math.max(0, penetration)
			local primary = bulletPenetrationRay.cast(origin, direction * maxDistance, nil, ignore, nil)
			if not primary.instance then
				return {}, nil
			end
			local firstDist = (primary.position - origin).Magnitude
			if firstDist > range then
				return {}, nil
			end
			local matName = (primary.material and primary.material.Name or "Plastic")
			local hits: { any } = {
				{
					Distance = firstDist,
					Instance = primary.instance,
					Position = primary.position,
					Normal = primary.normal or Vector3.zero,
					Material = matName,
					Exit = false,
				},
			}
			if penetration > 0 then
				local entry = primary.position + direction * 0.001
				local through =
					bulletPenetrationRay.castThrough(entry, direction * (penetration + 0.001), penetration, ignore)
				local prevPos = primary.position
				for i, r in next, through do
					local m = (r.material and r.material.Name or "Plastic")
					hits[#hits + 1] = {
						Distance = (r.position - prevPos).Magnitude,
						Instance = r.instance,
						Position = r.position,
						Normal = r.normal or Vector3.zero,
						Material = m,
						Exit = i % 2 == 0,
					}
					prevPos = r.position
				end
			end
			return hits, primary.instance
		end
	)

	local craftWallbangHits = LPH_NO_VIRTUALIZE(
		function(
			origin: Vector3,
			aimPoint: Vector3,
			direction: Vector3,
			targetPart: BasePart,
			penetration: number
		): ({ any }, boolean)
			local ignore: { Instance } = {}
			local localCharacter = LocalPlayer.Character
			if localCharacter then
				ignore[1] = localCharacter
			end
			local distance = (aimPoint - origin).Magnitude
			local rays = bulletPenetrationRay.castThrough(
				origin + direction * 0.01,
				direction * (distance + penetration),
				penetration,
				ignore
			)
			local targetModel = targetPart:FindFirstAncestorWhichIsA("Model")
			local hits: { any } = {}
			local prevPos = origin
			local reached = false
			for i, r in next, rays do
				if r.instance == targetPart then
					reached = true
					break
				end
				if targetModel and r.instance:IsDescendantOf(targetModel) then
					reached = true
					break
				end
				local matName = (r.material and r.material.Name or "Plastic")
				hits[#hits + 1] = {
					Distance = (r.position - prevPos).Magnitude,
					Instance = r.instance,
					Position = r.position,
					Normal = r.normal or Vector3.zero,
					Material = matName,
					Exit = i % 2 == 0,
				}
				prevPos = r.position
			end
			if not reached then
				local last = rays[#rays]
				if last and (last.position - origin):Dot(direction) >= distance - 0.12 then
					reached = true
				end
			end
			hits[#hits + 1] = {
				Distance = (aimPoint - prevPos).Magnitude,
				Instance = targetPart,
				Position = aimPoint,
				Normal = -direction,
				Material = targetPart.Material.Name,
				Exit = false,
			}
			return hits, reached
		end
	)

	Ragebot._tick = function(self: Ragebot): ()
		local cache = self._cache
		if not cache.enabled then
			return
		end

		if not peek(ClientState.alive) then
			return
		end

		local gameState = workspace:GetAttribute("GameState")
		if gameState == "Buy Period" then
			return
		end

		local hitboxes = cache.hitboxes
		if not hitboxes or #hitboxes == 0 then
			return
		end

		local weapon = peek(LoadoutState.currentEquipped) :: any
		local props = weapon and weapon.Properties

		local origin = getScanOriginPosition(cache.scanOrigin)
		if not origin then
			return
		end
		if originOffset ~= Vector3.zero then
			origin += originOffset
		end

		local penOpts = weapon and getPenetrationOpts(weapon) or nil
		if InfinitePenetration.IsEnabled() then
			penOpts = { penetration = 999, maxRange = ((props and props.Range) or 1200) :: number }
		end
		penetrationQuery.beginStep()

		if not weapon or not props or not WeaponController.CanShoot(weapon) then
			if cache.debug and weapon and props then
				self:_dbgNoShot("CanShoot=false (" .. tostring(weapon.Identifier) .. ")")
			end
			return
		end

		self._chanceRejects = 0

		if AutoStop.IsEnabled() and AutoStop.IsEarly() and not cache.noSpread and AutoStop.IsMoving() then
			local leadOrigin = AutoStop.PredictOrigin(origin)
			local predicted: CandidatePoint? = nil
			if cache.targeting == "Highest Damage" then
				local _, _, candidate = self:_pickHighestDamage(leadOrigin, weapon, penOpts, nil)
				predicted = candidate
			else
				local _, _, candidate = self:_pickClosestToCrosshair(leadOrigin, weapon, penOpts, nil)
				predicted = candidate
			end
			if predicted ~= nil then
				AutoStop.RequestStop()
			end
		end

		local fireRate = props.FireRate or 0.1
		local now = tick()
		local minInterval = fireRate
		if RapidFire.IsEnabled() then
			local rapidInterval = RapidFire.GetInterval()
			minInterval = rapidInterval > 0 and rapidInterval or 0
		end
		if minInterval > 0 and now - self._lastShotAt < minInterval then
			return
		end

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local spreadDeg: number? = nil
		if not cache.noSpread then
			spreadDeg = weaponSpreadState.getSpreadDegrees(weapon)
		end

		local best: CandidatePoint?
		if cache.targeting == "Highest Damage" then
			local _, _, candidate = self:_pickHighestDamage(origin, weapon, penOpts, spreadDeg)
			best = candidate
		else
			local _, _, candidate = self:_pickClosestToCrosshair(origin, weapon, penOpts, spreadDeg)
			best = candidate
		end
		if
			not AutoStop.IsEarly()
			and best == nil
			and AutoStop.IsEnabled()
			and not cache.noSpread
			and AutoStop.IsMoving()
			and self._chanceRejects > 0
		then
			local probe: CandidatePoint? = nil
			if cache.targeting == "Highest Damage" then
				local _, _, candidate = self:_pickHighestDamage(origin, weapon, penOpts, nil)
				probe = candidate
			else
				local _, _, candidate = self:_pickClosestToCrosshair(origin, weapon, penOpts, nil)
				probe = candidate
			end
			if probe ~= nil then
				AutoStop.RequestStop()
			end
		end

		if not best then
			if cache.debug then
				self:_dbgNoShot("no candidate point")
			end
			return
		end

		local bulletOrigin = best.shotOrigin
		local aimPoint = best.aimPoint
		local direction = (aimPoint - bulletOrigin)
		local mag = direction.Magnitude
		if mag < 1e-4 then
			return
		end
		direction = direction / mag

		local isZeus = props.MuzzleType == "Zeus x27"

		if isZeus and not cache.zeusBot then
			return
		end

		if isZeus and cache.zeusBot and mag > 10 then
			return
		end

		local targetInstance: Instance = best.targetInstance or best.part
		local material = best.part.Material.Name
		local virtualTarget = best.source == "backtrack" or best.source == "extrapolation"

		local hits: { any }
		local hitTarget = true
		if cache.noSpread or best.spoofed then
			if best.wallbang and penOpts then
				hits, hitTarget = craftWallbangHits(bulletOrigin, aimPoint, direction, best.part, penOpts.penetration)
			else
				hits = craftDirectHits(bulletOrigin, aimPoint, direction, targetInstance, material)
			end
		else
			direction = weaponSpreadState.applyBulletSpread(direction, spreadDeg or 0)
			local range = (weapon.Properties.Range or 500) :: number
			local pen = (penOpts and penOpts.penetration or 0)

			if virtualTarget then
				if rayHitsOBB(bulletOrigin, direction, best.effectiveCF, best.partSize) then
					hits = craftDirectHits(bulletOrigin, aimPoint, direction, targetInstance, material)
					hitTarget = true
				else
					local firstInstance: Instance?
					hits, firstInstance = castSpreadBulletHits(bulletOrigin, direction, range, pen)
					hitTarget = false
					if firstInstance then
						local targetModel = best.character
						if
							firstInstance == best.part or (targetModel and firstInstance:IsDescendantOf(targetModel))
						then
							hitTarget = true
						end
					end
				end
			else
				local firstInstance: Instance?
				hits, firstInstance = castSpreadBulletHits(bulletOrigin, direction, range, pen)
				local targetModel = best.character
				hitTarget = false
				if firstInstance then
					if firstInstance == best.part or (targetModel and firstInstance:IsDescendantOf(targetModel)) then
						hitTarget = true
					else
						for _, hit in next, hits do
							if
								hit.Instance == best.part or (targetModel and hit.Instance:IsDescendantOf(targetModel))
							then
								hitTarget = true
								break
							end
						end
					end
				end
			end
		end

		if best.wallbang and not hitTarget then
			if cache.debug then
				self:_dbgNoShot("wallbang sim blocked (bullet dies in wall)")
			end
			return
		end

		if type(weapon.Identifier) ~= "string" or type(weapon.Rounds) ~= "number" then
			return
		end

		local bullet = {
			Direction = direction,
			Origin = bulletOrigin,
			Hits = hits,
		}
		local shifted = bulletOrigin ~= origin
		if shifted then
			bullet.TracerOrigin = bulletOrigin
		end

		local rbxPlayer = best.player:GetPlayer()
		if rbxPlayer and ragebotApi.HasShotGates() then
			local allow = ragebotApi.RunShotGates({
				player = rbxPlayer,
				part = best.part,
				damage = best.damage,
				wallbang = best.wallbang,
				weapon = weapon,
				source = best.source,
			})
			if not allow then
				if cache.debug then
					self:_dbgNoShot("shot gate blocked")
				end
				return
			end
		end

		local wasScoped = weapon.IsSniperScoped == true
		fakeShoot.fire(weapon, { bullet }, "Primary")
		if shifted then
			bullet.TracerOrigin = nil
		end

		WeaponController.NoteRagebotShot(rbxPlayer)
		weapon.ShotSeq = (weapon.ShotSeq or 0) + 1
		setthreadidentity(2)
		NetworkController.SendPacket("Inventory", "ShootWeapon", {
			IsSniperScoped = wasScoped,
			ShootingHand = weapon.ShootingHand or "Right",
			Identifier = weapon.Identifier,
			Seq = weapon.ShotSeq,
			Bullets = {
				{
					Direction = bullet.Direction,
					Origin = bullet.Origin,
				},
			},
			ViewTick = fakeShoot.getViewTick(),
		})
		setthreadidentity(8)

		self._lastShotAt = now

		if cache.debug then
			dprint(
				string.format(
					"SHOT %s part=%s src=%s dmg=%.1f hc=%s wb=%s dist=%.1f hits=%d hitTarget=%s pen=%.2f spread=%s",
					rbxPlayer and rbxPlayer.Name or "?",
					best.part.Name,
					best.source,
					best.damage,
					best.hitChance and string.format("%.0f%%", (best.hitChance :: number) * 100) or "off",
					tostring(best.wallbang),
					mag,
					#hits,
					tostring(hitTarget),
					penOpts and penOpts.penetration or 0,
					spreadDeg and string.format("%.3f", spreadDeg) or "off"
				)
			)
			if best.wallbang or not hitTarget then
				for i, hit in next, hits do
					local inst = hit.Instance :: Instance?
					dprint(
						string.format(
							"  hit%d %s [%s] d=%.2f exit=%s pos=(%.1f, %.1f, %.1f)",
							i,
							inst and inst:GetFullName() or "?",
							tostring(hit.Material),
							hit.Distance,
							tostring(hit.Exit),
							hit.Position.X,
							hit.Position.Y,
							hit.Position.Z
						)
					)
				end
				if best.wallbang and penOpts then
					local ignore = self._scoreIgnore
					table.clear(ignore)
					local localCharacter = LocalPlayer.Character
					if localCharacter then
						ignore[#ignore + 1] = localCharacter
					end
					local backtrackFolder = Backtrack.GetFolder()
					if backtrackFolder then
						ignore[#ignore + 1] = backtrackFolder
					end
					penetrationQuery.reachThroughWalls(
						bulletOrigin,
						best.part,
						penOpts.penetration,
						penOpts.maxRange,
						ignore,
						true,
						best.aimPoint
					)
				end
			end
			table.clear(self._dbgPlayers)
		end

		if hitTarget and best.damage > 0 then
			ragebotApi.RecordShot(best.player, best.damage, now)
		end

		if rbxPlayer then
			ragebotApi.NotifyShotFired({
				player = rbxPlayer,
				part = best.part,
				damage = best.damage,
				wallbang = best.wallbang,
				source = best.source,
				hitTarget = hitTarget,
			})
			if hitTarget then
				WeaponController.hitPlayer:Fire(rbxPlayer, best.part)
			end
		end
	end

	Ragebot._hasReachableTarget = LPH_NO_VIRTUALIZE(function(self: Ragebot, origin: Vector3): boolean
		local cache = self._cache
		local localTeam = ClientController.GetTeam()
		local isDeathmatch = gamemodeState.isDeathmatch()
		local backtrackOn = Backtrack.IsEnabled()

		local weapon = peek(LoadoutState.currentEquipped) :: any
		local props = weapon and weapon.Properties
		local penOpts = weapon and getPenetrationOpts(weapon) or nil
		if InfinitePenetration.IsEnabled() then
			penOpts = { penetration = 999, maxRange = ((props and props.Range) or 1200) :: number }
		end

		for _, playerData in next, PlayerController.GetAll() do
			if not peek(playerData.alive) or peek(playerData.culled) or peek(playerData.invincible) then
				continue
			end
			local playerTeam = peek(playerData.team)
			if not isDeathmatch and (localTeam and localTeam ~= "" and playerTeam == localTeam) then
				continue
			end
			local character = peek(playerData.character)
			local hrp = peek(playerData.hrp) :: BasePart?
			if not character or not hrp then
				continue
			end
			local delta = hrp.Position - origin
			if delta:Dot(delta) > cache.maxDistanceSq then
				continue
			end
			if self:_isReachable(origin, playerData, character, penOpts, backtrackOn) then
				return true
			end
		end
		return false
	end)

	function Ragebot.HasReachableTarget(origin: Vector3): boolean
		if not _instance then
			return false
		end
		return _instance:_hasReachableTarget(origin)
	end

	function Ragebot.Destroy(self: Ragebot): ()
		self:_setActive(false)
		if (_instance :: any) == self then
			_instance = nil
		end
		BaseFeature.Destroy(self)
	end

	export type Ragebot =
		typeof(setmetatable(
			{} :: {
				_cache: any,
				_raycastParams: RaycastParams,
				_raycastFilter: { Instance },
				_tickConn: RBXScriptConnection?,
				_lastShotAt: number,
				_lastScanAt: number,
				_chanceRejects: number,
				_reachCache: any,
				_scorePool: { any },
				_cacheOccluded: (Ragebot, any, Vector3, Vector3, number) -> (),
				_dbgLastPrint: number,
				_dbgPlayers: { [string]: string },
			},
			Ragebot
		))
		& BaseFeature.BaseFeature

	return Ragebot
end)()
