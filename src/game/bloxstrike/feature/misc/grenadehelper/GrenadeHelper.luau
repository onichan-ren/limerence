local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local screenProject = require("@share/screenProject")
local FileController = require("@feature/file/FileController")
local NotifyController = require("@ui/hud/notify/NotifyController")
local clientState = require("@game/bloxstrike/client/clientState")
local ClientController = require("@game/bloxstrike/client/ClientController")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local moveController = require("@game/bloxstrike/client/moveController")
local NetworkController = require("@game/bloxstrike/network/NetworkController")
local grenadePredictionShared = require("@game/bloxstrike/grenade/grenadePredictionShared")
local worldMapSource = require("@game/bloxstrike/feature/visual/world/worldMapSource")
local lineupStore = require("@game/bloxstrike/feature/misc/grenadehelper/lineupStore")
local lineupMarkers = require("@game/bloxstrike/feature/misc/grenadehelper/lineupMarkers")

local peek = Charm.peek

local START_DIST = 12
local NEAR_DIST = 12
local SNAP_DIST = 0.35
local MAX_FLOOR_DELTA = 6
local PIN_EPS_SQ = 0.0004
local GLIDE_RATE = 8
local GLIDE_MAX_SQ = 2.25
local BRAKE_DECEL_INIT = 60
local THROW_DELAY_DEFAULT = 0.25
local MOVING_MIN_SPEED = 3
local RUNUP_DIST = 8
local JUMP_LEAD = 0.1
local OVERRUN_STOP = 8
local SETTLE_SPEED_SQ = 0.09
local JUMP_REQUEST_WINDOW = 0.5
local AIM_EPS_PX = 3
local AIM_LOOSE_PX = 40
local MIN_AIM_RATE = 500
local COARSE_TURN_SCALE = 400
local COARSE_TURN_CAP = 300
local SESSION_TIMEOUT = 8
local MISS_NOTIFY_COOLDOWN = 1.5
local DEFAULT_COLOR = Color3.fromRGB(140, 255, 140)
local TWO_PI = math.pi * 2
local GROUND_RAY = Vector3.new(0, -12, 0)
local GROUND_MISS_DROP = Vector3.new(0, -2.6, 0)
local EYE_OFFSET = Vector3.new(0, 1.5, 0)
local AIM_RAY_DIST = 400

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true
groundParams.IgnoreWater = true

type Session = {
	lineup: lineupStore.Lineup,
	mode: string,
	startedAt: number,
	walkTarget: Vector3,
	runup: boolean,
	runDir: Vector3,
	running: boolean,
	jumped: boolean,
	jumpRequestUntil: number?,
	releaseCalled: boolean,
	prevFlat: Vector3?,
	arrived: boolean,
	settled: boolean,
	pinned: boolean,
	brakeSpeed: number?,
	releaseAt: number?,
	aimed: boolean,
	aimLoose: boolean,
	lastAimX: number?,
	lastErrX: number?,
	touchedMove: boolean,
	throwState: "idle" | "starting" | "thrown",
	retryAt: number,
	cancelled: boolean,
	weapon: any,
	janitor: Janitor.Janitor,
}

local GrenadeHelper = {}
GrenadeHelper.__index = GrenadeHelper
setmetatable(GrenadeHelper, { __index = BaseFeature })

local function keyLabel(value: any): string
	if typeof(value) == "EnumItem" then
		return string.upper((value :: any).Name)
	end
	if type(value) == "table" and typeof(value[1]) == "EnumItem" then
		return string.upper((value[1] :: any).Name)
	end
	return "KEY"
end

local _gameJump: (() -> ())? = nil

local function requestJump(): ()
	setthreadidentity(2)
	if not _gameJump then
		local characterController = ModuleController.GetModule("CharacterController")
		if characterController then
			_gameJump = rawget(characterController, "jump") :: () -> ()
		end
	end
	if _gameJump then
		_gameJump()
	else
		local charObj = ClientController.GetCharacterObject()
		if charObj then
			rawset(charObj, "IsJumpRequested", true)
			charObj:Jump()
		end
	end
	setthreadidentity(8)
end

local function isAirborne(parts: any): boolean
	local charObj = ClientController.GetCharacterObject()
	if charObj and rawget(charObj, "IsJumping") == true then
		return true
	end
	local humanoid = parts.Humanoid :: Humanoid?
	if not humanoid then
		return false
	end
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.Jumping
		or humanoid.FloorMaterial == Enum.Material.Air
end

local function pumpJump(session: any, now: number): ()
	local jumpUntil = session.jumpRequestUntil
	if not jumpUntil then
		return
	end
	if now >= jumpUntil then
		session.jumpRequestUntil = nil
		return
	end
	local charObj = ClientController.GetCharacterObject()
	if charObj and rawget(charObj, "IsJumping") == true then
		session.jumpRequestUntil = nil
		return
	end
	requestJump()
end

local function equipPromptFor(lineup: any): string
	local cached = lineup._equipPrompt
	if not cached then
		cached = `EQUIP {lineup.grenade}`
		lineup._equipPrompt = cached
	end
	return cached
end

function GrenadeHelper.new(link: gameUi.Linker, mountOpts: { editorLink: gameUi.Linker }): GrenadeHelper
	local self = BaseFeature.new() :: any
	setmetatable(self, GrenadeHelper)

	local mainToggle = link:Toggle("grenadeHelper", "Grenade Helper", false):SetTip({
		title = "Grenade Helper",
		body = "Shows your saved grenade lineups in the world. Stand near one, hold the execute key and it walks you onto the spot, lines up the throw and releases the grenade.",
	})
	link:Extra(mainToggle, "grenadeHelperOpts", "Submenu", "Grenade Helper")
	local opts = link:OnKey("grenadeHelperOpts")
	self._opts = opts

	opts:Dropdown("mode", "Mode", { "Legit", "Rage" }, "Legit"):SetTip({
		title = "Mode",
		body = "Legit turns your view onto the lineup angle before throwing. Rage throws at the saved angle instantly without moving your view.",
	})
	local executeKey = opts:Key("executeKey", "Execute", Enum.KeyCode.T, "onHold"):SetTip({
		title = "Execute",
		body = "Hold near a lineup marker to run it. Release to cancel.",
	})
	opts:Slider("showDistance", "Show Distance", 80, 10, 300, 5, nil, "s"):SetTip({
		title = "Show Distance",
		body = "How far away lineup markers stay visible.",
	})
	opts:Slider("aimTime", "Aim Time", 0.5, 0.1, 2, 0.05, nil, "s"):SetTip({
		title = "Aim Time",
		body = "How quickly Legit mode turns onto the lineup angle.",
	})
	opts:Slider("pickFov", "Pick FOV", 150, 20, 400, 5, nil, "px"):SetTip({
		title = "Pick FOV",
		body = "When several lineups share a spot, look at the aim marker you want within this radius of your crosshair and hold the execute key to run that one.",
	})
	opts:Colorpicker("markerColor", "Marker Color", DEFAULT_COLOR, 0):SetTip({
		title = "Marker Color",
		body = "Accent color for lineup markers.",
	})

	local editor = mountOpts.editorLink
	self._editor = editor

	editor:Textbox("lineupName", "Name", "", "Lineup name..."):SetTip({
		title = "Name",
		body = "Name for the next lineup you save. Left empty, the grenade name is used.",
	})
	editor:Dropdown("lineupThrow", "Throw", { "Long Throw", "Short Throw" }, "Long Throw"):SetTip({
		title = "Throw",
		body = "Throw strength saved with the lineup. Long matches left click, short matches right click.",
	})
	local saveKey = editor:Key("saveKey", "Save Bind", Enum.KeyCode.F6, "onPress"):SetTip({
		title = "Save Bind",
		body = "Press while holding a grenade, standing on the spot and aiming the throw to save a lineup instantly.",
	})

	local saveButton = editor:Button("Save Lineup", FileController.Get("image", "disk") :: string)
	local deleteButton = saveButton:Combine("Delete", FileController.Get("image", "delete") :: string)
	deleteButton:RequireConfirm()

	local lineupList = editor
		:List("lineupSelected", "Lineups", {})
		:SetRenamable(true)
		:SetEmptyText("No lineups for this map")
		:SetMaxHeight(180)
		:SetTip({
			title = "Lineups",
			body = "Saved lineups for the current map. Select one to delete it, or rename it directly in the list.",
		})
	self._lineupList = lineupList

	self._link = link
	self._enabled = false
	self._janitor = Janitor.new()
	self._session = nil :: Session?
	self._override = nil :: { direction: Vector3, crouch: boolean, velocity: Vector3? }?
	self._map = worldMapSource.GetCurrent()
	self._lineups = {} :: { lineupStore.Lineup }
	self._equippedName = nil :: string?
	self._holdPrompt = `HOLD {keyLabel(opts:Peek("executeKey"))}`
	self._lastMissNotify = 0
	self._hovered = nil :: lineupStore.Lineup?
	self._aimGain = 1
	self._brakeDecel = BRAKE_DECEL_INIT
	self._throwDelay = { Far = THROW_DELAY_DEFAULT, Near = THROW_DELAY_DEFAULT } :: { [string]: number }

	self._screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = 7,
	}, cloneref(gethui())) :: ScreenGui
	self._markers = lineupMarkers.new(self._screenGui)

	self._promptFor = function(lineup: lineupStore.Lineup, dist: number): string
		if dist > NEAR_DIST then
			return ""
		end
		local session = self._session
		if session and session.lineup == lineup then
			return "EXECUTING"
		end
		if self._equippedName ~= lineup.grenade then
			return equipPromptFor(lineup)
		end
		return self._holdPrompt
	end

	saveButton:OnClick(function(): ()
		self:_saveLineup()
	end)
	deleteButton:OnClick(function(): ()
		self:_deleteSelected()
	end)
	self:Track(saveKey:OnCallback(function(active: boolean): ()
		if active then
			self:_saveLineup()
		end
	end))
	self:Track(lineupList:OnRename(function(oldName: string, newName: string): ()
		local map = self._map
		if not map then
			return
		end
		local trimmed = string.match(newName, "^%s*(.-)%s*$") or ""
		if lineupStore.Rename(map, oldName, trimmed) then
			NotifyController.Push({ title = "Lineup Renamed", subtext = trimmed, icon = "pencil", duration = 2 })
		end
	end))

	self:Track(executeKey:OnCallback(function(active: boolean): ()
		if active then
			self:_beginExecute()
		else
			self:_endExecute()
		end
	end))
	self:Track(opts:Watch("executeKey", function(value: any): ()
		self._holdPrompt = `HOLD {keyLabel(value)}`
	end))
	self:Track(opts:Watch("markerColor", function(): ()
		self:_applyMarkerColor()
	end))

	self:Track(worldMapSource.Changed(function(map: string?): ()
		self._map = map
		self:_refresh()
	end))
	local storeConn = lineupStore.Changed:Connect(function(map: string): ()
		if map == self._map then
			self:_refresh()
		end
	end)
	self:Track(function(): ()
		storeConn:Disconnect()
	end)

	self:Track(link:Get("grenadeHelper"):OnChange(function(value: boolean): ()
		if value then
			self:_enable()
		else
			self:_disable()
		end
	end))

	self:_refresh()
	if link:Peek("grenadeHelper") == true then
		self:_enable()
	end

	return self
end

function GrenadeHelper._applyMarkerColor(self: GrenadeHelper): ()
	local element: any = self._opts:Get("markerColor")
	if element and element._currentColor then
		self._markers:SetColor((element._currentColor :: any):getValue() :: Color3)
	end
end

function GrenadeHelper._refresh(self: GrenadeHelper): ()
	local map = self._map
	local lineups = map and lineupStore.GetForMap(map) or {}
	self._lineups = lineups

	local character = peek(clientState.character)
	if character then
		groundParams.FilterDescendantsInstances = { character }
	end
	for i = 1, #lineups do
		local lineup = lineups[i]
		local anchor = lineup.anchor or lineup.position
		local hit = Workspace:Raycast(anchor, GROUND_RAY, groundParams)
		lineup.markerPos = hit and hit.Position or anchor + GROUND_MISS_DROP

		local eye = lineup.position + EYE_OFFSET
		local aimHit = Workspace:Raycast(eye, lineup.direction * AIM_RAY_DIST, groundParams)
		lineup.aimPos = aimHit and aimHit.Position or eye + lineup.direction * AIM_RAY_DIST
	end

	local items = table.create(#lineups)
	for i = 1, #lineups do
		local lineup = lineups[i]
		items[i] = { id = lineup.name, meta = lineup.grenade }
	end
	self._lineupList:SetItems(items)

	if self._enabled then
		self._markers:SetLineups(lineups)
	end
end

function GrenadeHelper._saveLineup(self: GrenadeHelper): ()
	local map = worldMapSource.GetCurrent()
	if not map then
		NotifyController.Push({ title = "Grenade Helper", subtext = "Not in a map", icon = "trash", duration = 2 })
		return
	end
	local parts = peek(clientState.parts)
	local hrp = parts.HumanoidRootPart :: BasePart?
	if not hrp then
		return
	end

	local grenade = grenadePredictionShared.resolveGrenadeName(peek(loadoutState.currentEquipped))
	if not grenade then
		NotifyController.Push({
			title = "Grenade Helper",
			subtext = "Hold a grenade to save a lineup",
			duration = 2,
		})
		return
	end
	local rawName = self._editor:Peek("lineupName")
	local base = type(rawName) == "string" and string.match(rawName, "^%s*(.-)%s*$") or ""
	if base == "" or base == nil then
		base = grenade
	end

	local humanoid = parts.Humanoid :: Humanoid?
	local name = lineupStore.UniqueName(map, base :: string)
	local velocity = hrp.AssemblyLinearVelocity
	local airborne = isAirborne(parts) or velocity.Y > 2
	lineupStore.Add(map, {
		name = name,
		grenade = grenade,
		throwType = self._editor:Peek("lineupThrow") == "Short Throw" and "Near" or "Far",
		position = hrp.Position,
		direction = Workspace.CurrentCamera.CFrame.LookVector,
		velocity = velocity,
		jump = airborne,
		crouch = humanoid ~= nil and humanoid:GetAttribute("Crouching") == true,
		anchor = Vector3.zero,
	})
	NotifyController.Push({
		title = "Lineup Saved",
		subtext = `{name} · {grenade}`,
		icon = "saved_config",
		duration = 2,
	})
end

function GrenadeHelper._deleteSelected(self: GrenadeHelper): ()
	local map = self._map
	local selected = self._lineupList:GetSelected()
	if not map or type(selected) ~= "string" or selected == "" then
		return
	end
	if lineupStore.Remove(map, selected) then
		NotifyController.Push({ title = "Lineup Deleted", subtext = selected, icon = "trash", duration = 2 })
	end
end

function GrenadeHelper._beginExecute(self: GrenadeHelper): ()
	if not self._enabled or self._session then
		return
	end
	if not peek(clientState.alive) or peek(clientState.isSpectating) then
		return
	end
	local parts = peek(clientState.parts)
	local hrp = parts.HumanoidRootPart :: BasePart?
	if not hrp then
		return
	end

	local lineups = self._lineups
	local origin = hrp.Position
	local best: lineupStore.Lineup? = self._hovered
	if best then
		local delta = (best.anchor or best.position) - origin
		if delta.Magnitude > START_DIST then
			best = nil
		end
	end
	if not best then
		local bestDist = START_DIST
		for i = 1, #lineups do
			local lineup = lineups[i]
			local delta = (lineup.anchor or lineup.position) - origin
			if math.abs(delta.Y) > MAX_FLOOR_DELTA then
				continue
			end
			local flatDist = math.sqrt(delta.X * delta.X + delta.Z * delta.Z)
			if flatDist < bestDist then
				bestDist = flatDist
				best = lineup
			end
		end
	end

	if not best then
		local now = os.clock()
		if now - self._lastMissNotify > MISS_NOTIFY_COOLDOWN then
			self._lastMissNotify = now
			NotifyController.Push({ title = "Grenade Helper", subtext = "No lineup nearby", duration = 1.5 })
		end
		return
	end

	local lineup = best :: lineupStore.Lineup
	local mode = self._opts:Peek("mode") or "Legit"
	local savedVel = lineup.velocity
	local horizSpeedSq = savedVel.X * savedVel.X + savedVel.Z * savedVel.Z
	local moving = horizSpeedSq > MOVING_MIN_SPEED * MOVING_MIN_SPEED
	local runup = moving and mode ~= "Rage"
	local runDir = Vector3.zero
	local walkTarget = lineup.position
	if runup then
		runDir = Vector3.new(savedVel.X, 0, savedVel.Z).Unit
		walkTarget = lineup.position - runDir * RUNUP_DIST
	end

	local session: Session = {
		lineup = lineup,
		mode = mode,
		startedAt = os.clock(),
		walkTarget = walkTarget,
		runup = runup,
		runDir = runDir,
		running = false,
		jumped = false,
		jumpRequestUntil = nil,
		releaseCalled = false,
		prevFlat = nil,
		arrived = false,
		settled = false,
		pinned = false,
		brakeSpeed = nil,
		releaseAt = nil,
		aimed = false,
		aimLoose = false,
		lastAimX = nil,
		lastErrX = nil,
		touchedMove = false,
		throwState = "idle",
		retryAt = 0,
		cancelled = false,
		weapon = nil,
		janitor = Janitor.new(),
	}
	self._session = session

	session.janitor:Add(
		RunService.Stepped:Connect(LPH_NO_VIRTUALIZE(function(_: number, dt: number): ()
			self:_moveTick(dt)
		end)),
		"Disconnect"
	)
	session.janitor:Add(function(): ()
		if session.touchedMove then
			local controller = moveController.getActive()
			if controller then
				controller.moveVector = moveController.realMoveVector(controller)
			end
		end
	end, true)
end

function GrenadeHelper._endExecute(self: GrenadeHelper): ()
	local session = self._session
	if not session then
		return
	end
	self._session = nil
	session.cancelled = true

	local weapon = session.weapon
	if session.throwState == "starting" and weapon and weapon.ThrowStarted and not weapon.ThrowFinished then
		self._override = nil
		task.spawn(function(): ()
			setthreadidentity(8)
			weapon:Cancel()
		end)
	elseif session.throwState ~= "thrown" then
		self._override = nil
	end

	session.janitor:Destroy()
end

GrenadeHelper._moveTick = LPH_NO_VIRTUALIZE(function(self: GrenadeHelper, dt: number): ()
	local session = self._session
	if not session then
		return
	end
	if not peek(clientState.alive) then
		self:_endExecute()
		return
	end
	local parts = peek(clientState.parts)
	local hrp = parts.HumanoidRootPart :: BasePart?
	local controller = moveController.getActive()
	if not hrp or not controller then
		self:_endExecute()
		return
	end

	local lineup = session.lineup
	local pos = hrp.Position

	if session.running then
		session.touchedMove = true
		controller.moveVector = moveController.worldToMoveVector(session.runDir)

		local now = os.clock()
		local toSpot = lineup.position - pos
		local remaining = toSpot.X * session.runDir.X + toSpot.Z * session.runDir.Z
		local vel = hrp.AssemblyLinearVelocity
		local speed = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)

		if lineup.jump and not session.jumped and remaining <= speed * JUMP_LEAD then
			session.jumped = true
			session.jumpRequestUntil = now + JUMP_REQUEST_WINDOW
		end
		pumpJump(session, now)

		local throwDelay = self._throwDelay[lineup.throwType] or THROW_DELAY_DEFAULT
		if
			session.throwState == "starting"
			and not session.releaseCalled
			and (remaining <= speed * throwDelay or remaining < -2)
		then
			self:_releaseThrow(session)
		end
		if remaining < -OVERRUN_STOP then
			self:_endExecute()
		end
		return
	end

	local target = session.walkTarget
	local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)

	if not session.arrived then
		local dist = flat.Magnitude
		local vel = hrp.AssemblyLinearVelocity
		local speed = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)
		local prev = session.prevFlat
		local crossed = prev ~= nil and flat:Dot(prev) < 0
		local brakeDist = (speed * speed) / (2 * self._brakeDecel) + speed * dt
		if dist > SNAP_DIST and not crossed and dist > brakeDist then
			session.prevFlat = flat
			session.touchedMove = true
			session.settled = false
			session.pinned = false
			controller.moveVector = moveController.worldToMoveVector(flat)
			return
		end
		session.arrived = true
		session.brakeSpeed = speed
	end

	session.touchedMove = true
	controller.moveVector = Vector3.zero
	local vel = hrp.AssemblyLinearVelocity
	local speedSq = vel.X * vel.X + vel.Z * vel.Z
	local speed = math.sqrt(speedSq)

	local brakeSpeed = session.brakeSpeed
	if brakeSpeed and brakeSpeed > speed and dt > 0 then
		local decel = (brakeSpeed - speed) / dt
		if decel > 5 then
			self._brakeDecel = math.clamp(self._brakeDecel * 0.7 + decel * 0.3, 10, 300)
		end
	end
	session.brakeSpeed = speed

	session.settled = speedSq < SETTLE_SPEED_SQ
	if not session.settled then
		session.pinned = false
		return
	end

	local flatSq = flat.X * flat.X + flat.Z * flat.Z
	if flatSq > GLIDE_MAX_SQ then
		session.arrived = false
		session.prevFlat = nil
		session.pinned = false
		return
	end
	if flatSq > PIN_EPS_SQ then
		local dist = math.sqrt(flatSq)
		local step = math.min(dist, GLIDE_RATE * dt)
		local nx = pos.X + (flat.X / dist) * step
		local nz = pos.Z + (flat.Z / dist) * step
		hrp.CFrame = CFrame.new(nx, pos.Y, nz) * hrp.CFrame.Rotation
		if dist - step > 0.02 then
			session.pinned = false
			return
		end
	end
	session.pinned = true
end)

GrenadeHelper._aimTick = LPH_NO_VIRTUALIZE(function(self: GrenadeHelper, session: Session, dt: number): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local direction = session.lineup.direction
	local viewport = camera.ViewportSize
	local camCf = camera.CFrame
	local aimPoint = camCf.Position + direction * 1000
	local screenPos = screenProject.project(camera, viewport, aimPoint)
	local aimTime = self._opts:Peek("aimTime") or 0.5
	local closure = 1 - math.exp(-dt * (4.6 / aimTime))

	if screenPos.Z > 0 then
		local dx = screenPos.X - viewport.X * 0.5
		local dy = screenPos.Y - viewport.Y * 0.5
		local absX = math.abs(dx)
		local absY = math.abs(dy)

		local lastApplied = session.lastAimX
		local lastErr = session.lastErrX
		if lastApplied and lastErr and math.abs(lastApplied) >= 2 then
			local ratio = (lastErr - dx) / lastApplied
			if ratio > 0.05 and ratio < 20 then
				self._aimGain = math.clamp(self._aimGain * 0.7 + ratio * 0.3, 0.2, 5)
			end
		end

		session.aimed = absX < AIM_EPS_PX and absY < AIM_EPS_PX
		session.aimLoose = absX < AIM_LOOSE_PX and absY < AIM_LOOSE_PX
		if session.aimed then
			session.lastAimX = nil
			session.lastErrX = nil
			return
		end

		local stepX = dx * closure
		local stepY = dy * closure
		local stepMag = math.max(math.abs(stepX), math.abs(stepY))
		local minStep = MIN_AIM_RATE * dt
		if stepMag < minStep then
			local errMag = math.max(absX, absY)
			local scale = math.min(minStep, errMag) / math.max(stepMag, 1e-4)
			stepX *= scale
			stepY *= scale
		end
		if math.abs(stepX) > absX then
			stepX = dx
		end
		if math.abs(stepY) > absY then
			stepY = dy
		end

		local gain = self._aimGain
		local mouseX = stepX / gain
		local mouseY = stepY / gain
		mousemoverel(mouseX, mouseY)
		session.lastAimX = mouseX
		session.lastErrX = dx
	else
		local look = camCf.LookVector
		local yawTarget = math.atan2(-direction.X, -direction.Z)
		local yawCurrent = math.atan2(-look.X, -look.Z)
		local dyaw = (yawTarget - yawCurrent + math.pi) % TWO_PI - math.pi
		mousemoverel(math.clamp(-dyaw * COARSE_TURN_SCALE, -COARSE_TURN_CAP, COARSE_TURN_CAP) * closure, 0)
		session.aimed = false
		session.aimLoose = false
		session.lastAimX = nil
		session.lastErrX = nil
	end
end)

function GrenadeHelper._releaseThrow(self: GrenadeHelper, session: Session): ()
	if session.releaseCalled then
		return
	end
	session.releaseCalled = true
	local weapon = session.weapon
	task.spawn(function(): ()
		setthreadidentity(8)
		if weapon.ThrowFinished then
			session.throwState = "thrown"
			return
		end
		if not weapon.ThrowStarted then
			weapon:StartThrow()
			task.wait()
		end
		if session.cancelled then
			return
		end
		session.throwState = "thrown"
		session.releaseAt = os.clock()
		weapon:Throw(session.lineup.throwType)
	end)
end

function GrenadeHelper._attemptThrow(self: GrenadeHelper, session: Session, deferRelease: boolean): boolean
	local weapon = peek(loadoutState.currentEquipped) :: any
	if grenadePredictionShared.resolveGrenadeName(weapon) ~= session.lineup.grenade then
		return false
	end

	session.throwState = "starting"
	session.weapon = weapon

	local lineup = session.lineup
	if session.mode == "Rage" then
		local savedVel = lineup.velocity
		local movingSq = savedVel.X * savedVel.X + savedVel.Y * savedVel.Y + savedVel.Z * savedVel.Z
		self._override = {
			direction = lineup.direction,
			crouch = lineup.crouch,
			velocity = movingSq > 1 and savedVel or nil,
		}
	end

	if deferRelease then
		task.spawn(function(): ()
			setthreadidentity(2)
			if not weapon.ThrowStarted and not weapon.ThrowFinished then
				weapon:StartThrow()
			end
		end)
		return true
	end

	self:_releaseThrow(session)
	return true
end

GrenadeHelper._renderTick = LPH_NO_VIRTUALIZE(function(self: GrenadeHelper, dt: number): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local alive = peek(clientState.alive) and not peek(clientState.isSpectating)
	local parts = peek(clientState.parts)
	local hrp = parts.HumanoidRootPart :: BasePart?
	if not alive or not hrp then
		self._hovered = nil
		self._markers:HideAll()
		return
	end

	self._equippedName = grenadePredictionShared.resolveGrenadeName(peek(loadoutState.currentEquipped))

	local session = self._session
	local viewport = camera.ViewportSize
	local project = screenProject.make(camera, viewport)
	local showDist = self._opts:Peek("showDistance") or 80
	local fovPx = self._opts:Peek("pickFov") or 150
	self._hovered = self._markers:Draw(
		project,
		hrp.Position,
		showDist,
		NEAR_DIST,
		session and session.lineup,
		self._promptFor,
		fovPx,
		viewport.X * 0.5,
		viewport.Y * 0.5
	)

	if not session then
		return
	end

	if os.clock() - session.startedAt > SESSION_TIMEOUT then
		self:_endExecute()
		return
	end

	if session.mode ~= "Rage" then
		self:_aimTick(session, dt)
	end

	if session.throwState == "thrown" then
		local weapon = session.weapon
		if weapon and weapon.ThrowFinished then
			self:_endExecute()
		end
		return
	end

	if session.runup then
		if
			not session.running
			and session.arrived
			and session.settled
			and session.pinned
			and (session.aimed or session.aimLoose or session.mode == "Rage")
			and os.clock() >= session.retryAt
			and self:_attemptThrow(session, true)
		then
			session.running = true
		end
		return
	end

	if
		session.throwState == "idle"
		and session.arrived
		and session.settled
		and session.pinned
		and (session.aimed or session.mode == "Rage")
		and os.clock() >= session.retryAt
	then
		self:_attemptThrow(session, false)
	end
end)

function GrenadeHelper._enable(self: GrenadeHelper): ()
	if self._enabled then
		return
	end
	self._enabled = true

	lineupStore.Load()
	self:_applyMarkerColor()
	self:_refresh()

	NetworkController.HookPacket(
		"Inventory",
		"ThrowGrenade",
		LPH_NO_VIRTUALIZE(function(payload: any): boolean
			local session = self._session
			if session and session.releaseAt and type(payload) == "table" then
				local delay = os.clock() - session.releaseAt
				session.releaseAt = nil
				if delay > 0.02 and delay < 1.5 then
					local animation = payload.Animation
					local key = animation == "Near" and "Near" or "Far"
					local current = self._throwDelay[key] or THROW_DELAY_DEFAULT
					self._throwDelay[key] = math.clamp(current * 0.6 + delay * 0.4, 0.05, 1)
				end
			end
			local override = self._override
			if override and type(payload) == "table" then
				self._override = nil
				payload.Direction = override.direction
				payload.IsCrouching = override.crouch
				if override.velocity then
					payload.CharacterVelocity = override.velocity
				end
			end
			return true
		end)
	)
	self._janitor:Add(function(): ()
		NetworkController.UnhookPacket("Inventory", "ThrowGrenade")
	end, true)

	self._janitor:Add(
		RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
			self:_renderTick(dt)
		end)),
		"Disconnect"
	)
end

function GrenadeHelper._disable(self: GrenadeHelper): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self:_endExecute()
	self._override = nil
	self._hovered = nil
	self._janitor:Cleanup()
	self._markers:HideAll()
end

function GrenadeHelper.Destroy(self: GrenadeHelper): ()
	self:_disable()
	self._janitor:Destroy()
	self._markers:Destroy()
	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
	end
	BaseFeature.Destroy(self)
end

export type GrenadeHelper =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_opts: gameUi.Linker,
			_editor: gameUi.Linker,
			_lineupList: any,
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_session: Session?,
			_override: { direction: Vector3, crouch: boolean, velocity: Vector3? }?,
			_map: string?,
			_lineups: { lineupStore.Lineup },
			_equippedName: string?,
			_holdPrompt: string,
			_lastMissNotify: number,
			_hovered: lineupStore.Lineup?,
			_aimGain: number,
			_brakeDecel: number,
			_throwDelay: { [string]: number },
			_screenGui: ScreenGui?,
			_markers: lineupMarkers.Markers,
			_promptFor: (lineup: lineupStore.Lineup, dist: number) -> string,
		},
		GrenadeHelper
	))
	& BaseFeature.BaseFeature

return GrenadeHelper
