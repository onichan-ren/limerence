local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local bombState = require("@game/bloxstrike/bomb/bombState")
local indicatorVisibility = require("@game/bloxstrike/feature/visual/indicatorVisibility")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Camera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function(): ()
	Camera = Workspace.CurrentCamera
end)

local e = React.createElement
local useBinding = React.useBinding
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom

local MAX_VISIBLE_DISTANCE = 250
local DISTANCE_FADE_START = 0.85
local FADE_START_DISTANCE = MAX_VISIBLE_DISTANCE * DISTANCE_FADE_START
local FADE_RANGE = math.max(MAX_VISIBLE_DISTANCE - FADE_START_DISTANCE, 1)

local APPEAR_SPRING = { dampingRatio = 0.65, frequency = 3.5, precision = 0.005 }
local FOLLOW_SPRING = { dampingRatio = 1, frequency = 90, precision = 0.5 }

local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local INDICATOR_SIZE = UDim2.fromOffset(50, 14)
local LABEL_SIZE = UDim2.new(1, 0, 0, 12)
local TIMER_SIZE = UDim2.new(1, 0, 0, 12)
local BAR_SIZE = UDim2.new(0, 50, 0, 4)
local CORNER_FULL = UDim.new(1, 0)
local LIST_PADDING = UDim.new(0, 2)
local TEXT_OUTLINE = Color3.fromRGB(18, 18, 18)


export type BombState = bombState.BombState

type IndicatorProps = {
	state: BombState,
	colorBinding: any,
	barColorBinding: any,
	leaving: boolean,
}

local formatTime = LPH_NO_VIRTUALIZE(function(remaining: number): string
	if remaining <= 0 then
		return "0.0s"
	end
	return string.format("%.1fs", remaining)
end)

type StepState = {
	firstStep: boolean,
	lastOnScreen: number,
	lastProgress: number,
	lastTimerText: string,
	worldPos: Vector3?,
}

local runIndicatorStep = LPH_NO_VIRTUALIZE(
	function(
		state: BombState,
		stepState: StepState,
		setProgress: (number) -> (),
		setTime: (string) -> (),
		setOnScreen: (number) -> (),
		setDistance: (number) -> (),
		xSpring: any,
		ySpring: any
	): ()
		local now = Workspace:GetServerTimeNow()
		local remaining = math.max(0, state.explodeAt - now)
		local progress = (state.duration > 0 and remaining / state.duration or 0)
		if progress ~= stepState.lastProgress then
			stepState.lastProgress = progress
			setProgress(progress)
		end

		local timerText: string
		if state.isExploded then
			timerText = "EXPLODED"
		elseif state.isDefused then
			timerText = "DEFUSED"
		else
			timerText = formatTime(remaining)
		end
		if timerText ~= stepState.lastTimerText then
			stepState.lastTimerText = timerText
			setTime(timerText)
		end

		local model = state.model
		if not model or not model.Parent then
			return
		end

		local worldPos = stepState.worldPos
		if not worldPos then
			worldPos = model.GetPivot(model).Position
			stepState.worldPos = worldPos
		end
		local onScreen, sx, sy = indicatorVisibility.isWorldPosOnScreen(Camera, worldPos)
		local onScreenFlag = onScreen and 1 or 0
		if onScreenFlag ~= stepState.lastOnScreen then
			stepState.lastOnScreen = onScreenFlag
			setOnScreen(onScreenFlag)
		end

		if not onScreen then
			return
		end

		local camPos = Camera.CFrame.Position
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
	end
)

local Indicator = LPH_JIT_MAX(function(props: IndicatorProps): React.Element<any>?
	local state = props.state
	local colorBinding = props.colorBinding
	local barColorBinding = props.barColorBinding

	local progressBind, setProgress = useBinding(1)
	local timeBind, setTime = useBinding(formatTime(state.duration))
	local distanceBind, setDistance = useBinding(1)
	local onScreenBind, setOnScreen = useBinding(0)
	local xBind, xSpring = useSpring(0, FOLLOW_SPRING)
	local yBind, ySpring = useSpring(0, FOLLOW_SPRING)
	local appearBind, appearSpring = useSpring(0, APPEAR_SPRING)

	useEffect(function()
		appearSpring:setGoal(props.leaving and 0 or 1)
	end, { props.leaving })

	useEffect(function()
		local stepState: StepState = {
			firstStep = true,
			lastOnScreen = -1,
			lastProgress = -1,
			lastTimerText = "",
			worldPos = nil,
		}
		local function step(): ()
			runIndicatorStep(state, stepState, setProgress, setTime, setOnScreen, setDistance, xSpring, ySpring)
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
			Text = "C4",
			TextColor3 = colorBinding,
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
		Timer = e("TextLabel", {
			LayoutOrder = 2,
			Size = TIMER_SIZE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = timeBind,
			TextColor3 = colorBinding,
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
		}),
	})
end)

type RootProps = {
	enabledLink: any,
	bombColorLink: any,
	defusingColorLink: any,
	defusedColorLink: any,
	barColorLink: any,
}

return LPH_NO_VIRTUALIZE(function(props: RootProps): React.Element<any>?
	local enabled = useAt(props.enabledLink._state) :: boolean
	local bomb = useAt(bombState.bomb) :: BombState?
	local leaving = useAt(bombState.leaving) :: boolean

	if not enabled or not bomb then
		return nil
	end

	local colorBinding
	if bomb.isDefused or bomb.isExploded then
		colorBinding = props.defusedColorLink._currentColor
	elseif bomb.isDefusing then
		colorBinding = props.defusingColorLink._currentColor
	else
		colorBinding = props.bombColorLink._currentColor
	end

	return e(Indicator, {
		state = bomb,
		colorBinding = colorBinding,
		barColorBinding = props.barColorLink._currentColor,
		leaving = leaving == true,
	})
end)
