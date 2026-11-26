local React = require("@pkg/React")
local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")

local useAdvColor = require("@ui/hook/useAdvColor")
local useLabelHover = require("@ui/hook/useLabelHover")
local cursor = require("@ui/util/cursor")
local useMemo = React.useMemo
local useCallback = React.useCallback
local useRef = React.useRef
local e = React.createElement

local colors = themeState.colors.window.element

export type SubmenuRendererProperties = {
	Submenu: any,
	TextRef: { current: TextButton? }?,
	LayoutOrder: number?,
}

return function(properties: SubmenuRendererProperties): React.Element<any>
	local submenu = properties.Submenu
	local textRef = properties.TextRef
	local layoutOrder = properties.LayoutOrder or 1

	local backgroundColor = useAdvColor(colors.surface, colors.accent, submenu._open)
	local strokeColor = useAdvColor(colors.surfaceStroke, colors.accentStrong, submenu._open)
	local imageColor = useAdvColor(colors.caption, colors.textActive, submenu._open)

	local submenuRef = useRef(submenu)
	submenuRef.current = submenu

	local open = useCallback(function(): ()
		submenuRef.current:Open(cursor.getPosition())
	end, {})

	local hoverColors = useMemo(function()
		return { backgroundColor, strokeColor, imageColor }
	end, { backgroundColor, strokeColor, imageColor } :: { any })

	local hoverOptions = useMemo(function()
		return { onClick = open }
	end, { open } :: { any })

	useLabelHover(textRef, hoverColors, hoverOptions)

	local onMouseEnter = useMemo(function()
		return function()
			backgroundColor.onMouseEnter()
			strokeColor.onMouseEnter()
			imageColor.onMouseEnter()
		end
	end, { backgroundColor, strokeColor, imageColor } :: { any })

	local onMouseLeave = useMemo(function()
		return function()
			backgroundColor.onMouseLeave()
			strokeColor.onMouseLeave()
			imageColor.onMouseLeave()
		end
	end, { backgroundColor, strokeColor, imageColor } :: { any })

	return e("TextButton", {
		BackgroundColor3 = backgroundColor.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(14, 14),
		LayoutOrder = layoutOrder,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		[React.Event.MouseEnter] = onMouseEnter,
		[React.Event.MouseLeave] = onMouseLeave,
		[React.Event.MouseButton1Click] = open,
	}, {
		ImageLabel = e("ImageLabel", {
			BackgroundTransparency = 1,
			Image = FileController.Get("image", "options"),
			ImageColor3 = imageColor.binding,
			Size = UDim2.fromOffset(10, 10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
	})
end
