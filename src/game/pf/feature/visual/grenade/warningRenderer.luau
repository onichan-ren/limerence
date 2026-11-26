local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")
local useShadow = require("@ui/hook/useShadow")
local ModuleController = require("@game/pf/module/ModuleController")
local grenadeState = require("@game/pf/grenade/grenadeState")
local localThirdPerson = require("@game/pf/thirdperson/localThirdPerson")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local e = React.createElement
local useBinding = React.useBinding
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local useState = React.useState
local useRef = React.useRef

local peek = Charm.peek

local EDGE_PADDING = 40
local MIN_SIZE_RATIO = 0.4
local SIZE_REFERENCE_DISTANCE = 30
local MAX_VISIBLE_DISTANCE = 90
local ONSCREEN_FADE_START_RATIO = 0.7
local OFFSCREEN_MAX_DISTANCE = 60
local OFFSCREEN_FADE_START_RATIO = 0.6
local LEAVE_DURATION = 0.4
local OUTLINE = Color3.fromRGB(18, 18, 18)
local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local SHADOW_MULT = Vector2.new(1.22, 1.22)
local BAR_SIZE = UDim2.fromScale(0.46, 0.055)
local BAR_POSITION = UDim2.fromScale(0.5, 0.84)
local BAR_ANCHOR = Vector2.new(0.5, 0.5)
local CORNER_FULL = UDim.new(1, 0)
local CORNER_FRAME = UDim.new(1, 0)
local ICON_BASE_SCALE = 0.52
local ICON_LIFT = 0.16
local ICON_SHRINK = 0.06
local DAMAGE_POSITION = UDim2.fromScale(0.5, 0.7)
local DAMAGE_SIZE = UDim2.fromScale(0.8, 0.2)

local APPEAR_SPRING = { dampingRatio = 0.65, frequency = 3.5, precision = 0.005 }
local FOLLOW_SPRING = { dampingRatio = 1.2, frequency = 9, precision = 0.5 }
local SIZE_SPRING = { dampingRatio = 1.0, frequency = 5, precision = 0.5 }
local DAMAGE_SPRING = { dampingRatio = 0.7, frequency = 4.0, precision = 0.005 }
local TEXT_FADE_SPRING = { dampingRatio = 1.2, frequency = 9.0, precision = 0.005 }

local _weaponUtils: any = nil

local function interpDamage(graph: any, distance: number): number
	if type(graph) ~= "table" then
		return 0
	end
	if not _weaponUtils then
		_weaponUtils = ModuleController.GetModule("WeaponUtils")
	end
	if not _weaponUtils then
		return 0
	end
	local value = _weaponUtils.interpolateDamageGraph(graph, distance)
	if type(value) == "number" then
		return value
	end
	return 0
end

local function maxDamageDistance(graph: any): number
	if type(graph) ~= "table" then
		return 0
	end
	local last = graph[#graph]
	if type(last) == "table" and type(last.distance) == "number" then
		return last.distance
	end
	return math.huge
end

local _losParams = RaycastParams.new()
_losParams.FilterType = Enum.RaycastFilterType.Exclude
_losParams.IgnoreWater = true

local _losFilter: { Instance } = {}
local _ignoreFolder: Instance? = nil
local _playersFolder: Instance? = nil

local losBlocked = LPH_NO_VIRTUALIZE(function(origin: Vector3, target: Vector3, selfModel: Instance?): boolean
	local disp = target - origin
	if disp.Magnitude < 1e-3 then
		return false
	end
	if not _ignoreFolder or _ignoreFolder.Parent ~= Workspace then
		_ignoreFolder = Workspace:FindFirstChild("Ignore")
	end
	if not _playersFolder or _playersFolder.Parent ~= Workspace then
		_playersFolder = Workspace:FindFirstChild("Players")
	end
	local filter = _losFilter
	table.clear(filter)
	filter[1] = Workspace.CurrentCamera :: Instance
	filter[2] = Workspace.Terrain :: Instance
	if _ignoreFolder then
		filter[#filter + 1] = _ignoreFolder
	end
	if _playersFolder then
		filter[#filter + 1] = _playersFolder
	end
	if selfModel then
		filter[#filter + 1] = selfModel
	end
	local body = localThirdPerson.getCharacterModel()
	if body then
		filter[#filter + 1] = body
	end
	_losParams.FilterDescendantsInstances = filter

	local pos = origin
	while true do
		local result = Workspace:Raycast(pos, target - pos, _losParams)
		if not result then
			return false
		end
		local inst = result.Instance
		if inst.CanCollide and inst.Transparency < 1 then
			return true
		end
		filter[#filter + 1] = inst
		_losParams.FilterDescendantsInstances = filter
		pos = result.Position + (target - result.Position).Unit * 0.01
		if (target - pos).Magnitude < 0.05 then
			return false
		end
	end
end)

local _characterInterface: any = nil

local function localRoot(): BasePart?
	if not _characterInterface then
		_characterInterface = ModuleController.GetModule("CharacterInterface")
	end
	if not _characterInterface then
		return nil
	end
	local co = _characterInterface.getCharacterObject()
	if not co then
		return nil
	end
	return co:getRealRootPart()
end

type WarningSource = {
	position: Vector3,
	startedAt: number,
	duration: number,
	damageGraph: any,
	isFriendly: boolean,
	isSelf: boolean,
}

local function toSource(entry: grenadeState.IncomingGrenade): WarningSource
	return {
		position = entry.landing,
		startedAt = entry.detonateAt - entry.fuse,
		duration = entry.fuse,
		damageGraph = entry.damageGraph,
		isFriendly = entry.isFriendly,
		isSelf = entry.isSelf,
	}
end

type WarningProps = {
	source: WarningSource,
	color: any,
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
		setDamage: (string) -> (),
		xSpring: any,
		ySpring: any,
		sizeSpring: any,
		damageActiveSpring: any,
		damageTextActiveSpring: any
	): ()
		local elapsed = os.clock() - source.startedAt
		local duration = source.duration
		local remaining = duration - elapsed
		if remaining < 0 then
			remaining = 0
		end
		setProgress(duration > 0 and remaining / duration or 0)

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local viewport = camera.ViewportSize
		local vx, vy = viewport.X, viewport.Y
		local maxSize = (vx < vy and vx or vy) / 16

		local firePos = source.position
		local screenPos = camera:WorldToViewportPoint(firePos)
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
		local ddx = firePos.X - camPos.X
		local ddy = firePos.Y - camPos.Y
		local ddz = firePos.Z - camPos.Z
		local distance = math.sqrt(ddx * ddx + ddy * ddy + ddz * ddz)
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

		local dmg = 0
		local root = localRoot()
		if root then
			local victimPos = (root :: any).Position
			local victimDistance = (victimPos - firePos).Magnitude
			if
				victimDistance < maxDamageDistance(source.damageGraph)
				and not losBlocked(firePos, victimPos, (root :: any).Parent)
			then
				dmg = interpDamage(source.damageGraph, victimDistance)
			end
		end
		if dmg <= 0 then
			setDamage("")
			damageActiveSpring:setGoal(0)
			damageTextActiveSpring:setGoal(0)
		elseif dmg >= 100 then
			setDamage("LETHAL")
			damageActiveSpring:setGoal(1)
			damageTextActiveSpring:setGoal(1)
		else
			setDamage(string.format("%d dmg", math.floor(dmg + 0.5)))
			damageActiveSpring:setGoal(1)
			damageTextActiveSpring:setGoal(1)
		end
	end
)

local Warning = LPH_JIT_MAX(function(props: WarningProps): React.Element<any>?
	local source = props.source
	local color = props.color
	local bgColor = props.bgColor

	local progressBind, setProgress = useBinding(1)
	local distanceBind, setDistance = useBinding(1)
	local xBind, xSpring = useSpring(0, FOLLOW_SPRING)
	local yBind, ySpring = useSpring(0, FOLLOW_SPRING)
	local sizeBind, sizeSpring = useSpring(0, SIZE_SPRING)
	local appearBind, appearSpring = useSpring(0, APPEAR_SPRING)
	local damageActiveBind, damageActiveSpring = useSpring(0, DAMAGE_SPRING)
	local damageTextActiveBind, damageTextActiveSpring = useSpring(0, TEXT_FADE_SPRING)
	local damageBind, setDamage = useBinding("")

	useEffect(function()
		appearSpring:setGoal(props.leaving and 0 or 1)
	end, { props.leaving })

	useEffect(function()
		local stepState: StepState = { firstStep = true }
		local function step(): ()
			runWarningStep(
				source,
				stepState,
				setProgress,
				setDistance,
				setDamage,
				xSpring,
				ySpring,
				sizeSpring,
				damageActiveSpring,
				damageTextActiveSpring
			)
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

	local sizeUdimBind = React.joinBindings({ sizeBind, appearBind }):map(function(values: { number }): UDim2
		local scale = 0.45 + values[2] * 0.55
		local rounded = math.floor(values[1] * scale)
		return UDim2.fromOffset(rounded, rounded)
	end)

	local opacityBind = React.joinBindings({ appearBind, distanceBind }):map(function(values: { number }): number
		return values[1] * values[2]
	end)

	local iconSizeBind = damageActiveBind:map(function(t: number): UDim2
		local scale = ICON_BASE_SCALE - t * ICON_SHRINK
		return UDim2.fromScale(scale, scale)
	end)

	local iconPositionBind = damageActiveBind:map(function(t: number): UDim2
		return UDim2.new(0.5, 0, 0.5 - t * ICON_LIFT, 0)
	end)

	local strokeThicknessBind = sizeBind:map(function(v: number): number
		return math.clamp(math.floor(v * 0.03 + 0.5), 1, 2)
	end)

	local damageTextTransparencyBind = React.joinBindings({ opacityBind, damageTextActiveBind })
		:map(function(values: { number }): number
			return math.clamp(1 - values[1] * values[2], 0, 1)
		end)

	local damageTextSizeBind = sizeBind:map(function(v: number): number
		return math.clamp(math.floor(v * 0.19), 6, 10)
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
			CornerRadius = CORNER_FRAME,
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
		Warning = e("ImageLabel", {
			Size = iconSizeBind,
			AnchorPoint = CENTER_ANCHOR,
			Position = iconPositionBind,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = FileController.Get("image", "he_grenade"),
			ImageColor3 = color,
			ImageTransparency = accentTransparencyBind,
			ZIndex = 2,
		}),
		DamageText = e("TextLabel", {
			AnchorPoint = CENTER_ANCHOR,
			Position = DAMAGE_POSITION,
			Size = DAMAGE_SIZE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = damageBind,
			TextColor3 = color,
			TextTransparency = damageTextTransparencyBind,
			TextStrokeColor3 = OUTLINE,
			TextStrokeTransparency = damageTextTransparencyBind,
			FontFace = FileController.Get("font", "semi_bold"),
			TextScaled = false,
			TextSize = damageTextSizeBind,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 3,
		}),
		Bar = e("Frame", {
			Size = BAR_SIZE,
			Position = BAR_POSITION,
			AnchorPoint = BAR_ANCHOR,
			BackgroundColor3 = OUTLINE,
			BackgroundTransparency = barBackgroundBind,
			BorderSizePixel = 0,
			ClipsDescendants = true,
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
		}),
	})
end)

type RootProps = {
	enabledLink: any,
	showFriendlyLink: any,
	enemyColorLink: any,
	friendlyColorLink: any,
	lethalColorLink: any,
	backgroundColorLink: any,
}

return LPH_NO_VIRTUALIZE(function(props: RootProps): React.Element<any>?
	local enabled = useAt(props.enabledLink._state) :: boolean
	local showFriendly = useAt(props.showFriendlyLink._state) :: boolean

	local _, forceUpdate = useState(0)
	local displayRef = useRef(nil :: any)
	if displayRef.current == nil then
		displayRef.current = {}
	end
	local scratchRef = useRef(nil :: any)
	if scratchRef.current == nil then
		scratchRef.current = { seen = {} :: { [string]: boolean }, ids = {} :: { [any]: string } }
	end

	useEffect(function(): () -> ()
		local conn = RunService.Heartbeat:Connect(function(): ()
			local incoming = peek(grenadeState.incoming)
			local display = displayRef.current
			local scratch = scratchRef.current
			local seen = scratch.seen
			local ids = scratch.ids
			local now = os.clock()
			local dirty = false
			table.clear(seen)

			for key, entry in next, incoming do
				local id = ids[key]
				if not id then
					id = tostring(key)
					ids[key] = id
				end
				seen[id] = true
				local d = display[id]
				if not d then
					display[id] = { source = toSource(entry), leaving = false, key = key }
					dirty = true
				elseif d.leaving then
					d.leaving = false
					d.removeAt = nil
					dirty = true
				end
			end

			for id, d in next, display do
				if not seen[id] then
					if not d.leaving then
						d.leaving = true
						d.removeAt = now + LEAVE_DURATION
						dirty = true
					elseif now >= (d.removeAt or 0) then
						display[id] = nil
						ids[d.key] = nil
						dirty = true
					end
				end
			end

			if dirty then
				forceUpdate(function(n: number): number
					return n + 1
				end)
			end
		end)
		return function(): ()
			conn:Disconnect()
		end
	end, {})

	if not enabled then
		return nil
	end

	local enemyColor = props.enemyColorLink:GetColor()
	local friendlyColor = props.friendlyColorLink:GetColor()
	local bgColor = props.backgroundColorLink:GetColor()

	local children: { [string]: any } = {}
	for id, d in next, displayRef.current do
		local source = d.source
		if source.isFriendly and not source.isSelf and not showFriendly then
			continue
		end
		local color = (source.isFriendly and not source.isSelf) and friendlyColor or enemyColor
		children[id] = e(Warning, {
			source = source,
			color = color,
			bgColor = bgColor,
			leaving = d.leaving,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, children)
end)
