local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local useShadow = require("@ui/hook/useShadow")
local SPRING = require("@ui/util/spring")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local memo = React.memo
local e = React.createElement

local inventoryColors = themeState.colors.inventory
local windowColors = themeState.colors.window
local elementColors = themeState.colors.window.element

local CARD_HEIGHT = 138
local IMAGE_HEIGHT = 94
local CORNER = 6
local HOVER_LIFT = 3
local IMAGE_HOVER_SCALE = 1.06

export type WeaponCardProps = {
	Weapon: string,
	Group: string,
	Icon: string?,
	LayoutOrder: number,
	OnSelect: (weapon: string) -> (),
}

local function WeaponCardComponent(props: WeaponCardProps): React.Element<any>
	local hovered, setHovered = useState(false)
	local pressed, setPressed = useState(false)

	local hoverAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		hoverAtom(hovered)
	end, { hovered })

	local backgroundColor = useAdvColor(inventoryColors.cardBackground, inventoryColors.cardBackgroundHover, hoverAtom)
	local imageBgColor = useAt(inventoryColors.cardImageBg)
	local nameColor = useAt(inventoryColors.cardSkinName)
	local groupColor = useAt(inventoryColors.cardWeaponName)
	local shadowPack = useAt(windowColors.shadow)
	local shadowColor = shadowPack[1] :: Color3
	local shadowAlpha = shadowPack[2] :: number
	local baseStroke = useAt(elementColors.panelStroke)
	local accentStroke = useAt(elementColors.surfaceStroke)

	local hoverBind, hoverSpring = useSpring(0, SPRING.smoothPreciser)
	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	local pressBind, pressSpring = useSpring(0, SPRING.quickPreciser)
	useEffect(function()
		pressSpring:setGoal(pressed and 1 or 0)
	end, { pressed })

	local positionBind = useMemo(function()
		return React.joinBindings({ hoverBind, pressBind }):map(function(values)
			local hover: number = values[1]
			local press: number = values[2]
			local lift = -hover * HOVER_LIFT + press * 1
			return UDim2.fromOffset(0, lift)
		end)
	end, { hoverBind, pressBind } :: { any })

	local cardScaleBind = useMemo(function()
		return pressBind:map(function(value: number)
			return 1 - value * 0.012
		end)
	end, { pressBind } :: { any })

	local imageScaleBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return 1 + (IMAGE_HOVER_SCALE - 1) * value
		end)
	end, { hoverBind } :: { any })

	local strokeMixBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return baseStroke:Lerp(accentStroke, 0.18 + value * 0.55)
		end)
	end, { hoverBind, baseStroke, accentStroke } :: { any })

	local strokeTransparencyBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return 0.45 - value * 0.35
		end)
	end, { hoverBind } :: { any })

	local shadowTransparencyBind = useMemo(function()
		return hoverBind:map(function(value: number)
			local opaque = (1 - shadowAlpha) * (0.35 + value * 0.45)
			return 1 - opaque
		end)
	end, { hoverBind, shadowAlpha } :: { any })

	local onMouseEnter = useCallback(function()
		setHovered(true)
		backgroundColor.onMouseEnter()
	end, { backgroundColor } :: { any })

	local onMouseLeave = useCallback(function()
		setHovered(false)
		setPressed(false)
		backgroundColor.onMouseLeave()
	end, { backgroundColor } :: { any })

	local onClick = useCallback(function()
		props.OnSelect(props.Weapon)
	end, { props.OnSelect, props.Weapon } :: { any })

	return e("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		Position = positionBind,
		[React.Event.MouseEnter] = onMouseEnter,
		[React.Event.MouseLeave] = onMouseLeave,
		[React.Event.MouseButton1Down] = function()
			setPressed(true)
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
		end,
		[React.Event.MouseButton1Click] = onClick,
	}, {
		UIScale = e("UIScale", {
			Scale = cardScaleBind,
		}),
		Shadow = useShadow({
			color = shadowColor,
			transparency = shadowTransparencyBind,
			zIndex = 0,
		}),
		Body = e("Frame", {
			BackgroundColor3 = backgroundColor.binding,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, CORNER),
			}),
			UIStroke = e("UIStroke", {
				Color = strokeMixBind,
				Transparency = strokeTransparencyBind,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			ImageArea = e("Frame", {
				BackgroundColor3 = imageBgColor,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, IMAGE_HEIGHT),
				ClipsDescendants = true,
				ZIndex = 1,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, CORNER),
				}),
				BottomCover = e("Frame", {
					BackgroundColor3 = imageBgColor,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, CORNER),
					ZIndex = 1,
				}),
				Icon = e("ImageLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(0.78, 0, 0.78, 0),
					Image = props.Icon or "",
					ImageColor3 = Color3.new(1, 1, 1),
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 2,
				}, {
					UIScale = e("UIScale", {
						Scale = imageScaleBind,
					}),
				}),
			}),
			TextArea = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, IMAGE_HEIGHT),
				Size = UDim2.new(1, 0, 1, -IMAGE_HEIGHT),
				ZIndex = 2,
			}, {
				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 10),
				}),
				UIListLayout = e("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Top,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 2),
				}),
				Group = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					FontFace = FileController.Get("font", "semi_bold"),
					Text = string.upper(props.Group),
					TextColor3 = groupColor,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					Size = UDim2.new(1, 0, 0, 12),
					LayoutOrder = 0,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				Name = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					FontFace = FileController.Get("font", "semi_bold"),
					Text = props.Weapon,
					TextColor3 = nameColor,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					Size = UDim2.new(1, 0, 0, 16),
					LayoutOrder = 1,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
			}),
		}),
	})
end

local WeaponCard = memo(WeaponCardComponent, function(prev, next)
	return prev.Weapon == next.Weapon and prev.LayoutOrder == next.LayoutOrder and prev.OnSelect == next.OnSelect
end)

return WeaponCard
