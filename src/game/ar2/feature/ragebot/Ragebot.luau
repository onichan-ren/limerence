return LPH_JIT_MAX(function()
	local RunService = cloneref(game:GetService("RunService")) :: RunService
	local Players = cloneref(game:GetService("Players")) :: Players
	local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

	local Charm = require("@pkg/Charm")
	local BaseFeature = require("@game/BaseFeature")
	local gameUi = require("@game/gameUi")
	local ScopeController = require("@feature/ui/scope/ScopeController")
	local PlayerController = require("@feature/player/PlayerController")
	local playerState = require("@feature/record/module/playerState")
	local ClientState = require("@game/ar2/client/clientState")
	local WeaponController = require("@game/ar2/weapon/WeaponController")
	local ModuleController = require("@game/ar2/module/ModuleController")
	local NetworkController = require("@game/ar2/network/NetworkController")
	local hitboxParts = require("@game/universal/feature/combat/legitbot/hitboxParts")
	local ragebotFov = require("@game/universal/feature/combat/ragebot/ragebotFov")
	local multipoint = require("@game/universal/feature/combat/ragebot/multipoint")
	local boxOcclusion = require("@game/universal/feature/combat/ragebot/boxOcclusion")
	local ballistics = require("@game/ar2/weapon/ballistics")
	local worldRaycast = require("@game/ar2/weapon/worldRaycast")
	local manipScan = require("@game/ar2/weapon/manipScan")
	local ragebotApi = require("@game/ar2/feature/ragebot/ragebotApi")
	local originState = require("@game/universal/feature/visual/crosshair/originState")

	local peek = Charm.peek

	local LocalPlayer = Players.LocalPlayer

	local HITBOX_PARTS = hitboxParts.HITBOX_PARTS

	local HITBOX_OPTIONS: { string } = { "Head", "Torso", "Arms", "Legs", "Feet" }
	local HITBOX_PRIORITY: { string } = HITBOX_OPTIONS
	local DEFAULT_HITBOXES: { string } = { "Head", "Torso" }
	local TARGETING_OPTIONS: { string } = { "Closest To Crosshair", "Highest Damage" }

	local AIRBORNE_EPS = 3
	local REACH_CACHE_TTL = 0.08
	local REACH_CACHE_EPS_SQ = 0.25
	local CACHE_VEL_SKIP_SQ = 4
	local RAY_BUDGET = 100

	local SAMPLE_BUFFER = table.create(15)
	local ORDER_BUFFER = table.create(15)
	local SCORE_BUFFER = table.create(15)

	local segmentBlockedBy = boxOcclusion.segmentBlocked
	local registerBlocker = boxOcclusion.register

	local function byAlignDesc(a: any, b: any): boolean
		return a.align > b.align
	end

	local function chunkLoaded(
		pos: Vector3,
		localPos: Vector3,
		radius: number,
		chunkSize: number,
		corner: Vector3
	): boolean
		local dcx =
			math.abs(math.floor((pos.X - corner.X) / chunkSize) - math.floor((localPos.X - corner.X) / chunkSize))
		local dcz =
			math.abs(math.floor((pos.Z - corner.Z) / chunkSize) - math.floor((localPos.Z - corner.Z) / chunkSize))
		return dcx <= radius and dcz <= radius
	end

	local function hasAmmo(weapon: any): boolean
		local fc = weapon.FireConfig
		if fc and fc.InternalMag then
			return (weapon.WorkingAmount or 0) >= 1
		end
		local ammo = weapon.Attachments and weapon.Attachments.Ammo
		return ammo ~= nil and (ammo.WorkingAmount or 0) >= 1
	end

	local function consumeAmmo(weapon: any): boolean
		local fc = weapon.FireConfig
		if fc and fc.InternalMag and (weapon.WorkingAmount or 0) >= 1 then
			weapon.WorkingAmount -= 1
			return true
		end
		local ammo = weapon.Attachments and weapon.Attachments.Ammo
		if ammo and (ammo.WorkingAmount or 0) >= 1 then
			ammo.WorkingAmount -= 1
			return true
		end
		return false
	end

	local function predictDamage(weapon: any, hitboxName: string): number
		local fc = weapon.FireConfig
		if not fc then
			return 0
		end
		local dmg = math.abs(fc.Damage or 0)
		if hitboxName == "Head" and weapon.HitModifiers and weapon.HitModifiers.Head then
			dmg *= math.abs(weapon.HitModifiers.Head)
		end
		return dmg * math.max(fc.PelletCount or 1, 1)
	end

	local SEGMENT_TIME = 1 / 60

	local encodeShot = LPH_NO_VIRTUALIZE(
		function(origin: Vector3, direction: Vector3, fireTime: number, shotId: number): (Vector3, Vector3)
			local rng = Random.new(fireTime * 10000)
			local originEncode = rng:NextUnitVector() * shotId
			local directionEncode = rng:NextUnitVector() * shotId
			local encOrigin =
				Vector3.new(origin.X * originEncode.X, origin.Y * originEncode.Y, origin.Z * originEncode.Z)
			local encDirection = Vector3.new(
				direction.X * directionEncode.X,
				direction.Y * directionEncode.Y,
				direction.Z * directionEncode.Z
			)
			return encOrigin, encDirection
		end
	)

	local sendImpact = LPH_NO_VIRTUALIZE(
		function(
			weaponId: any,
			fireTime: number,
			shotId: number,
			pellet: number,
			hitPart: BasePart,
			hitPos: Vector3,
			origin: Vector3,
			speed: number
		): ()
			local toHit = hitPos - origin
			local dist = toHit.Magnitude
			if dist < 1e-4 then
				return
			end
			local segment = (toHit / dist) * (speed * SEGMENT_TIME)
			local rayOrigin = hitPos - segment
			local cf = hitPart.CFrame
			local size = hitPart.Size
			local posObf =
				Vector3.new(hitPos.X * size.X * shotId, hitPos.Y * size.Y * shotId, hitPos.Z * size.Z * shotId)
			local t7 = {
				cf:PointToObjectSpace(rayOrigin),
				cf:VectorToObjectSpace(segment),
				cf:PointToObjectSpace(hitPos),
			}
			NetworkController.send("Bullet Impact", shotId, weaponId, fireTime, pellet, hitPart, posObf, t7)
		end
	)

	local Ragebot = {}
	Ragebot.__index = Ragebot

	setmetatable(Ragebot, { __index = BaseFeature })

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

		link:Toggle("enabled", "Enable Ragebot", false):SetTip({
			title = "Enable Ragebot",
			body = "Automatically fires at the best enemy you can hit. You still see your weapon shoot on screen.",
		})

		opts.targetingLink:Dropdown("targeting", "Targeting", TARGETING_OPTIONS, TARGETING_OPTIONS[1]):SetTip({
			title = "Targeting",
			body = "How the Ragebot chooses which enemy to shoot at.",
		})
		opts.targetingLink
			:Dropdown("hitboxes", "Hitboxes", HITBOX_OPTIONS, DEFAULT_HITBOXES)
			:SetMode("multi")
			:SetMin(1)
			:SetTip({
				title = "Hitboxes",
				body = "The hitboxes the Ragebot will scan and shoot at.",
			})

		opts.filtersLink:Toggle("manipulation", "Manipulation", false):SetTip({
			title = "Manipulation",
			body = "Reaches enemies behind cover by shifting where your shots come from and where they land.",
		})
		local manipulationLink = opts.filtersLink:OnKey("manipulation")
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

		opts.performanceLink:Slider("tickRate", "Tick Rate", 120, 10, 240, 5, nil, " Hz"):SetTip({
			title = "Tick Rate",
			body = "How many times per second the Ragebot scans targets. Lower frees up FPS.",
		})
		opts.performanceLink:Slider("fovLimit", "FOV Limit", 180, 5, 180, 1, nil, "\194\176"):SetTip({
			title = "FOV Limit",
			body = "Only considers enemies within this cone around your camera look. 180\194\176 disables the FOV filter.",
		})
		opts.performanceLink:Slider("maxDistance", "Max Distance", 500, 50, 2000, 10, nil, "st"):SetTip({
			title = "Max Distance",
			body = "Only considers enemies within this distance.",
		})

		self._cache = {
			enabled = false,
			targeting = TARGETING_OPTIONS[1],
			hitboxes = DEFAULT_HITBOXES,
			hitboxSet = { Head = true, Torso = true },
			topHitbox = "Head",
			multipoint = true,
			multipointScale = 0.7,
			multipointSet = { Head = true, Torso = true, Arms = true, Legs = true, Feet = true },
			manipulation = false,
			manipOriginOffset = 6.9,
			manipHitOffset = 6.4,
			scanInterval = 1 / 120,
			maxDistance = 500,
			maxDistanceSq = 500 * 500,
			fovLimit = 180,
			cosFovHalf = -1,
		}
		self._lastScanAt = 0
		self._scanPool = {} :: { any }
		self._scanList = {} :: { any }
		self._losIgnore = {} :: { Instance }
		self._reachCache = setmetatable({}, { __mode = "k" }) :: any
		self._hitCache = setmetatable({}, { __mode = "k" }) :: any
		self._muzzlePart = nil :: BasePart?
		self._muzzleWeaponId = nil :: any
		self._targetUserId = nil :: number?
		self._bullets = nil :: any
		self._bulletsProtos = nil :: any
		self._world = nil :: any
		self._cameras = nil :: any
		self._localPlayer = nil :: any
		self._globals = nil :: any
		self._effects = nil :: Instance?
		self._tickConn = nil :: RBXScriptConnection?

		self:_subscribeSettings()

		ragebotFov.attach(self, opts.visualsLink, {
			getEnabled = ragebotApi.IsEnabled,
			getFovLimit = function(): number
				return self._cache.fovLimit
			end,
		})

		return self
	end

	function Ragebot._subscribeSettings(self: Ragebot): ()
		local cache = self._cache

		self:Track(ScopeController.OnChange("arAimbot.enabled", function(v: any): ()
			cache.enabled = v == true
			self:_setActive(cache.enabled)
		end))
		self:Track(ScopeController.OnChange("arAimbotTargeting.targeting", function(v: any): ()
			cache.targeting = v or TARGETING_OPTIONS[1]
		end))
		self:Track(ScopeController.OnChange("arAimbotTargeting.hitboxes", function(v: any): ()
			local list = (type(v) == "table" and v or DEFAULT_HITBOXES)
			cache.hitboxes = list
			local set: { [string]: boolean } = {}
			for _, name in next, list do
				set[name] = true
			end
			cache.hitboxSet = set
			local top: string? = nil
			for _, name in next, HITBOX_PRIORITY do
				if set[name] then
					top = name
					break
				end
			end
			cache.topHitbox = top or "Head"
			table.clear(self._reachCache)
		end))
		self:Track(ScopeController.OnChange("arAimbotFilters.manipulation", function(v: any): ()
			cache.manipulation = v == true
			table.clear(self._reachCache)
		end))
		self:Track(ScopeController.OnChange("arAimbotFilters.manipulation.opts.originOffset", function(v: any): ()
			cache.manipOriginOffset = v or 6.9
			table.clear(self._reachCache)
		end))
		self:Track(ScopeController.OnChange("arAimbotFilters.manipulation.opts.hitOffset", function(v: any): ()
			cache.manipHitOffset = v or 6.4
			table.clear(self._reachCache)
		end))
		self:Track(ScopeController.OnChange("arAimbotPerformance.tickRate", function(v: any): ()
			local hz = v or 120
			if hz < 10 then
				hz = 10
			elseif hz > 240 then
				hz = 240
			end
			cache.scanInterval = 1 / hz
		end))
		self:Track(ScopeController.OnChange("arAimbotPerformance.fovLimit", function(v: any): ()
			local fov = v or 180
			cache.fovLimit = fov
			cache.cosFovHalf = fov >= 180 and -1 or math.cos(math.rad(fov * 0.5))
		end))
		self:Track(ScopeController.OnChange("arAimbotPerformance.maxDistance", function(v: any): ()
			local d = v or 500
			cache.maxDistance = d
			cache.maxDistanceSq = d * d
		end))
	end

	function Ragebot._ensureModules(self: Ragebot): boolean
		if not self._bullets then
			local m = ModuleController.GetModule("Bullets")
			self._bullets = m and m.module
			self._bulletsProtos = m and m.protos
		end
		if not self._cameras then
			local m = ModuleController.GetModule("Cameras")
			self._cameras = m and m.module
		end
		if not self._localPlayer then
			local m = ModuleController.GetModule("LocalPlayer")
			self._localPlayer = m and m.module
		end
		if not self._globals then
			local m = ModuleController.GetModule("Globals")
			self._globals = m and m.module
		end
		if not self._world then
			local m = ModuleController.GetModule("World")
			self._world = m and m.module
		end
		if not self._effects then
			self._effects = Workspace:FindFirstChild("Effects")
		end
		return self._bullets ~= nil and self._cameras ~= nil and self._localPlayer ~= nil and self._globals ~= nil
	end

	function Ragebot._setActive(self: Ragebot, active: boolean): ()
		WeaponController.SetNoSpread(active, 0)
		ragebotApi.SetEnabled(active)
		if active then
			if not self._tickConn then
				self._lastScanAt = 0
				self._tickConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
					local now = os.clock()
					if now - self._lastScanAt < self._cache.scanInterval then
						return
					end
					self._lastScanAt = now
					self:_tick()
				end))
			end
		else
			if self._tickConn then
				self._tickConn:Disconnect()
				self._tickConn = nil
			end
			self._muzzlePart = nil
			self._muzzleWeaponId = nil
			self:_setTarget(nil)
		end
	end

	function Ragebot._setTarget(self: Ragebot, playerData: any, part: BasePart?): ()
		local player = playerData and playerData:GetPlayer() or nil
		self._targetUserId = player and player.UserId or nil
		ragebotApi.SetTarget(player, part)
	end

	Ragebot._getOrigin = LPH_NO_VIRTUALIZE(function(self: Ragebot, character: any, weapon: any): Vector3?
		if peek(ClientState.thirdPerson) then
			local head = peek(ClientState.parts).Head :: BasePart?
			if head and head.Parent then
				return head.Position
			end
		end

		if weapon.Id ~= self._muzzleWeaponId or not (self._muzzlePart and self._muzzlePart.Parent) then
			self._muzzleWeaponId = weapon.Id
			self._muzzlePart = nil
			local instance = character.Instance
			local equipped = instance and instance:FindFirstChild("Equipped")
			local model = equipped and equipped:FindFirstChild(weapon.Name)
			self._muzzlePart = model and model:FindFirstChild("Muzzle") :: BasePart?
		end

		local muzzle = self._muzzlePart
		if muzzle and muzzle.Parent then
			return muzzle.CFrame.Position
		end

		local camera = Workspace.CurrentCamera
		return camera and camera.CFrame.Position
	end)

	local scanHitboxes = LPH_NO_VIRTUALIZE(
		function(
			cache: any,
			origin: Vector3,
			parts: any,
			vel: Vector3,
			airborne: boolean,
			worldGravity: number,
			speed: number,
			projGravity: number,
			ignore: { Instance },
			useManip: boolean
		): (Vector3?, Vector3?, BasePart?, string?, Vector3?)
			local enabledSet = cache.hitboxSet
			local multipointOn = cache.multipoint and not useManip
			local multipointSet = cache.multipointSet
			local multipointScale = cache.multipointScale
			local rays = RAY_BUDGET

			for _, hitboxName in next, HITBOX_PRIORITY do
				if not enabledSet[hitboxName] then
					continue
				end

				local list = HITBOX_PARTS[hitboxName]
				if not list then
					continue
				end

				local useMulti = multipointOn and multipointSet[hitboxName] == true

				for _, partName in next, list do
					local part = parts[partName]
					if not part then
						continue
					end

					local cf = part.CFrame
					local center = cf.Position
					local aimPoint = ballistics.predictAimPosition(
						origin,
						center,
						vel,
						airborne,
						worldGravity,
						speed,
						projGravity
					)

					if (aimPoint - origin).Magnitude < 1e-3 then
						continue
					end

					if useManip then
						local solvedOrigin, solvedHit =
							manipScan.solve(origin, aimPoint, ignore, cache.manipOriginOffset, cache.manipHitOffset)
						if solvedOrigin and solvedHit then
							return solvedHit, solvedOrigin, part, hitboxName, solvedHit
						end
						continue
					end

					local hasGuide = false
					local guide = Vector3.zero
					local guidePos: Vector3? = nil

					local knownIdx = segmentBlockedBy(origin, aimPoint)
					if knownIdx then
						guidePos = boxOcclusion.position(knownIdx)
					elseif rays > 0 then
						rays -= 1
						local centerClear, centerBlocker = worldRaycast.losBlocker(origin, aimPoint, ignore)
						if centerClear then
							return aimPoint, origin, part, hitboxName
						end
						if centerBlocker then
							registerBlocker(centerBlocker)
							if centerBlocker:IsA("BasePart") then
								guidePos = (centerBlocker :: BasePart).Position
							end
						end
					else
						break
					end

					if guidePos then
						local rayDir = aimPoint - origin
						local rayMag = rayDir.Magnitude
						if rayMag > 1e-3 then
							rayDir /= rayMag
							local toCenter = center - guidePos
							local perp = toCenter - rayDir * toCenter:Dot(rayDir)
							local perpMag = perp.Magnitude
							if perpMag > 1e-3 then
								guide = perp / perpMag
								hasGuide = true
							end
						end
					end

					if useMulti and rays > 0 then
						local predOffset = aimPoint - center
						local sampleCount = multipoint.samplePointsInto(SAMPLE_BUFFER, cf, part.Size, multipointScale)
						local count = 0
						for si = 2, sampleCount do
							count += 1
							ORDER_BUFFER[count] = si
							SCORE_BUFFER[si] = hasGuide and (SAMPLE_BUFFER[si] - center):Dot(guide) or 0
						end

						if hasGuide then
							for i = 2, count do
								local si = ORDER_BUFFER[i]
								local score = SCORE_BUFFER[si]
								local j = i - 1
								while j >= 1 and SCORE_BUFFER[ORDER_BUFFER[j]] < score do
									ORDER_BUFFER[j + 1] = ORDER_BUFFER[j]
									j -= 1
								end
								ORDER_BUFFER[j + 1] = si
							end
						end

						for k = 1, count do
							local sample = SAMPLE_BUFFER[ORDER_BUFFER[k]]
							local samplePredicted = sample + predOffset
							if not segmentBlockedBy(origin, samplePredicted) then
								if rays <= 0 then
									break
								end
								rays -= 1
								local sampleClear, sampleBlocker = worldRaycast.losBlocker(origin, samplePredicted, ignore)
								if sampleClear then
									return samplePredicted, origin, part, hitboxName, sample
								end
								if sampleBlocker then
									registerBlocker(sampleBlocker)
								end
							end
						end

						if hasGuide and rays > 0 and multipointScale > 0 and multipointScale < 0.97 then
							local inv = 1 / multipointScale
							local probed = 0
							for k = 1, count do
								local si = ORDER_BUFFER[k]
								if si <= 7 then
									local probe = center + (SAMPLE_BUFFER[si] - center) * inv
									local probePredicted = probe + predOffset
									if not segmentBlockedBy(origin, probePredicted) then
										if rays <= 0 then
											break
										end
										rays -= 1
										local probeClear, probeBlocker =
											worldRaycast.losBlocker(origin, probePredicted, ignore)
										if probeClear then
											return probePredicted, origin, part, hitboxName, probe
										end
										if probeBlocker then
											registerBlocker(probeBlocker)
										end
									end
									probed += 1
									if probed >= 2 then
										break
									end
								end
							end
						end
					end
				end
			end

			return nil, nil, nil, nil
		end
	)

	Ragebot._resolveAim = LPH_NO_VIRTUALIZE(
		function(
			self: Ragebot,
			playerData: any,
			origin: Vector3,
			parts: any,
			vel: Vector3,
			airborne: boolean,
			worldGravity: number,
			speed: number,
			projGravity: number,
			ignore: { Instance }
		): (Vector3?, Vector3?, BasePart?, string?, Vector3?)
			local cache = self._cache
			local hitCache = self._hitCache

			local held = hitCache[playerData]
			if held then
				local heldPart = held.part :: BasePart
				if heldPart.Parent and cache.hitboxSet[held.hitbox] then
					if held.hitbox ~= cache.topHitbox then
						local names = HITBOX_PARTS[cache.topHitbox]
						local probePart: BasePart? = nil
						if names then
							for _, partName in next, names do
								local p = parts[partName]
								if p then
									probePart = p
									break
								end
							end
						end
						if probePart then
							local probeAim = ballistics.predictAimPosition(
								origin,
								probePart.Position,
								vel,
								airborne,
								worldGravity,
								speed,
								projGravity
							)
							if
								(probeAim - origin).Magnitude >= 1e-3
								and not segmentBlockedBy(origin, probeAim)
							then
								local probeClear, probeBlocker = worldRaycast.losBlocker(origin, probeAim, ignore)
								if probeClear then
									held.part = probePart
									held.hitbox = cache.topHitbox
									held.offset = Vector3.zero
									return probeAim, origin, probePart, cache.topHitbox, nil
								end
								if probeBlocker then
									registerBlocker(probeBlocker)
								end
							end
						end
					end

					local world = heldPart.CFrame:PointToWorldSpace(held.offset)
					local heldAim =
						ballistics.predictAimPosition(origin, world, vel, airborne, worldGravity, speed, projGravity)
					if
						(heldAim - origin).Magnitude >= 1e-3
						and not segmentBlockedBy(origin, heldAim)
						and worldRaycast.clearLineOfSight(origin, heldAim, ignore)
					then
						return heldAim, origin, heldPart, held.hitbox, world
					end
				end
				hitCache[playerData] = nil
			end

			local aimPoint, fireOrigin, part, hitboxName, reportPos =
				scanHitboxes(cache, origin, parts, vel, airborne, worldGravity, speed, projGravity, ignore, false)
			if aimPoint then
				local entry = held or {} :: any
				entry.part = part
				entry.hitbox = hitboxName
				entry.offset = (part :: BasePart).CFrame:PointToObjectSpace(reportPos or (part :: BasePart).Position)
				hitCache[playerData] = entry
				return aimPoint, fireOrigin, part, hitboxName, reportPos
			end

			if not cache.manipulation then
				return nil, nil, nil, nil
			end

			return scanHitboxes(cache, origin, parts, vel, airborne, worldGravity, speed, projGravity, ignore, true)
		end
	)

	Ragebot._executeShot = LPH_NO_VIRTUALIZE(
		function(
			self: Ragebot,
			weapon: any,
			speed: number,
			projGravity: number,
			worldGravity: number,
			fireOrigin: Vector3,
			hitPart: BasePart,
			reportPos: Vector3?,
			localChar: Instance?,
			effects: Instance?
		): boolean
			local targetChar = hitPart.Parent
			if not targetChar then
				return false
			end
			local ignore = { targetChar :: Instance }
			if localChar then
				ignore[#ignore + 1] = localChar
			end
			if effects then
				ignore[#ignore + 1] = effects
			end

			local hitPos = reportPos or hitPart.Position
			if not worldRaycast.clearLineOfSight(fireOrigin, hitPos, ignore) then
				return false
			end

			local aim, flightTime =
				ballistics.predictAimPosition(fireOrigin, hitPos, Vector3.zero, false, worldGravity, speed, projGravity)
			local direction = aim - fireOrigin
			local mag = direction.Magnitude
			if mag < 1e-4 or mag == math.huge then
				return false
			end
			direction /= mag

			if not consumeAmmo(weapon) then
				return false
			end

			local weaponId = weapon.Id
			local pelletCount = math.max(weapon.FireConfig.PelletCount or 1, 1)
			local shotId = WeaponController.GetNextShotId()
			local fireTime = Workspace:GetServerTimeNow() - flightTime
			local encOrigin, encDirection = encodeShot(fireOrigin, direction, fireTime, shotId)

			setthreadidentity(2)
			NetworkController.send("Bullet Fired", shotId, fireTime, weaponId, encOrigin, encDirection)
			for pellet = 1, pelletCount do
				sendImpact(weaponId, fireTime, shotId, pellet, hitPart, hitPos, fireOrigin, speed)
			end
			setthreadidentity(8)

			local protos = self._bulletsProtos
			local fx = protos and protos.impactEffects
			if fx then
				fx(true, hitPart, hitPos, -direction, weapon, direction)
			end

			return true
		end
	)

	Ragebot._tick = function(self: Ragebot): ()
		local cache = self._cache
		if not cache.enabled or not peek(ClientState.alive) then
			self:_setTarget(nil)
			return
		end

		if not self:_ensureModules() then
			return
		end

		local weapon = WeaponController.GetEquippedWeapon()
		if not weapon or not weapon.FireConfig then
			self:_setTarget(nil)
			return
		end

		local serverTime = Workspace:GetServerTimeNow()
		local fireInterval = WeaponController.GetFireInterval(weapon)
		local canFireNow = serverTime - (weapon.LastShot or 0) >= fireInterval
			and serverTime >= (weapon.NextShotValid or 0)
			and not weapon.Reloading
			and hasAmmo(weapon)

		local arLocalPlayer = self._localPlayer.get()
		local character = arLocalPlayer and arLocalPlayer.Character
		if not character then
			return
		end

		local gameCamera = self._cameras:GetCamera("Character")
		if not gameCamera then
			return
		end

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local origin = self:_getOrigin(character, weapon)
		if not origin then
			return
		end

		local speed = (weapon.FireConfig.MuzzleVelocity or 0) * (self._globals.MuzzleVelocityMod or 1)
		if speed <= 0 then
			return
		end
		local projGravity = self._globals.ProjectileGravity or 0
		local worldGravity = Workspace.Gravity

		local cameraCF = camera.CFrame
		local camPos = cameraCF.Position
		local camLook = cameraCF.LookVector
		local camLookX, camLookY, camLookZ = camLook.X, camLook.Y, camLook.Z
		local cosFovHalf = cache.cosFovHalf
		local hasFov = cosFovHalf > -0.999
		local maxDistanceSq = cache.maxDistanceSq
		local crosshairMode = cache.targeting ~= "Highest Damage"
		local localChar = peek(ClientState.character)
		local effects = self._effects

		local chunkSize = self._globals.MapChunkSize
		local corner = self._globals.MapLeftTopCorner
		local chunkRadius = -1
		if self._world and type(chunkSize) == "number" and chunkSize > 0 and corner then
			chunkRadius = self._world:GetDistance("Terrain") / chunkSize
		end

		local pool = self._scanPool
		local list = self._scanList
		local n = 0

		local forced = ragebotApi.GetForcedTarget()
		local hasFilters = ragebotApi.HasFilters()

		for _, playerData in next, PlayerController.GetAll() do
			if not peek(playerData.alive) then
				continue
			end
			local rbxPlayer = playerData:GetPlayer()
			if rbxPlayer == LocalPlayer then
				continue
			end
			if forced and rbxPlayer ~= forced then
				continue
			end
			if rbxPlayer and playerState.ShouldSkip(rbxPlayer.UserId) then
				continue
			end
			local enemyChar = peek(playerData.character)
			if not enemyChar then
				continue
			end
			if enemyChar.Parent == nil then
				continue
			end
			local hrp = peek(playerData.hrp) :: BasePart?
			if not hrp then
				continue
			end
			if
				hasFilters
				and rbxPlayer
				and not ragebotApi.RunFilters(rbxPlayer, { character = enemyChar, rootPart = hrp })
			then
				continue
			end

			local hrpPos = hrp.Position
			local ex, ey, ez = hrpPos.X - camPos.X, hrpPos.Y - camPos.Y, hrpPos.Z - camPos.Z
			local distSq = ex * ex + ey * ey + ez * ez
			if distSq > maxDistanceSq then
				continue
			end
			local mag = math.sqrt(distSq)
			local align = mag > 1e-3 and (ex * camLookX + ey * camLookY + ez * camLookZ) / mag or -1
			if hasFov and align < cosFovHalf then
				continue
			end
			if chunkRadius >= 0 and not chunkLoaded(hrpPos, camPos, chunkRadius, chunkSize, corner) then
				continue
			end

			n += 1
			local entry = pool[n]
			if not entry then
				entry = {} :: any
				pool[n] = entry
			end
			entry.parts = peek(playerData.parts)
			entry.vel = hrp.AssemblyLinearVelocity
			entry.hrpPos = hrpPos
			entry.enemyChar = enemyChar
			entry.playerData = playerData
			entry.userId = rbxPlayer and rbxPlayer.UserId or 0
			entry.align = align
			list[n] = entry
		end

		for i = n + 1, #list do
			list[i] = nil
		end
		if n == 0 then
			self:_setTarget(nil)
			return
		end
		if n > 1 then
			table.sort(list, byAlignDesc)
		end

		if not canFireNow then
			local targetUserId = self._targetUserId
			if targetUserId then
				local stillInFov = false
				for i = 1, n do
					if list[i].userId == targetUserId then
						stillInFov = true
						break
					end
				end
				if not stillInFov then
					self:_setTarget(nil)
				end
			end
			return
		end

		local bestAimPoint: Vector3? = nil
		local bestOrigin: Vector3 = origin
		local bestHitPart: BasePart? = nil
		local bestReportPos: Vector3? = nil
		local bestEntry: any = nil
		local bestScore = -math.huge

		local reachCache = self._reachCache
		local scanClock = os.clock()
		boxOcclusion.reset()

		for i = 1, n do
			local entry = list[i]
			local vel = entry.vel
			local airborne = math.abs(vel.Y) > AIRBORNE_EPS

			local rc = reachCache[entry.playerData]
			if rc and scanClock - rc.t < REACH_CACHE_TTL then
				local hp = entry.hrpPos
				local dex, dey, dez = hp.X - rc.ex, hp.Y - rc.ey, hp.Z - rc.ez
				local dox, doy, doz = origin.X - rc.ox, origin.Y - rc.oy, origin.Z - rc.oz
				if
					dex * dex + dey * dey + dez * dez < REACH_CACHE_EPS_SQ
					and dox * dox + doy * doy + doz * doz < REACH_CACHE_EPS_SQ
					and vel:Dot(vel) < CACHE_VEL_SKIP_SQ
				then
					continue
				end
			end

			local ignore = self._losIgnore
			table.clear(ignore)
			if localChar then
				ignore[#ignore + 1] = localChar
			end
			ignore[#ignore + 1] = entry.enemyChar
			if effects then
				ignore[#ignore + 1] = effects
			end

			local aimPoint, fireOrigin, hitPart, hitboxName, reportPos = self:_resolveAim(
				entry.playerData,
				origin,
				entry.parts,
				vel,
				airborne,
				worldGravity,
				speed,
				projGravity,
				ignore
			)
			if not aimPoint then
				if not rc then
					rc = {} :: any
					reachCache[entry.playerData] = rc
				end
				local hp = entry.hrpPos
				rc.ox, rc.oy, rc.oz = origin.X, origin.Y, origin.Z
				rc.ex, rc.ey, rc.ez = hp.X, hp.Y, hp.Z
				rc.t = scanClock
				continue
			end
			reachCache[entry.playerData] = nil

			if crosshairMode then
				bestAimPoint = aimPoint
				bestOrigin = fireOrigin or origin
				bestHitPart = hitPart
				bestReportPos = reportPos
				bestEntry = entry
				break
			end

			local dmg = predictDamage(weapon, hitboxName :: string)
			if dmg > bestScore then
				bestScore = dmg
				bestAimPoint = aimPoint
				bestOrigin = fireOrigin or origin
				bestHitPart = hitPart
				bestReportPos = reportPos
				bestEntry = entry
				if hitboxName == "Head" then
					break
				end
			end
		end

		if not bestAimPoint or not bestHitPart then
			self:_setTarget(nil)
			return
		end

		local targetPlayer = bestEntry and bestEntry.playerData and bestEntry.playerData:GetPlayer() or nil
		self:_setTarget(bestEntry and bestEntry.playerData or nil, bestHitPart)
		originState.NotifyRagebotTarget(bestHitPart)

		if ragebotApi.HasGates() and targetPlayer then
			local shot = {
				player = targetPlayer,
				part = bestHitPart,
				damage = 0,
				wallbang = false,
				source = "ragebot",
				hitTarget = true,
			}
			if not ragebotApi.RunGates(shot) then
				return
			end
		end

		local fired = self:_executeShot(
			weapon,
			speed,
			projGravity,
			worldGravity,
			bestOrigin,
			bestHitPart,
			bestReportPos,
			localChar,
			effects
		)

		if fired then
			local fireTime = Workspace:GetServerTimeNow()
			weapon.LastShot = fireTime
			weapon.NextShotValid = fireTime + fireInterval

			if targetPlayer then
				ragebotApi.NotifyShot({
					player = targetPlayer,
					part = bestHitPart,
					damage = 0,
					wallbang = false,
					source = "ragebot",
					hitTarget = true,
				})
			end
		end
	end

	function Ragebot.Destroy(self: Ragebot): ()
		self:_setActive(false)
		BaseFeature.Destroy(self)
	end

	export type Ragebot =
		typeof(setmetatable(
			{} :: {
				_cache: any,
				_lastScanAt: number,
				_scanPool: { any },
				_scanList: { any },
				_losIgnore: { Instance },
				_reachCache: any,
				_hitCache: any,
				_muzzlePart: BasePart?,
				_muzzleWeaponId: any,
				_targetUserId: number?,
				_bullets: any,
				_bulletsProtos: any,
				_cameras: any,
				_localPlayer: any,
				_globals: any,
				_world: any,
				_effects: Instance?,
				_tickConn: RBXScriptConnection?,
				_subscribeSettings: (Ragebot) -> (),
				_ensureModules: (Ragebot) -> boolean,
				_setActive: (Ragebot, boolean) -> (),
				_setTarget: (Ragebot, any, BasePart?) -> (),
				_getOrigin: (Ragebot, any, any) -> Vector3?,
				_resolveAim: (
					Ragebot,
					any,
					Vector3,
					any,
					Vector3,
					boolean,
					number,
					number,
					number,
					{ Instance }
				) -> (Vector3?, Vector3?, BasePart?, string?, Vector3?),
				_executeShot: (
					Ragebot,
					any,
					number,
					number,
					number,
					Vector3,
					BasePart,
					Vector3?,
					Instance?,
					Instance?
				) -> boolean,
				_tick: (Ragebot) -> (),
			},
			Ragebot
		))
		& BaseFeature.BaseFeature

	return Ragebot
end)()
