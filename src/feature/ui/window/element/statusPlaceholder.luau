local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")

local e = React.createElement
local useAt = ReactCharm.useAtom

export type StatusPlaceholderProps = {
	Text: string?,
	Align: ("left" | "center" | "right")?,
}

local function alignToEnum(align: ("left" | "center" | "right")?): Enum.TextXAlignment
	if align == "center" then
		return Enum.TextXAlignment.Center
	elseif align == "right" then
		return Enum.TextXAlignment.Right
	end
	return Enum.TextXAlignment.Left
end

local function StatusPlaceholder(props: StatusPlaceholderProps): React.Element<any>
	local color = useAt(themeState.colors.status.placeholder)

	return e("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = FileController.Get("font", "semi_bold"),
		TextColor3 = color,
		TextSize = 11,
		Text = props.Text or "—",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = alignToEnum(props.Align),
		TextYAlignment = Enum.TextYAlignment.Center,
	})
end

return StatusPlaceholder
