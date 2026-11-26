local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local useLabelHover = require("@ui/hook/useLabelHover")
local cursor = require("@ui/util/cursor")
local SPRING = require("@ui/util/spring")

local useSpring = ReactRipple.useSpring
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useAt = ReactCharm.useAtom
local peek = Charm.peek
local e = React.createElement

local colors = themeState.colors.window.element

export type DropdownRendererProperties = {
	Dropdown: any,
	TextRef: { current: TextButton? }?,
	LayoutOrder: number?,
}

return function(properties: DropdownRendererProperties): React.Element<any>
	local dropdown = properties.Dropdown
	local textRef = properties.TextRef
	local layoutOrder = properties.LayoutOrder or 2

	local label = useAt(dropdown._label)
	local placeholder = useAt(dropdown._placeholder)
	local isOpen = useAt(dropdown._open)

	local backgroundColor = useAdvColor(colors.panel, colors.surface, dropdown._open)
	local strokeColor = useAdvColor(colors.panelStroke, colors.accentStrong, dropdown._open)
	local imageColor = useAdvColor(colors.icon, colors.iconActive, dropdown._open)
	local textColor = useAdvColor(colors.caption, colors.text, dropdown._active)

	local rotationBind, rotationSpring = useSpring(0, SPRING.snap)

	useEffect(function()
		rotationSpring:setGoal(isOpen and 1 or 0)
	end, { isOpen })

	local dropdownRef = React.useRef(dropdown)
	dropdownRef.current = dropdown

	local toggle = useCallback(function(): ()
		local d = dropdownRef.current
		if peek(d._open) then
			d:Close()
		elseif not d:WasJustClosed() then
			d:Open(cursor.getPosition())
		end
	end, {})

	local hoverColors = useMemo(function()
		return { backgroundColor, strokeColor, imageColor, textColor }
	end, { backgroundColor, strokeColor, imageColor, textColor } :: { any })

	local hoverOptions = useMemo(function()
		return { onClick = toggle }
	end, { toggle } :: { any })

	useLabelHover(textRef, hoverColors, hoverOptions)

	local onMouseEnter = useMemo(function()
		return function()
			backgroundColor.onMouseEnter()
			strokeColor.onMouseEnter()
			imageColor.onMouseEnter()
			textColor.onMouseEnter()
		end
	end, { backgroundColor, strokeColor, imageColor, textColor } :: { any })

	local onMouseLeave = useMemo(function()
		return function()
			backgroundColor.onMouseLeave()
			strokeColor.onMouseLeave()
			imageColor.onMouseLeave()
			textColor.onMouseLeave()
		end
	end, { backgroundColor, strokeColor, imageColor, textColor } :: { any })

	local rotationVisualBind = useMemo(function()
		return rotationBind:map(function(value: number)
			return value * 180
		end)
	end, { rotationBind } :: { any })

	local displayText = label == "" and (placeholder) or (label)

	return e("TextButton", {
		BorderSizePixel = 0,
		Size = UDim2.new(0, 114, 0, 16),
		LayoutOrder = layoutOrder,
		BackgroundColor3 = backgroundColor.binding,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		[React.Event.MouseEnter] = onMouseEnter,
		[React.Event.MouseLeave] = onMouseLeave,
		[React.Event.MouseButton1Click] = toggle,
	}, {
		UIStroke = e("UIStroke", {
			Color = strokeColor.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}),
		Image = e("ImageLabel", {
			Size = UDim2.fromOffset(8, 8),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Image = FileController.Get("image", "down_arrow"),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ImageColor3 = imageColor.binding,
			Rotation = rotationVisualBind,
		}),
		Text = e("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = textColor.binding,
			TextSize = 12,
			Text = displayText,
			Size = UDim2.new(1, -12, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
	})
end
