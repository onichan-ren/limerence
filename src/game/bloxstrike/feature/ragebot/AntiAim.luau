local NetworkController = require("@game/bloxstrike/network/NetworkController")
local ClientController = require("@game/bloxstrike/client/ClientController")
local localLookController = require("@game/bloxstrike/client/localLookController")
local clientState = require("@game/bloxstrike/client/clientState")
local PlayerController = require("@feature/player/PlayerController")
local gamemodeState = require("@game/bloxstrike/gamemodeState")
local inventoryClassifier = require("@game/bloxstrike/feature/inventory/inventoryClassifier")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local FileController = require("@src/feature/file/FileController")
local instances = require("@share/instances")
local freestand = require("@game/universal/feature/combat/antiaim/freestand")
local antiAimApi = require("@game/bloxstrike/feature/ragebot/antiAimApi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local Players = cloneref(game:GetService("Players")) :: Players
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local _cameraInput: any = nil
local getCameraInput = LPH_NO_VIRTUALIZE(function(): any?
	if _cameraInput then
		return _cameraInput
	end
	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	local cameraModule = playerModule and playerModule:FindFirstChild("CameraModule")
	local moduleScript = cameraModule and cameraModule:FindFirstChild("CameraInput")
	if not moduleScript then
		return nil
	end
	setthreadidentity(2)
	local mod = require(moduleScript)
	setthreadidentity(8)
	if type(mod) ~= "table" then
		return nil
	end
	_cameraInput = mod
	return mod
end)

local LOCAL_LOOK_PRIORITY = 100
local PITCH_LIMIT = 0.999
local TAU = math.pi * 2
local LOOK_ANGLE_SEND_INTERVAL = 0.05
local INSTANT_RENDER_NAME = "AntiAimInstantRender"
local BACKSTAB_RANGE = 20
local THREAT_SCAN_INTERVAL = 0.1
local THREAT_SWITCH_RATIO = 1.3
local THREAT_MIN_DIST = 10
local THREAT_LOS_MULT = 3
local ROUND_END_SPIN_RATE = 14
local STEER_SENS = 0.05
local STEER_MAX = 10
local STEER_DEADZONE = 0.15
local INDICATOR_COLOR = Color3.fromRGB(145, 190, 215)
local INDICATOR_SIZE = 22
local INDICATOR_RADIUS = 70
local INDICATOR_STIFFNESS = 520
local INDICATOR_DAMPING = 30
local INDICATOR_FADE_SPEED = 16

local peek = Charm.peek
local sub = Charm.subscribe

local AntiAim = {}
AntiAim.__index = AntiAim

setmetatable(AntiAim, { __index = BaseFeature })

local resolveYaw = LPH_NO_VIRTUALIZE(function(mode: string, cameraYaw: number): number
	if mode == "Back" then
		return cameraYaw + math.pi
	elseif mode == "Left" then
		return cameraYaw + math.pi / 2
	elseif mode == "Right" then
		return cameraYaw - math.pi / 2
	elseif mode == "Random" then
		return cameraYaw + (math.random() - 0.5) * TAU
	end
	return cameraYaw
end)

local resolvePitch = LPH_NO_VIRTUALIZE(function(mode: string): number
	if mode == "Up" then
		return PITCH_LIMIT
	elseif mode == "Down" then
		return -PITCH_LIMIT
	elseif mode == "Random" then
		return (math.random() * 2 - 1) * PITCH_LIMIT
	elseif mode == "View" then
		return Camera.CFrame.LookVector.Y * PITCH_LIMIT
	end
	return 0
end)

local EYE_OFFSET = Vector3.new(0, 1.5, 0)
local FREESTAND_POSITIONS: { Vector3 } = table.create(16)
local FREESTAND_CONTEXTS: { any } = table.create(16)
local FREESTAND_RESET = {}

local FREESTAND_PARAMS = RaycastParams.new()
FREESTAND_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
FREESTAND_PARAMS.IgnoreWater = true
FREESTAND_PARAMS.RespectCanCollide = false
local FREESTAND_FILTER: { Instance } = table.create(2)
local freestandFilterCtx: any = FREESTAND_RESET

local freestandCastClear = LPH_NO_VIRTUALIZE(function(origin: Vector3, target: Vector3, context: any?): boolean
	local toTarget = target - origin
	if toTarget.Magnitude < 1e-3 then
		return true
	end
	if context ~= freestandFilterCtx then
		freestandFilterCtx = context
		table.clear(FREESTAND_FILTER)
		local localCharacter = LocalPlayer.Character
		if localCharacter then
			FREESTAND_FILTER[#FREESTAND_FILTER + 1] = localCharacter
		end
		if context then
			FREESTAND_FILTER[#FREESTAND_FILTER + 1] = context
		end
		FREESTAND_PARAMS.FilterDescendantsInstances = FREESTAND_FILTER
	end
	return Workspace:Raycast(origin, toTarget, FREESTAND_PARAMS) == nil
end)

local isEnemyPlayer = LPH_NO_VIRTUALIZE(function(playerData: any): boolean
	if not peek(playerData.alive) then
		return false
	end
	if peek(playerData.invincible) then
		return false
	end
	if not gamemodeState.isDeathmatch() then
		local localTeam = ClientController.GetTeam()
		local playerTeam = peek(playerData.team)
		if localTeam and localTeam ~= "" and playerTeam == localTeam then
			return false
		end
	end
	return true
end)

function AntiAim.new(link: gameUi.Linker): AntiAim
	local self = BaseFeature.new() :: any
	setmetatable(self, AntiAim)

	self._activeJanitor = nil :: Janitor.Janitor?
	self._desiredYaw = 0
	self._desiredPitch = 0
	self._lastLookAngleSend = 0

	link:Toggle("antiAim", "Anti Aim", false):SetTip({
		title = "Anti Aim",
		body = "Makes your character face a different direction than you are actually looking.",
	})
	link:Dropdown("pitch", "Pitch", { "Up", "Down", "View", "Random" }, "Down"):SetTip({
		title = "Pitch",
		body = "Up/down direction other players see you looking.",
	})
	link:Dropdown("yaw", "Yaw", { "View", "Back", "Left", "Right", "Random", "At Target" }, "Back"):SetTip({
		title = "Yaw",
		body = "Left/right direction other players see, relative to where you look. At Target turns your back toward the most dangerous enemy.",
	})
	local antiAimLink = link:OnKey("antiAim")
	antiAimLink:Submenu("opts", "Anti Aim")
	local optionsLink = antiAimLink:OnKey("opts")
	optionsLink:Toggle("mouseOverride", "Manual Mouse Override", false):SetTip({
		title = "Manual Mouse Override",
		body = "Hold your view still and steer your anti aim with the mouse: push a direction to face that way.",
	})
	local mouseLink = optionsLink:OnKey("mouseOverride")
	mouseLink:Submenu("indicator", "Indicator")
	local indicatorLink = mouseLink:OnKey("indicator")
	indicatorLink:Colorpicker("indicatorColor", "Color", INDICATOR_COLOR, 0):SetTip({
		title = "Color",
		body = "Steering indicator dot color.",
	})
	indicatorLink:Slider("indicatorSize", "Size", INDICATOR_SIZE, 8, 48, 1, nil, "px"):SetTip({
		title = "Size",
		body = "Steering indicator dot size.",
	})
	indicatorLink:Slider("indicatorDistance", "Distance", INDICATOR_RADIUS, 20, 200, 1, nil, "px"):SetTip({
		title = "Distance",
		body = "How far from the center the dot sits.",
	})
	optionsLink:Toggle("roundEnd", "Round End Anti Aim", false):SetTip({
		title = "Round End Anti Aim",
		body = "Applies an anti aim while the round is over.",
	})
	local roundEndLink = optionsLink:OnKey("roundEnd")
	roundEndLink:Submenu("opts", "Round End Anti Aim")
	local roundEndOptionsLink = roundEndLink:OnKey("opts")
	roundEndOptionsLink:Dropdown("type", "Type", { "None", "Spin" }, "Spin"):SetTip({
		title = "Type",
		body = "Spin rotates your character with level pitch. None keeps your normal facing.",
	})
	optionsLink:Toggle("avoidBackstab", "Avoid Backstab", false):SetTip({
		title = "Avoid Backstab",
		body = "Turns to face nearby knife enemies so they can't stab your back.",
	})
	optionsLink:Toggle("freestanding", "Freestanding", false):SetTip({
		title = "Freestanding",
		body = "Automatically faces the left or right side with the most cover from nearby enemies. Falls back to your Yaw setting when neither side is safer.",
	})
	optionsLink:Toggle("instant", "Instant", false):SetTip({
		title = "Instant",
		body = "Turns your character instantly instead of smoothly.",
	})

	self._pitch = link:Get("pitch"):Peek()
	self._yaw = link:Get("yaw"):Peek()
	self._mainEnabled = false
	self._roundEndEnabled = false
	self._roundEndType = roundEndOptionsLink:Get("type"):Peek()
	self._instant = false
	self._avoidBackstab = false
	self._mouseOverride = false
	self._freestanding = false
	self._freestand = freestand.new(freestandCastClear)
	self._threatPlayer = nil :: any
	self._threatScanAt = 0
	self._steerX = 0
	self._steerY = 0
	self._steerYaw = 0
	self._steerMoved = false
	self._faceOffset = 0
	self._pendingDX = 0
	self._pendingDY = 0
	self._camInputDisabled = false
	self._indColorEl = indicatorLink:Get("indicatorColor")
	self._indColor = self._indColorEl:GetColor()
	self._indSize = indicatorLink:Get("indicatorSize"):Peek()
	self._indRadius = indicatorLink:Get("indicatorDistance"):Peek()
	self._indGui = nil :: ScreenGui?
	self._indCircle = nil :: ImageLabel?
	self._indDirX = 0
	self._indDirY = -1
	self._indX = 0
	self._indY = 0
	self._indVelX = 0
	self._indVelY = 0
	self._indAlpha = 0
	self._indClock = nil :: number?
	self._indPrimed = false
	self._allowWrite = false
	self._alignOrientation = nil :: AlignOrientation?

	self:Track(link:Get("antiAim"):OnChange(function(value: boolean): ()
		self._mainEnabled = value
		antiAimApi.SetEnabled(value)
		self:refreshActive()
	end))
	self:Track(antiAimApi.signals.onOverrideChanged:Connect(function(): ()
		self:refreshActive()
	end))
	self:Track(link:Watch("antiAim.opts.roundEnd", function(value: boolean): ()
		self._roundEndEnabled = value
		self:refreshActive()
	end))
	self:Track(roundEndOptionsLink:Get("type"):OnChange(function(value: string): ()
		self._roundEndType = value
		self:refreshActive()
	end))
	self:Track(sub(gamemodeState.gameState, function(): ()
		self:refreshActive()
	end))
	self:Track(link:Get("pitch"):OnChange(function(value: string): ()
		self._pitch = value
	end))
	self:Track(link:Get("yaw"):OnChange(function(value: string): ()
		self._yaw = value
	end))
	self:Track(link:Watch("antiAim.opts.instant", function(value: boolean): ()
		self._instant = value
	end))
	self:Track(link:Watch("antiAim.opts.avoidBackstab", function(value: boolean): ()
		self._avoidBackstab = value
	end))
	self:Track(link:Watch("antiAim.opts.freestanding", function(value: boolean): ()
		self._freestanding = value
		if not value then
			self._freestand:Reset()
		end
	end))
	self:Track(link:Watch("antiAim.opts.mouseOverride", function(value: boolean): ()
		self._mouseOverride = value
		self._steerX = 0
		self._steerY = 0
		self._steerYaw = 0
		self._steerMoved = false
		self._pendingDX = 0
		self._pendingDY = 0
		if value then
			self._indPrimed = false
			self._indClock = nil
			self._indDirX = 0
			self._indDirY = -1
		end
	end))

	self:Track(self._indColorEl:OnColorChange(function(): ()
		self._indColor = self._indColorEl:GetColor()
		if self._indCircle then
			self._indCircle.ImageColor3 = self._indColor
		end
	end))
	self:Track(indicatorLink:Get("indicatorSize"):OnChange(function(value: number): ()
		self._indSize = value
		if self._indCircle then
			self._indCircle.Size = UDim2.fromOffset(value, value)
		end
	end))
	self:Track(indicatorLink:Get("indicatorDistance"):OnChange(function(value: number): ()
		self._indRadius = value
	end))

	self:Track(
		localLookController.RegisterSource("antiAim", LOCAL_LOOK_PRIORITY, function(): localLookController.LookAngles?
			if not self._activeJanitor then
				return nil
			end
			return {
				VerticalLook = self._desiredPitch,
				HorizontalAngle = self._desiredYaw,
			}
		end)
	)

	self._instant = link:Peek("antiAim.opts.instant") == true
	self._avoidBackstab = link:Peek("antiAim.opts.avoidBackstab") == true
	self._freestanding = link:Peek("antiAim.opts.freestanding") == true
	self._mouseOverride = link:Peek("antiAim.opts.mouseOverride") == true
	self._mainEnabled = link:Peek("antiAim") == true
	self._roundEndEnabled = link:Peek("antiAim.opts.roundEnd") == true
	antiAimApi.SetEnabled(self._mainEnabled)
	self:refreshActive()

	return self
end

AntiAim.isRoundEndActive = LPH_NO_VIRTUALIZE(function(self: AntiAim): boolean
	return self._roundEndEnabled and self._roundEndType == "Spin" and gamemodeState.isRoundOver()
end)

function AntiAim.refreshActive(self: AntiAim): ()
	if self._mainEnabled or self:isRoundEndActive() or antiAimApi.HasOverride() then
		self:Enable()
	else
		self:Disable()
	end
end

AntiAim._scanThreat = LPH_NO_VIRTUALIZE(function(self: AntiAim, origin: Vector3): ()
	local eyeOrigin = origin + EYE_OFFSET
	local best: any = nil
	local bestScore = 0
	local currentThreat = self._threatPlayer
	local currentScore = 0
	freestandFilterCtx = FREESTAND_RESET

	for _, playerData in next, PlayerController.GetAll() do
		if not isEnemyPlayer(playerData) then
			continue
		end
		local hrp = peek(playerData.hrp) :: BasePart?
		if not hrp then
			continue
		end
		local head = peek(playerData.parts).Head :: BasePart?
		local eyePart = (head or hrp) :: BasePart
		local enemyEye = head and head.Position or (hrp.Position + EYE_OFFSET)
		local delta = origin - enemyEye
		local dist = delta.Magnitude
		if dist < 1e-3 then
			continue
		end
		local toUs = delta / dist
		local look = eyePart.CFrame.LookVector
		local aimDot = look.X * toUs.X + look.Y * toUs.Y + look.Z * toUs.Z
		local aimScore = 0.25 + 0.75 * (aimDot > 0 and aimDot or 0)
		local score = aimScore / math.max(dist, THREAT_MIN_DIST)
		if freestandCastClear(enemyEye, eyeOrigin, hrp.Parent) then
			score *= THREAT_LOS_MULT
		end
		if playerData == currentThreat then
			currentScore = score
		end
		if score > bestScore then
			bestScore = score
			best = playerData
		end
	end

	if best == nil then
		self._threatPlayer = nil
		return
	end
	if
		currentThreat ~= nil
		and currentScore > 0
		and best ~= currentThreat
		and bestScore < currentScore * THREAT_SWITCH_RATIO
	then
		return
	end
	self._threatPlayer = best
end)

AntiAim.resolveAtTargetYaw = LPH_NO_VIRTUALIZE(function(self: AntiAim): number?
	local localHrp = peek(clientState.parts).HumanoidRootPart :: BasePart?
	if not localHrp then
		self._threatPlayer = nil
		return nil
	end
	local origin = localHrp.Position
	local now = os.clock()
	if now - self._threatScanAt >= THREAT_SCAN_INTERVAL then
		self._threatScanAt = now
		self:_scanThreat(origin)
	end
	local threat = self._threatPlayer
	if not threat then
		return nil
	end
	local hrp = peek(threat.hrp) :: BasePart?
	if not hrp then
		return nil
	end
	local targetPos = hrp.Position
	return math.atan2(targetPos.X - origin.X, targetPos.Z - origin.Z)
end)

AntiAim.resolveFreestandSide = LPH_NO_VIRTUALIZE(function(self: AntiAim, cameraYaw: number): freestand.Side?
	local solver = self._freestand
	local localParts = peek(clientState.parts)
	local localHead = localParts.Head :: BasePart?
	local localHrp = localParts.HumanoidRootPart :: BasePart?
	local eye: Vector3
	if localHead then
		eye = localHead.Position
	elseif localHrp then
		eye = localHrp.Position + EYE_OFFSET
	else
		solver:Reset()
		return nil
	end
	local now = os.clock()
	if solver:ShouldRecompute(now, eye) then
		local count = 0
		for _, playerData in next, PlayerController.GetAll() do
			if not isEnemyPlayer(playerData) then
				continue
			end
			local enemyHead = peek(playerData.parts).Head :: BasePart?
			local enemyHrp = peek(playerData.hrp) :: BasePart?
			local enemyPos: Vector3
			local enemyCharacter: Instance?
			if enemyHead then
				enemyPos = enemyHead.Position
				enemyCharacter = enemyHead.Parent
			elseif enemyHrp then
				enemyPos = enemyHrp.Position + EYE_OFFSET
				enemyCharacter = enemyHrp.Parent
			else
				continue
			end
			count += 1
			FREESTAND_POSITIONS[count] = enemyPos
			FREESTAND_CONTEXTS[count] = enemyCharacter
		end
		freestandFilterCtx = FREESTAND_RESET
		local right = CFrame.fromEulerAnglesYXZ(0, cameraYaw, 0).RightVector
		solver:Compute(now, eye, right, FREESTAND_POSITIONS, FREESTAND_CONTEXTS, count)
	end
	return solver:GetSide()
end)

AntiAim.resolveBackstabYaw = LPH_NO_VIRTUALIZE(function(self: AntiAim): number?
	if not self._avoidBackstab then
		return nil
	end
	local localHrp = peek(clientState.parts).HumanoidRootPart :: BasePart?
	if not localHrp then
		return nil
	end
	local origin = localHrp.Position
	local range = BACKSTAB_RANGE
	local bestDistance = math.huge
	local bestYaw: number? = nil

	for _, playerData in next, PlayerController.GetAll() do
		if not isEnemyPlayer(playerData) then
			continue
		end
		local equipped = peek(playerData.currentEquipped)
		if not equipped or not inventoryClassifier.isMeleeName(equipped.Name) then
			continue
		end
		local hrp = peek(playerData.hrp) :: BasePart?
		if not hrp then
			continue
		end
		local delta = hrp.Position - origin
		local distance = delta.Magnitude
		if distance > range or distance >= bestDistance then
			continue
		end
		bestDistance = distance
		bestYaw = math.atan2(-delta.X, -delta.Z)
	end

	return bestYaw
end)

function AntiAim.setupIndicator(self: AntiAim): ()
	if self._indGui then
		return
	end
	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = 6,
	}, cloneref(gethui())) :: ScreenGui
	self._indGui = screenGui

	self._indCircle = instances.new("ImageLabel", {
		Image = FileController.Get("image", "circle_shadow"),
		ImageColor3 = self._indColor,
		ImageTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(self._indSize, self._indSize),
		ZIndex = 2,
		Visible = false,
	}, screenGui) :: ImageLabel
end

function AntiAim.teardownIndicator(self: AntiAim): ()
	if self._indGui then
		self._indGui:Destroy()
		self._indGui = nil
		self._indCircle = nil
	end
end

AntiAim.updateCameraInput = LPH_NO_VIRTUALIZE(function(self: AntiAim): ()
	local active = self._mainEnabled and self._mouseOverride and localLookController.IsThirdPerson()
	if active == self._camInputDisabled then
		return
	end
	local cam = getCameraInput()
	if not cam then
		return
	end
	cam.setInputEnabled(not active)
	self._camInputDisabled = active
end)

AntiAim.updateIndicator = LPH_NO_VIRTUALIZE(function(self: AntiAim): ()
	setthreadidentity(8)
	local active = self._mainEnabled and self._mouseOverride and localLookController.IsThirdPerson()

	if not active and self._indAlpha <= 0.01 then
		self:teardownIndicator()
		self._indAlpha = 0
		self._indPrimed = false
		self._indClock = nil
		self._indVelX = 0
		self._indVelY = 0
		return
	end

	if not self._indGui then
		self:setupIndicator()
	end

	local now = os.clock()
	local dt = self._indClock and (now - self._indClock) or 0
	self._indClock = now
	if dt > 0.1 then
		dt = 0.1
	end

	local viewport = Camera.ViewportSize
	local centerX = viewport.X * 0.5
	local centerY = viewport.Y * 0.5

	local tx, ty
	if active then
		if self._steerMoved then
			local mag = math.sqrt(self._steerX * self._steerX + self._steerY * self._steerY)
			if mag > STEER_DEADZONE then
				self._indDirX = self._steerX / mag
				self._indDirY = self._steerY / mag
			end
		else
			self._indDirX = -math.sin(self._faceOffset)
			self._indDirY = math.cos(self._faceOffset)
		end
		tx = centerX + self._indDirX * self._indRadius
		ty = centerY - self._indDirY * self._indRadius
	else
		tx, ty = centerX, centerY
	end

	if not self._indPrimed then
		self._indX, self._indY = tx, ty
		self._indVelX, self._indVelY = 0, 0
		self._indPrimed = true
	else
		local ax = (tx - self._indX) * INDICATOR_STIFFNESS - self._indVelX * INDICATOR_DAMPING
		local ay = (ty - self._indY) * INDICATOR_STIFFNESS - self._indVelY * INDICATOR_DAMPING
		self._indVelX += ax * dt
		self._indVelY += ay * dt
		self._indX += self._indVelX * dt
		self._indY += self._indVelY * dt
	end

	local goal = active and 1 or 0
	local t = dt > 0 and (1 - math.exp(-INDICATOR_FADE_SPEED * dt)) or 0
	self._indAlpha += (goal - self._indAlpha) * t

	local circle = self._indCircle :: ImageLabel
	circle.Visible = true
	circle.Position = UDim2.fromOffset(self._indX, self._indY)
	circle.ImageTransparency = 1 - self._indAlpha
end)

function AntiAim.recompute(self: AntiAim): ()
	local _, cameraYaw = Camera.CFrame:ToEulerAnglesYXZ()
	if self:isRoundEndActive() then
		self._pendingDX = 0
		self._pendingDY = 0
		self._desiredYaw = (os.clock() * ROUND_END_SPIN_RATE) % TAU
		self._desiredPitch = 0
	elseif self._mainEnabled then
		local baseYaw: number
		local freestandSide = self._freestanding and self:resolveFreestandSide(cameraYaw) or nil
		if freestandSide == "Left" then
			baseYaw = cameraYaw + math.pi / 2
		elseif freestandSide == "Right" then
			baseYaw = cameraYaw - math.pi / 2
		elseif self._yaw == "At Target" then
			baseYaw = self:resolveAtTargetYaw() or (cameraYaw + math.pi)
		else
			baseYaw = resolveYaw(self._yaw, cameraYaw)
		end
		if self._mouseOverride and localLookController.IsThirdPerson() then
			local dx = self._pendingDX
			local dy = self._pendingDY
			self._pendingDX = 0
			self._pendingDY = 0
			local sx = self._steerX + dx * STEER_SENS
			local sy = self._steerY - dy * STEER_SENS
			local mag = math.sqrt(sx * sx + sy * sy)
			if mag > STEER_MAX then
				local k = STEER_MAX / mag
				sx *= k
				sy *= k
				mag = STEER_MAX
			end
			self._steerX = sx
			self._steerY = sy
			if mag > STEER_DEADZONE then
				self._steerYaw = math.atan2(-sx, sy)
				self._steerMoved = true
			end
			if self._steerMoved then
				self._desiredYaw = cameraYaw + self._steerYaw
			else
				self._desiredYaw = baseYaw
			end
		else
			self._desiredYaw = baseYaw
		end
		self._desiredPitch = resolvePitch(self._pitch)

		local backstabYaw = self:resolveBackstabYaw()
		if backstabYaw then
			self._desiredYaw = backstabYaw
		end
	else
		self._pendingDX = 0
		self._pendingDY = 0
		self._desiredYaw = cameraYaw
		self._desiredPitch = Camera.CFrame.LookVector.Y * PITCH_LIMIT
	end

	local yawOverride = antiAimApi.GetYawOverride()
	if yawOverride then
		self._desiredYaw = yawOverride
	end
	local pitchOverride = antiAimApi.GetPitchOverride()
	if pitchOverride then
		self._desiredPitch = pitchOverride
	end

	self._faceOffset = self._desiredYaw - cameraYaw
	antiAimApi.NotifyAngles(self._desiredYaw, self._desiredPitch)
end

function AntiAim.bindAlignOrientation(self: AntiAim, alignOrientation: AlignOrientation): () -> ()
	local metatable = getrawmetatable(alignOrientation) :: any
	local oldNewIndex = metatable.__newindex

	local newMetatable = {
		__newindex = LPH_NO_VIRTUALIZE(function(target: any, key: string, value: any): ()
			if not checkcaller() and not self._allowWrite then
				if key == "CFrame" then
					return
				elseif key == "Enabled" then
					local caller = getfenv(2) :: any
					local realMath = caller.math
					caller.math = setmetatable({
						abs = function(v: number): number
							return math.abs(v) > 4 and 50001 or realMath.abs(v)
						end,
					}, { __index = realMath })
					task.defer(function(): ()
						caller.math = realMath
					end)
					return oldNewIndex(target, key, true)
				end
			end
			return oldNewIndex(target, key, value)
		end),
	}

	for idx, meta in next, metatable do
		if not newMetatable[idx] then
			newMetatable[idx] = meta
		end
	end

	setrawmetatable(alignOrientation, newMetatable)
	alignOrientation.Enabled = true

	return function(): ()
		setrawmetatable(alignOrientation, metatable)
	end
end

function AntiAim.bindHumanoidRootPart(self: AntiAim, humanoidRootPart: BasePart, parentJanitor: Janitor.Janitor): ()
	local hrpJanitor = Janitor.new()
	parentJanitor:Add(hrpJanitor, "Destroy")

	local function tryBind(child: any): ()
		if child.ClassName ~= "AlignOrientation" then
			return
		end
		if hrpJanitor:Get("AlignOrientation") then
			return
		end
		local restore = self:bindAlignOrientation(child :: AlignOrientation)
		self._alignOrientation = child :: AlignOrientation
		hrpJanitor:Add(
			RunService.Stepped:Connect(LPH_NO_VIRTUALIZE(function(): ()
				self._allowWrite = true
				child.CFrame = CFrame.Angles(0, self._desiredYaw, 0)
				self._allowWrite = false
			end)),
			"Disconnect"
		)
		hrpJanitor:Add(function(): ()
			if self._alignOrientation == child then
				self._alignOrientation = nil
			end
			restore()
		end, true, "AlignOrientation")
	end

	hrpJanitor:Add(humanoidRootPart.ChildAdded:Connect(tryBind), "Disconnect")
	for _, child in next, humanoidRootPart:GetChildren() do
		tryBind(child)
	end
end

function AntiAim.Enable(self: AntiAim): ()
	if self._activeJanitor then
		return
	end
	local janitor = Janitor.new()
	self._activeJanitor = janitor
	antiAimApi.SetActive(true)

	self:recompute()
	self._lastLookAngleSend = 0

	janitor:Add(
		RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
			self:recompute()
			local now = tick()
			if now - self._lastLookAngleSend < LOOK_ANGLE_SEND_INTERVAL then
				return
			end
			self._lastLookAngleSend = now
			setthreadidentity(2)
			NetworkController.SendPacket("Character", "UpdateLookAngle", {
				HorizontalAngle = self._desiredYaw,
				VerticalLook = self._desiredPitch,
			})
			setthreadidentity(8)
		end)),
		"Disconnect"
	)

	NetworkController.HookPacket(
		"Character",
		"UpdateLookAngle",
		LPH_NO_VIRTUALIZE(function()
			return false, {
				HorizontalAngle = self._desiredYaw,
				VerticalLook = self._desiredPitch,
			}
		end)
	)
	janitor:Add(function(): ()
		NetworkController.UnhookPacket("Character", "UpdateLookAngle")
	end, true)

	RunService:BindToRenderStep(
		INSTANT_RENDER_NAME,
		Enum.RenderPriority.Last.Value,
		LPH_NO_VIRTUALIZE(function(): ()
			if not self._instant then
				return
			end

			local character = ClientController.GetCharacterObject()
			if not character then
				return
			end

			local desiredYaw = self._desiredYaw
			character.TargetYRotation = desiredYaw
			character.CurrentYRotation = desiredYaw

			local alignOrientation = self._alignOrientation
			if alignOrientation then
				self._allowWrite = true
				alignOrientation.CFrame = CFrame.Angles(0, desiredYaw, 0)
				alignOrientation.RigidityEnabled = true
				alignOrientation.Enabled = true
				self._allowWrite = false
			end

			local hrp = peek(clientState.parts).HumanoidRootPart :: BasePart?
			if not hrp or not hrp.Parent then
				return
			end

			local _, currentYaw = hrp.CFrame:ToEulerAnglesYXZ()
			local delta = (desiredYaw - currentYaw) % TAU
			if delta > math.pi then
				delta = delta - TAU
			end
			if math.abs(delta) < 0.01 then
				return
			end

			hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, desiredYaw, 0)
		end)
	)
	janitor:Add(function(): ()
		RunService:UnbindFromRenderStep(INSTANT_RENDER_NAME)
	end, true)

	janitor:Add(UserInputService.InputChanged:Connect(LPH_NO_VIRTUALIZE(function(input: InputObject): ()
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if not self._mainEnabled or not self._mouseOverride or not localLookController.IsThirdPerson() then
			return
		end
		self._pendingDX += input.Delta.X
		self._pendingDY += input.Delta.Y
	end)))

	janitor:Add(RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
		self:updateCameraInput()
		self:updateIndicator()
	end)))
	janitor:Add(function(): ()
		if self._camInputDisabled then
			local cam = getCameraInput()
			if cam then
				cam.setInputEnabled(true)
			end
			self._camInputDisabled = false
		end
		self:teardownIndicator()
	end, true)

	local hrpJanitor: Janitor.Janitor? = nil

	local function applyForHumanoidRootPart(humanoidRootPart: BasePart?): ()
		if hrpJanitor then
			hrpJanitor:Destroy()
			hrpJanitor = nil
		end
		if not humanoidRootPart then
			return
		end
		local bindJanitor = Janitor.new()
		hrpJanitor = bindJanitor
		janitor:Add(bindJanitor, "Destroy")
		self:bindHumanoidRootPart(humanoidRootPart, bindJanitor)
	end

	janitor:Add(sub(clientState.parts, function(parts: { [string]: Instance }): ()
		applyForHumanoidRootPart(parts.HumanoidRootPart :: any)
	end))

	local initialParts = peek(clientState.parts)
	applyForHumanoidRootPart(initialParts.HumanoidRootPart :: any)
end

function AntiAim.Disable(self: AntiAim): ()
	local janitor = self._activeJanitor
	if not janitor then
		return
	end
	self._activeJanitor = nil
	antiAimApi.SetActive(false)
	janitor:Destroy()
	self._freestand:Reset()
	self._threatPlayer = nil
end

function AntiAim.Destroy(self: AntiAim): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AntiAim =
	typeof(setmetatable(
		{} :: {
			_pitch: string,
			_yaw: string,
			_instant: boolean,
			_avoidBackstab: boolean,
			_mouseOverride: boolean,
			_freestanding: boolean,
			_freestand: freestand.Freestand,
			_threatPlayer: any,
			_threatScanAt: number,
			_steerX: number,
			_steerY: number,
			_steerYaw: number,
			_steerMoved: boolean,
			_faceOffset: number,
			_pendingDX: number,
			_pendingDY: number,
			_camInputDisabled: boolean,
			_indColorEl: any,
			_indColor: Color3,
			_indSize: number,
			_indRadius: number,
			_indGui: ScreenGui?,
			_indCircle: ImageLabel?,
			_indDirX: number,
			_indDirY: number,
			_indX: number,
			_indY: number,
			_indVelX: number,
			_indVelY: number,
			_indAlpha: number,
			_indClock: number?,
			_indPrimed: boolean,
			_allowWrite: boolean,
			_alignOrientation: AlignOrientation?,
			_desiredYaw: number,
			_desiredPitch: number,
			_lastLookAngleSend: number,
			_mainEnabled: boolean,
			_roundEndEnabled: boolean,
			_roundEndType: string,
			_activeJanitor: Janitor.Janitor?,
		},
		AntiAim
	))
	& BaseFeature.BaseFeature

return AntiAim
