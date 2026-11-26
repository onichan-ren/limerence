local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local e = React.createElement
local useBinding = React.useBinding
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom

local EDGE_PADDING = 12
local LIFETIME = 300 / 55
local BAR_WIDTH = 40
local BAR_HEIGHT = 4
local LABEL = "FLASH"

local APPEAR_SPRING = { dampingRatio = 0.65, frequency = 3.5, precision = 0.005 }
local FOLLOW_SPRING = { dampingRatio = 1, frequency = 90, precision = 0.5 }
local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local LIST_PADDING = UDim.new(0, 2)
local CORNER_FULL = UDim.new(1, 0)
local TEXT_OUTLINE = Color3.fromRGB(18, 18, 18)
local TRACK = Color3.fromRGB(24, 24, 24)

export type FlashEntry = {
	id: number,
	model: Model,
	started: number,
}

local function modelWorldPosition(model: Model): Vector3?
	local primary = model.PrimaryPart
	if primary then
		return primary.Position
	end
	local pivot = model:GetPivot()
	if typeof(pivot) == "CFrame" then
		return pivot.Position
	end
	return nil
end

type IndicatorProps = {
	entry: FlashEntry,
	colorLink: any,
	showTimer: boolean,
}

type StepState = {
	firstStep: boolean,
	lastOnScreen: number,
	lastTimerInt: number,
}

local runIndicatorStep = LPH_NO_VIRTUALIZE(
	function(
		entry: FlashEntry,
		stepState: StepState,
		showTimer: boolean,
		setOnScreen: (number) -> (),
		setRatio: (number) -> (),
		setTimerText: (string) -> (),
		xSpring: any,
		ySpring: any
	): ()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local model = entry.model
		if not model.Parent then
			return
		end

		local worldPos = modelWorldPosition(model)
		if not worldPos then
			return
		end

		local viewport = camera.ViewportSize
		local vx, vy = viewport.X, viewport.Y
		local screenPos = camera:WorldToViewportPoint(worldPos)
		local sx = screenPos.X
		local sy = screenPos.Y

		local offScreen = screenPos.Z <= 0
			or sx < EDGE_PADDING
			or sx > vx - EDGE_PADDING
			or sy < EDGE_PADDING
			or sy > vy - EDGE_PADDING

		local onScreenFlag = offScreen and 0 or 1
		if onScreenFlag ~= stepState.lastOnScreen then
			stepState.lastOnScreen = onScreenFlag
			setOnScreen(onScreenFlag)
		end

		if offScreen then
			return
		end

		local remaining = math.max(LIFETIME - (os.clock() - entry.started), 0)
		setRatio(math.clamp(remaining / LIFETIME, 0, 1))

		if showTimer then
			local timerInt = math.ceil(remaining)
			if timerInt ~= stepState.lastTimerInt then
				stepState.lastTimerInt = timerInt
				setTimerText(string.format("%ds", timerInt))
			end
		end

		if stepState.firstStep then
			stepState.firstStep = false
			xSpring:setPosition(sx)
			ySpring:setPosition(sy)
		end

		xSpring:setGoal(sx)
		ySpring:setGoal(sy)
	end
)

local Indicator = LPH_NO_VIRTUALIZE(function(props: IndicatorProps): React.Element<any>?
	local entry = props.entry

	local ratioBind, setRatio = useBinding(1)
	local timerTextBind, setTimerText = useBinding("")
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
			lastTimerInt = -1,
		}
		local function step(): ()
			runIndicatorStep(entry, stepState, props.showTimer, setOnScreen, setRatio, setTimerText, xSpring, ySpring)
		end

		step()
		local conn = RunService.PreRender:Connect(step)
		return function()
			conn:Disconnect()
		end
	end, { entry.model, props.showTimer } :: { any })

	local positionBind = React.joinBindings({ xBind, yBind }):map(function(values): UDim2
		return UDim2.fromOffset(math.floor(values[1]), math.floor(values[2]))
	end)

	local opacityBind = React.joinBindings({ appearBind, onScreenBind }):map(function(values: { number }): number
		return values[1] * values[2]
	end)

	local fadeBind = opacityBind:map(function(v: number): number
		return math.clamp(1 - v, 0, 1)
	end)

	local barSizeBind = ratioBind:map(function(r: number): UDim2
		return UDim2.new(math.max(r, 0), 0, 1, 0)
	end)

	local colorBinding = props.colorLink._currentColor
	local font = FileController.Get("font", "pixel2")

	return e("Frame", {
		AnchorPoint = CENTER_ANCHOR,
		Position = positionBind,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(BAR_WIDTH, 0),
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
			Size = UDim2.fromOffset(0, 11),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = LABEL,
			TextColor3 = colorBinding,
			TextTransparency = fadeBind,
			FontFace = font,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, {
			Stroke = e("UIStroke", {
				Color = TEXT_OUTLINE,
				Thickness = 1,
				Transparency = fadeBind,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}),
		}),
		Bar = e("Frame", {
			LayoutOrder = 2,
			Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT),
			BackgroundColor3 = TRACK,
			BackgroundTransparency = fadeBind,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = CORNER_FULL,
			}),
			Fill = e("Frame", {
				Size = barSizeBind,
				BackgroundColor3 = colorBinding,
				BackgroundTransparency = fadeBind,
				BorderSizePixel = 0,
				ZIndex = 1,
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
		Timer = props.showTimer and e("TextLabel", {
			LayoutOrder = 3,
			Size = UDim2.fromOffset(0, 9),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = timerTextBind,
			TextColor3 = colorBinding,
			TextTransparency = fadeBind,
			FontFace = font,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, {
			Stroke = e("UIStroke", {
				Color = TEXT_OUTLINE,
				Thickness = 1,
				Transparency = fadeBind,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}),
		}) or nil,
	})
end)

type RootProps = {
	enabledLink: any,
	colorLink: any,
	showTimerLink: any,
	entries: Charm.Atom<{ [Model]: FlashEntry }>,
}

return LPH_NO_VIRTUALIZE(function(props: RootProps): React.Element<any>?
	local enabled = useAt(props.enabledLink._state) :: boolean
	local showTimer = useAt(props.showTimerLink._state) :: boolean
	local entries = useAt(props.entries) :: { [Model]: FlashEntry }

	if not enabled then
		return nil
	end

	local children: { [string]: any } = {}
	for model, entry in next, entries do
		if not model.Parent then
			continue
		end
		children[tostring(entry.id)] = e(Indicator, {
			entry = entry,
			colorLink = props.colorLink,
			showTimer = showTimer,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, children)
end)
