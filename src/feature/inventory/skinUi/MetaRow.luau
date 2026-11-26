local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local layout = require("@feature/inventory/skinUi/layout")

local useMemo = React.useMemo
local useCallback = React.useCallback
local useRef = React.useRef
local useAt = ReactCharm.useAtom
local e = React.createElement

local elementColors = themeState.colors.window.element

local BACK_SIZE = 20
local CONTENT_PAD_X = layout.CONTENT_PAD_X
local ELEMENT_GAP = layout.ELEMENT_GAP
local META_HEIGHT = layout.META_HEIGHT

export type MetaRowProps = {
	Heading: string,
	Meta: string,
	Top: number,
	ShowBack: boolean?,
	OnBack: (() -> ())?,
}

local function BackButton(props: { OnClick: (() -> ())? }): React.Element<any>
	local hoveredRef = useRef(false)

	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	local backgroundColor = useAdvColor(elementColors.surface, elementColors.fieldBackgroundActive, activeAtom, true)
	local iconColor = useAdvColor(elementColors.icon, elementColors.iconActive, activeAtom)

	local onEnter = useCallback(function()
		hoveredRef.current = true
		activeAtom(true)
		backgroundColor.onMouseEnter()
		iconColor.onMouseEnter()
	end, { backgroundColor, iconColor } :: { any })

	local onLeave = useCallback(function()
		hoveredRef.current = false
		activeAtom(false)
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
			Size = UDim2.fromOffset(9, 9),
			Image = FileController.Get("image", "down_arrow") or "",
			ImageColor3 = iconColor.binding,
			Rotation = 90,
		}),
	})
end

return function(props: MetaRowProps): React.Element<any>
	local mutedColor = useAt(elementColors.caption)
	local strongColor = useAt(elementColors.textActive)

	local showBack = props.ShowBack == true

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, props.Top),
		Size = UDim2.new(1, 0, 0, META_HEIGHT),
	}, {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, CONTENT_PAD_X),
			PaddingRight = UDim.new(0, CONTENT_PAD_X),
		}),
		Back = showBack and e(BackButton, {
			OnClick = props.OnBack,
		}) or nil,
		Heading = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = props.Heading,
			TextColor3 = strongColor,
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Position = UDim2.fromOffset(showBack and (BACK_SIZE + ELEMENT_GAP) or 0, 0),
			Size = UDim2.new(0.6, -(showBack and (BACK_SIZE + ELEMENT_GAP) or 0), 1, 0),
		}),
		Meta = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = props.Meta,
			TextColor3 = mutedColor,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Center,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.4, 0, 1, 0),
		}),
	})
end
