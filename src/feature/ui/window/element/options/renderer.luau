local React = require("@pkg/React")
local themeState = require("@ui/theme/themeState")
local FileController = require("@src/feature/file/FileController")

local useAdvColor = require("@ui/hook/useAdvColor")
local useLabelHover = require("@ui/hook/useLabelHover")
local cursor = require("@ui/util/cursor")
local e = React.createElement

local colors = themeState.colors.window.element

export type OptionsRendererProperties = {
	Options: any,
	TextRef: { current: TextButton? }?,
	LayoutOrder: number?,
}

return function(properties: OptionsRendererProperties): React.Element<any>
	local options = properties.Options
	local textRef = properties.TextRef
	local layoutOrder = properties.LayoutOrder or 2

	local backgroundColor = useAdvColor(colors.surface, colors.accent, options._active)
	local strokeColor = useAdvColor(colors.surfaceStroke, colors.accentStrong, options._active)
	local imageColor = useAdvColor(colors.icon, colors.iconActive, options._active)

	useLabelHover(textRef, { backgroundColor }, {
		onClick = function()
			options:Open(cursor.getPosition())
		end,
	})

	return e("TextButton", {
		BackgroundColor3 = backgroundColor.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(30, 14),
		[React.Event.MouseEnter] = function()
			backgroundColor.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			backgroundColor.onMouseLeave()
		end,
		[React.Event.MouseButton1Click] = function()
			options:Open(cursor.getPosition())
		end,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		LayoutOrder = layoutOrder,
	}, {
		ImageLabel = e("ImageLabel", {
			BackgroundTransparency = 1,
			Image = FileController.Get("image", "double_right_arrow"),
			ImageColor3 = imageColor.binding,
			Size = UDim2.fromOffset(8, 8),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
	})
end
