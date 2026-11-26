local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local Charm = require("@pkg/Charm")

local themeState = require("@ui/theme/themeState")
local FileController = require("@feature/file/FileController")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local scopeState = require("@ui/scope/scopeState")
local SPRING = require("@ui/util/spring")
local dpiState = require("@ui/util/dpiState")

local useSpring = ReactRipple.useSpring
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef
local useAt = ReactCharm.useAtom
local e = React.createElement

local elementColors = themeState.colors.window.element

export type ScopeSelectorProperties = {
	OnManage: (() -> ())?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Size: UDim2?,
}

return function(properties: ScopeSelectorProperties): React.Element<any>
	local current = useAt(scopeState.currentScope)
	local scopes = useAt(scopeState.scopes)
	local isOpen = useAt(scopeState.menuOpen)

	local fieldBackground = useAt(elementColors.fieldBackground)
	local fieldBackgroundActive = useAt(elementColors.fieldBackgroundActive)
	local fieldStroke = useAt(elementColors.fieldStroke)
	local fieldStrokeActive = useAt(elementColors.fieldStrokeActive)
	local textActive = useAt(elementColors.textActive)
	local iconColor = useAt(elementColors.icon)

	local isHovering, setHovering = useState(false)

	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	local openBind, openSpring = useSpring(0, SPRING.smooth)

	useEffect(function()
		hoverSpring:setGoal(isHovering and 1 or 0)
	end, { isHovering })

	useEffect(function()
		openSpring:setGoal(isOpen and 1 or 0)
	end, { isOpen })

	useEffect(function()
		local onManage = properties.OnManage
		local menu: any = SubwindowController.Get("ScopeMenu")
		if menu then
			menu:SetOnManage(onManage)
		end
		return function()
			if menu then
				menu:SetOnManage(nil)
			end
		end
	end, { properties.OnManage } :: { any })

	local frameRef = useRef(nil :: GuiObject?)

	local def = scopes[current]
	local label = def and def.label or current

	return e("TextButton", {
		ref = frameRef,
		BackgroundColor3 = hoverBind:map(function(value: number)
			return fieldBackground:Lerp(fieldBackgroundActive, value * 0.55)
		end),
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		Size = properties.Size or UDim2.fromOffset(0, 22),
		AutomaticSize = properties.Size and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		Position = properties.Position,
		AnchorPoint = properties.AnchorPoint,
		LayoutOrder = properties.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
		[React.Event.MouseButton1Click] = function()
			if SubwindowController.WasScopeMenuJustClosed() then
				return
			end
			if Charm.peek(scopeState.menuOpen) then
				SubwindowController.CloseScopeMenu()
				return
			end
			local frame = frameRef.current
			if not frame then
				return
			end
			local pos = frame.AbsolutePosition
			local size = frame.AbsoluteSize
			local MENU_WIDTH = 184
			local scale = Charm.peek(dpiState.scale)
			if scale <= 0 then
				scale = 1
			end
			local logicalX = (pos.X + size.X) / scale - MENU_WIDTH
			local logicalY = (pos.Y + size.Y) / scale + 6
			local anchor = UDim2.fromOffset(math.floor(logicalX), math.floor(logicalY))
			SubwindowController.OpenScopeMenu(anchor, frameRef)
		end,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIStroke = e("UIStroke", {
			Color = hoverBind:map(function(value: number)
				return fieldStroke:Lerp(fieldStrokeActive, value)
			end),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 9),
			PaddingRight = UDim.new(0, 8),
		}),
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 7),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = label,
			TextColor3 = textActive,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			FontFace = FileController.Get("font", "semi_bold"),
			LayoutOrder = 1,
		}),
		Arrow = e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(8, 8),
			Image = FileController.Get("image", "down_arrow"),
			ImageColor3 = iconColor,
			Rotation = openBind:map(function(value: number)
				return value * 180
			end),
			LayoutOrder = 2,
		}),
	})
end
