local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local PlayerController = require("@feature/player/PlayerController")
local gameRegistry = require("@game/gameRegistry")
local themeState = require("@ui/theme/themeState")
local uiState = require("@ui/uiState")
local contextApi = require("@ui/subwindow/context/contextApi")
local cursor = require("@ui/util/cursor")
local useDraggable = require("@ui/hook/useDraggable")
local useHudHover = require("@ui/hook/useHudHover")
local useShadow = require("@ui/hook/useShadow")
local SPRING = require("@ui/util/spring")

local e = React.createElement
local createBinding = React.createBinding
local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useCallback = React.useCallback
local useAt = ReactCharm.useAtom
local useSpring = ReactRipple.useSpring
local peek = Charm.peek

local colors = themeState.colors.hud

local POOL = 24
local DEFAULT_RANGE = 120
local CORNER = 6
local LINE_ALPHA = 0.25
local EDGE_CLAMP = 0.92
local EDGE_DIM = 0.45
local CENTER_SIZE = 7

local step = LPH_NO_VIRTUALIZE(function(state: any, fade: number): ()
	local slots = state.slots
	local used = 0

	if fade > 0.005 then
		local camera = Workspace.CurrentCamera
		if camera then
			local cf = camera.CFrame
			local look = cf.LookVector
			local fx, fz = look.X, look.Z
			local lenSq = fx * fx + fz * fz
			if lenSq < 1e-4 then
				local up = cf.UpVector
				fx, fz = up.X, up.Z
				lenSq = fx * fx + fz * fz
			end
			if lenSq > 1e-6 then
				local inv = 1 / math.sqrt(lenSq)
				fx *= inv
				fz *= inv
				local rx, rz = -fz, fx

				local centerPos = cf.Position
				local clientState = gameRegistry.clientState
				if clientState then
					local hrp = peek(clientState.parts).HumanoidRootPart :: BasePart?
					if hrp then
						centerPos = hrp.Position
					end
				end

				local getRange = state.getRange
				local range = DEFAULT_RANGE
				if getRange then
					local mapRange = getRange()
					if mapRange then
						range = mapRange
					end
					range *= (peek(state.mapScaleEl._state) :: number) / 100
				else
					range = peek(state.rangeEl._state) :: number
				end
				local showTeam = peek(state.showTeamEl._state) :: boolean
				local enemyColor = state.enemyEl:GetColor() :: Color3
				local teamColor = state.teamEl:GetColor() :: Color3
				local isTeammate = state.isTeammate
				local filter = state.filter

				for _, basePlayer in next, PlayerController.GetAll() do
					if not peek(basePlayer.alive) then
						continue
					end
					if filter and filter(basePlayer) then
						continue
					end
					local hrp = peek(basePlayer.hrp) :: BasePart?
					if not hrp then
						continue
					end
					local isTeam = false
					if isTeammate then
						isTeam = isTeammate(basePlayer)
					end
					if isTeam and not showTeam then
						continue
					end
					if used >= POOL then
						break
					end

					local position = hrp.Position
					local dx, dz = position.X - centerPos.X, position.Z - centerPos.Z
					local x = (dx * rx + dz * rz) / range
					local y = -(dx * fx + dz * fz) / range
					local edge = false
					local extent = math.max(math.abs(x), math.abs(y))
					if extent > EDGE_CLAMP then
						local scale = EDGE_CLAMP / extent
						x *= scale
						y *= scale
						edge = true
					end

					used += 1
					local slot = slots[used]
					slot.setPos(UDim2.fromScale(0.5 + x * 0.5, 0.5 + y * 0.5))
					local color = isTeam and teamColor or enemyColor
					if slot.color ~= color then
						slot.color = color
						slot.setColor(color)
					end
					local trans = 1 - fade * (edge and EDGE_DIM or 1)
					if slot.trans ~= trans then
						slot.trans = trans
						slot.setTrans(trans)
					end
				end
			end
		end
	end

	for i = used + 1, POOL do
		local slot = slots[i]
		if slot.trans ~= 1 then
			slot.trans = 1
			slot.setTrans(1)
		end
	end
end)

return function(props: {
	open: any,
	position: any,
	sizeEl: any,
	rangeEl: any,
	dotSizeEl: any,
	showTeamEl: any,
	enemyColorEl: any,
	teamColorEl: any,
	resetPosition: UDim2,
	isTeammate: ((basePlayer: any) -> boolean)?,
	getRange: (() -> number?)?,
	filter: ((basePlayer: any) -> boolean)?,
	mapScaleEl: any,
}): React.Element<any>
	local open = useAt(props.open) :: boolean
	local menuOpen = useAt(uiState.isOpen) :: boolean
	local size = useAt(props.sizeEl._state) :: number
	local dotSize = useAt(props.dotSizeEl._state) :: number
	local accentColor = useAt(themeState.colors.window.element.accent) :: Color3

	local bgPack = useAt(colors.background)
	local bgColor = bgPack[1] :: Color3
	local bgAlpha = bgPack[2] :: number

	local strokePack = useAt(colors.stroke)
	local strokeColor = strokePack[1] :: Color3
	local strokeAlpha = strokePack[2] :: number

	local shadowPack = useAt(colors.shadow)
	local shadowColor = shadowPack[1] :: Color3
	local shadowAlpha = shadowPack[2] :: number

	local fadeBind, fadeSpring = useSpring(0, SPRING.smooth)
	useEffect(function(): ()
		fadeSpring:setGoal(open and 1 or 0)
	end, { open })

	local positionAtom = props.position._state
	local onDragInput, positionBind = useDraggable(positionAtom)
	local onHoverEnter, onHoverLeave, hoverGlow = useHudHover(menuOpen and open)

	local stateRef = useRef(nil :: any)
	if not stateRef.current then
		local slots: { any } = {}
		for i = 1, POOL do
			local posBind, setPos = createBinding(UDim2.fromScale(0.5, 0.5))
			local colorBind, setColor = createBinding(Color3.new(1, 1, 1))
			local transBind, setTrans = createBinding(1)
			slots[i] = {
				posBind = posBind,
				setPos = setPos,
				colorBind = colorBind,
				setColor = setColor,
				transBind = transBind,
				setTrans = setTrans,
				color = nil,
				trans = 1,
			}
		end
		stateRef.current = { slots = slots }
	end
	local state = stateRef.current
	state.rangeEl = props.rangeEl
	state.showTeamEl = props.showTeamEl
	state.enemyEl = props.enemyColorEl
	state.teamEl = props.teamColorEl
	state.isTeammate = props.isTeammate
	state.filter = props.filter
	state.getRange = props.getRange
	state.mapScaleEl = props.mapScaleEl

	useEffect(function(): () -> ()
		local conn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
			step(state, fadeBind:getValue())
		end))
		return function(): ()
			conn:Disconnect()
		end
	end, {})

	local onInputBegan = useCallback(function(_: any, input: InputObject): ()
		if not menuOpen or not open then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onDragInput(input)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			contextApi.Open({
				{
					Label = "Reset Position",
					Callback = function(): ()
						positionAtom(props.resetPosition)
					end,
				},
			}, cursor.getPosition(input))
		end
	end, { menuOpen, open } :: { any })

	local visible = useMemo(function()
		return fadeBind:map(function(v: number): boolean
			return v > 0.005
		end)
	end, { fadeBind })

	local bgTransparency = useMemo(function()
		return fadeBind:map(function(v: number): number
			return 1 - v * (1 - bgAlpha)
		end)
	end, { fadeBind, bgAlpha } :: { any })

	local strokeTransparency = useMemo(function()
		return fadeBind:map(function(v: number): number
			return 1 - v * (1 - strokeAlpha)
		end)
	end, { fadeBind, strokeAlpha } :: { any })

	local shadowTransparency = useMemo(function()
		return fadeBind:map(function(v: number): number
			return 1 - v * (1 - shadowAlpha)
		end)
	end, { fadeBind, shadowAlpha } :: { any })

	local lineTransparency = useMemo(function()
		return fadeBind:map(function(v: number): number
			return 1 - v * LINE_ALPHA
		end)
	end, { fadeBind })

	local centerTransparency = useMemo(function()
		return fadeBind:map(function(v: number): number
			return 1 - v
		end)
	end, { fadeBind })

	local dotImage = FileController.Get("image", "circle_shadow")

	local bodyChildren: { [string]: any } = {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, CORNER),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor,
			Transparency = strokeTransparency,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		LineV = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0, 1, 1, 0),
			BackgroundColor3 = strokeColor,
			BackgroundTransparency = lineTransparency,
			BorderSizePixel = 0,
			ZIndex = 1,
		}),
		LineH = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = strokeColor,
			BackgroundTransparency = lineTransparency,
			BorderSizePixel = 0,
			ZIndex = 1,
		}),
		Center = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(CENTER_SIZE, CENTER_SIZE),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = dotImage,
			ImageColor3 = accentColor,
			ImageTransparency = centerTransparency,
			ZIndex = 3,
		}),
	}

	local slots = state.slots :: { any }
	for i = 1, POOL do
		local slot = slots[i]
		bodyChildren["blip" .. i] = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = slot.posBind,
			Size = UDim2.fromOffset(dotSize, dotSize),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = dotImage,
			ImageColor3 = slot.colorBind,
			ImageTransparency = slot.transBind,
			ZIndex = 2,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = visible,
		Active = false,
		ZIndex = 2,
	}, {
		Root = e("Frame", {
			Active = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = positionBind,
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 2,
			[React.Event.InputBegan] = onInputBegan,
			[React.Event.MouseEnter] = onHoverEnter,
			[React.Event.MouseLeave] = onHoverLeave,
		}, {
			Glow = hoverGlow,
			Shadow = useShadow({
				color = shadowColor,
				transparency = shadowTransparency,
				zIndex = 0,
				multiplier = Vector2.new(1.12, 1.12),
			}),
			Body = e("Frame", {
				BackgroundColor3 = bgColor,
				BackgroundTransparency = bgTransparency,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ClipsDescendants = true,
				ZIndex = 1,
			}, bodyChildren),
		}),
	})
end
