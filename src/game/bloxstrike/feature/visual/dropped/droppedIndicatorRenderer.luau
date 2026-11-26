local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local EspElement = require("@game/bloxstrike/feature/visual/esp/EspElement")
local droppedItemState = require("@game/bloxstrike/dropped/droppedItemState")

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
local MAX_VISIBLE_DISTANCE = 55
local DISTANCE_FADE_START = 0.7
local FADE_START_DISTANCE = MAX_VISIBLE_DISTANCE * DISTANCE_FADE_START
local FADE_RANGE = math.max(MAX_VISIBLE_DISTANCE - FADE_START_DISTANCE, 1)

local APPEAR_SPRING = { dampingRatio = 0.65, frequency = 3.5, precision = 0.005 }
local FOLLOW_SPRING = { dampingRatio = 1, frequency = 90, precision = 0.5 }
local CENTER_ANCHOR = Vector2.new(0.5, 0.5)

local AMMO_BAR_WIDTH = 36
local AMMO_BAR_HEIGHT = 2
local AMMO_BAR_GAP = 2
local GRADIENT_ROTATION = 0
local WHITE = Color3.new(1, 1, 1)
local OUTLINE_COLOR = Color3.fromRGB(18, 18, 18)

local function toNumberSequence(t: number): NumberSequence
	return NumberSequence.new(t)
end

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

type WeaponStyle = {
	textColor: Color3,
	textOutline: boolean,
	textOutlineColor: Color3,
	showAmmo: boolean,
	ammoFillPicker: any,
	ammoBackgroundPicker: any,
	barOutline: boolean,
	barOutlinePicker: any,
}

type IndicatorProps = {
	entry: droppedItemState.DroppedEntry,
	color: Color3,
	weaponStyle: WeaponStyle?,
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

		local worldPos = modelWorldPosition(model)
		if not worldPos then
			return
		end

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
	local isWeapon = weaponStyle ~= nil

	local textColor = (isWeapon and weaponStyle.textColor or props.color)
	local textOutline = true
	if isWeapon then
		textOutline = weaponStyle.textOutline
	end
	local textOutlineColor = (isWeapon and weaponStyle.textOutlineColor or OUTLINE_COLOR)

	local showAmmoBar = isWeapon and weaponStyle.showAmmo and entry.showAmmo and entry.maxRounds > 0

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

	local ammoRatio = (entry.maxRounds > 0 and entry.rounds / entry.maxRounds or 0)
	local fadeTransparency = EspElement.fadedTransparency(opacityBind)

	return e("Frame", {
		AnchorPoint = CENTER_ANCHOR,
		Position = positionBind,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(showAmmoBar and AMMO_BAR_WIDTH or 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, AMMO_BAR_GAP),
		}),
		Label = e("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(0, 12),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = entry.label,
			TextColor3 = textColor,
			TextTransparency = textTransparencyBind,
			FontFace = FileController.Get("font", "pixel2"),
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, {
			Stroke = textOutline and e("UIStroke", {
				Color = textOutlineColor,
				Thickness = 1,
				Transparency = textTransparencyBind,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}) or nil,
		}),
		AmmoBar = showAmmoBar and weaponStyle and e("Frame", {
			LayoutOrder = 2,
			Size = UDim2.fromOffset(AMMO_BAR_WIDTH, AMMO_BAR_HEIGHT),
			BackgroundColor3 = weaponStyle.ammoBackgroundPicker._currentColor,
			BackgroundTransparency = fadeTransparency,
			BorderSizePixel = 0,
		}, {
			Fill = e("Frame", {
				Size = UDim2.fromScale(math.clamp(ammoRatio, 0, 1), 1),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = fadeTransparency,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, {
				UIGradient = e("UIGradient", {
					Color = weaponStyle.ammoFillPicker._currentGradient,
					Rotation = GRADIENT_ROTATION,
					Transparency = weaponStyle.ammoFillPicker._currentTransparency:map(toNumberSequence),
				}),
			}),
			Outline = weaponStyle.barOutline and e("UIStroke", {
				Color = weaponStyle.barOutlinePicker._currentColor,
				Transparency = fadeTransparency,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Miter,
			}) or nil,
		}) or nil,
	})
end)

type RootProps = {
	enabledLink: any,
	weaponLink: any,
	bombLink: any,
	itemLink: any,
	weaponTextColorLink: any,
	weaponTextOutlineLink: any,
	weaponTextOutlineColorLink: any,
	weaponAmmoLink: any,
	weaponAmmoFillLink: any,
	weaponAmmoBackgroundLink: any,
	weaponBarOutlineLink: any,
	weaponBarOutlineColorLink: any,
	bombColorLink: any,
	itemColorLink: any,
}

return LPH_NO_VIRTUALIZE(function(props: RootProps): React.Element<any>?
	local masterEnabled = useAt(props.enabledLink._state) :: boolean
	local weaponEnabled = useAt(props.weaponLink._state) :: boolean
	local bombEnabled = useAt(props.bombLink._state) :: boolean
	local itemEnabled = useAt(props.itemLink._state) :: boolean
	local weaponAmmoEnabled = useAt(props.weaponAmmoLink._state) :: boolean
	local weaponTextOutline = useAt(props.weaponTextOutlineLink._state) :: boolean
	local weaponBarOutline = useAt(props.weaponBarOutlineLink._state) :: boolean
	local entries = useAt(droppedItemState.entries) :: { [Model]: droppedItemState.DroppedEntry }

	if not masterEnabled then
		return nil
	end

	local weaponStyle: WeaponStyle = {
		textColor = props.weaponTextColorLink._currentColor,
		textOutline = weaponTextOutline,
		textOutlineColor = props.weaponTextOutlineColorLink._currentColor,
		showAmmo = weaponAmmoEnabled,
		ammoFillPicker = props.weaponAmmoFillLink,
		ammoBackgroundPicker = props.weaponAmmoBackgroundLink,
		barOutline = weaponBarOutline,
		barOutlinePicker = props.weaponBarOutlineColorLink,
	}

	local bombColor = props.bombColorLink._currentColor
	local itemColor = props.itemColorLink._currentColor

	local children: { [string]: any } = {}
	for model, entry in next, entries do
		if not model.Parent then
			continue
		end

		local kindEnabled = false
		local color: Color3
		local style: WeaponStyle? = nil
		if entry.kind == "weapon" then
			kindEnabled = weaponEnabled
			color = weaponStyle.textColor
			style = weaponStyle
		elseif entry.kind == "bomb" then
			kindEnabled = bombEnabled
			color = bombColor
		else
			kindEnabled = itemEnabled
			color = itemColor
		end

		if not kindEnabled then
			continue
		end

		children[tostring(model)] = e(Indicator, {
			entry = entry,
			color = color,
			weaponStyle = style,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, children)
end)
