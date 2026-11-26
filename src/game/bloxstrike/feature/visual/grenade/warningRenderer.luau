local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")

local FileController = require("@src/feature/file/FileController")
local useShadow = require("@ui/hook/useShadow")
local grenadeState = require("@game/bloxstrike/grenade/grenadeState")
local gamemodeState = require("@game/bloxstrike/gamemodeState")
local clientState = require("@game/bloxstrike/client/clientState")
local clientApi = require("@game/bloxstrike/client/clientApi")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local e = React.createElement
local useBinding = React.useBinding
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom

local at = Charm.atom
local sub = Charm.subscribe
local peek = Charm.peek

local EDGE_PADDING = 40
local MIN_SIZE_RATIO = 0.4
local SIZE_REFERENCE_DISTANCE = 30
local MAX_VISIBLE_DISTANCE = 60
local ONSCREEN_FADE_START_RATIO = 0.6
local HE_OFFSCREEN_MAX_DISTANCE = 38
local FIRE_OFFSCREEN_MAX_DISTANCE = 22
local OFFSCREEN_FADE_START_RATIO = 0.55
local LEAVE_DURATION = 0.4
local OUTLINE = Color3.fromRGB(18, 18, 18)
local HE_MAX_RANGE = 22.3
local HE_FALLOFF = 0.27
local HE_ARMOR_FACTOR = 0.574
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

local estimateHeDamage = LPH_NO_VIRTUALIZE(function(landingPos: Vector3): number
	local parts = peek(clientState.parts)
	local hrp = parts.HumanoidRootPart :: any?
	if not hrp then
		return 0
	end
	local dist = (hrp.Position - landingPos).Magnitude
	local armor = peek(clientState.armor)
	local dmg = HE_FALLOFF * math.max(0, HE_MAX_RANGE - dist) ^ 2 * (armor.kevlar and HE_ARMOR_FACTOR or 1.0)
	return dmg < 0.5 and 0 or math.floor(dmg + 0.5)
end)

local _losParams = RaycastParams.new()
_losParams.FilterType = Enum.RaycastFilterType.Exclude
_losParams.IgnoreWater = true
_losParams.RespectCanCollide = false
local _losDebris: Instance? = nil
local _losFilter: { Instance } = {}

local heBlocked = LPH_NO_VIRTUALIZE(function(landingPos: Vector3, hrpPos: Vector3): boolean
	local disp = hrpPos - landingPos
	if disp.Magnitude < 1e-3 then
		return false
	end
	if not _losDebris or not _losDebris.Parent then
		_losDebris = Workspace:FindFirstChild("Debris")
	end
	local filter = _losFilter
	table.clear(filter)
	local character = peek(clientState.character)
	if character then
		filter[#filter + 1] = character
	end
	if _losDebris then
		filter[#filter + 1] = _losDebris
	end
	_losParams.FilterDescendantsInstances = filter

	local pos = landingPos
	while true do
		local result = Workspace:Raycast(pos, hrpPos - pos, _losParams)
		if not result then
			return false
		end
		local inst = result.Instance
		if inst.CanCollide and inst.Transparency < 1 then
			return true
		end
		filter[#filter + 1] = inst
		_losParams.FilterDescendantsInstances = filter
		pos = result.Position + (hrpPos - result.Position).Unit * 0.01
		if (hrpPos - pos).Magnitude < 0.05 then
			return false
		end
	end
end)

type WarningKind = "he" | "fire"

type WarningSource = {
	position: Vector3,
	startedAt: number,
	duration: number,
	kind: WarningKind,
	weapon: string?,
}

type DisplayEntry = {
	source: WarningSource,
	leaving: boolean,
}

local FIRE_WEAPONS: { [string]: boolean } = {
	["Molotov"] = true,
	["Incendiary Grenade"] = true,
}

local WEAPON_ICONS: { [string]: string } = {
	["HE Grenade"] = "he_grenade",
	["Molotov"] = "molotov",
	["Incendiary Grenade"] = "incendiary",
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
	if not fire.position or not fire.startedAt or not fire.duration then
		return nil
	end
	if fire.isFriendly == true and not gamemodeState.isCompetitive() then
		return nil
	end
	return {
		position = fire.position :: Vector3,
		startedAt = fire.startedAt :: number,
		duration = fire.duration :: number,
		kind = "fire",
		weapon = nil,
	}
end

local function projectileToSource(entry: grenadeState.ProjectileEntry): WarningSource?
	if entry.isFriendly and not gamemodeState.isCompetitive() then
		return nil
	end
	local kind: WarningKind?
	if entry.weapon == "HE Grenade" then
		kind = "he"
	elseif FIRE_WEAPONS[entry.weapon] then
		kind = "fire"
	end
	if not kind then
		return nil
	end
	return {
		position = entry.landingPosition,
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
	local newMap: { [string]: DisplayEntry } = {}
	for k, v in next, now do
		if k ~= id then
			newMap[k] = v
		end
	end
	displayWarnings(newMap)
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
	local newMap: { [string]: DisplayEntry } = {}
	for k, v in next, now do
		if k == id then
			newMap[k] = { source = v.source, leaving = true }
		else
			newMap[k] = v
		end
	end
	displayWarnings(newMap)
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
	local t = expiryTimers[id]
	if t then
		task.cancel(t)
		expiryTimers[id] = nil
	end
end

local reconcile = LPH_NO_VIRTUALIZE(function(activeSources: { [string]: WarningSource }): ()
	local current = peek(displayWarnings)
	local nextDisplay: { [string]: DisplayEntry } = {}

	for id, source in next, activeSources do
		local existing = current[id]
		if existing and existing.leaving then
			nextDisplay[id] = existing
		else
			nextDisplay[id] = { source = source, leaving = false }
			local leaveT = leavingTimers[id]
			if leaveT then
				task.cancel(leaveT)
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
end)

local function collectSources(): { [string]: WarningSource }
	local sources: { [string]: WarningSource } = {}

	for id, fire in next, peek(grenadeState.activeFires) do
		local source = fireToSource(fire)
		if source then
			sources["fire:" .. id] = source
		end
	end

	for id, entry in next, peek(grenadeState.activeProjectiles) do
		local source = projectileToSource(entry)
		if source then
			sources["proj:" .. id] = source
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

type FireWarningProps = {
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
		local duration = source.duration
		local remaining = duration - elapsed
		if remaining < 0 then
			remaining = 0
		end
		local progress = (duration > 0 and remaining / duration or 0)

		setProgress(progress)

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local viewport = camera.ViewportSize
		local vx, vy = viewport.X, viewport.Y
		local maxSize = (vx < vy and vx or vy) / 16

		local firePos = source.position
		local screenPos = camera:WorldToViewportPoint(firePos)
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

		local camPos = camera.CFrame.Position
		local ddx = firePos.X - camPos.X
		local ddy = firePos.Y - camPos.Y
		local ddz = firePos.Z - camPos.Z
		local distance = math.sqrt(ddx * ddx + ddy * ddy + ddz * ddz)
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
			local hp = clientApi.GetHealth()
			local dmg = estimateHeDamage(source.position)
			if dmg > 0 then
				local parts = peek(clientState.parts)
				local hrp = parts.HumanoidRootPart :: any?
				if not hrp or heBlocked(source.position, hrp.Position) then
					dmg = 0
				end
			end
			if hp <= 0 or dmg <= 0 then
				setDamage("")
				damageActiveSpring:setGoal(0)
				damageTextActiveSpring:setGoal(0)
			elseif dmg >= hp then
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

local FireWarning = LPH_JIT_MAX(function(props: FireWarningProps): React.Element<any>?
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
		children[id] = e(FireWarning, {
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
