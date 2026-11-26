local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")

local FileController = require("@src/feature/file/FileController")
local useShadow = require("@ui/hook/useShadow")

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
local MIN_SIZE_RATIO = 0.25
local SIZE_REFERENCE_DISTANCE = 30
local FADE_START_RATIO = 0.7
local LEAVE_DURATION = 0.4
local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local SHADOW_MULT = Vector2.new(1.22, 1.22)
local BAR_SIZE = UDim2.fromScale(0.46, 0.055)
local BAR_POSITION = UDim2.fromScale(0.5, 0.84)
local CORNER_FULL = UDim.new(1, 0)
local OUTLINE = Color3.fromRGB(18, 18, 18)
local LABEL_POSITION = UDim2.fromScale(0.5, 1)
local LABEL_OFFSET = UDim2.fromOffset(0, 4)

local mmax = math.max
local mabs = math.abs
local mfloor = math.floor
local mclamp = math.clamp
local matan2 = math.atan2
local mcos = math.cos
local msin = math.sin
local mhuge = math.huge

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

export type Entry = {
	id: string,
}

export type Adapter = {
	shouldShow: (entry: any) -> boolean,
	isVisible: ((entry: any) -> boolean)?,
	resolvePosition: (entry: any) -> Vector3,
	resolveDuration: ((entry: any) -> (number?, number?))?,
	resolveIcon: ((entry: any) -> string?)?,
	resolveLabel: ((entry: any, distance: number, remaining: number?) -> string?)?,
	resolveColorKey: ((entry: any) -> string?)?,
}

export type RootProps = {
	enabledAtom: any,
	entriesAtom: any,
	adapter: Adapter,
	clampOffscreen: boolean,
	showBar: boolean,
	maxDistance: number,
	markerScale: number,
	color: any,
	bgColor: any,
	colorByKey: { [string]: any }?,
}

type Source = {
	id: string,
	entry: any,
}

type DisplayEntry = {
	source: Source,
	leaving: boolean,
}

local function makeController(entriesAtom: any, adapter: Adapter)
	local displayWarnings = at({} :: { [string]: DisplayEntry })
	local leavingTimers: { [string]: thread } = {}

	local function removeFromDisplay(id: string): ()
		local now = peek(displayWarnings)
		if not now[id] then
			return
		end
		local nextMap: { [string]: DisplayEntry } = {}
		for k, v in next, now do
			if k ~= id then
				nextMap[k] = v
			end
		end
		displayWarnings(nextMap)
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

	local function reconcile(): ()
		local current = peek(displayWarnings)
		local active: { [string]: Source } = {}
		for id, entry in next, peek(entriesAtom) do
			if adapter.shouldShow(entry) then
				active[id] = { id = id, entry = entry }
			end
		end

		local nextDisplay: { [string]: DisplayEntry } = {}
		for id, source in next, active do
			local existing = current[id]
			if existing and existing.leaving then
				nextDisplay[id] = existing
			else
				nextDisplay[id] = { source = source, leaving = false }
				local leaveTimer = leavingTimers[id]
				if leaveTimer then
					task.cancel(leaveTimer)
					leavingTimers[id] = nil
				end
			end
		end

		for id, entry in next, current do
			if not active[id] then
				if entry.leaving then
					nextDisplay[id] = entry
				else
					nextDisplay[id] = { source = entry.source, leaving = true }
					startLeaveTimer(id)
				end
			end
		end

		displayWarnings(nextDisplay)
	end

	return displayWarnings, reconcile
end

type MarkerProps = {
	source: Source,
	adapter: Adapter,
	clampOffscreen: boolean,
	showBar: boolean,
	maxDistance: number,
	markerScale: number,
	color: any,
	bgColor: any,
	leaving: boolean,
}

local runMarkerStep = LPH_NO_VIRTUALIZE(
	function(
		props: MarkerProps,
		stepState: { firstStep: boolean },
		setProgress: (number) -> (),
		setHasBar: (boolean) -> (),
		setDistance: (number) -> (),
		setLabel: (string) -> (),
		xSpring: any,
		ySpring: any,
		sizeSpring: any
	): ()
		local adapter = props.adapter
		local entry = props.source.entry

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		if adapter.isVisible and not adapter.isVisible(entry) then
			setDistance(0)
			return
		end

		local camCFrame = camera.CFrame
		local viewport = camera.ViewportSize
		local vx, vy = viewport.X, viewport.Y
		local maxSize = (vx < vy and vx or vy) / 16 * props.markerScale

		local worldPos = adapter.resolvePosition(entry)
		local screenPos = camera:WorldToViewportPoint(worldPos)
		local sx = screenPos.X
		local sy = screenPos.Y
		local behind = screenPos.Z <= 0

		local cx = vx * 0.5
		local cy = vy * 0.5
		local distance = (worldPos - camCFrame.Position).Magnitude

		local remaining: number? = nil
		if adapter.resolveDuration then
			local duration, rem = adapter.resolveDuration(entry)
			if duration then
				setHasBar(true)
				setProgress(duration > 0 and mclamp((rem or 0) / duration, 0, 1) or 0)
				remaining = rem
			else
				setHasBar(false)
			end
		end

		if adapter.resolveLabel then
			setLabel(adapter.resolveLabel(entry, distance, remaining) or "")
		end

		if behind then
			sx = vx - sx
			sy = vy - sy
		end

		local offscreen = behind
			or sx < EDGE_PADDING
			or sx > vx - EDGE_PADDING
			or sy < EDGE_PADDING
			or sy > vy - EDGE_PADDING

		if offscreen and not props.clampOffscreen then
			setDistance(0)
			return
		end

		if offscreen then
			local dx = sx - cx
			local dy = sy - cy
			if mabs(dx) < 0.5 and mabs(dy) < 0.5 then
				dx = 1
				dy = 0
			end
			local angle = matan2(dy, dx)
			local cosA = mcos(angle)
			local sinA = msin(angle)
			local maxX = cx - EDGE_PADDING
			local maxY = cy - EDGE_PADDING
			local absCos = mabs(cosA)
			local absSin = mabs(sinA)
			local tX = (absCos > 0.001 and maxX / absCos or mhuge)
			local tY = (absSin > 0.001 and maxY / absSin or mhuge)
			local t = (tX < tY and tX or tY)
			sx = cx + t * cosA
			sy = cy + t * sinA
		end

		local sizeFactor = mclamp(SIZE_REFERENCE_DISTANCE / (distance > 10 and distance or 10), MIN_SIZE_RATIO, 1)
		local targetSize = maxSize * sizeFactor

		local maxDistance = props.maxDistance
		local fadeStart = maxDistance * FADE_START_RATIO
		local fadeRange = mmax(maxDistance - fadeStart, 1)
		setDistance(mclamp(1 - (distance - fadeStart) / fadeRange, 0, 1))

		if stepState.firstStep then
			stepState.firstStep = false
			xSpring:setPosition(sx)
			ySpring:setPosition(sy)
			sizeSpring:setPosition(targetSize)
		elseif not offscreen then
			xSpring:setPosition(sx)
			ySpring:setPosition(sy)
		end

		xSpring:setGoal(sx)
		ySpring:setGoal(sy)
		sizeSpring:setGoal(targetSize)
	end
)

local Marker = LPH_NO_VIRTUALIZE(function(props: MarkerProps): React.Element<any>?
	local color = props.color
	local bgColor = props.bgColor
	local adapter = props.adapter
	local hasIcon = adapter.resolveIcon ~= nil
	local hasLabelResolver = adapter.resolveLabel ~= nil

	local progressBind, setProgress = useBinding(1)
	local hasBarBind, setHasBar = useBinding(false)
	local distanceBind, setDistance = useBinding(1)
	local labelBind, setLabel = useBinding("")
	local xBind, xSpring = useSpring(0, FOLLOW_SPRING)
	local yBind, ySpring = useSpring(0, FOLLOW_SPRING)
	local sizeBind, sizeSpring = useSpring(0, SIZE_SPRING)
	local appearBind, appearSpring = useSpring(0, APPEAR_SPRING)

	local iconImage = hasIcon and (adapter.resolveIcon :: any)(props.source.entry) or nil

	local propsRef = React.useRef(props)
	propsRef.current = props

	useEffect(function()
		appearSpring:setGoal(props.leaving and 0 or 1)
	end, { props.leaving })

	useEffect(function()
		local stepState = { firstStep = true }
		local function step(): ()
			runMarkerStep(
				propsRef.current,
				stepState,
				setProgress,
				setHasBar,
				setDistance,
				setLabel,
				xSpring,
				ySpring,
				sizeSpring
			)
		end
		step()
		local conn = RunService.PreRender:Connect(step)
		return function()
			conn:Disconnect()
		end
	end, {})

	local positionBind = React.joinBindings({ xBind, yBind }):map(function(values): UDim2
		return UDim2.fromOffset(mfloor(values[1]), mfloor(values[2]))
	end)

	local sizeUdimBind = React.joinBindings({ sizeBind, appearBind }):map(function(values: { number }): UDim2
		local scale = 0.45 + values[2] * 0.55
		local rounded = mfloor(values[1] * scale)
		return UDim2.fromOffset(rounded, rounded)
	end)

	local opacityBind = React.joinBindings({ appearBind, distanceBind }):map(function(values: { number }): number
		return values[1] * values[2]
	end)

	local strokeThicknessBind = sizeBind:map(function(v: number): number
		return mclamp(mfloor(v * 0.03 + 0.5), 1, 2)
	end)

	local bgTransparencyBind = opacityBind:map(function(v: number): number
		return 0.25 + (1 - v) * 0.75
	end)

	local accentTransparencyBind = opacityBind:map(function(v: number): number
		return mclamp(1 - v, 0, 1)
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

	local barVisibleBind = React.joinBindings({ hasBarBind, opacityBind }):map(function(values: { any }): boolean
		return values[1] == true and values[2] > 0.01
	end)

	local barFillSizeBind = progressBind:map(function(p: number): UDim2
		return UDim2.fromScale(mclamp(p, 0, 1), 1)
	end)

	local labelTextSizeBind = sizeBind:map(function(v: number): number
		return mclamp(mfloor(v * 0.34), 9, 16)
	end)

	local labelTransparencyBind = opacityBind:map(function(v: number): number
		return mclamp(1 - v, 0, 1)
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
			CornerRadius = CORNER_FULL,
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
		Icon = (hasIcon and iconImage) and e("ImageLabel", {
			Size = UDim2.fromScale(0.52, 0.52),
			AnchorPoint = CENTER_ANCHOR,
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = FileController.Get("image", iconImage),
			ImageColor3 = color,
			ImageTransparency = accentTransparencyBind,
			ZIndex = 2,
		}) or nil,
		Bar = props.showBar and e("Frame", {
			Size = BAR_SIZE,
			Position = BAR_POSITION,
			AnchorPoint = CENTER_ANCHOR,
			BackgroundColor3 = OUTLINE,
			BackgroundTransparency = barBackgroundBind,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Visible = barVisibleBind,
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
		}) or nil,
		Label = hasLabelResolver and e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = LABEL_POSITION + LABEL_OFFSET,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = labelBind,
			TextColor3 = color,
			TextTransparency = labelTransparencyBind,
			TextStrokeColor3 = OUTLINE,
			TextStrokeTransparency = labelTransparencyBind,
			FontFace = FileController.Get("font", "semi_bold"),
			TextScaled = false,
			TextSize = labelTextSizeBind,
			ZIndex = 3,
		}) or nil,
	})
end)

return LPH_NO_VIRTUALIZE(function(props: RootProps): React.Element<any>?
	local enabled = useAt(props.enabledAtom) :: boolean

	local controllerRef = React.useRef(nil :: any)
	if controllerRef.current == nil then
		local displayWarnings, reconcile = makeController(props.entriesAtom, props.adapter)
		controllerRef.current = { displayWarnings = displayWarnings, reconcile = reconcile }
	end
	local controller = controllerRef.current
	local entries = useAt(controller.displayWarnings) :: { [string]: DisplayEntry }

	useEffect(function()
		controller.reconcile()
		local disconnect = sub(props.entriesAtom, controller.reconcile)
		return disconnect
	end, {})

	if not enabled then
		return nil
	end

	local adapter = props.adapter
	local colorByKey = props.colorByKey
	local resolveColorKey = adapter.resolveColorKey

	local children: { [string]: any } = {}
	for id, entry in next, entries do
		local markerColor = props.color
		if resolveColorKey and colorByKey then
			local key = resolveColorKey(entry.source.entry)
			if key and colorByKey[key] then
				markerColor = colorByKey[key]
			end
		end
		children[id] = e(Marker, {
			source = entry.source,
			adapter = adapter,
			clampOffscreen = props.clampOffscreen,
			showBar = props.showBar,
			maxDistance = props.maxDistance,
			markerScale = props.markerScale,
			color = markerColor,
			bgColor = props.bgColor,
			leaving = entry.leaving,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, children)
end)
