local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")
local worldEspState = require("@game/ar2/feature/visuals/world/worldEspState")

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

local EDGE_PADDING = 24
local DISTANCE_FADE_START = 0.85

local APPEAR_SPRING = { dampingRatio = 0.65, frequency = 3.5, precision = 0.005 }
local FOLLOW_SPRING = { dampingRatio = 1, frequency = 90, precision = 0.5 }
local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local LIST_PADDING = UDim.new(0, 2)
local TEXT_OUTLINE = Color3.fromRGB(18, 18, 18)

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
	entry: worldEspState.WorldEntry,
	colorLink: any,
	maxDistance: number,
	showDistance: boolean,
}

type StepState = {
	firstStep: boolean,
	lastOnScreen: number,
	lastDistanceText: string,
}

local runIndicatorStep = LPH_NO_VIRTUALIZE(
	function(
		entry: worldEspState.WorldEntry,
		stepState: StepState,
		maxDistance: number,
		showDistance: boolean,
		setOnScreen: (number) -> (),
		setDistance: (number) -> (),
		setDistanceText: (string) -> (),
		xSpring: any,
		ySpring: any
	): ()
		local camera = currentCamera
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

		local camPos = camera.CFrame.Position
		local ddx = worldPos.X - camPos.X
		local ddy = worldPos.Y - camPos.Y
		local ddz = worldPos.Z - camPos.Z
		local distance = math.sqrt(ddx * ddx + ddy * ddy + ddz * ddz)

		local offScreen = screenPos.Z <= 0
			or distance > maxDistance
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

		local fadeStart = maxDistance * DISTANCE_FADE_START
		local fadeRange = math.max(maxDistance - fadeStart, 1)
		setDistance(math.clamp(1 - (distance - fadeStart) / fadeRange, 0, 1))

		if showDistance then
			local distanceText = string.format("%dm", distance)
			if distanceText ~= stepState.lastDistanceText then
				stepState.lastDistanceText = distanceText
				setDistanceText(distanceText)
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

	local distanceBind, setDistance = useBinding(1)
	local distanceTextBind, setDistanceText = useBinding("")
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
			lastDistanceText = "",
		}
		local function step(): ()
			runIndicatorStep(
				entry,
				stepState,
				props.maxDistance,
				props.showDistance,
				setOnScreen,
				setDistance,
				setDistanceText,
				xSpring,
				ySpring
			)
		end

		step()
		local conn = RunService.PreRender:Connect(step)
		return function()
			conn:Disconnect()
		end
	end, { entry.model, props.maxDistance, props.showDistance } :: { any })

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

	local colorBinding = props.colorLink._currentColor
	local font = FileController.Get("font", "pixel2")

	return e("Frame", {
		AnchorPoint = CENTER_ANCHOR,
		Position = positionBind,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
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
			Size = UDim2.fromOffset(0, 12),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = entry.label,
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
		Distance = props.showDistance and e("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, 10),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = distanceTextBind,
			TextColor3 = colorBinding,
			TextTransparency = textTransparencyBind,
			FontFace = font,
			TextSize = 9,
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
	})
end)

type RootProps = {
	enabledLink: any,
	colorLink: any,
	maxDistanceLink: any,
	showDistanceLink: any,
	entries: Charm.Atom<{ [Model]: worldEspState.WorldEntry }>,
	excludeAtom: Charm.Atom<Model?>?,
}

return LPH_NO_VIRTUALIZE(function(props: RootProps): React.Element<any>?
	local enabled = useAt(props.enabledLink._state) :: boolean
	local maxDistance = useAt(props.maxDistanceLink._state) :: number
	local showDistance = useAt(props.showDistanceLink._state) :: boolean
	local entries = useAt(props.entries) :: { [Model]: worldEspState.WorldEntry }
	local excludeAtom = props.excludeAtom
	local excludeModel = excludeAtom and useAt(excludeAtom) or nil

	if not enabled then
		return nil
	end

	local children: { [string]: any } = {}
	for model, entry in next, entries do
		if not model.Parent or model == excludeModel then
			continue
		end
		children[tostring(model)] = e(Indicator, {
			entry = entry,
			colorLink = props.colorLink,
			maxDistance = maxDistance,
			showDistance = showDistance,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, children)
end)
