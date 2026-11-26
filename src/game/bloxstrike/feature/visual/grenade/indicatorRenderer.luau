local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")

local FileController = require("@src/feature/file/FileController")
local grenadeState = require("@game/bloxstrike/grenade/grenadeState")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local currentCamera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function(): ()
	currentCamera = Workspace.CurrentCamera
end)

local e = React.createElement
local useBinding = React.useBinding
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom

local at = Charm.atom
local sub = Charm.subscribe
local peek = Charm.peek

local EDGE_PADDING = 24
local MAX_VISIBLE_DISTANCE = 100
local DISTANCE_FADE_START = 0.7
local FADE_START_DISTANCE = MAX_VISIBLE_DISTANCE * DISTANCE_FADE_START
local FADE_RANGE = math.max(MAX_VISIBLE_DISTANCE - FADE_START_DISTANCE, 1)
local LEAVE_DURATION = 0.4
local TEXT_OUTLINE = Color3.fromRGB(18, 18, 18)

local APPEAR_SPRING = { dampingRatio = 0.65, frequency = 3.5, precision = 0.005 }
local FOLLOW_SPRING = { dampingRatio = 1.5, frequency = 16, precision = 0.05 }

local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local INDICATOR_SIZE = UDim2.fromOffset(96, 24)
local LABEL_SIZE = UDim2.new(1, 0, 0, 12)
local BAR_SIZE = UDim2.new(0, 56, 0, 4)
local CORNER_FULL = UDim.new(1, 0)
local LIST_PADDING = UDim.new(0, 2)

local Debris = Workspace:WaitForChild("Debris")

type IndicatorKind = "flash" | "smoke"
type IndicatorPhase = "flight" | "landed"

type IndicatorSource = {
	kind: IndicatorKind,
	phase: IndicatorPhase,
	startedAt: number,
	duration: number,
	label: string,
	grenadeId: string?,
	fallbackPosition: Vector3,
	friendly: boolean,
}

type DisplayEntry = {
	source: IndicatorSource,
	leaving: boolean,
}

local LABELS: { [string]: string } = {
	["Flashbang"] = "FLASHBANG",
	["Smoke Grenade"] = "SMOKE GRENADE",
}

local displayIndicators = at({} :: { [string]: DisplayEntry })
local leavingTimers: { [string]: thread } = {}
local expiryTimers: { [string]: thread } = {}

local function projectileToSource(entry: grenadeState.ProjectileEntry): IndicatorSource?
	local kind: IndicatorKind?
	if entry.weapon == "Flashbang" then
		kind = "flash"
	elseif entry.weapon == "Smoke Grenade" then
		kind = "smoke"
	end
	if not kind then
		return nil
	end
	return {
		kind = kind,
		phase = "flight",
		startedAt = entry.startedAt,
		duration = math.max(0, entry.detonateAt - entry.startedAt),
		label = LABELS[entry.weapon] or entry.weapon,
		grenadeId = entry.id,
		fallbackPosition = entry.landingPosition,
		friendly = entry.isFriendly == true,
	}
end

local function smokeToSource(_folderName: string, smoke: grenadeState.SmokeEntry): IndicatorSource?
	if not smoke.position or not smoke.startedAt or not smoke.duration then
		return nil
	end
	return {
		kind = "smoke",
		phase = "landed",
		startedAt = smoke.startedAt :: number,
		duration = smoke.duration :: number,
		label = LABELS["Smoke Grenade"],
		grenadeId = nil,
		fallbackPosition = smoke.position :: Vector3,
		friendly = smoke.isFriendly == true,
	}
end

local function removeFromDisplay(id: string): ()
	local now = peek(displayIndicators)
	if not now[id] then
		return
	end
	local nextMap: { [string]: DisplayEntry } = {}
	for k, v in next, now do
		if k ~= id then
			nextMap[k] = v
		end
	end
	displayIndicators(nextMap)
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
	local now = peek(displayIndicators)
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
	displayIndicators(nextMap)
	startLeaveTimer(id)
end

local function scheduleExpiry(id: string, source: IndicatorSource): ()
	if expiryTimers[id] then
		task.cancel(expiryTimers[id])
	end
	if source.kind == "smoke" and source.phase == "flight" then
		return
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

local function reconcile(activeSources: { [string]: IndicatorSource }): ()
	local current = peek(displayIndicators)
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

	displayIndicators(nextDisplay)
end

local function collectSources(): { [string]: IndicatorSource }
	local sources: { [string]: IndicatorSource } = {}

	for id, entry in next, peek(grenadeState.activeProjectiles) do
		local source = projectileToSource(entry)
		if source then
			sources["proj:" .. id] = source
		end
	end

	for folderName, smoke in next, peek(grenadeState.activeSmokes) do
		local source = smokeToSource(folderName, smoke)
		if source then
			sources["smoke:" .. folderName] = source
		end
	end

	return sources
end

sub(grenadeState.activeProjectiles, function(): ()
	reconcile(collectSources())
end)

sub(grenadeState.activeSmokes, function(): ()
	reconcile(collectSources())
end)

local function findGrenadeModel(id: string): Model?
	local model = Debris:FindFirstChild(id)
	if model and model.ClassName == "Model" then
		return model :: Model
	end
	return nil
end

type IndicatorProps = {
	source: IndicatorSource,
	color: any,
	barColor: any,
	leaving: boolean,
}

type StepState = {
	firstStep: boolean,
	model: Model?,
}

local runIndicatorStep = LPH_NO_VIRTUALIZE(
	function(
		source: IndicatorSource,
		stepState: StepState,
		setProgress: (number) -> (),
		setDistance: (number) -> (),
		setOnScreen: (number) -> (),
		xSpring: any,
		ySpring: any
	): ()
		local progress: number
		if source.kind == "smoke" and source.phase == "flight" then
			progress = 1
		else
			local elapsed = os.clock() - source.startedAt
			local duration = source.duration
			local remaining = duration - elapsed
			if remaining < 0 then
				remaining = 0
			end
			progress = (duration > 0 and remaining / duration or 0)
		end
		setProgress(progress)

		local camera = currentCamera
		if not camera then
			return
		end

		local worldPos = source.fallbackPosition
		if source.grenadeId then
			local model = stepState.model
			if not model or model.Parent ~= Debris then
				model = findGrenadeModel(source.grenadeId)
				stepState.model = model
			end
			if model then
				worldPos = model:GetPivot().Position
			end
		end

		local viewport = camera.ViewportSize
		local vx, vy = viewport.X, viewport.Y
		local screenPos = camera:WorldToViewportPoint(worldPos)
		local sx = screenPos.X
		local sy = screenPos.Y
		local behind = screenPos.Z <= 0

		local offScreen = behind
			or sx < EDGE_PADDING
			or sx > vx - EDGE_PADDING
			or sy < EDGE_PADDING
			or sy > vy - EDGE_PADDING

		setOnScreen(offScreen and 0 or 1)

		local camPos = camera.CFrame.Position
		local ddx = worldPos.X - camPos.X
		local ddy = worldPos.Y - camPos.Y
		local ddz = worldPos.Z - camPos.Z
		local distance = math.sqrt(ddx * ddx + ddy * ddy + ddz * ddz)
		local distanceFactor = math.clamp(1 - (distance - FADE_START_DISTANCE) / FADE_RANGE, 0, 1)
		setDistance(distanceFactor)

		if stepState.firstStep then
			stepState.firstStep = false
			xSpring:setPosition(sx)
			ySpring:setPosition(sy)
		end

		xSpring:setGoal(sx)
		ySpring:setGoal(sy)
	end
)

local Indicator = LPH_JIT_MAX(function(props: IndicatorProps): React.Element<any>?
	local source = props.source
	local color = props.color
	local barColor = props.barColor

	local progressBind, setProgress = useBinding(1)
	local distanceBind, setDistance = useBinding(1)
	local onScreenBind, setOnScreen = useBinding(0)
	local xBind, xSpring = useSpring(0, FOLLOW_SPRING)
	local yBind, ySpring = useSpring(0, FOLLOW_SPRING)
	local appearBind, appearSpring = useSpring(0, APPEAR_SPRING)

	useEffect(function()
		appearSpring:setGoal(props.leaving and 0 or 1)
	end, { props.leaving })

	useEffect(function()
		local stepState: StepState = { firstStep = true, model = nil }
		local function step(): ()
			runIndicatorStep(source, stepState, setProgress, setDistance, setOnScreen, xSpring, ySpring)
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

	local opacityBind = React.joinBindings({ appearBind, distanceBind, onScreenBind })
		:map(function(values: { number }): number
			return values[1] * values[2] * values[3]
		end)

	local textTransparencyBind = opacityBind:map(function(v: number): number
		return math.clamp(1 - v, 0, 1)
	end)

	local barBgTransparencyBind = opacityBind:map(function(v: number): number
		return 0.35 + (1 - v) * 0.65
	end)

	local barFillSizeBind = progressBind:map(function(p: number): UDim2
		return UDim2.fromScale(math.clamp(p, 0, 1), 1)
	end)

	return e("Frame", {
		AnchorPoint = CENTER_ANCHOR,
		Position = positionBind,
		Size = INDICATOR_SIZE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = LIST_PADDING,
		}),
		Label = e("TextLabel", {
			LayoutOrder = 1,
			Size = LABEL_SIZE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = source.label,
			TextColor3 = color,
			TextTransparency = textTransparencyBind,
			FontFace = FileController.Get("font", "pixel2"),
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, {
			Stroke = e("UIStroke", {
				Color = TEXT_OUTLINE,
				Thickness = 1,
				Transparency = textTransparencyBind,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}),
		}),
		Bar = e("Frame", {
			LayoutOrder = 2,
			Size = BAR_SIZE,
			BackgroundColor3 = barColor,
			BackgroundTransparency = barBgTransparencyBind,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = CORNER_FULL,
			}),
			Fill = e("Frame", {
				Size = barFillSizeBind,
				BackgroundColor3 = color,
				BackgroundTransparency = textTransparencyBind,
				BorderSizePixel = 0,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = CORNER_FULL,
				}),
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 1),
				PaddingRight = UDim.new(0, 1),
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
			}),
		}),
	})
end)

type RootProps = {
	enabledLink: any,
	enemyFlashColorLink: any,
	friendlyFlashColorLink: any,
	enemySmokeColorLink: any,
	friendlySmokeColorLink: any,
	barColorLink: any,
}

return function(props: RootProps): React.Element<any>?
	local enabled = useAt(props.enabledLink._state) :: boolean
	local entries = useAt(displayIndicators) :: { [string]: DisplayEntry }

	if not enabled then
		return nil
	end

	local enemyFlash = props.enemyFlashColorLink._currentColor
	local friendlyFlash = props.friendlyFlashColorLink._currentColor
	local enemySmoke = props.enemySmokeColorLink._currentColor
	local friendlySmoke = props.friendlySmokeColorLink._currentColor
	local barColor = props.barColorLink._currentColor

	local children: { [string]: any } = {}
	for id, entry in next, entries do
		local source = entry.source
		local color: any
		if source.kind == "flash" then
			color = (source.friendly and friendlyFlash or enemyFlash)
		else
			color = (source.friendly and friendlySmoke or enemySmoke)
		end
		children[id] = e(Indicator, {
			source = source,
			color = color,
			barColor = barColor,
			leaving = entry.leaving,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, children)
end
