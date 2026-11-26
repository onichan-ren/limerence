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

local SORT_LABELS: { [string]: string } = {
	rarity = "By Rarity",
	name = "By Name",
	weapon = "By Weapon",
}

return function(): React.Element<any>
	local sortMode = useAt(inventoryState.sortMode)
	local hovered, setHovered = useState(false)
	local active, setActive = useState(false)

	local hoverAtom = useMemo(function()
		return Charm.atom(false)
	end, {})
	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		hoverAtom(hovered or active)
	end, { hovered, active })

	useEffect(function()
		activeAtom(active)
	end, { active })

	local backgroundColor = useAdvColor(colors.panel, colors.surface, activeAtom)
	local strokeColor = useAdvColor(colors.panelStroke, colors.accentStrong, activeAtom)
	local imageColor = useAdvColor(colors.icon, colors.iconActive, hoverAtom)
	local textColor = useAdvColor(colors.caption, colors.textActive, hoverAtom)

	local rotationBind, rotationSpring = useSpring(0, SPRING.snap)
	useEffect(function()
		rotationSpring:setGoal(active and 1 or 0)
	end, { active })

	local rotationVisualBind = useMemo(function()
		return rotationBind:map(function(value: number)
			return value * 180
		end)
	end, { rotationBind } :: { any })

	local onMouseEnter = useCallback(function()
		setHovered(true)
		backgroundColor.onMouseEnter()
		strokeColor.onMouseEnter()
		imageColor.onMouseEnter()
		textColor.onMouseEnter()
	end, { backgroundColor, strokeColor, imageColor, textColor } :: { any })

	local onMouseLeave = useCallback(function()
		setHovered(false)
		backgroundColor.onMouseLeave()
		strokeColor.onMouseLeave()
		imageColor.onMouseLeave()
		textColor.onMouseLeave()
	end, { backgroundColor, strokeColor, imageColor, textColor } :: { any })

	local toggle = useCallback(function()
		setActive(function(prev)
			return not prev
		end)
	end, {})

	local label = "Sort: " .. (SORT_LABELS[sortMode] or "By Rarity")

	return e("TextButton", {
		BackgroundColor3 = backgroundColor.binding,
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(140, 24),
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
			CornerRadius = UDim.new(0, 4),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 8),
		}),
		Arrow = e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(8, 8),
			Image = FileController.Get("image", "down_arrow") or "",
			ImageColor3 = imageColor.binding,
			Rotation = rotationVisualBind,
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = label,
			TextColor3 = textColor.binding,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.new(1, -14, 1, 0),
		}),
	})
end
