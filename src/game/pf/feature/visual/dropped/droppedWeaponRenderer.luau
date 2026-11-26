local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local droppedWeaponState = require("@game/pf/feature/visual/dropped/droppedWeaponState")

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
local MAX_VISIBLE_DISTANCE = 90
local DISTANCE_FADE_START = 0.7
local FADE_START_DISTANCE = MAX_VISIBLE_DISTANCE * DISTANCE_FADE_START
local FADE_RANGE = math.max(MAX_VISIBLE_DISTANCE - FADE_START_DISTANCE, 1)

local FOLLOW_SPRING = { dampingRatio = 1, frequency = 90, precision = 0.5 }
local APPEAR_SPRING = { dampingRatio = 0.65, frequency = 3.5, precision = 0.005 }
local CENTER_ANCHOR = Vector2.new(0.5, 0.5)

type WeaponStyle = {
	textColor: Color3,
	textOutline: boolean,
	textOutlineColor: Color3,
}

type IndicatorProps = {
	entry: droppedWeaponState.DroppedEntry,
	weaponStyle: WeaponStyle,
}

local runIndicatorStep = LPH_NO_VIRTUALIZE(
	function(
		entry: any,
		setOnScreen: (number) -> (),
		setDistance: (number) -> (),
		xSpring: any,
		ySpring: any,
		firstStep: { boolean }
	)
		local model = entry.model
		if not model.Parent then
			return
		end

		local worldPos = entry.position
		local camera = currentCamera
		if not camera then
			return
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

		if firstStep[1] then
			firstStep[1] = false
			xSpring:setPosition(sx)
			ySpring:setPosition(sy)
		end

		xSpring:setGoal(sx)
		ySpring:setGoal(sy)
	end
)

local Indicator = LPH_NO_VIRTUALIZE(function(props: IndicatorProps): React.Element<any>?
	local entry = props.entry
	local weaponStyle = props.weaponStyle

	local distanceBind, setDistance = useBinding(1)
	local onScreenBind, setOnScreen = useBinding(0)
	local xBind, xSpring = useSpring(0, FOLLOW_SPRING)
	local yBind, ySpring = useSpring(0, FOLLOW_SPRING)
	local appearBind, appearSpring = useSpring(1, APPEAR_SPRING)

	useEffect(function()
		appearSpring:setGoal(1)
	end, {})

	useEffect(function()
		local firstStep = { true }
		local function step(): ()
			runIndicatorStep(entry, setOnScreen, setDistance, xSpring, ySpring, firstStep)
		end
		step()
		local conn = RunService.PreRender:Connect(step)
		return function()
			conn:Disconnect()
		end
	end, { entry.model })

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

	return e("Frame", {
		AnchorPoint = CENTER_ANCHOR,
		Position = positionBind,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Label = e("TextLabel", {
			Size = UDim2.fromOffset(0, 12),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = entry.label,
			TextColor3 = weaponStyle.textColor,
			TextTransparency = textTransparencyBind,
			FontFace = FileController.Get("font", "pixel2"),
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, {
			Stroke = weaponStyle.textOutline and e("UIStroke", {
				Color = weaponStyle.textOutlineColor,
				Thickness = 1,
				Transparency = textTransparencyBind,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}) or nil,
		}),
	})
end)

type RootProps = {
	enabledLink: any,
	weaponTextColorLink: any,
	weaponTextOutlineLink: any,
	weaponTextOutlineColorLink: any,
}

return LPH_NO_VIRTUALIZE(function(props: RootProps): React.Element<any>?
	local masterEnabled = useAt(props.enabledLink._state) :: boolean
	local weaponTextOutline = useAt(props.weaponTextOutlineLink._state) :: boolean
	local entries = useAt(droppedWeaponState.entries) :: { [any]: droppedWeaponState.DroppedEntry }

	if not masterEnabled then
		return nil
	end

	local weaponStyle: WeaponStyle = {
		textColor = props.weaponTextColorLink._currentColor,
		textOutline = weaponTextOutline,
		textOutlineColor = props.weaponTextOutlineColorLink._currentColor,
	}

	local children: { [string]: any } = {}
	for key, entry in next, entries do
		if not entry.model.Parent then
			continue
		end
		children[tostring(key)] = e(Indicator, {
			entry = entry,
			weaponStyle = weaponStyle,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, children)
end)
