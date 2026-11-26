local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local inventoryState = require("@feature/inventory/inventoryState")
local SPRING = require("@ui/util/spring")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local e = React.createElement

local colors = themeState.colors.window.element

local BUTTON_SIZE = 24

type PageButtonProps = {
	Label: string,
	Selected: boolean,
	Disabled: boolean?,
	IconKey: string?,
	IconRotation: number?,
	LayoutOrder: number,
	OnClick: () -> (),
}

local function PageButton(props: PageButtonProps): React.Element<any>
	local hovered, setHovered = useState(false)
	local pressed, setPressed = useState(false)

	local selectedAtom = useMemo(function()
		return Charm.atom(false)
	end, {})
	local hoverAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		selectedAtom(props.Selected)
	end, { props.Selected })

	useEffect(function()
		hoverAtom((hovered or pressed) and not (props.Disabled or false))
	end, { hovered, pressed, props.Disabled })

	local backgroundColor = useAdvColor(colors.panel, colors.accentStrong, selectedAtom, true)
	local strokeColor = useAdvColor(colors.panelStroke, colors.accentStrong, selectedAtom)
	local textColor = useAdvColor(colors.text, colors.thumbStroke, selectedAtom)
	local iconColor = useAdvColor(colors.icon, colors.iconActive, hoverAtom)

	local pressBind, pressSpring = useSpring(0, SPRING.quick)
	useEffect(function()
		pressSpring:setGoal(pressed and 1 or 0)
	end, { pressed })

	local scaleBind = useMemo(function()
		return pressBind:map(function(value: number)
			return 1 - value * 0.06
		end)
	end, { pressBind } :: { any })

	local onMouseEnter = useCallback(function()
		if props.Disabled then
			return
		end
		setHovered(true)
		backgroundColor.onMouseEnter()
		strokeColor.onMouseEnter()
		textColor.onMouseEnter()
		iconColor.onMouseEnter()
	end, { backgroundColor, strokeColor, textColor, iconColor, props.Disabled } :: { any })

	local onMouseLeave = useCallback(function()
		setHovered(false)
		setPressed(false)
		backgroundColor.onMouseLeave()
		strokeColor.onMouseLeave()
		textColor.onMouseLeave()
		iconColor.onMouseLeave()
	end, { backgroundColor, strokeColor, textColor, iconColor } :: { any })

	local onDown = useCallback(function()
		if props.Disabled then
			return
		end
		setPressed(true)
	end, { props.Disabled })

	local onUp = useCallback(function()
		setPressed(false)
	end, {})

	local onClick = useCallback(function()
		if props.Disabled then
			return
		end
		props.OnClick()
	end, { props.OnClick, props.Disabled } :: { any })

	local children: { [string]: React.Element<any> } = {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
			Transparency = props.Selected and 0 or 0.2,
		}),
		UIScale = e("UIScale", {
			Scale = scaleBind,
		}),
	}

	if props.IconKey then
		children.Icon = e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			Image = FileController.Get("image", props.IconKey) or "",
			ImageColor3 = iconColor.binding,
			ImageTransparency = props.Disabled and 0.6 or 0,
			Rotation = props.IconRotation or 0,
		})
	else
		children.Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = props.Label,
			TextColor3 = textColor.binding,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		})
	end

	return e("TextButton", {
		BackgroundColor3 = backgroundColor.binding,
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = onMouseEnter,
		[React.Event.MouseLeave] = onMouseLeave,
		[React.Event.MouseButton1Down] = onDown,
		[React.Event.MouseButton1Up] = onUp,
		[React.Event.MouseButton1Click] = onClick,
	}, children)
end

export type InventoryPaginationProps = {
	TotalPages: number,
}

return function(props: InventoryPaginationProps): React.Element<any>
	local currentPage = useAt(inventoryState.currentPage)
	local totalPages = math.max(1, props.TotalPages)

	local setPage = useCallback(function(page: number)
		local clamped = math.clamp(page, 1, totalPages)
		inventoryState.currentPage(clamped)
	end, { totalPages })

	local buttons: { [string]: React.Element<any> } = {}

	buttons.UIListLayout = e("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	})

	buttons.Prev = e(PageButton, {
		Label = "<",
		Selected = false,
		Disabled = currentPage <= 1,
		IconKey = "down_arrow",
		IconRotation = 90,
		LayoutOrder = 1,
		OnClick = function()
			setPage(currentPage - 1)
		end,
	})

	for i = 1, totalPages do
		buttons[`Page_{i}`] = e(PageButton, {
			Label = tostring(i),
			Selected = i == currentPage,
			LayoutOrder = 1 + i,
			OnClick = function()
				setPage(i)
			end,
		})
	end

	buttons.Next = e(PageButton, {
		Label = ">",
		Selected = false,
		Disabled = currentPage >= totalPages,
		IconKey = "down_arrow",
		IconRotation = -90,
		LayoutOrder = 2 + totalPages,
		OnClick = function()
			setPage(currentPage + 1)
		end,
	})

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 0, 0, BUTTON_SIZE),
		AutomaticSize = Enum.AutomaticSize.X,
	}, buttons)
end
