local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local FileController = require("@src/feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local Sift = require("@pkg/Sift")

local useAt = ReactCharm.useAtom
local useMemo = React.useMemo
local e = React.createElement

local colors = themeState.colors.window.section

export type SectionRendererProperties = {
	Section: any,
	TextOffsetY: number?,
}

return function(properties: SectionRendererProperties): React.Element<any>
	local section = properties.Section
	local textOffsetY = properties.TextOffsetY

	local elements = useAt(section._elements)
	local headerAccessory = useAt(section._headerAccessory)

	local renderedElements = useMemo(function()
		local rendered = {}
		for index, element in next, elements do
			rendered[index] = element:Render(index, { textOffsetY = textOffsetY })
		end
		return rendered
	end, { elements, textOffsetY })

	local renderedAccessory = useMemo(function(): React.Element<any>?
		if not headerAccessory then
			return nil
		end
		return headerAccessory:Render(2, { textOffsetY = textOffsetY })
	end, { headerAccessory, textOffsetY })

	local backgroundColor = useAt(colors.background)
	local strokeColor = useAt(colors.stroke)
	local textColor = useAt(colors.text)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Header = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 0,
		}, {
			UIListLayout = e("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Title = e("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = FileController.Get("font", "semi_bold"),
				TextColor3 = textColor,
				TextSize = 11,
				Text = section._title,
				Size = UDim2.fromOffset(0, 14),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 0,
			}),
			Spacer = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = 1,
			}, {
				UIFlexItem = e("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Fill,
				}),
			}),
			Accessory = renderedAccessory,
		}),
		Frame = e(
			"Frame",
			{
				BackgroundColor3 = backgroundColor,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 34),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
			},
			Sift.Dictionary.join({
				UIStroke = e("UIStroke", {
					Color = strokeColor,
					Thickness = 1,
				}),
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
				}),
				UIListLayout = e("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Top,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10),
				}),
			}, renderedElements)
		),
	})
end
