local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local Charm = require("@pkg/Charm")
local themeState = require("@ui/theme/themeState")

local useAdvColor = require("@ui/hook/useAdvColor")
local useLabelHover = require("@ui/hook/useLabelHover")
local SPRING = require("@ui/util/spring")
local useEffect = React.useEffect
local useAt = ReactCharm.useAtom
local e = React.createElement

local colors = themeState.colors.window.element
local EMPTY_CONTROL_SELECTION = Charm.atom("base")

export type ToggleRendererProperties = {
	Toggle: any,
	TextRef: { current: TextButton? }?,
	LayoutOrder: number?,
}

return function(properties: ToggleRendererProperties): React.Element<any>
	local sourceToggle = properties.Toggle
	useAt(sourceToggle._displaySelection or EMPTY_CONTROL_SELECTION)
	local toggle = sourceToggle._displayResolver and sourceToggle._displayResolver() or sourceToggle
	local textRef = properties.TextRef
	local layoutOrder = properties.LayoutOrder or 2

	local isToggled = useAt(toggle._state, { toggle })
	local controlSelection = useAt(toggle._controlSelection or EMPTY_CONTROL_SELECTION, { toggle })
	local controlVisible = toggle._controlSelection == nil or controlSelection == "base"

	local backgroundColor = useAdvColor(colors.surface, colors.accent, toggle._active, true)
	local circleColor = useAdvColor(colors.thumb, colors.thumbActive, toggle._active, true)
	local strokeColor = useAdvColor(colors.surfaceStroke, colors.accentStrong, toggle._active)

	local circleBind, circleSpring = ReactRipple.useSpring(0, SPRING.quick)

	useEffect(function()
		circleSpring:setGoal(isToggled and 1 or 0)
	end, { isToggled })

	useLabelHover(textRef, { backgroundColor, circleColor }, {
		onClick = function()
			toggle:Toggle()
		end,
	})

	return e("TextButton", {
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(30, 14),
		BackgroundColor3 = backgroundColor.binding,
		[React.Event.MouseEnter] = function()
			backgroundColor.onMouseEnter()
			circleColor.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			backgroundColor.onMouseLeave()
			circleColor.onMouseLeave()
		end,
		Text = "",
		Visible = controlVisible,
		Active = false,
		AutoButtonColor = false,
		[React.Event.MouseButton1Click] = function()
			toggle:Toggle()
		end,
		LayoutOrder = layoutOrder,
	}, {
		UIStroke = e("UIStroke", {
			Color = strokeColor.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}),
		Circle = e("Frame", {
			BackgroundTransparency = 0,
			BackgroundColor3 = circleColor.binding,
			Position = circleBind:map(function(value: number)
				return UDim2.fromScale(value, 0)
			end),
			AnchorPoint = circleBind:map(function(value: number)
				return Vector2.new(value, 0)
			end),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(10, 10),
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
	})
end
