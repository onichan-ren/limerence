local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Sift = require("@pkg/Sift")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local dpiState = require("@ui/util/dpiState")
local useAdvColor = require("@ui/hook/useAdvColor")
local useContext = require("@ui/hook/useContext")
local useDragValue = require("@ui/hook/useDragValue")
local inputHandler = require("@ui/util/inputHandler")
local SPRING = require("@ui/util/spring")

local useState = React.useState
local useRef = React.useRef
local useMemo = React.useMemo
local useCallback = React.useCallback
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local e = React.createElement
local memo = React.memo

local colors = themeState.colors.window.element

local CURVE_THICKNESS = 1
local POINT_SIZE = 6
local POINT_HITBOX = 10
local GRID_X_DIVISIONS = 4
local GRID_Y_DIVISIONS = 4
local CANVAS_INSET = 6
local AXIS_LABEL_INSET = 6
local GHOST_DELAY = 0.2
local GHOST_GLOW_PADDING = 6
local POINT_ACTIVE_SCALE = (POINT_SIZE + 2) / POINT_SIZE
local HOVER_EPSILON = 0.001

local function localSize(absolute: Vector2): Vector2
	local scale = Charm.peek(dpiState.scale)
	if scale <= 0 then
		scale = 1
	end
	return absolute / scale
end

export type CurveEditorRendererProperties = {
	CurveEditor: any,
	LayoutOrder: number?,
}

type HoverInfo = { Kind: string, Index: number?, X: number?, Y: number?, CursorY: number? }

local function formatAxisValue(value: number): string
	if value == math.floor(value) then
		return tostring(math.floor(value))
	end
	return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

local function hitTestPoints(surface: GuiObject, input: InputObject, points: { any }): number?
	local localX = input.Position.X - surface.AbsolutePosition.X
	local localY = input.Position.Y - surface.AbsolutePosition.Y
	local sizeX = surface.AbsoluteSize.X
	local sizeY = surface.AbsoluteSize.Y

	for i, p in points do
		local px = p.x * sizeX
		local py = (1 - p.y) * sizeY
		local dx = localX - px
		local dy = localY - py
		if dx * dx + dy * dy <= POINT_HITBOX * POINT_HITBOX then
			return i
		end
	end
	return nil
end

type PointProps = {
	Curve: any,
	Index: number,
	Point: { x: number, y: number },
	IsActive: boolean,
	IsEndpoint: boolean,
	SurfaceRef: { current: GuiObject? },
	OnHoverEnter: (idx: number) -> (),
}

local Point = memo(function(props: PointProps): React.Element<any>
	local curve = props.Curve
	local idx = props.Index
	local p = props.Point
	local isActive = props.IsActive
	local isEndpoint = props.IsEndpoint
	local surfaceRef = props.SurfaceRef
	local onHoverEnter = props.OnHoverEnter

	local pointBase = isActive and colors.thumbHighlight or colors.thumbActive
	local pointColor = useAt(pointBase)
	local strokeColor = useAt(colors.thumbStroke)

	local mounted, setMounted = useState(false)
	useEffect(function()
		setMounted(true)
	end, {})

	local scaleGoal = not mounted and (0 and isActive or POINT_ACTIVE_SCALE) or 1
	local scaleBind, scaleSpring = useSpring(0, SPRING.smooth)
	useEffect(function()
		scaleSpring:setGoal(scaleGoal)
	end, { scaleGoal })

	local onDragStart = useDragValue(function(alpha: Vector2)
		curve:MovePoint(idx, alpha.X, 1 - alpha.Y)
	end)

	local onContext = useContext(function()
		if isEndpoint then
			return nil
		end
		return {
			{
				Label = "Delete Point",
				Icon = FileController.Get("image", "delete"),
				Callback = function()
					curve:RemovePoint(idx)
				end,
			},
		}
	end, curve)

	local pointBtnRef = useRef(nil :: TextButton?)

	useEffect(function()
		local btn = pointBtnRef.current
		if btn then
			btn:SetAttribute("ConsumesRightClick", true)
		end
	end, {})

	return e("TextButton", {
		ref = pointBtnRef,
		Size = UDim2.fromOffset(POINT_SIZE, POINT_SIZE),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(p.x, 1 - p.y),
		BackgroundColor3 = pointColor,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = false,
		Text = "",
		ZIndex = 3,
		[React.Event.MouseEnter] = function()
			onHoverEnter(idx)
		end,
		[React.Event.InputBegan] = inputHandler(function(rbx, input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if isActive then
					curve:SetActivePoint(nil)
				else
					curve:SetActivePoint(idx)
				end
				local surface = surfaceRef.current
				if surface then
					onDragStart(surface, input)
				end
				return
			end
			onContext(rbx, input)
		end),
	}, {
		UIScale = e("UIScale", {
			Scale = scaleBind,
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor,
			Thickness = 1,
		}),
	})
end)

local function buildGrid(gridColor: Color3): { [string]: React.Element<any> }
	local lines: { [string]: React.Element<any> } = {}

	for i = 1, GRID_X_DIVISIONS - 1 do
		local x = i / GRID_X_DIVISIONS
		lines[`VLine_{i}`] = e("Frame", {
			Size = UDim2.new(0, 1, 1, 0),
			Position = UDim2.fromScale(x, 0),
			BackgroundColor3 = gridColor,
			BorderSizePixel = 0,
			ZIndex = 1,
		})
	end

	for i = 1, GRID_Y_DIVISIONS - 1 do
		local y = i / GRID_Y_DIVISIONS
		lines[`HLine_{i}`] = e("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, y),
			BackgroundColor3 = gridColor,
			BorderSizePixel = 0,
			ZIndex = 1,
		})
	end

	return lines
end

local function buildCurveSegments(
	points: { any },
	canvasSize: Vector2,
	curveColor: Color3
): { [string]: React.Element<any> }
	local segments: { [string]: React.Element<any> } = {}

	if #points < 2 or canvasSize.X <= 0 or canvasSize.Y <= 0 then
		return segments
	end

	local sx = canvasSize.X
	local sy = canvasSize.Y

	for i = 1, #points - 1 do
		local p1 = points[i]
		local p2 = points[i + 1]

		local px1 = p1.x * sx
		local py1 = (1 - p1.y) * sy
		local px2 = p2.x * sx
		local py2 = (1 - p2.y) * sy

		local dx = px2 - px1
		local dy = py2 - py1
		local length = math.sqrt(dx * dx + dy * dy)
		if length <= 0 then
			continue
		end

		segments[`Seg_{i}`] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((px1 + px2) / 2, (py1 + py2) / 2),
			Size = UDim2.fromOffset(length + 1, CURVE_THICKNESS),
			Rotation = math.deg(math.atan2(dy, dx)),
			BackgroundColor3 = curveColor,
			BorderSizePixel = 0,
			ZIndex = 2,
		})
	end

	return segments
end

return function(properties: CurveEditorRendererProperties): React.Element<any>
	local curve = properties.CurveEditor
	local layoutOrder = properties.LayoutOrder or 2

	local points = useAt(curve._state) or {}
	local activeIdx = useAt(curve._activeIdx)
	local labelText = useAt(curve._text)

	local surfaceRef = useRef(nil :: GuiObject?)
	local absSize, setAbsSize = useState(Vector2.new(280, curve._height - CANVAS_INSET * 2))
	local hoverInfo, setHoverInfo = useState(nil :: HoverInfo?)
	local ghostVisible, setGhostVisible = useState(false)
	local ghostVisibleRef = useRef(false)
	ghostVisibleRef.current = ghostVisible

	local ghostBind, ghostSpring = useSpring(0, SPRING.smooth)
	useEffect(function()
		ghostSpring:setGoal(ghostVisible and 1 or 0)
	end, { ghostVisible })

	useEffect(function()
		setGhostVisible(false)
		if not (hoverInfo and hoverInfo.Kind == "curve") then
			return nil
		end
		local cancelled = false
		task.delay(GHOST_DELAY, function()
			if not cancelled then
				setGhostVisible(true)
			end
		end)
		return function()
			cancelled = true
		end :: any
	end, { hoverInfo } :: { any })

	useEffect(function()
		local surface = surfaceRef.current
		if not surface then
			return nil
		end

		setAbsSize(localSize(surface.AbsoluteSize))
		local conn = surface:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			setAbsSize(localSize(surface.AbsoluteSize))
		end)

		return function()
			conn:Disconnect()
		end :: any
	end, {})

	local backgroundColor = useAt(colors.panel)
	local strokeColor = useAt(colors.panelStroke)
	local gridColor = useAt(colors.surface)
	local curveColor = useAt(colors.accentStrong)
	local ghostFillColor = useAt(colors.thumbActive)
	local axisColor = useAt(colors.caption)
	local labelColor = useAdvColor(colors.text, colors.textActive, curve._active)

	local segments = useMemo(function()
		return buildCurveSegments(points, absSize, curveColor)
	end, { points, absSize, curveColor } :: { any })

	local grid = useMemo(function()
		return buildGrid(gridColor)
	end, { gridColor })

	local setPointHover = useCallback(function(idx: number)
		setHoverInfo({ Kind = "point", Index = idx } :: HoverInfo)
	end, {})

	local setCurveHoverFromInput = useCallback(function(input: InputObject)
		local surface = surfaceRef.current
		if not surface then
			return
		end
		local hitIdx = hitTestPoints(surface, input, points)
		if hitIdx then
			setHoverInfo(function(prev: HoverInfo?): HoverInfo?
				if prev and prev.Kind == "point" and prev.Index == hitIdx then
					return prev
				end
				return { Kind = "point", Index = hitIdx } :: HoverInfo
			end :: any)
			return
		end
		local localX = input.Position.X - surface.AbsolutePosition.X
		local localY = input.Position.Y - surface.AbsolutePosition.Y
		local sizeX = surface.AbsoluteSize.X
		local sizeY = surface.AbsoluteSize.Y
		if sizeX <= 0 or sizeY <= 0 then
			return
		end
		local nx = math.clamp(localX / sizeX, 0, 1)
		local cursorY = 1 - math.clamp(localY / sizeY, 0, 1)
		local ny = curve:SampleNormalized(nx)
		setHoverInfo(function(prev: HoverInfo?): HoverInfo?
			if
				prev
				and prev.Kind == "curve"
				and prev.X
				and prev.Y
				and prev.CursorY
				and math.abs(prev.X - nx) < HOVER_EPSILON
				and math.abs(prev.Y - ny) < HOVER_EPSILON
				and math.abs(prev.CursorY - cursorY) < HOVER_EPSILON
			then
				return prev
			end
			return { Kind = "curve", X = nx, Y = ny, CursorY = cursorY } :: HoverInfo
		end :: any)
	end, { points, curve } :: { any })

	local renderedPoints = useMemo(function(): { [string]: React.Element<any> }
		local rendered: { [string]: React.Element<any> } = {}
		for i, p in points do
			rendered[`Point_{i}`] = e(Point, {
				Curve = curve,
				Index = i,
				Point = p,
				IsActive = i == activeIdx,
				IsEndpoint = i == 1 or i == #points,
				SurfaceRef = surfaceRef,
				OnHoverEnter = setPointHover,
			})
		end
		return rendered
	end, { points, activeIdx, curve, setPointHover } :: { any })

	local axisLeft = formatAxisValue(curve._xMin) .. curve._xSuffix
	local axisRight = formatAxisValue(curve._xMax) .. curve._xSuffix

	local pointText = ""
	if hoverInfo then
		local nx: number? = nil
		local ny: number? = nil
		if hoverInfo.Kind == "point" then
			local hp = hoverInfo.Index and points[hoverInfo.Index]
			if hp then
				nx, ny = hp.x, hp.y
			end
		elseif hoverInfo.Kind == "curve" then
			nx, ny = hoverInfo.X, hoverInfo.Y
		end

		if nx and ny then
			local actualX = curve._xMin + nx * (curve._xMax - curve._xMin)
			local actualY = curve._min + ny * (curve._max - curve._min)
			pointText = formatAxisValue(actualX) .. curve._xSuffix .. ", " .. formatAxisValue(actualY) .. curve._ySuffix
		end
	end

	local ghostExtras: { [string]: React.Element<any> } = {}
	if hoverInfo and hoverInfo.Kind == "curve" and hoverInfo.X and hoverInfo.CursorY then
		ghostExtras.Ghost = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(hoverInfo.X, 1 - hoverInfo.CursorY),
			Size = UDim2.fromOffset(POINT_SIZE, POINT_SIZE),
			BackgroundColor3 = ghostFillColor,
			BackgroundTransparency = ghostBind:map(function(a: number): number
				return 1 - a * 0.5
			end),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			UIScale = e("UIScale", {
				Scale = ghostBind:map(function(a: number): number
					return 0.5 + a * 0.5
				end),
			}),
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			UIStroke = e("UIStroke", {
				Color = curveColor,
				Thickness = 1,
				Transparency = ghostBind:map(function(a: number): number
					return 1 - a * 0.65
				end),
			}),
			Glow = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(POINT_SIZE + GHOST_GLOW_PADDING, POINT_SIZE + GHOST_GLOW_PADDING),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
				UIStroke = e("UIStroke", {
					Color = curveColor,
					Thickness = 1,
					Transparency = ghostBind:map(function(a: number): number
						return 1 - a * 0.2
					end),
				}),
			}),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = layoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = e("TextButton", {
			BackgroundTransparency = 1,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = labelColor.binding,
			TextSize = 13,
			Text = labelText,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = 0,
			AutoButtonColor = false,
			Active = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			[React.Event.MouseEnter] = function()
				labelColor.onMouseEnter()
			end,
			[React.Event.MouseLeave] = function()
				labelColor.onMouseLeave()
			end,
		}, {
			PointLabel = e("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = FileController.Get("font", "semi_bold"),
				TextColor3 = labelColor.binding,
				TextSize = 13,
				Text = pointText,
				Size = UDim2.new(1, 0, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}),
		Canvas = e("TextButton", {
			Size = UDim2.new(1, 0, 0, curve._height),
			BackgroundColor3 = backgroundColor,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			AutoButtonColor = false,
			Text = "",
			Active = false,
			ClipsDescendants = true,
			[React.Event.InputBegan] = inputHandler(function(rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					local surface = surfaceRef.current
					if surface and hitTestPoints(surface, input, points) == nil then
						if ghostVisibleRef.current then
							local localX = input.Position.X - surface.AbsolutePosition.X
							local localY = input.Position.Y - surface.AbsolutePosition.Y
							local sizeX = surface.AbsoluteSize.X
							local sizeY = surface.AbsoluteSize.Y
							local nx = sizeX > 0 and (math.clamp(localX / sizeX, 0, 1)) or 0
							local ny = sizeY > 0 and (1 - math.clamp(localY / sizeY, 0, 1)) or 0
							local newIdx = curve:AddPoint(nx, ny)
							if newIdx then
								curve:SetActivePoint(newIdx)
							end
							setGhostVisible(false)
						else
							curve:SetActivePoint(nil)
						end
					end
					return
				end
			end),
			[React.Event.InputChanged] = function(_rbx: TextButton, input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseMovement then
					setCurveHoverFromInput(input)
				end
			end,
			[React.Event.MouseLeave] = function()
				setHoverInfo(nil :: any)
			end,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			UIStroke = e("UIStroke", {
				Color = strokeColor,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			AxisLeft = e("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = FileController.Get("font", "semi_bold"),
				TextColor3 = axisColor,
				TextSize = 11,
				Text = axisLeft,
				Size = UDim2.fromOffset(0, 12),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromOffset(AXIS_LABEL_INSET, AXIS_LABEL_INSET),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 4,
			}),
			AxisRight = e("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = FileController.Get("font", "semi_bold"),
				TextColor3 = axisColor,
				TextSize = 11,
				Text = axisRight,
				Size = UDim2.fromOffset(0, 12),
				AutomaticSize = Enum.AutomaticSize.X,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -AXIS_LABEL_INSET, 0, AXIS_LABEL_INSET),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 4,
			}),
			Surface = e("Frame", {
				ref = surfaceRef,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(CANVAS_INSET, CANVAS_INSET),
				Size = UDim2.new(1, -CANVAS_INSET * 2, 1, -CANVAS_INSET * 2),
			}, Sift.Dictionary.join({}, grid, segments, ghostExtras, renderedPoints)),
		}),
	})
end
