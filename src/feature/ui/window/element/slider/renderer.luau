local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local useDragValue = require("@ui/hook/useDragValue")
local useLabelHover = require("@ui/hook/useLabelHover")
local useClickOutside = require("@ui/hook/useClickOutside")
local SPRING = require("@ui/util/spring")
local inputHandler = require("@ui/util/inputHandler")

local useSpring = ReactRipple.useSpring
local useEffect = React.useEffect
local useState = React.useState
local useRef = React.useRef
local useMemo = React.useMemo
local useCallback = React.useCallback
local useAt = ReactCharm.useAtom
local e = React.createElement

local colors = themeState.colors.window.element

export type SliderRendererProperties = {
	Slider: any,
	TextRef: { current: TextButton? }?,
	LayoutOrder: number?,
	TextOffsetY: number?,
}

return function(properties: SliderRendererProperties): React.Element<any>
	local slider = properties.Slider
	local textRef = properties.TextRef
	local layoutOrder = properties.LayoutOrder or 2
	local textOffsetY = properties.TextOffsetY or 0

	local textboxRef = useRef(nil :: TextBox?)
	local boxRef = useRef(nil :: GuiObject?)
	local isFocused, setFocused = useState(false)

	local value = useAt(slider._state) or slider._min
	local formattedValue = useAt(slider._formattedValue)

	local barColor = useAdvColor(colors.panel, colors.panel, slider._active)
	local fillColor = useAdvColor(colors.accentSoft, colors.accent, slider._active)
	local circleColor = useAdvColor(colors.thumb, colors.thumbActive, slider._active)
	local boxColor = useAdvColor(colors.fieldBackground, colors.fieldBackgroundActive, slider._active)
	local strokeColor = useAdvColor(colors.fieldStroke, colors.fieldStrokeActive, slider._active)
	local textColor = useAdvColor(colors.caption, colors.captionActive, slider._active)

	local range = slider._max - slider._min
	local alpha = range > 0 and (math.clamp((value - slider._min) / range, 0, 1)) or 0

	local alphaBind, alphaSpring = useSpring(alpha, SPRING.snap)

	useEffect(function()
		alphaSpring:setGoal(alpha)
	end, { alpha })

	local sliderRef = useRef(slider)
	sliderRef.current = slider

	local onDragStart = useDragValue(function(a: Vector2)
		sliderRef.current:SetFromAlpha(a.X)
	end)

	local barEnter = useMemo(function()
		return function()
			barColor.onMouseEnter()
			fillColor.onMouseEnter()
			circleColor.onMouseEnter()
		end
	end, { barColor, fillColor, circleColor } :: { any })

	local barLeave = useMemo(function()
		return function()
			barColor.onMouseLeave()
			fillColor.onMouseLeave()
			circleColor.onMouseLeave()
		end
	end, { barColor, fillColor, circleColor } :: { any })

	local boxEnter = useMemo(function()
		return function()
			boxColor.onMouseEnter()
			strokeColor.onMouseEnter()
			textColor.onMouseEnter()
		end
	end, { boxColor, strokeColor, textColor } :: { any })

	local boxLeave = useMemo(function()
		return function()
			boxColor.onMouseLeave()
			strokeColor.onMouseLeave()
			textColor.onMouseLeave()
		end
	end, { boxColor, strokeColor, textColor } :: { any })

	local onInputBegan = useMemo(function()
		return inputHandler(function(rbx, input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			onDragStart(rbx, input)
		end)
	end, { onDragStart } :: { any })

	local nudgeUp = useCallback(function()
		sliderRef.current:Nudge(1)
	end, {})

	local nudgeDown = useCallback(function()
		sliderRef.current:Nudge(-1)
	end, {})

	local boxClick = useCallback(function()
		if textboxRef.current then
			textboxRef.current:CaptureFocus()
		end
	end, {})

	local labelHoverColors = useMemo(function()
		return { barColor, fillColor, circleColor, boxColor, strokeColor, textColor }
	end, { barColor, fillColor, circleColor, boxColor, strokeColor, textColor } :: { any })

	local labelHoverOptions = useMemo(function()
		return {
			onClick = function()
				if textboxRef.current then
					textboxRef.current:CaptureFocus()
				end
			end,
		}
	end, {})

	local clickOutsideHandler = useCallback(function()
		if textboxRef.current then
			textboxRef.current:ReleaseFocus()
		end
	end, {})

	local fillSizeBind = useMemo(function()
		return alphaBind:map(function(a: number)
			return UDim2.fromScale(a, 1)
		end)
	end, { alphaBind } :: { any })

	local circlePosBind = useMemo(function()
		return alphaBind:map(function(a: number)
			return UDim2.fromScale(a, 0.5)
		end)
	end, { alphaBind } :: { any })

	local circleAnchorBind = useMemo(function()
		return alphaBind:map(function(a: number)
			return Vector2.new(a, 0.5)
		end)
	end, { alphaBind } :: { any })

	useEffect(function()
		local box = textboxRef.current
		if not box then
			return
		end

		local connections = {
			box.Focused:Connect(function()
				box.Text = ""
				setFocused(true)
			end),
			box.FocusLost:Connect(function()
				setFocused(false)
				sliderRef.current:SetFromText(box.Text)
				box.Text = ""
			end),
		}

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, {})

	useClickOutside(boxRef, isFocused, clickOutsideHandler)

	useLabelHover(textRef, labelHoverColors, labelHoverOptions)

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(115, 14),
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Slider = e("TextButton", {
			Size = UDim2.fromOffset(70, 4),
			BackgroundColor3 = barColor.binding,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			LayoutOrder = 0,
			AutoButtonColor = false,
			Text = "",
			Active = false,
			[React.Event.MouseEnter] = barEnter,
			[React.Event.MouseLeave] = barLeave,
			[React.Event.InputBegan] = onInputBegan,
			[React.Event.MouseWheelForward] = nudgeUp,
			[React.Event.MouseWheelBackward] = nudgeDown,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			UIFlexItem = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
				ItemLineAlignment = Enum.ItemLineAlignment.Automatic,
			}),
			Fill = e("Frame", {
				Size = fillSizeBind,
				BackgroundColor3 = fillColor.binding,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),
			Circle = e("Frame", {
				Size = UDim2.fromOffset(8, 8),
				Position = circlePosBind,
				AnchorPoint = circleAnchorBind,
				BackgroundColor3 = circleColor.binding,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),
		}),
		Box = e("TextButton", {
			ref = boxRef,
			Size = UDim2.fromOffset(0, 14),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = boxColor.binding,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			AutoButtonColor = false,
			Text = "",
			Active = false,
			ClipsDescendants = true,
			[React.Event.MouseEnter] = boxEnter,
			[React.Event.MouseLeave] = boxLeave,
			[React.Event.MouseButton1Click] = boxClick,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
			}),
			UISizeConstraint = e("UISizeConstraint", {
				MinSize = Vector2.new(30, 14),
				MaxSize = Vector2.new(72, 14),
			}),
			UIStroke = e("UIStroke", {
				Color = strokeColor.binding,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			Text = e("TextBox", {
				ref = textboxRef,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 20, 0, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, textOffsetY),
				AutomaticSize = Enum.AutomaticSize.XY,
				Text = isFocused and "" or formattedValue,
				FontFace = FileController.Get("font", "semi_bold"),
				TextSize = 11,
				TextColor3 = textColor.binding,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ClearTextOnFocus = true,
				Interactable = isFocused,
				MultiLine = false,
				TextWrapped = false,
			}),
		}),
	})
end
