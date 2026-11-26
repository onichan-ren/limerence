local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local Charm = require("@pkg/Charm")
local FileController = require("@feature/file/FileController")

local e = React.createElement
local useAt = ReactCharm.useAtom

export type BadgeProps = {
	Label: string,
	Color: Charm.Atom<Color3>,
	Icon: string?,
	LayoutOrder: number?,
	Outlined: boolean?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
}

local function Badge(props: BadgeProps): React.Element<any>
	local color = useAt(props.Color)
	local hasIcon = props.Icon ~= nil and props.Icon ~= ""
	local outlined = props.Outlined ~= false

	local children: { [string]: React.Element<any> } = {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, hasIcon and 5 or 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 1),
		}),
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "bold"),
			TextColor3 = color,
			TextSize = 10,
			Text = string.upper(props.Label),
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 2,
		}),
	}

	if outlined then
		children.UIStroke = e("UIStroke", {
			Color = color,
			Transparency = 0.5,
			Thickness = 1,
		})
	end

	if hasIcon then
		children.Icon = e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = props.Icon,
			ImageColor3 = color,
			Size = UDim2.fromOffset(10, 10),
			LayoutOrder = 1,
		})
	end

	return e("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0.5),
		Position = props.Position or UDim2.fromScale(0, 0.5),
		LayoutOrder = props.LayoutOrder,
	}, children)
end

return Badge
