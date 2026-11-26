local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")

local FileController = require("@src/feature/file/FileController")
local useShadow = require("@ui/hook/useShadow")
local grenadeState = require("@game/rivals/grenade/grenadeState")
local clientState = require("@game/rivals/client/clientState")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Players = cloneref(game:GetService("Players")) :: Players
local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService

local LocalPlayer = Players.LocalPlayer

local e = React.createElement
local useBinding = React.useBinding
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom

local at = Charm.atom
local sub = Charm.subscribe
local peek = Charm.peek

local EDGE_PADDING = 40
local MIN_SIZE_RATIO = 0.2
local SIZE_REFERENCE_DISTANCE = 30
local MAX_VISIBLE_DISTANCE = 60
local ONSCREEN_FADE_START_RATIO = 0.6
local HE_OFFSCREEN_MAX_DISTANCE = 38
local FIRE_OFFSCREEN_MAX_DISTANCE = 24
local OFFSCREEN_FADE_START_RATIO = 0.55
local LEAVE_DURATION = 0.4
local OUTLINE = Color3.fromRGB(18, 18, 18)
local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local SHADOW_MULT = Vector2.new(1.22, 1.22)
local BAR_SIZE = UDim2.fromScale(0.46, 0.055)
local BAR_POSITION = UDim2.fromScale(0.5, 0.84)
local BAR_ANCHOR = Vector2.new(0.5, 0.5)
local CORNER_FULL = UDim.new(1, 0)
local CORNER_FRAME = UDim.new(1, 0)
local ICON_BASE_SCALE = 0.52
local ICON_LIFT = 0.16
local ICON_SHRINK = 0.06
local DAMAGE_POSITION = UDim2.fromScale(0.5, 0.7)
local DAMAGE_SIZE = UDim2.fromScale(0.8, 0.2)
local HE_DAMAGE = 75
local HE_RADIUS = 16

local APPEAR_SPRING = {
	dampingRatio = 0.65,
	frequency = 3.5,
	precision = 0.005,
}

local FOLLOW_SPRING = {
	dampingRatio = 1.2,
	frequency = 9,
	precision = 0.5,
}

local SIZE_SPRING = {
	dampingRatio = 1.0,
	frequency = 5,
	precision = 0.5,
}

local DAMAGE_SPRING = {
	dampingRatio = 0.7,
	frequency = 4.0,
	precision = 0.005,
}

local TEXT_FADE_SPRING = {
	dampingRatio = 1.2,
	frequency = 9.0,
	precision = 0.005,
}

local _losParams = RaycastParams.new()
_losParams.FilterType = Enum.RaycastFilterType.Include
_losParams.IgnoreWater = true
_losParams.RespectCanCollide = false

local _wlCache: { Instance } = {}
local _wlFetch = 0
local _wlEnv: any = nil

local function getWhitelist(): { Instance }
	local now = tick()
	local envId = LocalPlayer:GetAttribute("EnvironmentID")
	if envId ~= _wlEnv or now - _wlFetch > 1 then
		_wlFetch = now
		_wlEnv = envId
		_wlCache = CollectionService:GetTagged("RaycastWhitelist" .. (envId or ""))
	end
	return _wlCache
end

local function losBlocked(origin: Vector3, target: Vector3): boolean
	local disp = target - origin
	if disp.Magnitude < 1e-3 then
		return false
	end
	_losParams.FilterDescendantsInstances = getWhitelist()
	return Workspace:Raycast(origin, disp, _losParams) ~= nil
end

local function estimateHeDamage(landingPos: Vector3, hrpPos: Vector3): number
	local dist = (hrpPos - landingPos).Magnitude
	if dist >= HE_RADIUS then
		return 0
	end
	local dmg = HE_DAMAGE * (1 - dist / HE_RADIUS)
	return dmg < 0.5 and 0 or math.floor(dmg + 0.5)
end

type WarningKind = "he" | "fire"

type WarningSource = {
	fallbackPosition: Vector3,
	startedAt: number,
	duration: number,
	kind: WarningKind,
	weapon: string?,
}

type DisplayEntry = {
	source: WarningSource,
	leaving: boolean,
}

local WEAPON_ICONS: { [string]: string } = {
	["Grenade"] = "he_grenade",
	["Molotov"] = "molotov",
}

local function pickIcon(source: WarningSource): string
	local weapon = source.weapon
	if weapon then
		local specific = WEAPON_ICONS[weapon]
		if specific and FileController.Get("image", specific) then
			return specific
		end
	end
	return (source.kind == "he" and "he_grenade" or "flame")
end

local displayWarnings = at({} :: { [string]: DisplayEntry })
local leavingTimers: { [string]: thread } = {}
local expiryTimers: { [string]: thread } = {}

local function fireToSource(fire: grenadeState.FireEntry): WarningSource?
	if not fire.position or not fire.startedAt or not fire.duration or fire.isFriendly == true then
		return nil
	end
	return {
		fallbackPosition = fire.position,
		startedAt = fire.startedAt,
		duration = fire.duration,
		kind = "fire",
		weapon = "Molotov",
	}
end

local function projectileToSource(entry: grenadeState.ProjectileEntry): WarningSource?
	if entry.isFriendly then
		return nil
	end

	local kind: WarningKind?
	if entry.weapon == "Grenade" then
		kind = "he"
	elseif entry.weapon == "Molotov" then
		kind = "fire"
	end

	if not kind then
		return nil
	end

	return {
		fallbackPosition = entry.landingPosition,
		startedAt = entry.startedAt,
		duration = math.max(0, entry.detonateAt - entry.startedAt),
		kind = kind,
		weapon = entry.weapon,
	}
end

local function removeFromDisplay(id: string): ()
	local now = peek(displayWarnings)
	if not now[id] then
		return
	end
	local nextMap: { [string]: DisplayEntry } = {}
	for k, v in next, now do
		if k ~= id then
			nextMap[k] = v
		end
	end
	displayWarnings(nextMap)
end

local function startLeaveTimer(id: string): ()
	if leavingTimers[id] then
		task.cancel(leavingTimers[id])
	end
	leavingTimers[id] = task.delay(LEAVE_DURATION, function()
		leavingTimers[id] = nil
		removeFromDisplay(id)
	end)
end

local function transitionToLeaving(id: string): ()
	local now = peek(displayWarnings)
	local entry = now[id]
	if not entry or entry.leaving then
		return
	end
	local nextMap: { [string]: DisplayEntry } = {}
	for k, v in next, now do
		if k == id then
			nextMap[k] = { source = v.source, leaving = true }
		else
			nextMap[k] = v
		end
	end
	displayWarnings(nextMap)
	startLeaveTimer(id)
end

local function scheduleExpiry(id: string, source: WarningSource): ()
	if expiryTimers[id] then
		task.cancel(expiryTimers[id])
	end
	local elapsed = os.clock() - source.startedAt
	local remaining = math.max(0, source.duration - elapsed)
	expiryTimers[id] = task.delay(remaining, function()
		expiryTimers[id] = nil
		transitionToLeaving(id)
	end)
end

local function cancelExpiry(id: string): ()
	local timer = expiryTimers[id]
	if timer then
		task.cancel(timer)
		expiryTimers[id] = nil
	end
end

local function reconcile(activeSources: { [string]: WarningSource }): ()
	local current = peek(displayWarnings)
	local nextDisplay: { [string]: DisplayEntry } = {}

	for id, source in next, activeSources do
		local existing = current[id]
		if existing and existing.leaving then
			nextDisplay[id] = existing
		else
			nextDisplay[id] = { source = source, leaving = false }
			local leaveTimer = leavingTimers[id]
			if leaveTimer then
				task.cancel(leaveTimer)
				leavingTimers[id] = nil
			end
			scheduleExpiry(id, source)
		end
	end

	for id, entry in next, current do
		if not activeSources[id] then
			if entry.leaving then
				nextDisplay[id] = entry
			else
				nextDisplay[id] = { source = entry.source, leaving = true }
				cancelExpiry(id)
				startLeaveTimer(id)
			end
		end
	end

	displayWarnings(nextDisplay)
end

local function collectSources(): { [string]: WarningSource }
	local sources: { [string]: WarningSource } = {}

	for id, entry in next, peek(grenadeState.activeProjectiles) do
		local source = projectileToSource(entry)
		if source then
			sources["impact:" .. id] = source
		end
	end

	for id, fire in next, peek(grenadeState.activeFires) do
		local source = fireToSource(fire)
		if source then
			sources["impact:" .. id] = source
		end
	end

	return sources
end

sub(grenadeState.activeFires, function(): ()
	reconcile(collectSources())
end)

sub(grenadeState.activeProjectiles, function(): ()
	reconcile(collectSources())
end)

type WarningProps = {
	source: WarningSource,
	color: any,
	bgColor: any,
	image: string,
	leaving: boolean,
}

type StepState = {
	firstStep: boolean,
}

local runWarningStep = LPH_NO_VIRTUALIZE(
	function(
		source: WarningSource,
		stepState: StepState,
		setProgress: (number) -> (),
		setDistance: (number) -> (),
		setDamage: (string) -> (),
		xSpring: any,
		ySpring: any,
		sizeSpring: any,
		damageActiveSpring: any,
		damageTextActiveSpring: any
	): ()
		local elapsed = os.clock() - source.startedAt
		local remaining = source.duration - elapsed
		if remaining < 0 then
			remaining = 0
		end
		local progress = (source.duration > 0 and remaining / source.duration or 0)
		setProgress(progress)

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local camCFrame = camera.CFrame
		local viewport = camera.ViewportSize
		local vx, vy = viewport.X, viewport.Y
		local maxSize = (vx < vy and vx or vy) / 16

		local worldPos = source.fallbackPosition
		local screenPos = camera:WorldToViewportPoint(worldPos)
		local sx = screenPos.X
		local sy = screenPos.Y
		local behind = screenPos.Z <= 0

		local cx = vx * 0.5
		local cy = vy * 0.5

		if behind then
			sx = vx - sx
			sy = vy - sy
		end

		local needsClamp = behind
			or sx < EDGE_PADDING
			or sx > vx - EDGE_PADDING
			or sy < EDGE_PADDING
			or sy > vy - EDGE_PADDING

		if needsClamp then
			local dx = sx - cx
			local dy = sy - cy
			if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then
				dx = 1
				dy = 0
			end
			local angle = math.atan2(dy, dx)
			local cosA = math.cos(angle)
			local sinA = math.sin(angle)
			local maxX = cx - EDGE_PADDING
			local maxY = cy - EDGE_PADDING
			local absCos = math.abs(cosA)
			local absSin = math.abs(sinA)
			local tX = (absCos > 0.001 and maxX / absCos or math.huge)
			local tY = (absSin > 0.001 and maxY / absSin or math.huge)
			local t = (tX < tY and tX or tY)
			sx = cx + t * cosA
			sy = cy + t * sinA
		end

		local distance = (worldPos - camCFrame.Position).Magnitude
		local sizeFactor = math.clamp(SIZE_REFERENCE_DISTANCE / (distance > 10 and distance or 10), MIN_SIZE_RATIO, 1)
		local targetSize = maxSize * sizeFactor

		local distanceFactor: number
		if needsClamp then
			local maxDist = (source.kind == "he" and HE_OFFSCREEN_MAX_DISTANCE or FIRE_OFFSCREEN_MAX_DISTANCE)
			local fadeStart = maxDist * OFFSCREEN_FADE_START_RATIO
			local fadeRange = math.max(maxDist - fadeStart, 1)
			distanceFactor = math.clamp(1 - (distance - fadeStart) / fadeRange, 0, 1)
		else
			local fadeStart = MAX_VISIBLE_DISTANCE * ONSCREEN_FADE_START_RATIO
			local fadeRange = math.max(MAX_VISIBLE_DISTANCE - fadeStart, 1)
			distanceFactor = math.clamp(1 - (distance - fadeStart) / fadeRange, 0, 1)
		end
		setDistance(distanceFactor)

		if stepState.firstStep then
			stepState.firstStep = false
			xSpring:setPosition(sx)
			ySpring:setPosition(sy)
			sizeSpring:setPosition(targetSize)
		elseif not needsClamp then
			xSpring:setPosition(sx)
			ySpring:setPosition(sy)
		end

		xSpring:setGoal(sx)
		ySpring:setGoal(sy)
		sizeSpring:setGoal(targetSize)

		if source.kind == "he" then
			local hrp = peek(clientState.hrp)
			local dmg = 0
			if hrp then
				local hrpPos = (hrp :: any).Position
				dmg = estimateHeDamage(worldPos, hrpPos)
				if dmg > 0 and losBlocked(worldPos, hrpPos) then
					dmg = 0
				end
			end
			local hp = peek(clientState.health)
			if dmg <= 0 then
				setDamage("")
				damageActiveSpring:setGoal(0)
				damageTextActiveSpring:setGoal(0)
			elseif hp > 0 and dmg >= hp then
				setDamage("LETHAL")
				damageActiveSpring:setGoal(1)
				damageTextActiveSpring:setGoal(1)
			else
				setDamage(string.format("%d dmg", dmg))
				damageActiveSpring:setGoal(1)
				damageTextActiveSpring:setGoal(1)
			end
		else
			damageActiveSpring:setGoal(0)
			damageTextActiveSpring:setGoal(0)
		end
	end
)

local Warning = LPH_NO_VIRTUALIZE(function(props: WarningProps): React.Element<any>?
	local source = props.source
	local color = props.color
	local bgColor = props.bgColor
	local image = props.image

	local progressBind, setProgress = useBinding(1)
	local distanceBind, setDistance = useBinding(1)
	local xBind, xSpring = useSpring(0, FOLLOW_SPRING)
	local yBind, ySpring = useSpring(0, FOLLOW_SPRING)
	local sizeBind, sizeSpring = useSpring(0, SIZE_SPRING)
	local appearBind, appearSpring = useSpring(0, APPEAR_SPRING)
	local damageActiveBind, damageActiveSpring = useSpring(0, DAMAGE_SPRING)
	local damageTextActiveBind, damageTextActiveSpring = useSpring(0, TEXT_FADE_SPRING)
	local damageBind, setDamage = useBinding("")

	useEffect(function()
		appearSpring:setGoal(props.leaving and 0 or 1)
	end, { props.leaving })

	useEffect(function()
		local stepState: StepState = { firstStep = true }
		local function step(): ()
			runWarningStep(
				source,
				stepState,
				setProgress,
				setDistance,
				setDamage,
				xSpring,
				ySpring,
				sizeSpring,
				damageActiveSpring,
				damageTextActiveSpring
			)
		end

		step()
		local conn = RunService.PreRender:Connect(step)
		return function()
			conn:Disconnect()
		end
	end, {})

	local positionBind = React.joinBindings({ xBind, yBind }):map(function(values): UDim2
		return UDim2.fromOffset(math.floor(values[1]), math.floor(values[2]))
	end)

	local sizeUdimBind = React.joinBindings({ sizeBind, appearBind }):map(function(values: { number }): UDim2
		local scale = 0.45 + values[2] * 0.55
		local rounded = math.floor(values[1] * scale)
		return UDim2.fromOffset(rounded, rounded)
	end)

	local opacityBind = React.joinBindings({ appearBind, distanceBind }):map(function(values: { number }): number
		return values[1] * values[2]
	end)

	local iconSizeBind = damageActiveBind:map(function(t: number): UDim2
		local scale = ICON_BASE_SCALE - t * ICON_SHRINK
		return UDim2.fromScale(scale, scale)
	end)

	local iconPositionBind = damageActiveBind:map(function(t: number): UDim2
		return UDim2.new(0.5, 0, 0.5 - t * ICON_LIFT, 0)
	end)

	local strokeThicknessBind = sizeBind:map(function(v: number): number
		return math.clamp(math.floor(v * 0.03 + 0.5), 1, 2)
	end)

	local damageTextTransparencyBind = React.joinBindings({ opacityBind, damageTextActiveBind })
		:map(function(values: { number }): number
			return math.clamp(1 - values[1] * values[2], 0, 1)
		end)

	local damageTextSizeBind = sizeBind:map(function(v: number): number
		return math.clamp(math.floor(v * 0.19), 6, 10)
	end)

	local bgTransparencyBind = opacityBind:map(function(v: number): number
		return 0.25 + (1 - v) * 0.75
	end)

	local accentTransparencyBind = opacityBind:map(function(v: number): number
		return math.clamp(1 - v, 0, 1)
	end)

	local surfaceTransparencyBind = opacityBind:map(function(v: number): number
		return 1 - v * 0.1
	end)

	local barBackgroundBind = opacityBind:map(function(v: number): number
		return 0.45 + (1 - v) * 0.55
	end)

	local shadowTransparencyBind = opacityBind:map(function(v: number): number
		return 1 - v * 0.5
	end)

	local barFillSizeBind = progressBind:map(function(p: number): UDim2
		return UDim2.fromScale(math.clamp(p, 0, 1), 1)
	end)

	return e("Frame", {
		AnchorPoint = CENTER_ANCHOR,
		Position = positionBind,
		Size = sizeUdimBind,
		BackgroundColor3 = bgColor,
		BackgroundTransparency = bgTransparencyBind,
		BorderSizePixel = 0,
	}, {
		Shadow = useShadow({
			transparency = shadowTransparencyBind,
			multiplier = SHADOW_MULT,
			zIndex = 0,
		}),
		UICorner = e("UICorner", {
			CornerRadius = CORNER_FRAME,
		}),
		Surface = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = color,
			BackgroundTransparency = surfaceTransparencyBind,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = CORNER_FULL,
			}),
		}),
		UIStroke = e("UIStroke", {
			Color = color,
			Transparency = accentTransparencyBind,
			Thickness = strokeThicknessBind,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Warning = e("ImageLabel", {
			Size = iconSizeBind,
			AnchorPoint = CENTER_ANCHOR,
			Position = iconPositionBind,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = FileController.Get("image", image),
			ImageColor3 = color,
			ImageTransparency = accentTransparencyBind,
			ZIndex = 2,
		}),
		DamageText = e("TextLabel", {
			AnchorPoint = CENTER_ANCHOR,
			Position = DAMAGE_POSITION,
			Size = DAMAGE_SIZE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = damageBind,
			TextColor3 = color,
			TextTransparency = damageTextTransparencyBind,
			TextStrokeColor3 = OUTLINE,
			TextStrokeTransparency = damageTextTransparencyBind,
			FontFace = FileController.Get("font", "semi_bold"),
			TextScaled = false,
			TextSize = damageTextSizeBind,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 3,
		}),
		Bar = e("Frame", {
			Size = BAR_SIZE,
			Position = BAR_POSITION,
			AnchorPoint = BAR_ANCHOR,
			BackgroundColor3 = OUTLINE,
			BackgroundTransparency = barBackgroundBind,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 2,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = CORNER_FULL,
			}),
			Fill = e("Frame", {
				Size = barFillSizeBind,
				BackgroundColor3 = color,
				BackgroundTransparency = accentTransparencyBind,
				BorderSizePixel = 0,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = CORNER_FULL,
				}),
			}),
		}),
	})
end)

type RootProps = {
	enabledLink: any,
	heColorLink: any,
	fireColorLink: any,
	bgColorLink: any,
}

return LPH_NO_VIRTUALIZE(function(props: RootProps): React.Element<any>?
	local enabled = useAt(props.enabledLink._state) :: boolean
	local entries = useAt(displayWarnings) :: { [string]: DisplayEntry }

	if not enabled then
		return nil
	end

	local heColor = props.heColorLink._currentColor
	local fireColor = props.fireColorLink._currentColor
	local bgColor = props.bgColorLink._currentColor

	local children: { [string]: any } = {}
	for id, entry in next, entries do
		local isHe = entry.source.kind == "he"
		children[id] = e(Warning, {
			source = entry.source,
			color = (isHe and heColor or fireColor),
			bgColor = bgColor,
			image = pickIcon(entry.source),
			leaving = entry.leaving,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, children)
end)
