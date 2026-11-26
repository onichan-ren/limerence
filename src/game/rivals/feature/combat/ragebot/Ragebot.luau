local RunService = cloneref(game:GetService("RunService")) :: RunService
local Players = cloneref(game:GetService("Players")) :: Players
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ClientState = require("@game/rivals/client/clientState")
local ModuleController = require("@game/rivals/module/ModuleController")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local PlayerController = require("@feature/player/PlayerController")
local ragebotApi = require("@game/rivals/feature/combat/ragebot/ragebotApi")
local playerState = require("@feature/record/module/playerState")
local projectileGlue = require("@game/rivals/feature/combat/ragebot/projectileGlue")
local mapWhitelist = require("@game/rivals/feature/combat/legitbot/mapWhitelist")
local bulletRedirection = require("@game/rivals/feature/combat/legitbot/bulletRedirection")

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

local HITBOX_PRIORITY: { string } =
	{ "HitboxHead", "Head", "UpperTorso", "Torso", "HitboxBody", "HumanoidRootPart", "LowerTorso" }

local HEAD_HITBOX_PRIORITY: { string } = { "HitboxHead", "Head" }

local function pickHeadHitbox(parts: { [string]: Instance }, fallback: BasePart): BasePart
	for _, name in next, HEAD_HITBOX_PRIORITY do
		local part = parts[name]
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return fallback
end

local MELEE_EXTRA_KEY = utf8.char(2)
local MELEE_ANIM = "\xCC\xB0"
local MELEE_BEHIND_DIST = 4

local SLOT_BY_NAME: { [string]: number } = { Primary = 1, Secondary = 2, Melee = 3 }
local WEAPON_PRIORITY_OPTIONS: { string } = { "Primary", "Secondary", "Melee" }
local ON_EMPTY_MODES: { string } = { "Reload", "Switch" }
local DEFAULT_REMOTE_COOLDOWN = 0.08
local MANIP_RETRY_INTERVAL = 0.1
local REMOTE_COOLDOWN_FRACTION = 0.9
local HIT_JITTER_FRACTION = 0.6
local CAMERA_DATA_KEY = utf8.char(1)
local CAMERA_START_KEY = utf8.char(0)
local CAMERA_END_KEY = utf8.char(1)
local HIT_PART_KEY = utf8.char(2)
local HIT_OFFSET_KEY = utf8.char(3)
local ITEM_OBJECT_ID_KEYS = {
	"ObjectID",
	"ObjectId",
	"objectID",
	"objectId",
	"NetworkID",
	"NetworkId",
	"networkID",
	"networkId",
	"_network_id",
	"ItemID",
	"ItemId",
	"ID",
	"Id",
	"id",
	"_id",
}

type PendingShot = {
	item: any,
	targetPart: BasePart,
	origin: Vector3,
	aimPos: Vector3,
	melee: boolean?,
	manip: boolean?,
	hrp: BasePart?,
	player: Player?,
}

local encodeCFrame = LPH_NO_VIRTUALIZE(function(cf: CFrame): { [string]: number }
	local rx, ry, rz = cf:ToOrientation()
	return {
		[utf8.char(0)] = cf.X,
		[utf8.char(1)] = cf.Y,
		[utf8.char(2)] = cf.Z,
		[utf8.char(3)] = rx,
		[utf8.char(4)] = ry,
		[utf8.char(5)] = rz,
	}
end)

local function getUseItemRemote(): Instance?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		return nil
	end
	local replication = remotes:FindFirstChild("Replication")
	if not replication then
		return nil
	end
	local fighter = replication:FindFirstChild("Fighter")
	if not fighter then
		return nil
	end
	return fighter:FindFirstChild("UseItem")
end

local function getRemoteCooldown(): number
	local info = peek(WeaponController.info)
	if type(info) == "table" and type(info.ShootCooldown) == "number" and info.ShootCooldown > 0 then
		return info.ShootCooldown * REMOTE_COOLDOWN_FRACTION
	end
	return DEFAULT_REMOTE_COOLDOWN
end

local cachedStartShootingEnum: any = nil
local function getStartShootingEnum(): any?
	if cachedStartShootingEnum ~= nil then
		return cachedStartShootingEnum
	end

	local EnumLibrary = ModuleController.GetModule("EnumLibrary")
	if not EnumLibrary then
		return nil
	end

	if not rawget(EnumLibrary, "_enum_builder_complete") then
		return nil
	end

	cachedStartShootingEnum = EnumLibrary:ToEnum("StartShooting", true)
	return cachedStartShootingEnum
end

local visibilityParams = RaycastParams.new()
visibilityParams.FilterType = Enum.RaycastFilterType.Include
visibilityParams.IgnoreWater = true
visibilityParams.RespectCanCollide = false

local isPartVisible = LPH_NO_VIRTUALIZE(function(origin: Vector3, part: BasePart): boolean
	visibilityParams.FilterDescendantsInstances = mapWhitelist.get()
	return Workspace:Raycast(origin, part.Position - origin, visibilityParams) == nil
end)

local pickHitboxPart = LPH_NO_VIRTUALIZE(function(parts: { [string]: Instance }): BasePart?
	for _, name in next, HITBOX_PRIORITY do
		local part = parts[name]
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end)

local voidCFrame = LPH_NO_VIRTUALIZE(function(pos: Vector3): CFrame
	return CFrame.new(math.random(-200e99, 200e99), pos.Y, math.random(-200e99, 200e99))
end)

local jitterHitPoint = LPH_NO_VIRTUALIZE(function(part: BasePart): Vector3
	local half = part.Size * 0.5
	return (part.CFrame * CFrame.new(
		(math.random() * 2 - 1) * half.X * HIT_JITTER_FRACTION,
		(math.random() * 2 - 1) * half.Y * HIT_JITTER_FRACTION,
		(math.random() * 2 - 1) * half.Z * HIT_JITTER_FRACTION
	)).Position
end)

local function ensureAiming(item: any): ()
	if item:Get("IsAiming") then
		return
	end
	item:SetReplicate("IsAiming", true)
end

local Ragebot = {}
Ragebot.__index = Ragebot

setmetatable(Ragebot, { __index = BaseFeature })

function Ragebot.new(link: gameUi.Linker): Ragebot
	local self = BaseFeature.new() :: any
	setmetatable(self, Ragebot)

	link:Toggle("enabled", "Enable Ragebot", false):SetTip({
		title = "Enable Ragebot",
		body = "Auto-fires at the closest enemy that is visible or reachable with shot manipulation. Strafe is optional.",
	})

	link:Options("weapon", "Weapon")
	local weaponLink = link:OnKey("weapon")
	weaponLink
		:PriorityList("weaponPriority", "Weapon Priority", WEAPON_PRIORITY_OPTIONS, WEAPON_PRIORITY_OPTIONS)
		:SetTip({
			title = "Weapon Priority",
			body = "Order ragebot prefers weapons in. Drag a row up; top row is highest priority.",
		})
	weaponLink:Dropdown("onEmpty", "On Empty", ON_EMPTY_MODES, ON_EMPTY_MODES[1]):SetTip({
		title = "On Empty",
		body = "When the active gun runs out of ammo: reload it, or switch to the next weapon.",
	})

	link:Options("strafe", "Strafe")
	local strafeLink = link:OnKey("strafe")
	strafeLink:Toggle("targetStrafe", "Target Strafe", false):SetTip({
		title = "Target Strafe",
		body = "Orbit the target while firing. Off auto-shoots without moving you.",
	})
	strafeLink:Slider("distance", "Strafe Distance", 9, 1, 15, 1, nil, "st"):SetTip({
		title = "Strafe Distance",
		body = "Distance to circle around the target while strafing.",
	})
	strafeLink:Slider("height", "Strafe Height", 0, -15, 15, 1, nil, "st"):SetTip({
		title = "Strafe Height",
		body = "Height the strafe stays at relative to the target. Positive floats above, negative drops below. The orbit bob only adds upward from here.",
	})
	strafeLink:Toggle("voidSpam", "Void Spam", false):SetTip({
		title = "Void Spam",
		body = "While strafing, alternate between the strafe position and a void position.",
	})
	local voidSpamLink = strafeLink:OnKey("voidSpam")
	voidSpamLink:Submenu("opts", "Void Spam")
	local voidSpamOpts = voidSpamLink:OnKey("opts")
	voidSpamOpts:RangeSlider("interval", "Interval", 15, 200, 1, 1000, 10, nil, "ms"):SetTip({
		title = "Interval",
		body = "Each swap waits a random time picked between the low and high values.",
	})

	self._link = link
	self._janitor = Janitor.new()

	self._cache = {
		enabled = false,
		targetStrafe = false,
		strafeDistance = 20,
		strafeHeight = 0,
		voidSpam = false,
		weaponPriority = table.clone(WEAPON_PRIORITY_OPTIONS),
		onEmpty = ON_EMPTY_MODES[1],
	}

	self._voidIntervalElement = voidSpamOpts:Get("interval")
	self._voidSwapInterval = 0.1

	do
		local priority = weaponLink:Peek("weaponPriority")
		if type(priority) == "table" then
			self._cache.weaponPriority = priority
		end
		local onEmpty = weaponLink:Peek("onEmpty")
		if type(onEmpty) == "string" then
			self._cache.onEmpty = onEmpty
		end
		self._cache.targetStrafe = strafeLink:Peek("targetStrafe") == true
	end

	self._strafeAngle = 0
	self._spiralPhase = 0
	self._lastSwapAt = 0
	self._swapOnVoid = false
	self._lastManipFail = 0

	self._steppedConn = nil :: RBXScriptConnection?
	self._desiredCF = nil :: CFrame?
	self._realCF = CFrame.identity
	self._displaced = false
	self._displacedHrp = nil :: BasePart?
	self._pendingShot = nil :: PendingShot?
	self._lastRemoteFire = 0

	self._filterArg = {}
	self._strafeArg = {}

	self._gluedTo = nil :: BasePart?
	self._gluedHrp = nil :: BasePart?

	self._hookedHrp = nil :: BasePart?
	self._hrpOriginalMeta = nil :: any
	self._spoofCFrame = false
	self._spoofedCFrame = CFrame.identity

	self:Track(sub(ClientState.hrp, function(hrp: BasePart?): ()
		if self._cache.enabled then
			self:_rebindHrpHook(hrp)
		end
	end))

	self:Track(link:Get("enabled"):OnChange(function(v: boolean): ()
		self._cache.enabled = v == true
		self:_setActive(self._cache.enabled)
	end))
	self:Track(strafeLink:Get("targetStrafe"):OnChange(function(v: boolean): ()
		self._cache.targetStrafe = v == true
	end))
	self:Track(strafeLink:Get("distance"):OnChange(function(v: number): ()
		self._cache.strafeDistance = v or 0
	end))
	self:Track(strafeLink:Get("height"):OnChange(function(v: number): ()
		self._cache.strafeHeight = v or 0
	end))
	self:Track(strafeLink:Get("voidSpam"):OnChange(function(v: boolean): ()
		self._cache.voidSpam = v == true
	end))

	self:Track(weaponLink:Get("weaponPriority"):OnChange(function(v: any): ()
		if type(v) == "table" then
			self._cache.weaponPriority = v
		end
		if self._cache.enabled and peek(ClientState.alive) then
			self:_manageWeapon()
		end
	end))
	self:Track(weaponLink:Get("onEmpty"):OnChange(function(v: string): ()
		self._cache.onEmpty = v or ON_EMPTY_MODES[1]
	end))

	return self
end

function Ragebot._installHrpHook(self: Ragebot, hrp: BasePart): ()
	if not hrp or self._hookedHrp == hrp then
		return
	end

	self:_uninstallHrpHook()

	local original = getrawmetatable(hrp) :: any
	local oldIndex = original.__index

	local spoofedIndex = LPH_NO_VIRTUALIZE(function(target: any, key: any): any
		if not checkcaller() then
			if self._spoofCFrame then
				if key == "CFrame" then
					return self._spoofedCFrame
				elseif key == "Position" then
					return self._spoofedCFrame.Position
				end
			end
		end
		return oldIndex(target, key)
	end)

	local newMeta: { [string]: any } = {
		__index = spoofedIndex,
	}
	for k, v in next, original do
		if newMeta[k] == nil then
			newMeta[k] = v
		end
	end

	setrawmetatable(hrp, newMeta)
	self._hookedHrp = hrp
	self._hrpOriginalMeta = original
end

function Ragebot._uninstallHrpHook(self: Ragebot): ()
	if self._hookedHrp and self._hrpOriginalMeta then
		setrawmetatable(self._hookedHrp :: any, self._hrpOriginalMeta)
	end
	self._hookedHrp = nil
	self._hrpOriginalMeta = nil
	self._spoofCFrame = false
end

function Ragebot._rebindHrpHook(self: Ragebot, hrp: BasePart?): ()
	self:_uninstallHrpHook()
	if hrp then
		self:_installHrpHook(hrp)
	end
end

function Ragebot._setActive(self: Ragebot, active: boolean): ()
	ragebotApi.SetEnabled(active)
	projectileGlue.setActive(active)

	if active then
		ragebotApi.SetStrafeProvider(function(): CFrame?
			return self._desiredCF
		end)
		local currentHrp = peek(ClientState.hrp)
		if currentHrp then
			self:_installHrpHook(currentHrp)
		end
		if not self._tickConn then
			self._tickConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
				self:_restoreDisplace()
				self:_tick(dt)
			end))
		end
		if not self._steppedConn then
			self._steppedConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
				local displaced = self:_applyDisplace()
				if not self._desiredCF or displaced then
					self:_flushPendingShot()
				end
			end))
		end
	else
		if self._steppedConn then
			self._steppedConn:Disconnect()
			self._steppedConn = nil
		end
		if self._tickConn then
			self._tickConn:Disconnect()
			self._tickConn = nil
		end
		self:_restoreDisplace()
		self:_clearGlue()
		ragebotApi.SetStrafeProvider(nil)
		self._desiredCF = nil
		self._pendingShot = nil
		self:_uninstallHrpHook()
	end
end

function Ragebot._pickTarget(self: Ragebot): (any?, BasePart?, Vector3?)
	local localTeam = peek(ClientState.team)
	local camera = Workspace.CurrentCamera
	local cameraPos = camera and camera.CFrame.Position or Vector3.zero
	local localHead = peek(ClientState.parts).Head :: BasePart?
	local fireOrigin = localHead and localHead.Position or cameraPos

	local bestPlayer: any? = nil
	local bestPart: BasePart? = nil
	local bestDistSq = math.huge
	local bestRank = -1

	local occludedPlayer: any? = nil
	local occludedPart: BasePart? = nil
	local occludedDistSq = math.huge
	local occludedRank = -1

	local forcedRbxPlayer = ragebotApi.GetForcedTarget()
	local needVisible = not self._cache.targetStrafe and not WeaponController.IsMelee()
	local hasFilters = ragebotApi.HasTargetFilters()
	local weapon: any = nil
	if hasFilters then
		local fighter = WeaponController.GetLocalFighter()
		weapon = fighter and fighter.EquippedItem
	end

	for _, playerData in next, PlayerController.GetAll() do
		if not peek(playerData.alive) then
			continue
		end
		if peek(playerData.isInvincible) then
			continue
		end
		local rbxPlayer = playerData:GetPlayer()
		if forcedRbxPlayer then
			if rbxPlayer ~= forcedRbxPlayer then
				continue
			end
		else
			local team = peek(playerData.team)
			if localTeam and localTeam ~= "" and team == localTeam then
				continue
			end
		end
		if not forcedRbxPlayer and rbxPlayer and playerState.ShouldSkip(rbxPlayer.UserId) then
			continue
		end
		local rank = (not forcedRbxPlayer and rbxPlayer) and playerState.GetRank(rbxPlayer.UserId) or 0
		local parts = peek(playerData.parts)
		if not parts or next(parts) == nil then
			continue
		end
		local part = pickHitboxPart(parts)
		if not part then
			continue
		end
		if hasFilters then
			local filterArg = self._filterArg
			filterArg.player = rbxPlayer
			filterArg.character = peek(playerData.character)
			filterArg.weapon = weapon
			if not ragebotApi.RunTargetFilters(filterArg) then
				continue
			end
		end
		local partPos = part.Position
		local dx = partPos.X - cameraPos.X
		local dy = partPos.Y - cameraPos.Y
		local dz = partPos.Z - cameraPos.Z
		local distSq = dx * dx + dy * dy + dz * dz
		if not needVisible or isPartVisible(fireOrigin, part) then
			if rank > bestRank or (rank == bestRank and distSq < bestDistSq) then
				bestDistSq = distSq
				bestRank = rank
				bestPlayer = playerData
				bestPart = part
			end
		elseif rank > occludedRank or (rank == occludedRank and distSq < occludedDistSq) then
			occludedDistSq = distSq
			occludedRank = rank
			occludedPlayer = playerData
			occludedPart = part
		end
	end

	if bestPlayer then
		return bestPlayer, bestPart, nil
	end

	if occludedPart and os.clock() - self._lastManipFail >= MANIP_RETRY_INTERVAL then
		local solved = bulletRedirection.solveShotOrigin(fireOrigin, occludedPart.Position)
		if solved then
			return occludedPlayer, occludedPart, solved
		end
		self._lastManipFail = os.clock()
	end

	return nil, nil, nil
end

function Ragebot._queueShot(
	self: Ragebot,
	item: any,
	targetPart: BasePart,
	origin: Vector3,
	aimPos: Vector3,
	player: Player?,
	manip: boolean?
): ()
	self._pendingShot = {
		item = item,
		targetPart = targetPart,
		origin = origin,
		aimPos = aimPos,
		player = player,
		manip = manip,
	}
end

function Ragebot._flushPendingShot(self: Ragebot): ()
	local shot = self._pendingShot
	if not shot then
		return
	end
	self._pendingShot = nil

	local targetPart = shot.targetPart
	if not targetPart or not targetPart.Parent then
		return
	end

	local player = shot.player
	if player and ragebotApi.HasShotGates() then
		if
			not ragebotApi.RunShotGates({
				player = player,
				part = targetPart,
				damage = 0,
				wallbang = false,
				weapon = shot.item,
				source = "ragebot",
			})
		then
			return
		end
	end

	local fired: boolean
	if shot.melee then
		if not (shot.hrp and shot.hrp.Parent) then
			return
		end
		fired = self:_fireMelee(shot.item, targetPart, shot.hrp)
	else
		fired = self:_fireAt(shot.item, targetPart, shot.origin, shot.aimPos, shot.manip)
	end

	if fired and player then
		ragebotApi.NotifyShotFired({
			player = player,
			part = targetPart,
			damage = 0,
			wallbang = false,
			source = "ragebot",
			hitTarget = true,
		})
	end
end

function Ragebot._fireAt(
	self: Ragebot,
	item: any,
	targetPart: BasePart,
	shootOrigin: Vector3,
	aimPos: Vector3,
	manip: boolean?
): boolean
	local useItem = WeaponController._useItemRemote or getUseItemRemote()
	if not useItem then
		return false
	end
	local startShooting = getStartShootingEnum()
	if not startShooting then
		return false
	end
	local objectId = item:Get("ObjectID")
	if objectId == nil then
		return false
	end
	local jitteredAim = jitterHitPoint(targetPart)
	local hitOffset = targetPart.CFrame:ToObjectSpace(CFrame.new(jitteredAim))
	local headPart = peek(ClientState.parts).Head :: BasePart?
	local origin = manip and shootOrigin or (headPart and headPart.Position) or shootOrigin

	local encodedCamera = encodeCFrame(CFrame.lookAt(origin, jitteredAim))
	local cameraData = {
		[CAMERA_DATA_KEY] = {
			[CAMERA_START_KEY] = encodedCamera,
			[CAMERA_END_KEY] = encodedCamera,
			[HIT_PART_KEY] = targetPart,
			[HIT_OFFSET_KEY] = encodeCFrame(hitOffset),
		},
	}

	useItem:FireServer(objectId, startShooting, cameraData, nil)
	self._lastRemoteFire = os.clock()
	WeaponController.NotifyFired()
	return true
end

function Ragebot._fireMelee(self: Ragebot, item: any, headPart: BasePart, hrp: BasePart): boolean
	local useItem = WeaponController._useItemRemote or getUseItemRemote()
	if not useItem then
		return false
	end
	local action = getStartShootingEnum()
	if not action then
		return false
	end
	local objectId = item:Get("ObjectID")
	if objectId == nil then
		return false
	end

	local aimPos = jitterHitPoint(headPart)
	local behindPos = aimPos - hrp.CFrame.LookVector * MELEE_BEHIND_DIST
	local cameraCF = CFrame.lookAt(behindPos, aimPos)
	local hitOffset = headPart.CFrame:ToObjectSpace(CFrame.new(aimPos))
	local cameraData = {
		[CAMERA_DATA_KEY] = {
			[CAMERA_START_KEY] = encodeCFrame(cameraCF),
			[CAMERA_END_KEY] = encodeCFrame(cameraCF),
			[HIT_PART_KEY] = headPart,
			[HIT_OFFSET_KEY] = encodeCFrame(hitOffset),
		},
		[MELEE_EXTRA_KEY] = MELEE_ANIM,
	}

	useItem:FireServer(objectId, action, cameraData, nil)
	self._lastRemoteFire = os.clock()
	WeaponController.NotifyFired()
	return true
end

Ragebot._applyDisplace = LPH_NO_VIRTUALIZE(function(self: Ragebot): boolean
	if self._displaced then
		return true
	end
	local cf = self._desiredCF
	if not cf then
		return false
	end
	local hrp = peek(ClientState.parts).HumanoidRootPart :: BasePart?
	if not hrp then
		return false
	end
	self._realCF = hrp.CFrame
	self._spoofedCFrame = self._realCF
	self._spoofCFrame = true
	hrp.CFrame = cf
	self._displacedHrp = hrp
	self._displaced = true
	return true
end)

Ragebot._restoreDisplace = LPH_NO_VIRTUALIZE(function(self: Ragebot): ()
	if not self._displaced then
		return
	end
	local hrp = self._displacedHrp
	if hrp and hrp.Parent then
		hrp.CFrame = self._realCF
	end
	self._spoofCFrame = false
	self._displaced = false
	self._displacedHrp = nil
end)

function Ragebot._applyGlue(self: Ragebot, targetHrp: BasePart): ()
	local ourHrp = peek(ClientState.parts).HumanoidRootPart :: BasePart?
	if not ourHrp or not targetHrp then
		return
	end
	if self._gluedTo == targetHrp and self._gluedHrp == ourHrp then
		return
	end
	sethiddenproperty(ourHrp, "PhysicsRepRootPart", targetHrp)
	self._gluedTo = targetHrp
	self._gluedHrp = ourHrp
end

function Ragebot._clearGlue(self: Ragebot): ()
	if not self._gluedTo then
		return
	end
	local ourHrp = self._gluedHrp
	if ourHrp and ourHrp.Parent then
		sethiddenproperty(ourHrp, "PhysicsRepRootPart", ourHrp)
	end
	self._gluedTo = nil
	self._gluedHrp = nil
end

local strafeLookAt = LPH_NO_VIRTUALIZE(function(pos: Vector3, targetPos: Vector3): CFrame
	return CFrame.lookAt(pos, Vector3.new(targetPos.X, pos.Y, targetPos.Z))
end)

Ragebot._computeStrafeCFrame = LPH_NO_VIRTUALIZE(
	function(self: Ragebot, hrp: BasePart, targetPos: Vector3, dt: number): CFrame
		self._strafeAngle = (self._strafeAngle + dt * 8) % (math.pi * 2)
		self._spiralPhase = (self._spiralPhase + dt * 3) % (math.pi * 2)
		local distance = self._cache.strafeDistance
		local angle = self._strafeAngle
		local phase = self._spiralPhase
		local radius = distance * (0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase)))
		local bob = math.abs(math.sin(phase * 1.5)) * distance * 0.25
		local height = self._cache.strafeHeight + bob
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local pos = Vector3.new(targetPos.X + offset.X, targetPos.Y + height, targetPos.Z + offset.Z)
		return strafeLookAt(pos, targetPos)
	end
)

function Ragebot._randomVoidInterval(self: Ragebot): number
	local element = self._voidIntervalElement
	if element then
		local value = element:GetRandomValue()
		if type(value) == "number" then
			return math.max(value, 0) / 1000
		end
	end
	return 0.1
end

Ragebot._shouldVoidThisTick = LPH_NO_VIRTUALIZE(function(self: Ragebot): boolean
	if not self._cache.voidSpam then
		return false
	end
	local now = os.clock()
	if now - self._lastSwapAt >= self._voidSwapInterval then
		self._lastSwapAt = now
		self._swapOnVoid = not self._swapOnVoid
		self._voidSwapInterval = self:_randomVoidInterval()
	end
	return self._swapOnVoid
end)

Ragebot._getLoadout = function(
	self: Ragebot
): { [number]: { item: any, isGun: boolean, ammo: number, reserve: number } }
	local out: { [number]: { item: any, isGun: boolean, ammo: number, reserve: number } } = {}
	local fighter = WeaponController.GetLocalFighter()
	if not fighter then
		return out
	end
	local items = rawget(fighter, "Items")
	if not items then
		return out
	end
	local itemLibrary = ModuleController.GetModule("ItemLibrary")
	local libItems = itemLibrary and rawget(itemLibrary, "Items")
	if not libItems then
		return out
	end

	for _, item in next, items do
		local entry = libItems[item.Name]
		local slot = entry and SLOT_BY_NAME[entry.Class]
		if not slot then
			continue
		end
		local isGun = entry.Type == "Gun"
		local ammo = 0
		local reserve = 0
		if isGun then
			ammo = rawget(item, "Ammo")
			if ammo == nil then
				ammo = item:Get("Ammo")
			end
			ammo = ammo or 0
			reserve = rawget(item, "AmmoReserve")
			if reserve == nil then
				reserve = item:Get("AmmoReserve")
			end
			reserve = reserve or 0
		end
		out[slot] = { item = item, isGun = isGun, ammo = ammo, reserve = reserve }
	end

	return out
end

Ragebot._manageWeapon = function(self: Ragebot): ()
	local order = self._cache.weaponPriority
	if type(order) ~= "table" or #order == 0 then
		return
	end

	local loadout = self:_getLoadout()
	if next(loadout) == nil then
		return
	end

	local switchOnEmpty = self._cache.onEmpty == "Switch"
	local desiredSlot: number? = nil
	local reloadDesired = false

	for _, name in next, order do
		local slot = SLOT_BY_NAME[name]
		local entry = slot and loadout[slot]
		if not entry then
			continue
		end
		if entry.isGun and entry.ammo <= 0 then
			if switchOnEmpty or entry.reserve <= 0 then
				continue
			end
			desiredSlot = slot
			reloadDesired = true
			break
		end
		desiredSlot = slot
		break
	end

	if not desiredSlot then
		return
	end

	if WeaponController.GetEquippedSlot() ~= desiredSlot then
		WeaponController.EquipSlot(desiredSlot)
		return
	end

	if reloadDesired and not peek(WeaponController.reloading) and not WeaponController.HasAmmo() then
		WeaponController.Reload()
	end
end

function Ragebot._handleMelee(self: Ragebot, targetData: any, targetPart: BasePart): ()
	local liveHrp = peek(targetData.hrp) :: BasePart?
	if not liveHrp then
		self._pendingShot = nil
		self._desiredCF = nil
		return
	end

	local fighter = WeaponController.GetLocalFighter()
	local item = fighter and fighter.EquippedItem
	if not item then
		self._pendingShot = nil
		return
	end

	local parts = peek(targetData.parts)
	local headPart = (parts and pickHeadHitbox(parts, targetPart)) or targetPart

	local center = liveHrp.CFrame.Position
	local behind = center - liveHrp.CFrame.LookVector * MELEE_BEHIND_DIST
	self._desiredCF = CFrame.lookAt(behind, center)

	if os.clock() - self._lastRemoteFire >= getRemoteCooldown() then
		self._pendingShot = {
			item = item,
			targetPart = headPart,
			origin = behind,
			aimPos = headPart.Position,
			melee = true,
			hrp = liveHrp,
			player = targetData:GetPlayer(),
		}
	else
		self._pendingShot = nil
	end
end

function Ragebot._tick(self: Ragebot, dt: number): ()
	local cache = self._cache
	self._desiredCF = nil
	if not cache.enabled then
		return
	end

	if peek(ClientState.isFrozen) then
		return
	end

	local character = LocalPlayer.Character
	if not character then
		return
	end
	local hrp = peek(ClientState.parts).HumanoidRootPart :: BasePart?
	if not hrp then
		return
	end

	if not peek(ClientState.alive) then
		return
	end

	local fighter = WeaponController.GetLocalFighter()
	if not fighter then
		return
	end
	local item = fighter.EquippedItem
	if not item then
		return
	end

	local targetPlayer, targetPart, manipOrigin = self:_pickTarget()
	local hasTarget = targetPlayer ~= nil and targetPart ~= nil

	self:_manageWeapon()

	if peek(WeaponController.reloading) then
		self._pendingShot = nil
		self:_clearGlue()
		if cache.targetStrafe then
			self._desiredCF = voidCFrame(hrp.Position)
		end
		return
	end

	if hasTarget and WeaponController.IsMelee() then
		self:_handleMelee(targetPlayer, targetPart :: BasePart)
		return
	end

	local canShoot = WeaponController.CanShoot()
	local canFire = os.clock() - self._lastRemoteFire >= getRemoteCooldown()

	if hasTarget and canShoot then
		ensureAiming(item)
		local targetPart_ = targetPart :: BasePart
		local targetData = targetPlayer :: any
		local liveHrp = peek(targetData.hrp) :: BasePart?

		projectileGlue.setTarget(peek(targetData.parts).HitboxHead)

		local usingProjectiles = false and WeaponController.IsProjectile() or false

		local strafeCenter: Vector3? = nil
		local aimPos: Vector3? = nil
		if liveHrp then
			strafeCenter = liveHrp.Position
		end
		aimPos = targetPart_.Position

		local shotOrigin: Vector3? = nil
		if cache.targetStrafe and cache.strafeDistance > 0 and strafeCenter then
			local useVoid = self:_shouldVoidThisTick()
			local serverCF: CFrame
			if useVoid or usingProjectiles then
				self:_clearGlue()
				serverCF = voidCFrame(hrp.Position)
			else
				if liveHrp and not usingProjectiles then
					self:_applyGlue(liveHrp)
				elseif usingProjectiles then
					self:_clearGlue()
				end
				serverCF = self:_computeStrafeCFrame(hrp, strafeCenter, dt)
			end
			if ragebotApi.HasStrafeOverrides() then
				local strafeArg = self._strafeArg
				strafeArg.cframe = serverCF
				strafeArg.position = serverCF.Position
				strafeArg.targetPosition = strafeCenter
				strafeArg.origin = hrp.Position
				strafeArg.isVoid = useVoid
				strafeArg.distance = cache.strafeDistance
				strafeArg.height = cache.strafeHeight
				strafeArg.dt = dt
				strafeArg.angle = self._strafeAngle
				strafeArg.player = targetData:GetPlayer()
				strafeArg.time = os.clock()
				serverCF = ragebotApi.RunStrafeOverride(strafeArg, serverCF)
			end
			self._desiredCF = serverCF
			shotOrigin = serverCF.Position
		else
			self:_clearGlue()
			if manipOrigin then
				shotOrigin = manipOrigin
			else
				local cam = Workspace.CurrentCamera
				if cam then
					shotOrigin = cam.CFrame.Position
				end
			end
		end

		if canFire and shotOrigin and aimPos then
			self:_queueShot(item, targetPart_, shotOrigin, aimPos, targetData:GetPlayer(), manipOrigin ~= nil)
		else
			self._pendingShot = nil
		end
	elseif not canShoot then
		self._pendingShot = nil
		self:_clearGlue()
		if cache.targetStrafe then
			self._desiredCF = voidCFrame(hrp.Position)
		end
	else
		self._pendingShot = nil
		self:_clearGlue()
	end
end

function Ragebot.Destroy(self: Ragebot): ()
	self:_setActive(false)
	self:_uninstallHrpHook()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type Ragebot =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_janitor: Janitor.Janitor,
			_cache: {
				enabled: boolean,
				targetStrafe: boolean,
				strafeDistance: number,
				strafeHeight: number,
				voidSpam: boolean,
				weaponPriority: { string },
				onEmpty: string,
			},
			_voidIntervalElement: any,
			_voidSwapInterval: number,
			_strafeAngle: number,
			_spiralPhase: number,
			_lastSwapAt: number,
			_swapOnVoid: boolean,
			_lastManipFail: number,
			_tickConn: RBXScriptConnection?,
			_steppedConn: RBXScriptConnection?,
			_desiredCF: CFrame?,
			_realCF: CFrame,
			_displaced: boolean,
			_displacedHrp: BasePart?,
			_pendingShot: PendingShot?,
			_lastRemoteFire: number,
			_gluedTo: BasePart?,
			_gluedHrp: BasePart?,
			_hookedHrp: BasePart?,
			_hrpOriginalMeta: any,
			_spoofCFrame: boolean,
			_spoofedCFrame: CFrame,
		},
		Ragebot
	))
	& BaseFeature.BaseFeature

return Ragebot
