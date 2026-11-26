local RunService = cloneref(game:GetService("RunService")) :: RunService

local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")
local gameRegistry = require("@game/gameRegistry")
local speedometerState = require("@ui/hud/speedometer/speedometerState")
local themeState = require("@ui/theme/themeState")
local uiState = require("@ui/uiState")
local useDraggable = require("@ui/hook/useDraggable")
local useHudHover = require("@ui/hook/useHudHover")
local useShadow = require("@ui/hook/useShadow")
local SPRING = require("@ui/util/spring")

local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useMemo = React.useMemo
local useBinding = React.useBinding
local e = React.createElement

local peek = Charm.peek

local colors = themeState.colors.hud

local STUDS_TO_UNITS = 12.5
local FRAME_HEIGHT = 28
local FRAME_WIDTH = 72
local TEXT_SIZE = 14
local PADDING_X = 8
local CORNER = 6
local OPEN_OFFSET = 6

return function(): React.Element<any>
	local enabled = useAt(speedometerState.enabled)
	local menuOpen = useAt(uiState.isOpen)

	local textBind, setText = useBinding("0 u/s")

	useEffect(function()
		if not enabled then
			setText("0 u/s")
			return
		end
		local clientState = gameRegistry.clientState
		if not clientState then
			return
		end
		local conn = RunService.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function()
			local parts = peek(clientState.parts)
			local hrp = parts.HumanoidRootPart :: BasePart?
			if not hrp then
				setText("0 u/s")
				return
			end
			local v = hrp.AssemblyLinearVelocity
			local speed = math.sqrt(v.X * v.X + v.Z * v.Z) * STUDS_TO_UNITS
			setText(string.format("%d u/s", speed + 0.5))
		end))
		return function()
			conn:Disconnect()
		end
	end, { enabled })

	local textColor = useAt(colors.title)

	local bgPack = useAt(colors.background)
	local bgColor = bgPack[1] :: Color3
	local bgAlpha = bgPack[2] :: number

	local strokePack = useAt(colors.stroke)
	local strokeColor = strokePack[1] :: Color3
	local strokeAlpha = strokePack[2] :: number

	local shadowPack = useAt(colors.shadow)
	local shadowColor = shadowPack[1] :: Color3
	local shadowAlpha = shadowPack[2] :: number

	local widgetBind, widgetSpring = useSpring(0, SPRING.smoothPreciser)

	useEffect(function()
		widgetSpring:setGoal(enabled and 1 or 0)
	end, { enabled })

	local onDragInput, positionBind = useDraggable(speedometerState.position)
	local onHoverEnter, onHoverLeave, hoverGlow = useHudHover(menuOpen and enabled)

	local outerSize = useMemo(function()
		return widgetBind:map(function(v: number)
			return UDim2.fromOffset(FRAME_WIDTH * v, FRAME_HEIGHT)
		end)
	end, { widgetBind })

	local outerPosition = useMemo(function()
		return React.joinBindings({ widgetBind, positionBind }):map(function(values)
			local v: number = values[1]
			local pos: UDim2 = values[2]
			local offset = (1 - v) * OPEN_OFFSET
			return UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, (pos.Y.Offset :: number) + offset)
		end)
	end, { widgetBind, positionBind } :: { any })

	local visible = useMemo(function()
		return widgetBind:map(function(v: number)
			return v > 0.001
		end)
	end, { widgetBind })

	local bgTransparency = useMemo(function()
		return widgetBind:map(function(v: number)
			return 1 - v * (1 - bgAlpha)
		end)
	end, { widgetBind, bgAlpha } :: { any })

	local strokeTransparency = useMemo(function()
		return widgetBind:map(function(v: number)
			return 1 - v * (1 - strokeAlpha)
		end)
	end, { widgetBind, strokeAlpha } :: { any })

	local shadowTransparency = useMemo(function()
		return widgetBind:map(function(v: number)
			return 1 - v * (1 - shadowAlpha)
		end)
	end, { widgetBind, shadowAlpha } :: { any })

	local textTransparency = useMemo(function()
		return widgetBind:map(function(v: number)
			return 1 - v
		end)
	end, { widgetBind })

	local function onInputBegan(_: any, input: InputObject): ()
		if not menuOpen or not enabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onDragInput(input)
		end
	end

	return e("Frame", {
		Active = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = outerPosition,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = outerSize,
		Visible = visible,
		[React.Event.InputBegan] = onInputBegan,
		[React.Event.MouseEnter] = onHoverEnter,
		[React.Event.MouseLeave] = onHoverLeave,
	}, {
		Glow = hoverGlow,
		Shadow = useShadow({
			color = shadowColor,
			transparency = shadowTransparency,
			zIndex = 0,
			multiplier = Vector2.new(1.24, 1.46),
		}),
		Body = e("Frame", {
			BackgroundColor3 = bgColor,
			BackgroundTransparency = bgTransparency,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			ClipsDescendants = true,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, CORNER),
			}),
			UIStroke = e("UIStroke", {
				Color = strokeColor,
				Transparency = strokeTransparency,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, PADDING_X),
				PaddingRight = UDim.new(0, PADDING_X),
			}),
			Text = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = textBind,
				TextSize = TEXT_SIZE,
				TextColor3 = textColor,
				TextTransparency = textTransparency,
				FontFace = FileController.Get("font", "semi_bold"),
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		}),
	})
end
