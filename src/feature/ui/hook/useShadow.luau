local React = require("@pkg/React")
local FileController = require("@src/feature/file/FileController")

local e = React.createElement

export type ShadowOptions = {
	multiplier: Vector2?,
	transparency: any?,
	visible: any?,
	zIndex: number?,
	color: Color3?,
}

local function useShadow(options: ShadowOptions?): React.Element<any>
	local opts = options or {} :: ShadowOptions
	local multiplier = opts.multiplier or Vector2.new(1.4, 1.4)

	return e("ImageLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(multiplier.X, multiplier.Y),
		Image = FileController.Get("image", "shadow"),
		ImageColor3 = opts.color or Color3.new(0, 0, 0),
		ImageTransparency = opts.transparency or 0,
		Visible = opts.visible == nil and true or opts.visible,
		ZIndex = opts.zIndex or 0,
		ScaleType = Enum.ScaleType.Stretch,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
	})
end

return useShadow
