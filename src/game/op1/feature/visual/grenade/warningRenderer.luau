local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")

local useShadow = require("@ui/hook/useShadow")
local GrenadeController = require("@game/op1/grenade/GrenadeController")
local clientState = require("@game/op1/client/clientState")

local Workspace = cloneref(game:GetService("Workspace"))
local RunService = cloneref(game:GetService("RunService"))

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
local MAX_VISIBLE_DISTANCE = 70
local ONSCREEN_FADE_START_RATIO = 0.65
local OFFSCREEN_MAX_DISTANCE = 45
local OFFSCREEN_FADE_START_RATIO = 0.6
local LEAVE_DURATION = 0.4
local OUTLINE = Color3.fromRGB(18, 18, 18)
local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local SHADOW_MULT = Vector2.new(1.22, 1.22)
local BAR_SIZE = UDim2.fromScale(0.46, 0.055)
local BAR_POSITION = UDim2.fromScale(0.5, 0.84)
local BAR_ANCHOR = Vector2.new(0.5, 0.5)
local CORNER_FULL = UDim.new(1, 0)
local ICON_SCALE = 0.52
local SLOW_INTERVAL = 8

local APPEAR_SPRING = { dampingRatio = 0.65, frequency = 3.5, precision = 0.005 }
local FOLLOW_SPRING = { dampingRatio = 1.2, frequency = 9, precision = 0.5 }
local SIZE_SPRING = { dampingRatio = 1.0, frequency = 5, precision = 0.5 }

type WarningSource = {
	root: BasePart,
	startedAt: number,
	duration: number,
	image: string,
	entry: any,
}

type DisplayEntry = {
	source: WarningSource,
	leaving: boolean,
}

local displayWarnings = at({} :: { [string]: DisplayEntry })
local leavingTimers: { [string]: thread } = {}

local function commitDisplay(map: { [string]: DisplayEntry }): ()
	setthreadidentity(8)
	displayWarnings(map)
end

local function collectSources(): { [string]: WarningSource }
	local sources: { [string]: WarningSource } = {}

	for id, entry in next, peek(GrenadeController.active) do
		local root = entry.root
		if root and root.Parent then
			sources["g:" .. id] = {
				root = root,
				startedAt = entry.startedAt,
				duration = entry.profile.fuse,
				image = entry.profile.image,
				entry = entry,
			}
		end
	end

	return sources
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
	commitDisplay(newMap)
end

local function startLeaveTimer(id: string): ()
	if leavingTimers[id] then
		task.cancel(leavingTimers[id])
	end
	leavingTimers[id] = task.delay(LEAVE_DURATION, function(): ()
		leavingTimers[id] = nil
		removeFromDisplay(id)
	end)
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
		end
	end

	for id, entry in next, current do
		if not activeSources[id] then
			if entry.leaving then
				nextDisplay[id] = entry
			else
				nextDisplay[id] = { source = entry.source, leaving = true }
				startLeaveTimer(id)
			end
		end
	end

	commitDisplay(nextDisplay)
end)

sub(GrenadeController.active, function(): ()
	reconcile(collectSources())
end)

type WarningProps = {
	source: WarningSource,
	enemyColorLink: any,
	friendlyColorLink: any,
	localColorLink: any,
	bgColor: any,
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
		xSpring: any,
		ySpring: any,
		sizeSpring: any
	): ()
		local root = source.root
		if not root or not root.Parent then
			setDistance(0)
			return
		end

		local charObject = peek(clientState.charObject)
		local values = charObject and charObject.values
		if values then
			local viewmodels = values.viewmodels
			local items = values.Items
			if (viewmodels and root:IsDescendantOf(viewmodels)) or (typeof(items) == "Instance" and root:IsDescendantOf(items)) then
				setDistance(0)
				return
			end
		end

		local duration = source.duration
		if duration > 0 then
			local remaining = duration - (os.clock() - source.startedAt)
			setProgress(math.clamp(remaining / duration, 0, 1))
		else
			setProgress(0)
		end

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local viewport = camera.ViewportSize
		local vx, vy = viewport.X, viewport.Y
		local maxSize = (vx < vy and vx or vy) / 16

		local worldPos = root.Position
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

		local camPos = camera.CFrame.Position
		local distance = (worldPos - camPos).Magnitude
		local sizeFactor = math.clamp(SIZE_REFERENCE_DISTANCE / (distance > 10 and distance or 10), MIN_SIZE_RATIO, 1)
		local targetSize = maxSize * sizeFactor

		local distanceFactor: number
		if needsClamp then
			local fadeStart = OFFSCREEN_MAX_DISTANCE * OFFSCREEN_FADE_START_RATIO
			local fadeRange = math.max(OFFSCREEN_MAX_DISTANCE - fadeStart, 1)
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
	end
)

local Warning = LPH_JIT_MAX(function(props: WarningProps): React.Element<any>?
	local source = props.source
	local bgColor = props.bgColor

	local enemyLink = props.enemyColorLink
	local friendlyLink = props.friendlyColorLink
	local localLink = props.localColorLink

	local colorBind, setColor = useBinding((enemyLink._currentColor :: any):getValue() :: Color3)
	local progressBind, setProgress = useBinding(1)
	local distanceBind, setDistance = useBinding(1)
	local xBind, xSpring = useSpring(0, FOLLOW_SPRING)
	local yBind, ySpring = useSpring(0, FOLLOW_SPRING)
	local sizeBind, sizeSpring = useSpring(0, SIZE_SPRING)
	local appearBind, appearSpring = useSpring(0, APPEAR_SPRING)

	useEffect(function()
		appearSpring:setGoal(props.leaving and 0 or 1)
	end, { props.leaving })

	useEffect(function()
		local stepState: StepState = { firstStep = true }
		local frame = SLOW_INTERVAL
		local function step(): ()
			runWarningStep(source, stepState, setProgress, setDistance, xSpring, ySpring, sizeSpring)
			frame += 1
			if frame >= SLOW_INTERVAL then
				frame = 0
				local relation = GrenadeController.GetRelation(source.entry)
				local link = (relation == "local" and localLink)
					or (relation == "friendly" and friendlyLink)
					or enemyLink
				setColor((link._currentColor :: any):getValue() :: Color3)
			end
		end

		step()
		local conn = RunService.PreRender:Connect(step)
		return function(): ()
			conn:Disconnect()
		end
	end, {})

	local positionBind = React.joinBindings({ xBind, yBind }):map(function(values: { number }): UDim2
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

	local strokeThicknessBind = sizeBind:map(function(v: number): number
		return math.clamp(math.floor(v * 0.03 + 0.5), 1, 2)
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

	local children: { [string]: any } = {
		Shadow = useShadow({
			transparency = shadowTransparencyBind,
			multiplier = SHADOW_MULT,
			zIndex = 0,
		}),
		UICorner = e("UICorner", { CornerRadius = CORNER_FULL }),
		Surface = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = colorBind,
			BackgroundTransparency = surfaceTransparencyBind,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			UICorner = e("UICorner", { CornerRadius = CORNER_FULL }),
		}),
		UIStroke = e("UIStroke", {
			Color = colorBind,
			Transparency = accentTransparencyBind,
			Thickness = strokeThicknessBind,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Icon = e("ImageLabel", {
			Size = UDim2.fromScale(ICON_SCALE, ICON_SCALE),
			AnchorPoint = CENTER_ANCHOR,
			Position = UDim2.fromScale(0.5, 0.46),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = source.image,
			ImageColor3 = colorBind,
			ImageTransparency = accentTransparencyBind,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
		}),
	}

	if source.duration > 0 then
		children.Bar = e("Frame", {
			Size = BAR_SIZE,
			Position = BAR_POSITION,
			AnchorPoint = BAR_ANCHOR,
			BackgroundColor3 = OUTLINE,
			BackgroundTransparency = barBackgroundBind,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 2,
		}, {
			UICorner = e("UICorner", { CornerRadius = CORNER_FULL }),
			Fill = e("Frame", {
				Size = barFillSizeBind,
				BackgroundColor3 = colorBind,
				BackgroundTransparency = accentTransparencyBind,
				BorderSizePixel = 0,
			}, {
				UICorner = e("UICorner", { CornerRadius = CORNER_FULL }),
			}),
		})
	end

	return e("Frame", {
		AnchorPoint = CENTER_ANCHOR,
		Position = positionBind,
		Size = sizeUdimBind,
		BackgroundColor3 = bgColor,
		BackgroundTransparency = bgTransparencyBind,
		BorderSizePixel = 0,
	}, children)
end)

type RootProps = {
	enabledLink: any,
	enemyColorLink: any,
	friendlyColorLink: any,
	localColorLink: any,
	bgColorLink: any,
}

return LPH_NO_VIRTUALIZE(function(props: RootProps): React.Element<any>?
	local enabled = useAt(props.enabledLink._state) :: boolean
	local entries = useAt(displayWarnings) :: { [string]: DisplayEntry }

	if not enabled then
		return nil
	end

	local bgColor = props.bgColorLink._currentColor

	local children: { [string]: any } = {}
	for id, entry in next, entries do
		children[id] = e(Warning, {
			source = entry.source,
			enemyColorLink = props.enemyColorLink,
			friendlyColorLink = props.friendlyColorLink,
			localColorLink = props.localColorLink,
			bgColor = bgColor,
			leaving = entry.leaving,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, children)
end)
