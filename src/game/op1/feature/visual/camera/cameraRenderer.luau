local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")

local CameraController = require("@game/op1/camera/CameraController")
local FileController = require("@feature/file/FileController")
local espProject = require("@share/screenProject")

local peek = Charm.peek

local Workspace = cloneref(game:GetService("Workspace"))
local RunService = cloneref(game:GetService("RunService"))

local e = React.createElement
local useBinding = React.useBinding
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom

local EDGE_PADDING = 36
local SIZE_REFERENCE_DISTANCE = 28
local MIN_SIZE_RATIO = 0.5
local OFFSCREEN_MAX_DISTANCE = 140
local OFFSCREEN_FADE_START_RATIO = 0.6
local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local NAME_ANCHOR = Vector2.new(0.5, 0)
local CORNER_FULL = UDim.new(0, 6)
local NAME_CORNER = UDim.new(0, 4)
local NAME_PAD = UDim.new(0, 5)
local ICON_SCALE = 0.78
local NAME_TEXT_SIZE = 12
local SLOW_INTERVAL = 8

local APPEAR_SPRING = { dampingRatio = 0.7, frequency = 3.5, precision = 0.005 }
local FOLLOW_SPRING = { dampingRatio = 1.2, frequency = 9, precision = 0.5 }
local SIZE_SPRING = { dampingRatio = 1.0, frequency = 5, precision = 0.5 }

type MarkerProps = {
	entry: any,
	enemyColorLink: any,
	friendlyColorLink: any,
	localColorLink: any,
	neutralColorLink: any,
	showEnemyLink: any,
	showFriendlyLink: any,
	showLocalLink: any,
	showNeutralLink: any,
	bgColor: any,
}

type StepState = {
	firstStep: boolean,
}

local runMarkerStep = LPH_NO_VIRTUALIZE(
	function(
		entry: any,
		stepState: StepState,
		setOpacity: (number) -> (),
		xSpring: any,
		ySpring: any,
		sizeSpring: any
	): ()
		local instance = entry.instance
		if not instance or instance.Parent == nil then
			setOpacity(0)
			return
		end

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local camValue = entry.object.values and entry.object.values.camera
		if camValue and camValue.get and camValue:get() == camera then
			stepState.firstStep = true
			setOpacity(0)
			return
		end

		local viewport = camera.ViewportSize
		local vx, vy = viewport.X, viewport.Y
		local maxSize = (vx < vy and vx or vy) / 24

		local worldPos = (instance :: any):GetPivot().Position
		local screenPos = espProject.project(camera, viewport, worldPos)
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

		local opacity = 1
		if needsClamp then
			local fadeStart = OFFSCREEN_MAX_DISTANCE * OFFSCREEN_FADE_START_RATIO
			local fadeRange = OFFSCREEN_MAX_DISTANCE - fadeStart
			opacity = math.clamp(1 - (distance - fadeStart) / fadeRange, 0, 1)
		end
		setOpacity(opacity)

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

local Marker = LPH_JIT_MAX(function(props: MarkerProps): React.Element<any>?
	local entry = props.entry
	local bgColor = props.bgColor

	local enemyLink = props.enemyColorLink
	local friendlyLink = props.friendlyColorLink
	local localLink = props.localColorLink
	local neutralLink = props.neutralColorLink

	local showEnemyLink = props.showEnemyLink
	local showFriendlyLink = props.showFriendlyLink
	local showLocalLink = props.showLocalLink
	local showNeutralLink = props.showNeutralLink

	local colorBind, setColor = useBinding((enemyLink._currentColor :: any):getValue() :: Color3)
	local opacityBind, setOpacity = useBinding(0)
	local nameBind, setName = useBinding("")
	local xBind, xSpring = useSpring(0, FOLLOW_SPRING)
	local yBind, ySpring = useSpring(0, FOLLOW_SPRING)
	local sizeBind, sizeSpring = useSpring(0, SIZE_SPRING)
	local appearBind, appearSpring = useSpring(0, APPEAR_SPRING)

	useEffect(function()
		appearSpring:setGoal(1)
		return function(): ()
			appearSpring:setGoal(0)
		end
	end, {})

	useEffect(function()
		local stepState: StepState = { firstStep = true }
		local relation = CameraController.GetRelation(entry)
		local frame = SLOW_INTERVAL
		local function step(): ()
			frame += 1
			if frame >= SLOW_INTERVAL then
				frame = 0
				relation = CameraController.GetRelation(entry)
				setName(CameraController.GetController(entry) or "")
				local link = (relation == "local" and localLink)
					or (relation == "friendly" and friendlyLink)
					or (relation == "neutral" and neutralLink)
					or enemyLink
				setColor((link._currentColor :: any):getValue() :: Color3)
			end

			local showLink = (relation == "local" and showLocalLink)
				or (relation == "friendly" and showFriendlyLink)
				or (relation == "neutral" and showNeutralLink)
				or showEnemyLink

			if not peek(showLink._state) then
				stepState.firstStep = true
				setOpacity(0)
				return
			end

			runMarkerStep(entry, stepState, setOpacity, xSpring, ySpring, sizeSpring)
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

	local sizeUdimBind = React.joinBindings({ sizeBind, appearBind, opacityBind }):map(function(values: { number }): UDim2
		local scale = (0.5 + values[2] * 0.5) * (0.4 + values[3] * 0.6)
		local rounded = math.floor(values[1] * scale)
		return UDim2.fromOffset(rounded, rounded)
	end)

	local visibleBind = React.joinBindings({ appearBind, opacityBind }):map(function(values: { number }): number
		return values[1] * values[2]
	end)

	local strokeThicknessBind = sizeBind:map(function(v: number): number
		return math.clamp(math.floor(v * 0.035 + 0.5), 1, 2)
	end)

	local bgTransparencyBind = visibleBind:map(function(v: number): number
		return 0.25 + (1 - v) * 0.75
	end)

	local accentTransparencyBind = visibleBind:map(function(v: number): number
		return math.clamp(1 - v, 0, 1)
	end)

	local surfaceTransparencyBind = visibleBind:map(function(v: number): number
		return 1 - v * 0.12
	end)

	local nameVisibleBind = nameBind:map(function(value: string): boolean
		return value ~= ""
	end)

	return e("Frame", {
		AnchorPoint = CENTER_ANCHOR,
		Position = positionBind,
		Size = sizeUdimBind,
		BackgroundColor3 = bgColor,
		BackgroundTransparency = bgTransparencyBind,
		BorderSizePixel = 0,
	}, {
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
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = entry.icon,
			ImageColor3 = colorBind,
			ImageTransparency = accentTransparencyBind,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
		}),
		Name = e("Frame", {
			AnchorPoint = NAME_ANCHOR,
			Position = UDim2.new(0.5, 0, 1, 4),
			Size = UDim2.fromOffset(0, NAME_TEXT_SIZE + 3),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = bgColor,
			BackgroundTransparency = bgTransparencyBind,
			BorderSizePixel = 0,
			Visible = nameVisibleBind,
			ZIndex = 3,
		}, {
			UICorner = e("UICorner", { CornerRadius = NAME_CORNER }),
			UIPadding = e("UIPadding", {
				PaddingLeft = NAME_PAD,
				PaddingRight = NAME_PAD,
			}),
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = nameBind,
				TextSize = NAME_TEXT_SIZE,
				TextColor3 = colorBind,
				TextTransparency = accentTransparencyBind,
				FontFace = FileController.Get("font", "semi_bold"),
				Size = UDim2.fromOffset(0, NAME_TEXT_SIZE - 1),
				AutomaticSize = Enum.AutomaticSize.X,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		}),
	})
end)

type RootProps = {
	enabledLink: any,
	enemyColorLink: any,
	friendlyColorLink: any,
	localColorLink: any,
	neutralColorLink: any,
	showEnemyLink: any,
	showFriendlyLink: any,
	showLocalLink: any,
	showNeutralLink: any,
	bgColorLink: any,
}

return LPH_NO_VIRTUALIZE(function(props: RootProps): React.Element<any>?
	local enabled = useAt(props.enabledLink._state) :: boolean
	local entries = useAt(CameraController.active) :: { [number]: any }

	if not enabled then
		return nil
	end

	local bgColor = props.bgColorLink._currentColor

	local children: { [string]: any } = {}
	for id, entry in next, entries do
		children["c" .. id] = e(Marker, {
			entry = entry,
			enemyColorLink = props.enemyColorLink,
			friendlyColorLink = props.friendlyColorLink,
			localColorLink = props.localColorLink,
			neutralColorLink = props.neutralColorLink,
			showEnemyLink = props.showEnemyLink,
			showFriendlyLink = props.showFriendlyLink,
			showLocalLink = props.showLocalLink,
			showNeutralLink = props.showNeutralLink,
			bgColor = bgColor,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, children)
end)
