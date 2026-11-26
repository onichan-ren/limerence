local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local hostageState = require("@game/bloxstrike/hostage/hostageState")
local indicatorVisibility = require("@game/bloxstrike/feature/visual/indicatorVisibility")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local e = React.createElement
local useBinding = React.useBinding
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom

local MAX_VISIBLE_DISTANCE = 400
local DISTANCE_FADE_START = 0.85
local FADE_START_DISTANCE = MAX_VISIBLE_DISTANCE * DISTANCE_FADE_START
local FADE_RANGE = math.max(MAX_VISIBLE_DISTANCE - FADE_START_DISTANCE, 1)

local APPEAR_SPRING = { dampingRatio = 0.65, frequency = 3.5, precision = 0.005 }
local FOLLOW_SPRING = { dampingRatio = 1, frequency = 90, precision = 0.5 }

local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local INDICATOR_SIZE = UDim2.fromOffset(64, 14)
local LABEL_SIZE = UDim2.new(1, 0, 0, 12)
local TIMER_SIZE = UDim2.new(1, 0, 0, 12)
local BAR_SIZE = UDim2.new(0, 70, 0, 4)
local CORNER_FULL = UDim.new(1, 0)
local LIST_PADDING = UDim.new(0, 2)
local TEXT_OUTLINE = Color3.fromRGB(18, 18, 18)


type IndicatorProps = {
	entry: hostageState.HostageEntry,
	colorLink: any,
	barColorLink: any,
}

type StepState = {
	firstStep: boolean,
	lastOnScreen: number,
	lastProgress: number,
	lastTimerText: string,
	worldPos: Vector3?,
}

local runHostageStep = LPH_NO_VIRTUALIZE(
	function(
		entry: hostageState.HostageEntry,
		stepState: StepState,
		setProgress: (number) -> (),
		setTime: (string) -> (),
		setOnScreen: (number) -> (),
		setDistance: (number) -> (),
		xSpring: any,
		ySpring: any
	): ()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local model = entry.model
		if not model or not model.Parent then
			return
		end

		local worldPos = stepState.worldPos
		if not worldPos then
			worldPos = model.GetPivot(model).Position
			stepState.worldPos = worldPos
		end
		local onScreen, sx, sy = indicatorVisibility.isWorldPosOnScreen(camera, worldPos)
		local onScreenFlag = onScreen and 1 or 0
		if onScreenFlag ~= stepState.lastOnScreen then
			stepState.lastOnScreen = onScreenFlag
			setOnScreen(onScreenFlag)
		end

		if not onScreen then
			return
		end

		local camPos = camera.CFrame.Position
		local distance = (worldPos - camPos).Magnitude
		local distanceFactor = math.clamp(1 - (distance - FADE_START_DISTANCE) / FADE_RANGE, 0, 1)
		setDistance(distanceFactor)

		if stepState.firstStep then
			stepState.firstStep = false
			xSpring:setPosition(sx)
			ySpring:setPosition(sy)
		end

		xSpring:setGoal(sx)
		ySpring:setGoal(sy)

		if entry.rescuingPlayer and entry.rescueStartedAt and entry.rescueDuration then
			local elapsed = Workspace:GetServerTimeNow() - entry.rescueStartedAt
			local remaining = math.max(0, entry.rescueDuration - elapsed)
			local progress = math.clamp(elapsed / entry.rescueDuration, 0, 1)
			if progress ~= stepState.lastProgress then
				stepState.lastProgress = progress
				setProgress(progress)
			end
			local timerText = string.format("%.1fs", remaining)
			if timerText ~= stepState.lastTimerText then
				stepState.lastTimerText = timerText
				setTime(timerText)
			end
		else
			if stepState.lastProgress ~= 0 then
				stepState.lastProgress = 0
				setProgress(0)
			end
			if stepState.lastTimerText ~= "" then
				stepState.lastTimerText = ""
				setTime("")
			end
		end
	end
)

local HostageIndicator = LPH_JIT_MAX(function(props: IndicatorProps): React.Element<any>?
	local entry = props.entry

	local progressBind, setProgress = useBinding(0)
	local timeBind, setTime = useBinding("")
	local distanceBind, setDistance = useBinding(1)
	local onScreenBind, setOnScreen = useBinding(0)
	local xBind, xSpring = useSpring(0, FOLLOW_SPRING)
	local yBind, ySpring = useSpring(0, FOLLOW_SPRING)
	local appearBind, appearSpring = useSpring(0, APPEAR_SPRING)

	useEffect(function()
		appearSpring:setGoal(1)
	end, {})

	useEffect(function()
		local stepState: StepState = {
			firstStep = true,
			lastOnScreen = -1,
			lastProgress = -1,
			lastTimerText = "",
			worldPos = nil,
		}
		local function step(): ()
			runHostageStep(entry, stepState, setProgress, setTime, setOnScreen, setDistance, xSpring, ySpring)
		end

		step()
		local conn = RunService.PreRender:Connect(step)
		return function()
			conn:Disconnect()
		end
	end, { entry.rescuingPlayer, entry.rescueStartedAt, entry.rescueDuration, entry.state } :: { any })

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

	local label: string
	if entry.state == "Carrying" then
		label = "CARRIED"
	elseif entry.rescuingPlayer then
		label = "RESCUING"
	else
		label = "HOSTAGE"
	end

	local colorBinding = props.colorLink._currentColor
	local barColorBinding = props.barColorLink._currentColor
	local font = FileController.Get("font", "pixel2")

	local showBar = entry.rescuingPlayer ~= nil

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
			Text = label,
			TextColor3 = colorBinding,
			TextTransparency = textTransparencyBind,
			FontFace = font,
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
		Timer = showBar and e("TextLabel", {
			LayoutOrder = 2,
			Size = TIMER_SIZE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = timeBind,
			TextColor3 = colorBinding,
			TextTransparency = textTransparencyBind,
			FontFace = font,
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
		}) or nil,
		Bar = showBar and e("Frame", {
			LayoutOrder = 3,
			Size = BAR_SIZE,
			BackgroundColor3 = barColorBinding,
			BackgroundTransparency = barBgTransparencyBind,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = CORNER_FULL,
			}),
			Fill = e("Frame", {
				Size = barFillSizeBind,
				BackgroundColor3 = colorBinding,
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
		}) or nil,
	})
end)

type RootProps = {
	enabledLink: any,
	idleColorLink: any,
	rescuingColorLink: any,
	carriedColorLink: any,
	barColorLink: any,
}

return LPH_NO_VIRTUALIZE(function(props: RootProps): React.Element<any>?
	local enabled = useAt(props.enabledLink._state) :: boolean
	local hostages = useAt(hostageState.hostages) :: { [string]: hostageState.HostageEntry }

	if not enabled then
		return nil
	end

	local children: { [string]: any } = {}

	for key, entry in next, hostages do
		local colorLink: any
		if entry.state == "Carrying" then
			colorLink = props.carriedColorLink
		elseif entry.rescuingPlayer then
			colorLink = props.rescuingColorLink
		else
			colorLink = props.idleColorLink
		end
		children[key] = e(HostageIndicator, {
			entry = entry,
			colorLink = colorLink,
			barColorLink = props.barColorLink,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, children)
end)
