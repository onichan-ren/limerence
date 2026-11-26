local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useAt = ReactCharm.useAtom
local e = React.createElement

local windowColors = themeState.colors.window
local elementColors = themeState.colors.window.element
local gridLayout = require("@feature/inventory/gridLayout")

local BAR_HEIGHT = 32
local BACK_SIZE = 23
local PAD_X = gridLayout.PADDING_X

type BackButtonProps = {
	OnClick: () -> (),
}

local function BackButton(props: BackButtonProps): React.Element<any>
	local hovered, setHovered = useState(false)

	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		activeAtom(hovered)
	end, { hovered })

	local backgroundColor = useAdvColor(elementColors.surface, elementColors.fieldBackgroundActive, activeAtom, true)
	local iconColor = useAdvColor(elementColors.icon, elementColors.iconActive, activeAtom)

	local onEnter = useCallback(function()
		setHovered(true)
		backgroundColor.onMouseEnter()
		iconColor.onMouseEnter()
	end, { backgroundColor, iconColor } :: { any })

	local onLeave = useCallback(function()
		setHovered(false)
		backgroundColor.onMouseLeave()
		iconColor.onMouseLeave()
	end, { backgroundColor, iconColor } :: { any })

	return e("TextButton", {
		BackgroundColor3 = backgroundColor.binding,
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(BACK_SIZE, BACK_SIZE),
		[React.Event.MouseEnter] = onEnter,
		[React.Event.MouseLeave] = onLeave,
		[React.Event.MouseButton1Click] = props.OnClick,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		Icon = e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			Image = FileController.Get("image", "down_arrow") or "",
			ImageColor3 = iconColor.binding,
			Rotation = 90,
		}),
	})
end

export type AddSkinHeaderProps = {
	OnBack: () -> (),
}

return function(props: AddSkinHeaderProps): React.Element<any>
	local dividerColor = useAt(windowColors.divider)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
	}, {
		Content = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, -1),
		}, {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, PAD_X),
				PaddingRight = UDim.new(0, PAD_X),
			}),
			Back = e(BackButton, {
				OnClick = props.OnBack,
			}),
		}),
		Divider = e("Frame", {
			BackgroundColor3 = dividerColor,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 1),
		}),
	})
end
