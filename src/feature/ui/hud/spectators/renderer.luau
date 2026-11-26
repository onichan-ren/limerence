local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")
local gameRegistry = require("@game/gameRegistry")
local RollingText = require("@ui/hud/watermark/RollingText")

local _fallbackCount = Charm.atom(0)
local spectatorsState = require("@ui/hud/spectators/spectatorsState")
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
local e = React.createElement

local colors = themeState.colors.hud

local FRAME_HEIGHT = 28
local TEXT_SIZE = 14
local ICON_SIZE = 14
local PADDING_X = 8
local ICON_TEXT_GAP = 6
local CORNER = 6
local OPEN_OFFSET = 6

return function(): React.Element<any>
	local enabled = useAt(spectatorsState.enabled)
	local hideWhenEmpty = useAt(spectatorsState.hideWhenEmpty)
	local menuOpen = useAt(uiState.isOpen)
	local clientState = gameRegistry.clientState
	local spectatorAtom = (clientState and clientState.spectatorCount) or _fallbackCount
	local count = useAt(spectatorAtom) :: number

	local shown = enabled and (menuOpen or not hideWhenEmpty or count > 0)

	local textColor = useAt(colors.title)
	local iconColor = useAt(colors.image)

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
		widgetSpring:setGoal(shown and 1 or 0)
	end, { shown })

	local onDragInput, positionBind = useDraggable(spectatorsState.position)
	local onHoverEnter, onHoverLeave, hoverGlow = useHudHover(menuOpen and enabled)

	local outerSize = useMemo(function()
		return widgetBind:map(function(v: number)
			return UDim2.fromOffset(0, FRAME_HEIGHT * v)
		end)
	end, { widgetBind })

	local outerPosition = useMemo(function()
		return React.joinBindings({ widgetBind, positionBind }):map(function(values)
			local v: number = values[1]
			local pos: UDim2 = values[2]
			local offset = (1 - v) * OPEN_OFFSET
			return UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, (pos.Y.Offset :: number) - offset)
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

	local fadeTransparency = useMemo(function()
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

	local suffix = count == 1 and " spectator" or " spectators"

	return e("Frame", {
		Active = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = outerPosition,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = outerSize,
		AutomaticSize = Enum.AutomaticSize.X,
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
			AutomaticSize = Enum.AutomaticSize.X,
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
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, ICON_TEXT_GAP),
			}),
			Icon = e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = FileController.Get("image", "person") :: string,
				ImageColor3 = iconColor,
				ImageTransparency = fadeTransparency,
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				LayoutOrder = 0,
			}),
			Text = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, TEXT_SIZE + 2),
				LayoutOrder = 1,
				Active = false,
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),
				Count = e(RollingText, {
					atom = spectatorAtom,
					format = tostring,
					color = textColor,
					transparency = fadeTransparency,
					textSize = TEXT_SIZE,
					height = TEXT_SIZE + 2,
					layoutOrder = 0,
					roll = "char",
				}),
				Suffix = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = suffix,
					TextSize = TEXT_SIZE,
					TextColor3 = textColor,
					TextTransparency = fadeTransparency,
					FontFace = FileController.Get("font", "semi_bold"),
					Size = UDim2.fromOffset(0, TEXT_SIZE + 2),
					AutomaticSize = Enum.AutomaticSize.X,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					LayoutOrder = 1,
				}),
			}),
		}),
	})
end
