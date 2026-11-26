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
local joinBindings = React.joinBindings
local e = React.createElement

local colors = themeState.colors.window.element

export type RangeSliderRendererProperties = {
	Slider: any,
	TextRef: { current: TextButton? }?,
	LayoutOrder: number?,
}

return function(properties: RangeSliderRendererProperties): React.Element<any>
	local slider = properties.Slider
	local textRef = properties.TextRef
	local layoutOrder = properties.LayoutOrder or 2

	local lowBoxRef = useRef(nil :: TextBox?)
	local highBoxRef = useRef(nil :: TextBox?)
	local boxRef = useRef(nil :: GuiObject?)
	local focusedHandle, setFocusedHandle = useState("none")

	useAt(slider._state)
	local formattedLow = useAt(slider._formattedLow)
	local formattedHigh = useAt(slider._formattedHigh)

	local barColor = useAdvColor(colors.panel, colors.panel, slider._active)
	local fillColor = useAdvColor(colors.accentSoft, colors.accent, slider._active)
	local circleColor = useAdvColor(colors.thumb, colors.thumbActive, slider._active)
	local boxColor = useAdvColor(colors.fieldBackground, colors.fieldBackgroundActive, slider._active)
	local strokeColor = useAdvColor(colors.fieldStroke, colors.fieldStrokeActive, slider._active)
	local textColor = useAdvColor(colors.caption, colors.captionActive, slider._active)

	local lowAlpha, highAlpha = slider:GetAlphas()

	local lowBind, lowSpring = useSpring(lowAlpha, SPRING.snap)
	local highBind, highSpring = useSpring(highAlpha, SPRING.snap)

	useEffect(function()
		lowSpring:setGoal(lowAlpha)
	end, { lowAlpha })

	useEffect(function()
		highSpring:setGoal(highAlpha)
	end, { highAlpha })

	local sliderRef = useRef(slider)
	sliderRef.current = slider

	local activeHandleRef = useRef("low")

	local onDrag = useDragValue(function(a: Vector2)
		if activeHandleRef.current == "low" then
			sliderRef.current:SetLowFromAlpha(a.X)
		else
			sliderRef.current:SetHighFromAlpha(a.X)
		end
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
		return inputHandler(function(rbx: GuiObject, input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			local origin = rbx.AbsolutePosition
			local size = rbx.AbsoluteSize
			local width = size.X > 0 and size.X or 1
			local pressAlpha = math.clamp((input.Position.X - origin.X) / width, 0, 1)
			local lo, hi = sliderRef.current:GetAlphas()
			if math.abs(pressAlpha - lo) <= math.abs(pressAlpha - hi) then
				activeHandleRef.current = "low"
			else
				activeHandleRef.current = "high"
			end
			onDrag(rbx, input)
		end)
	end, { onDrag } :: { any })

	local labelHoverColors = useMemo(function()
		return { barColor, fillColor, circleColor, boxColor, strokeColor, textColor }
	end, { barColor, fillColor, circleColor, boxColor, strokeColor, textColor } :: { any })

	local labelHoverOptions = useMemo(function()
		return {
			onClick = function()
				if lowBoxRef.current then
					lowBoxRef.current:CaptureFocus()
				end
			end,
		}
	end, {})

	local clickOutsideHandler = useCallback(function()
		if lowBoxRef.current then
			lowBoxRef.current:ReleaseFocus()
		end
		if highBoxRef.current then
			highBoxRef.current:ReleaseFocus()
		end
	end, {})

	local fillSizeBind = useMemo(function()
		return joinBindings({ lowBind, highBind }):map(function(pair: { number })
			return UDim2.fromScale(math.max(pair[2] - pair[1], 0), 1)
		end)
	end, { lowBind, highBind } :: { any })

	local lowPosBind = useMemo(function()
		return lowBind:map(function(a: number)
			return UDim2.fromScale(a, 0.5)
		end)
	end, { lowBind } :: { any })

	local lowAnchorBind = useMemo(function()
		return lowBind:map(function(a: number)
			return Vector2.new(a, 0.5)
		end)
	end, { lowBind } :: { any })

	local highPosBind = useMemo(function()
		return highBind:map(function(a: number)
			return UDim2.fromScale(a, 0.5)
		end)
	end, { highBind } :: { any })

	local highAnchorBind = useMemo(function()
		return highBind:map(function(a: number)
			return Vector2.new(a, 0.5)
		end)
	end, { highBind } :: { any })

	useEffect(function()
		local low = lowBoxRef.current
		local high = highBoxRef.current
		if not low or not high then
			return
		end

		local connections = {
			low.Focused:Connect(function()
				low.Text = ""
				setFocusedHandle("low")
			end),
			low.FocusLost:Connect(function()
				setFocusedHandle("none")
				sliderRef.current:SetLowFromText(low.Text)
				low.Text = ""
			end),
			high.Focused:Connect(function()
				high.Text = ""
				setFocusedHandle("high")
			end),
			high.FocusLost:Connect(function()
				setFocusedHandle("none")
				sliderRef.current:SetHighFromText(high.Text)
				high.Text = ""
			end),
		}

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, {})

	useClickOutside(boxRef, focusedHandle ~= "none", clickOutsideHandler)

	useLabelHover(textRef, labelHoverColors, labelHoverOptions)

	local valueField = function(props: { Ref: any, Order: number, Text: string }): React.Element<any>
		return e("TextBox", {
			ref = props.Ref,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 12),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = props.Text,
			FontFace = FileController.Get("font", "semi_bold"),
			TextSize = 11,
			TextColor3 = textColor.binding,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ClearTextOnFocus = true,
			MultiLine = false,
			TextWrapped = false,
			LayoutOrder = props.Order,
		})
	end

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
				Position = lowPosBind,
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = fillColor.binding,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),
			LowCircle = e("Frame", {
				Size = UDim2.fromOffset(8, 8),
				Position = lowPosBind,
				AnchorPoint = lowAnchorBind,
				BackgroundColor3 = circleColor.binding,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),
			HighCircle = e("Frame", {
				Size = UDim2.fromOffset(8, 8),
				Position = highPosBind,
				AnchorPoint = highAnchorBind,
				BackgroundColor3 = circleColor.binding,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),
		}),
		Box = e("Frame", {
			ref = boxRef,
			Size = UDim2.fromOffset(0, 14),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = boxColor.binding,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			ClipsDescendants = true,
			[React.Event.MouseEnter] = boxEnter,
			[React.Event.MouseLeave] = boxLeave,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
			}),
			UIListLayout = e("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 3),
			}),
			UISizeConstraint = e("UISizeConstraint", {
				MinSize = Vector2.new(44, 14),
				MaxSize = Vector2.new(90, 14),
			}),
			UIStroke = e("UIStroke", {
				Color = strokeColor.binding,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			Low = valueField({
				Ref = lowBoxRef,
				Order = 0,
				Text = focusedHandle == "low" and "" or formattedLow,
			}),
			Dash = e("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(6, 12),
				Text = "-",
				FontFace = FileController.Get("font", "semi_bold"),
				TextSize = 11,
				TextColor3 = textColor.binding,
				TextTransparency = 0.35,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 1,
			}),
			High = valueField({
				Ref = highBoxRef,
				Order = 2,
				Text = focusedHandle == "high" and "" or formattedHigh,
			}),
		}),
	})
end
