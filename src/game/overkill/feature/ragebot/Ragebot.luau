return LPH_JIT(function()
	local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
	local RunService = cloneref(game:GetService("RunService")) :: RunService

	local Charm = require("@pkg/Charm")
	local BaseFeature = require("@game/BaseFeature")
	local gameUi = require("@game/gameUi")
	local PlayerController = require("@feature/player/PlayerController")
	local ClientState = require("@game/overkill/client/clientState")
	local WeaponController = require("@game/overkill/weapon/WeaponController")
	local CommandController = require("@game/overkill/weapon/CommandController")
	local ModuleController = require("@game/overkill/module/ModuleController")
	local bulletRedirection = require("@game/overkill/feature/legitbot/bulletRedirection")
	local Backtrack = require("@game/overkill/feature/legitbot/BacktrackController")
	local deflectPov = require("@game/overkill/feature/legitbot/deflectPov")
	local originState = require("@game/universal/feature/visual/crosshair/originState")
	local worldRaycast = require("@game/overkill/weapon/worldRaycast")
	local botSource = require("@game/overkill/feature/training/botSource")
	local targeting = require("@game/overkill/player/targeting")
	local slotKeys = require("@game/overkill/weapon/slotKeys")
	local ragebotFov = require("@game/universal/feature/combat/ragebot/ragebotFov")
	local multipoint = require("@game/universal/feature/combat/ragebot/multipoint")
	local cameraState = require("@share/cameraState")
	local gunCategories = require("@game/overkill/weapon/gunCategories")
	local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")
	local playerState = require("@feature/record/module/playerState")
	local hudState = require("@game/universal/feature/visual/hud/hudState")

	local peek = Charm.peek
	local at = Charm.atom

	local OVERKILL_HITBOX_PARTS = targeting.HITBOX_PARTS
	local HITBOX_OPTIONS: { string } = { "Head", "Torso", "Arms", "Legs", "Feet" }
	local HITBOX_PRIORITY: { string } = { "Head", "Torso", "Arms", "Legs", "Feet" }
	local DEFAULT_HITBOXES: { string } = { "Head", "Torso" }
	local TARGETING_OPTIONS: { string } = { "Closest To Crosshair", "Closest Distance", "Lowest Health" }
	local ON_EMPTY_MODES: { string } = { "Reload", "Switch" }

	local BTN_PRIMARY = 1
	local BTN_RELOAD = 4

	local STEP_NAME = "limerenceRagebot"
	local STEP_PRIORITY = Enum.RenderPriority.Input.Value - 2

	local FIRE_RELEASE_GAP = 0.05
	local FIRE_NOFIRE_TIMEOUT = 0.06
	local CHARGE_HOLD_LINGER = 0.4
	local STICKY_BRIDGE = 0.1
	local STICKY_LINGER = 0.5

	local SAMPLE_BUFFER: { Vector3 } = table.create(15)
	local DEFAULT_MULTIPOINT: { string } = { "Head", "Torso", "Arms", "Legs", "Feet" }
	local RAY_BUDGET = 32


	local CHARGE_IGNORE: { Instance } = table.create(2)

	local Ragebot = {}
	Ragebot.__index = Ragebot

	setmetatable(Ragebot, { __index = BaseFeature })

	local isEnemy = targeting.isEnemy

	local clientModule: any = nil
	local items: any = nil

	local function isGunSlot(state: any, slot: number): boolean
		local weaponId = state[slotKeys[slot].weaponID]
		if type(weaponId) ~= "string" or weaponId == "" then
			return false
		end
		if not items then
			items = ModuleController.GetModule("items")
		end
		local item = items and items.all[weaponId]
		return item ~= nil and gunCategories[item.category] == true
	end

	local function currentHoldMode(): boolean
		if not clientModule then
			clientModule = ModuleController.GetModule("clientModule")
		end
		local localChickynoid = clientModule and clientModule.localChickynoid
		local simulation = localChickynoid and localChickynoid.simulation
		local state = simulation and simulation.state
		if type(state) ~= "table" then
			return true
		end
		local slot = state.equippedSlot or 1
		return state[(slotKeys[slot] or slotKeys[1]).mode] ~= "single"
	end

	local function loadedSlot(currentSlot: number): number?
		if not clientModule then
			clientModule = ModuleController.GetModule("clientModule")
		end
		local localChickynoid = clientModule and clientModule.localChickynoid
		local simulation = localChickynoid and localChickynoid.simulation
		local state = simulation and simulation.state
		if type(state) ~= "table" then
			return nil
		end
		for slot = 1, 4 do
			if slot == currentSlot or not isGunSlot(state, slot) then
				continue
			end
			local mag = state[slotKeys[slot].magCount]
			if type(mag) == "number" and mag > 0 then
				return slot
			end
		end
		return nil
	end

	local bestVisiblePart = LPH_NO_VIRTUALIZE(
		function(
			parts: { [string]: any },
			hitboxSet: { [string]: boolean },
			camera: Camera,
			centerX: number,
			centerY: number,
			fovPixels: number,
			noScreenCheck: boolean,
			originPos: Vector3,
			ourChar: Instance?,
			ignore: { Instance },
			multipointOn: boolean,
			multipointSet: { [string]: boolean },
			multipointScale: number
		): (Vector3?, BasePart?, number)
			local _, anyPart = next(parts)
			local targetModel = anyPart and (anyPart :: Instance).Parent
			table.clear(ignore)
			if ourChar then
				ignore[#ignore + 1] = ourChar
			end
			if targetModel then
				ignore[#ignore + 1] = targetModel
			end

			local camCf = camera.CFrame
			local camLook = camCf.LookVector
			local camOrigin = camCf.Position

			local sampleBuffer = SAMPLE_BUFFER
			local bestPoint: Vector3? = nil
			local bestPart: BasePart? = nil
			local bestDist = math.huge
			local rays = RAY_BUDGET
			for _, hitboxName in next, HITBOX_PRIORITY do
				if not hitboxSet[hitboxName] then
					continue
				end
				local names = OVERKILL_HITBOX_PARTS[hitboxName]
				if not names then
					continue
				end
				local isHead = hitboxName == "Head"
				local useMulti = multipointOn and multipointSet[hitboxName] == true
				for _, partName in next, names do
					local part = parts[partName]
					if not part or not part:IsA("BasePart") then
						continue
					end
					local cf = part.CFrame
					local center = cf.Position
					local cd
					local cOnScreen = true
					if noScreenCheck then
						cd = 1 - camLook:Dot((center - camOrigin).Unit)
					else
						local screen = camera:WorldToViewportPoint(center)
						if screen.Z <= 0 then
							cOnScreen = false
						else
							local dx = screen.X - centerX
							local dy = screen.Y - centerY
							cd = math.sqrt(dx * dx + dy * dy)
							if cd > fovPixels then
								cOnScreen = false
							end
						end
					end

					local centerTaken = false
					if cOnScreen and (isHead or cd < bestDist) and rays > 0 then
						rays -= 1
						if worldRaycast.clearLineOfSight(originPos, center, ignore) then
							if isHead then
								return center, part, cd
							end
							bestDist = cd
							bestPoint = center
							bestPart = part
							centerTaken = true
						end
					end

					if useMulti and not centerTaken and rays > 0 then
						local sampleCount = multipoint.samplePointsInto(sampleBuffer, cf, part.Size, multipointScale)
						for si = 2, sampleCount do
							if rays <= 0 then
								break
							end
							local point = sampleBuffer[si]
							local dist
							if noScreenCheck then
								dist = 1 - camLook:Dot((point - camOrigin).Unit)
							else
								local screen = camera:WorldToViewportPoint(point)
								if screen.Z <= 0 then
									continue
								end
								local dx = screen.X - centerX
								local dy = screen.Y - centerY
								dist = math.sqrt(dx * dx + dy * dy)
								if dist > fovPixels then
									continue
								end
							end
							if not isHead and dist >= bestDist then
								continue
							end
							rays -= 1
							if worldRaycast.clearLineOfSight(originPos, point, ignore) then
								if isHead then
									return point, part, dist
								end
								bestDist = dist
								bestPoint = point
								bestPart = part
							end
						end
					end
				end
			end
			return bestPoint, bestPart, bestDist
		end
	)

	local bestHistoricalPart = LPH_NO_VIRTUALIZE(
		function(
			player: Player,
			parts: { [string]: any },
			hitboxSet: { [string]: boolean },
			camera: Camera,
			centerX: number,
			centerY: number,
			fovPixels: number,
			noScreenCheck: boolean,
			originPos: Vector3,
			ourChar: Instance?,
			ignore: { Instance }
		): (Vector3?, BasePart?, number)
			local _, anyPart = next(parts)
			local targetModel = anyPart and (anyPart :: Instance).Parent
			table.clear(ignore)
			if ourChar then
				ignore[#ignore + 1] = ourChar
			end
			if targetModel then
				ignore[#ignore + 1] = targetModel
			end

			local camCf = camera.CFrame
			local camLook = camCf.LookVector
			local camOrigin = camCf.Position

			local bestPoint: Vector3? = nil
			local bestPart: BasePart? = nil
			local bestDist = math.huge
			for _, hitboxName in next, HITBOX_PRIORITY do
				if not hitboxSet[hitboxName] then
					continue
				end
				local names = OVERKILL_HITBOX_PARTS[hitboxName]
				if not names then
					continue
				end
				for _, partName in next, names do
					local part = parts[partName]
					if not part or not part:IsA("BasePart") then
						continue
					end
					local point = Backtrack.GetHistoricalPosition(player, partName)
					if not point then
						continue
					end
					local dist
					if noScreenCheck then
						dist = 1 - camLook:Dot((point - camOrigin).Unit)
					else
						local screen = camera:WorldToViewportPoint(point)
						if screen.Z <= 0 then
							continue
						end
						local dx = screen.X - centerX
						local dy = screen.Y - centerY
						dist = math.sqrt(dx * dx + dy * dy)
						if dist > fovPixels then
							continue
						end
					end
					if dist >= bestDist then
						continue
					end
					if worldRaycast.clearLineOfSight(originPos, point, ignore) then
						bestDist = dist
						bestPoint = point
						bestPart = part
					end
				end
			end
			return bestPoint, bestPart, bestDist
		end
	)

	local PICK_IGNORE: { Instance } = table.create(2)
	local PICK_HITBOXES: { [string]: boolean } = {}
	local PICK_MP_HITBOXES: { [string]: boolean } = {}
	local PICK_BEST = {
		position = nil :: Vector3?,
		player = nil :: any,
		part = nil :: BasePart?,
		useBacktrack = false,
	}
	local PICK_BEST_BACK = {
		position = nil :: Vector3?,
		player = nil :: any,
		part = nil :: BasePart?,
		useBacktrack = true,
	}
	local PICK_CTX = {
		camera = nil :: Camera?,
		cx = 0,
		cy = 0,
		fovPixels = 0,
		noScreenCheck = false,
		originPos = Vector3.zero,
		ourChar = nil :: Instance?,
		mode = "",
		camPos = Vector3.zero,
		backtrackOn = false,
		multipointOn = true,
		multipointScale = 0.7,
		best = nil :: any,
		bestScore = 0,
		bestRank = -1,
		bestBack = nil :: any,
		bestBackScore = 0,
		bestBackRank = -1,
	}

	local function scoreFor(ctx: any, point: Vector3, bp: any, partDist: number): number
		local mode = ctx.mode
		if mode == "Closest Distance" then
			return (point - ctx.camPos).Magnitude
		elseif mode == "Lowest Health" then
			return (bp.health and peek(bp.health)) or 0
		end
		return partDist
	end

	local considerTarget = LPH_NO_VIRTUALIZE(function(ctx: any, bp: any): ()
		if not isEnemy(bp) then
			return
		end
		if deflectPov.isPlayerDeflecting(bp) then
			return
		end

		local isBot = bp.isBot == true
		local rbxPlayer = bp:GetPlayer()
		local userId = (not isBot and rbxPlayer) and rbxPlayer.UserId or nil
		if userId and playerState.ShouldSkip(userId) then
			return
		end
		local rank = userId and playerState.GetRank(userId) or 0

		local parts = peek(bp.parts)
		if next(parts) == nil then
			return
		end

		local point, part, partDist = bestVisiblePart(
			parts,
			PICK_HITBOXES,
			ctx.camera,
			ctx.cx,
			ctx.cy,
			ctx.fovPixels,
			ctx.noScreenCheck,
			ctx.originPos,
			ctx.ourChar,
			PICK_IGNORE,
			ctx.multipointOn,
			PICK_MP_HITBOXES,
			ctx.multipointScale
		)
		if point and partDist <= ctx.fovPixels then
			local score = scoreFor(ctx, point, bp, partDist)
			if rank > ctx.bestRank or (rank == ctx.bestRank and score < ctx.bestScore) then
				ctx.bestRank = rank
				ctx.bestScore = score
				PICK_BEST.position = point
				PICK_BEST.player = bp
				PICK_BEST.part = part
				ctx.best = PICK_BEST
			end
			return
		end

		if not ctx.backtrackOn then
			return
		end
		local backPoint, backPart, backDist = bestHistoricalPart(
			rbxPlayer,
			parts,
			PICK_HITBOXES,
			ctx.camera,
			ctx.cx,
			ctx.cy,
			ctx.fovPixels,
			ctx.noScreenCheck,
			ctx.originPos,
			ctx.ourChar,
			PICK_IGNORE
		)
		if backPoint and backDist <= ctx.fovPixels then
			local score = scoreFor(ctx, backPoint, bp, backDist)
			if rank > ctx.bestBackRank or (rank == ctx.bestBackRank and score < ctx.bestBackScore) then
				ctx.bestBackRank = rank
				ctx.bestBackScore = score
				PICK_BEST_BACK.position = backPoint
				PICK_BEST_BACK.player = bp
				PICK_BEST_BACK.part = backPart
				ctx.bestBack = PICK_BEST_BACK
			end
		end
	end)

	function Ragebot.new(
		link: gameUi.Linker,
		opts: {
			targetingLink: gameUi.Linker?,
			performanceLink: gameUi.Linker?,
			visualsLink: gameUi.Linker?,
		}?
	): Ragebot
		local self = BaseFeature.new() :: any
		setmetatable(self, Ragebot)

		local targeting = (opts and opts.targetingLink) or link
		local perf = (opts and opts.performanceLink) or link
		local visualsLink = (opts and opts.visualsLink) or link

		local toggle = link:Toggle("ragebot", "Enabled", false):SetTip({
			title = "Ragebot",
			body = "Snaps to and fires at the best target in range. Aggressive, not legit.",
		})
		link:Dropdown("onEmpty", "On Empty", ON_EMPTY_MODES, ON_EMPTY_MODES[1]):SetTip({
			title = "On Empty",
			body = "When the active gun runs out of ammo: reload it, or switch to the next weapon.",
		})

		targeting:Dropdown("targeting", "Targeting", TARGETING_OPTIONS, TARGETING_OPTIONS[1]):SetTip({
			title = "Targeting",
			body = "How the Ragebot chooses which enemy to shoot at.",
		})
		targeting:Dropdown("hitbox", "Hitboxes", HITBOX_OPTIONS, DEFAULT_HITBOXES):SetMode("multi"):SetMin(1):SetTip({
			title = "Hitboxes",
			body = "Which body parts to scan and aim at.",
		})
		targeting:Toggle("multipoint", "Multipoint", true):SetTip({
			title = "Multipoint",
			body = "Scans multiple points across each hitbox and aims at the best visible one.",
		})
		local multipointLink = targeting:OnKey("multipoint")
		multipointLink:Submenu("opts", "Multipoint")
		local multipointOpts = multipointLink:OnKey("opts")
		multipointOpts:Dropdown("hitboxes", "Hitboxes", HITBOX_OPTIONS, DEFAULT_MULTIPOINT):SetMode("multi"):SetTip({
			title = "Hitboxes",
			body = "Which hitboxes get multi-point scanning. Others are scanned at their center only.",
		})
		multipointOpts:Slider("scale", "Scale", 70, 0, 100, 1, nil, "%"):SetTip({
			title = "Scale",
			body = "How far from the center of each hitbox extra aim points are tested.",
		})

		perf:Slider("fov", "FOV", 30, 1, 180, 1, nil, "°"):SetTip({
			title = "FOV",
			body = "Only targets within this cone around your crosshair.",
		})

		perf:Slider("scanRate", "Scan Rate", 120, 10, 240, 5, nil, " Hz"):SetTip({
			title = "Scan Rate",
			body = "How many times per second targets are scanned. Lower frees up FPS with slightly less reactive aim.",
		})

		self._enabled = false
		self._targetingEl = targeting:Get("targeting")
		self._hitboxEl = targeting:Get("hitbox")
		self._multipointEl = targeting:Get("multipoint")
		self._multipointHitboxEl = multipointOpts:Get("hitboxes")
		self._multipointScaleEl = multipointOpts:Get("scale")
		self._fovEl = perf:Get("fov")
		self._scanRateEl = perf:Get("scanRate")
		self._onEmptyEl = link:Get("onEmpty")
		self._bound = false
		self._emptyHandled = false
		self._lastSlot = 0
		self._injectReload = false
		self._injectSlot = 0
		self._cmdUnregister = nil
		self._firePressed = false
		self._firedSincePress = false
		self._pressClock = 0
		self._releaseClock = 0
		local firedConn = WeaponController.weaponFiredLocal:Connect(function(): ()
			self._firedSincePress = true
		end)
		self:Track(function(): ()
			firedConn:Disconnect()
		end)
		self._targetPlayerAtom = at(nil :: Player?)
		self._infoName = nil :: string?
		self._stickyTarget = nil :: any?
		self._stickyClock = 0
		self._lastScanAt = 0
		self._scanHadTarget = false
		self._aimOffset = Vector3.zero
		self:Track(espStateColors.RegisterTargetSource(self._targetPlayerAtom))

		self:Track(toggle:OnChange(function(value: boolean): ()
			if value then
				self:_enable()
			else
				self:_disable()
			end
		end))

		ragebotFov.attach(self, visualsLink, {
			getEnabled = function(): boolean
				return self._enabled
			end,
			getFovLimit = function(): number
				return self._fovEl:Peek() or 30
			end,
		})

		return self
	end

	function Ragebot._pickTarget(self: Ragebot): any?
		local camera = Workspace.CurrentCamera
		if not camera then
			return nil
		end
		local viewport = camera.ViewportSize
		local fovValue = self._fovEl:Peek() or 30
		local noScreenCheck = fovValue >= 180
		local camPos = camera.CFrame.Position

		local selected = self._hitboxEl:Peek()
		if type(selected) ~= "table" then
			selected = DEFAULT_HITBOXES
		end
		table.clear(PICK_HITBOXES)
		for _, name in next, selected do
			PICK_HITBOXES[name] = true
		end

		local multipointOn = self._multipointEl:Peek() ~= false
		local mpSelected = self._multipointHitboxEl:Peek()
		if type(mpSelected) ~= "table" then
			mpSelected = DEFAULT_MULTIPOINT
		end
		table.clear(PICK_MP_HITBOXES)
		for _, name in next, mpSelected do
			PICK_MP_HITBOXES[name] = true
		end

		local fpCamera = peek(ClientState.fpCamera)

		local ctx = PICK_CTX
		ctx.camera = camera
		ctx.cx = viewport.X * 0.5
		ctx.cy = viewport.Y * 0.5
		ctx.fovPixels = noScreenCheck and math.huge or cameraState.FovToPixels(fovValue)
		ctx.noScreenCheck = noScreenCheck
		ctx.originPos = (fpCamera and fpCamera.Position) or camPos
		ctx.ourChar = peek(ClientState.character)
		ctx.mode = self._targetingEl:Peek() or TARGETING_OPTIONS[1]
		ctx.camPos = camPos
		ctx.backtrackOn = Backtrack.IsEnabled()
		ctx.multipointOn = multipointOn
		ctx.multipointScale = (self._multipointScaleEl:Peek() or 70) / 100

		ctx.best = nil
		ctx.bestScore = math.huge
		ctx.bestRank = -1
		ctx.bestBack = nil
		ctx.bestBackScore = math.huge
		ctx.bestBackRank = -1

		for _, bp in next, PlayerController.GetAll() do
			considerTarget(ctx, bp)
		end
		for _, bot in next, botSource.GetAll() do
			considerTarget(ctx, bot)
		end

		return ctx.best or ctx.bestBack
	end

	function Ragebot._publishTarget(self: Ragebot, name: string): ()
		if name == self._infoName then
			return
		end
		self._infoName = name
		hudState.SetInfo("ragebotTarget", "targetting: " .. name, 10)
	end

	function Ragebot._clearTarget(self: Ragebot): ()
		self._stickyTarget = nil
		bulletRedirection.setRagebotTarget(nil)
		originState.NotifyRagebotTarget(nil)
		self._targetPlayerAtom(nil)
		self:_publishTarget("none")
		self:_driveFire(false, false, true)
	end

	function Ragebot._step(self: Ragebot): ()
		if not self._enabled then
			return
		end
		bulletRedirection.SetChargeDump(false)
		bulletRedirection.SetChargeHold(self._firePressed or (os.clock() - self._releaseClock) < CHARGE_HOLD_LINGER)
		if not peek(ClientState.alive) then
			self:_clearTarget()
			return
		end
		if not gunCategories[peek(ClientState.weaponCategory)] then
			self:_clearTarget()
			return
		end

		self:_handleEmpty()

		local now = os.clock()
		local scanHz = self._scanRateEl:Peek() or 120
		local target
		if now - self._lastScanAt >= 1 / scanHz then
			self._lastScanAt = now
			target = self:_pickTarget()
			self._scanHadTarget = target ~= nil
			if target and target.part then
				self._aimOffset = target.part.CFrame:PointToObjectSpace(target.position)
			end
		elseif self._scanHadTarget then
			local held = self._stickyTarget
			if held and self:_stickyValid(held) and held.part then
				held.position = held.part.CFrame:PointToWorldSpace(self._aimOffset)
				target = held
			end
		end
		local sticky = false
		if target then
			self._stickyTarget = target
			self._stickyClock = now
		else
			local held = self._stickyTarget
			local elapsed = now - self._stickyClock
			if
				held
				and (elapsed < STICKY_BRIDGE or (self._firePressed and elapsed < STICKY_LINGER))
				and self:_stickyValid(held)
			then
				target = held
				sticky = true
			else
				self._stickyTarget = nil
				self:_clearTarget()
				return
			end
		end
		local chargeMaxHp = bulletRedirection.GetChargeMaxHealth()
		if chargeMaxHp > 0 then
			local targetHp = (target.player.health and peek(target.player.health)) or 0
			if targetHp > 0 and targetHp <= chargeMaxHp then
				bulletRedirection.SetChargeHold(true)
			end
		end

		bulletRedirection.setRagebotTarget(target)
		originState.NotifyRagebotTarget(target.part)
		local targetPlayer = target.player:GetPlayer()
		self._targetPlayerAtom(targetPlayer)
		local display = targetPlayer and targetPlayer.DisplayName
		self:_publishTarget(
			(display ~= nil and display ~= "" and display) or (targetPlayer and targetPlayer.Name) or "unknown"
		)
		local canFire = peek(ClientState.canFire)
		if not canFire and bulletRedirection.GetTimeShift() > 0 then
			canFire = peek(ClientState.ammo) > 0 and not peek(ClientState.isReloading)
		end
		if canFire and not self:_chargeAimClear(target, sticky) then
			canFire = false
		end
		self:_driveFire(true, canFire, currentHoldMode())
	end

	function Ragebot._stickyValid(self: Ragebot, target: any): boolean
		local bp = target.player
		if not bp or not target.part or not isEnemy(bp) then
			return false
		end
		if not bp:GetPlayer() then
			return false
		end
		return next(peek(bp.parts)) ~= nil
	end

	function Ragebot._chargeAimClear(self: Ragebot, target: any, sticky: boolean): boolean
		local shift = bulletRedirection.GetAimShift()
		if shift <= 0 then
			return not sticky
		end
		if not sticky then
			if bulletRedirection.GetTimeShift() < bulletRedirection.GetChargeMinRelease() then
				bulletRedirection.SetChargeDump(true)
				return false
			end
			local maxHp = bulletRedirection.GetChargeMaxHealth()
			if maxHp > 0 then
				local hp = (target.player.health and peek(target.player.health)) or 0
				if hp > 0 and hp <= maxHp then
					bulletRedirection.SetChargeDump(true)
					return false
				end
			end
		end
		local part = target.part
		local rbxPlayer = target.player and target.player:GetPlayer()
		if not part or not rbxPlayer then
			return not sticky
		end
		if target.useBacktrack then
			shift += Backtrack.GetDelaySeconds()
		end
		local point = Backtrack.GetPositionAt(rbxPlayer, part.Name, shift)
		if not point then
			return not sticky
		end
		local camera = Workspace.CurrentCamera
		local fpCamera = peek(ClientState.fpCamera)
		local originPos = (fpCamera and fpCamera.Position) or (camera and camera.CFrame.Position)
		if not originPos then
			return not sticky
		end
		table.clear(CHARGE_IGNORE)
		local ourChar = peek(ClientState.character)
		if ourChar then
			CHARGE_IGNORE[#CHARGE_IGNORE + 1] = ourChar
		end
		local targetModel = part.Parent
		if targetModel then
			CHARGE_IGNORE[#CHARGE_IGNORE + 1] = targetModel
		end
		if worldRaycast.clearLineOfSight(originPos, point, CHARGE_IGNORE) then
			return true
		end
		if sticky then
			return false
		end
		if bulletRedirection.GetChargeNoWait() then
			bulletRedirection.SetChargeDump(true)
		end
		return false
	end

	function Ragebot._handleEmpty(self: Ragebot): ()
		local slot = peek(ClientState.equippedSlot)
		local switched = slot ~= self._lastSlot
		self._lastSlot = slot

		if peek(ClientState.ammo) > 0 then
			self._emptyHandled = false
			return
		end
		if switched then
			self._emptyHandled = false
		end
		if self._emptyHandled then
			return
		end

		if not switched and (self._onEmptyEl:Peek() or ON_EMPTY_MODES[1]) == "Switch" then
			local target = loadedSlot(slot)
			if target then
				self._emptyHandled = true
				self._injectSlot = target
				return
			end
		end

		if peek(ClientState.isReloading) then
			self._emptyHandled = true
			return
		end
		self._injectReload = true
	end

	function Ragebot._driveFire(self: Ragebot, wantFire: boolean, canFire: boolean, holdMode: boolean): ()
		local now = os.clock()
		if self._firePressed then
			local fired = self._firedSincePress
			local pulseDone = not holdMode and fired
			local stuck = not fired
				and (now - self._pressClock) > FIRE_NOFIRE_TIMEOUT
				and bulletRedirection.GetTimeShift() <= 0
			if not canFire or not wantFire or pulseDone or stuck then
				WeaponController.SetShooting(false)
				self._firePressed = false
				self._releaseClock = now
			end
			return
		end
		if wantFire and canFire and (now - self._releaseClock) >= FIRE_RELEASE_GAP then
			self._firedSincePress = false
			WeaponController.SetShooting(true)
			self._firePressed = true
			self._pressClock = now
		end
	end

	function Ragebot._enable(self: Ragebot): ()
		if self._enabled then
			return
		end
		self._enabled = true
		bulletRedirection.setRagebotActive(true)
		self:_publishTarget("none")

		if not self._cmdUnregister then
			self._cmdUnregister = CommandController.Register(function(command: any): ()
				if type(command) ~= "table" then
					return
				end
				if self._injectReload then
					self._injectReload = false
					command.buttons = bit32.bor(command.buttons or 0, BTN_RELOAD)
				end
				if self._injectSlot > 0 then
					command.slot = self._injectSlot
					self._injectSlot = 0
				end

				if self._firePressed then
					command.buttons = bit32.bor(command.buttons or 0, BTN_PRIMARY)
				end
			end, 10)
		end

		if not self._bound then
			self._bound = true
			RunService:BindToRenderStep(
				STEP_NAME,
				STEP_PRIORITY,
				LPH_NO_VIRTUALIZE(function(): ()
					self:_step()
				end)
			)
		end
	end

	function Ragebot._disable(self: Ragebot): ()
		if not self._enabled then
			return
		end
		self._enabled = false

		if self._bound then
			self._bound = false
			RunService:UnbindFromRenderStep(STEP_NAME)
		end

		if self._cmdUnregister then
			self._cmdUnregister()
			self._cmdUnregister = nil
		end
		self._emptyHandled = false
		self._lastSlot = 0
		self._injectReload = false
		self._injectSlot = 0

		self._stickyTarget = nil
		bulletRedirection.SetChargeDump(false)
		bulletRedirection.SetChargeHold(false)
		bulletRedirection.setRagebotTarget(nil)
		bulletRedirection.setRagebotActive(false)
		originState.NotifyRagebotTarget(nil)
		WeaponController.SetShooting(false)
		self._firePressed = false
		self._firedSincePress = false
		self._targetPlayerAtom(nil)
		self._infoName = nil
		hudState.SetInfo("ragebotTarget", nil)
	end

	function Ragebot.Destroy(self: Ragebot): ()
		self:_disable()
		BaseFeature.Destroy(self)
	end

	export type Ragebot =
		typeof(setmetatable(
			{} :: {
				_enabled: boolean,
				_targetingEl: any,
				_hitboxEl: any,
				_multipointEl: any,
				_multipointHitboxEl: any,
				_multipointScaleEl: any,
				_fovEl: any,
				_scanRateEl: any,
				_onEmptyEl: any,
				_bound: boolean,
				_emptyHandled: boolean,
				_lastSlot: number,
				_injectReload: boolean,
				_injectSlot: number,
				_cmdUnregister: (() -> ())?,
				_firePressed: boolean,
				_firedSincePress: boolean,
				_pressClock: number,
				_releaseClock: number,
				_targetPlayerAtom: Charm.Atom<Player?>,
				_infoName: string?,
				_handleEmpty: (Ragebot) -> (),
				_stickyTarget: any?,
				_stickyClock: number,
				_lastScanAt: number,
				_scanHadTarget: boolean,
				_aimOffset: Vector3,
				_stickyValid: (Ragebot, any) -> boolean,
				_chargeAimClear: (Ragebot, any, boolean) -> boolean,
				_publishTarget: (Ragebot, string) -> (),
				_clearTarget: (Ragebot) -> (),
				_driveFire: (Ragebot, boolean, boolean, boolean) -> (),
			},
			Ragebot
		))
		& BaseFeature.BaseFeature

	return Ragebot
end)()
