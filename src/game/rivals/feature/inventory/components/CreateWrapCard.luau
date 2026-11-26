local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local SPRING = require("@ui/util/spring")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useAt = ReactCharm.useAtom
local useSpring = ReactRipple.useSpring
local e = React.createElement

local inventoryColors = themeState.colors.inventory
local elementColors = themeState.colors.window.element

local CARD_HEIGHT = 178
local CORNER = 6
local DASH_LEN = 7
local DASH_GAP = 5
local DASH_THICK = 1
local BORDER_INSET = 5

export type CreateWrapCardProps = {
	LayoutOrder: number,
	Label: string?,
	OnClick: () -> (),
}

local function dashRow(horizontal: boolean, color: Color3, transparency: any): React.Element<any>
	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = horizontal and UDim2.new(1, 0, 0, DASH_THICK) or UDim2.new(0, DASH_THICK, 1, 0),
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, DASH_GAP),
		}),
		Dashes = e(
			React.Fragment,
			nil,
			(function(): { [string]: React.Element<any> }
				local dashes: { [string]: React.Element<any> } = {}
				for i = 1, 56 do
					dashes[`d{i}`] = e("Frame", {
						BackgroundColor3 = color,
						BackgroundTransparency = transparency,
						BorderSizePixel = 0,
						Size = horizontal and UDim2.fromOffset(DASH_LEN, DASH_THICK)
							or UDim2.fromOffset(DASH_THICK, DASH_LEN),
						LayoutOrder = i,
					})
				end
				return dashes
			end)()
		),
	})
end

return function(props: CreateWrapCardProps): React.Element<any>
	local hovered, setHovered = useState(false)
	local pressed, setPressed = useState(false)

	local accent = useAt(inventoryColors.customWrap)
	local imageBg = useAt(inventoryColors.cardImageBg)
	local caption = useAt(elementColors.caption)
	local captionActive = useAt(elementColors.textActive)

	local hoverBind, hoverSpring = useSpring(0, SPRING.smoothPreciser)
	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	local pressBind, pressSpring = useSpring(0, SPRING.quick)
	useEffect(function()
		pressSpring:setGoal(pressed and 1 or 0)
	end, { pressed })

	local cardPos = useMemo(function()
		return React.joinBindings({ hoverBind, pressBind }):map(function(values)
			local hover = values[1]
			local press = values[2]
			return UDim2.fromOffset(0, math.floor(-hover * 3 + press * 1))
		end)
	end, { hoverBind, pressBind } :: { any })

	local backgroundTransparencyBind = useMemo(function()
		return React.joinBindings({ hoverBind, pressBind }):map(function(values)
			local hover = values[1]
			local press = values[2]
			return 0.56 - hover * 0.2 + press * 0.1
		end)
	end, { hoverBind, pressBind } :: { any })

	local dashTransparencyBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return 0.5 - value * 0.38
		end)
	end, { hoverBind } :: { any })

	local iconTransparencyBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return 0.18 - value * 0.18
		end)
	end, { hoverBind } :: { any })

	local iconScaleBind = useMemo(function()
		return React.joinBindings({ hoverBind, pressBind }):map(function(values)
			local hover = values[1]
			local press = values[2]
			return 1 + hover * 0.07 - press * 0.03
		end)
	end, { hoverBind, pressBind } :: { any })

	local labelColorBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return caption:Lerp(captionActive, value)
		end)
	end, { hoverBind, caption, captionActive } :: { any })

	local onEnter = useCallback(function(): ()
		setHovered(true)
	end, {})
	local onLeave = useCallback(function(): ()
		setHovered(false)
		setPressed(false)
	end, {})
	local onDown = useCallback(function(): ()
		setPressed(true)
	end, {})
	local onUp = useCallback(function(): ()
		setPressed(false)
	end, {})

	return e("TextButton", {
		BackgroundColor3 = imageBg,
		BackgroundTransparency = backgroundTransparencyBind,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Selectable = false,
		Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		Position = cardPos,
		[React.Event.MouseEnter] = onEnter,
		[React.Event.MouseLeave] = onLeave,
		[React.Event.MouseButton1Down] = onDown,
		[React.Event.MouseButton1Up] = onUp,
		[React.Event.MouseButton1Click] = props.OnClick,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, CORNER),
		}),
		Top = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(BORDER_INSET, BORDER_INSET),
			Size = UDim2.new(1, -BORDER_INSET * 2, 0, DASH_THICK),
		}, { Row = dashRow(true, accent, dashTransparencyBind) }),
		Bottom = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, BORDER_INSET, 1, -BORDER_INSET),
			Size = UDim2.new(1, -BORDER_INSET * 2, 0, DASH_THICK),
		}, { Row = dashRow(true, accent, dashTransparencyBind) }),
		Left = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(BORDER_INSET, BORDER_INSET),
			Size = UDim2.new(0, DASH_THICK, 1, -BORDER_INSET * 2),
		}, { Row = dashRow(false, accent, dashTransparencyBind) }),
		Right = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -BORDER_INSET, 0, BORDER_INSET),
			Size = UDim2.new(0, DASH_THICK, 1, -BORDER_INSET * 2),
		}, { Row = dashRow(false, accent, dashTransparencyBind) }),
		Content = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -20, 1, -20),
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Icon = e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(32, 32),
				Image = FileController.Get("image", "download"),
				ImageColor3 = accent,
				ImageTransparency = iconTransparencyBind,
				ScaleType = Enum.ScaleType.Fit,
				LayoutOrder = 0,
			}, {
				UIScale = e("UIScale", {
					Scale = iconScaleBind,
				}),
			}),
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = FileController.Get("font", "semi_bold"),
				Text = props.Label or "Create Custom Wrap",
				TextColor3 = labelColorBind,
				TextSize = 12,
				Size = UDim2.new(1, 0, 0, 16),
				LayoutOrder = 1,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			SubLabel = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = FileController.Get("font", "light"),
				Text = "Open creator",
				TextColor3 = labelColorBind,
				TextTransparency = 0.35,
				TextSize = 11,
				Size = UDim2.new(1, 0, 0, 13),
				LayoutOrder = 2,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		}),
	})
end
