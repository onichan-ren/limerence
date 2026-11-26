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

local CARD_HEIGHT = 178
local IMAGE_HEIGHT = 104
local CORNER = 6
local BADGE_HEIGHT = 16
local HOVER_LIFT = 3
local IMAGE_HOVER_SCALE = 1.06

local RARITY_LABELS: { [string]: string } = {
	common = "Consumer",
	uncommon = "Mil-Spec",
	classified = "Classified",
	covert = "Covert",
	extraordinary = "Extraordinary",
	master = "Master",
}

export type SkinCardProps = {
	Weapon: string,
	Skin: string,
	Rarity: string,
	Collection: string?,
	Icon: string?,
	LayoutOrder: number,
	OnSelect: (weapon: string, skin: string) -> (),
}

local function SkinCardComponent(props: SkinCardProps): React.Element<any>
	local hovered, setHovered = useState(false)
	local pressed, setPressed = useState(false)

	local hoverAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		hoverAtom(hovered)
	end, { hovered })

	local rarityAtom = (inventoryColors.rarity[props.Rarity] or inventoryColors.rarity.common) :: Charm.Atom<Color3>
	local rarityColor = useAt(rarityAtom)

	local backgroundColor = useAdvColor(inventoryColors.cardBackground, inventoryColors.cardBackgroundHover, hoverAtom)
	local imageBgColor = useAt(inventoryColors.cardImageBg)
	local skinNameColor = useAt(inventoryColors.cardSkinName)
	local weaponNameColor = useAt(inventoryColors.cardWeaponName)
	local shadowPack = useAt(windowColors.shadow)
	local shadowColor = shadowPack[1] :: Color3
	local shadowAlpha = shadowPack[2] :: number

	local baseStroke = useAt(elementColors.panelStroke)

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
			return baseStroke:Lerp(rarityColor, 0.18 + value * 0.55)
		end)
	end, { hoverBind, baseStroke, rarityColor } :: { any })

	local strokeTransparencyBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return 0.45 - value * 0.35
		end)
	end, { hoverBind } :: { any })

	local imageBgMixBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return imageBgColor:Lerp(rarityColor, value * 0.06)
		end)
	end, { hoverBind, imageBgColor, rarityColor } :: { any })

	local rarityAccentTransparencyBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return 1 - (0.85 + value * 0.15)
		end)
	end, { hoverBind } :: { any })

	local shadowTransparencyBind = useMemo(function()
		return hoverBind:map(function(value: number)
			local opaque = (1 - shadowAlpha) * (0.35 + value * 0.45)
			return 1 - opaque
		end)
	end, { hoverBind, shadowAlpha } :: { any })

	local accentBarSizeBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return UDim2.new(0.20 + value * 0.60, 0, 0, 2)
		end)
	end, { hoverBind } :: { any })

	local accentBarTransparencyBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return 1 - (0.55 + value * 0.45)
		end)
	end, { hoverBind } :: { any })

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
		props.OnSelect(props.Weapon, props.Skin)
	end, { props.OnSelect, props.Weapon, props.Skin } :: { any })

	local rarityLabel = RARITY_LABELS[props.Rarity] or props.Rarity
	local subtitleText = props.Collection or string.upper(props.Weapon)

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
				BackgroundColor3 = imageBgMixBind,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, IMAGE_HEIGHT),
				ClipsDescendants = true,
				ZIndex = 1,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, CORNER),
				}),
				BottomCover = e("Frame", {
					BackgroundColor3 = imageBgMixBind,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, CORNER),
					ZIndex = 1,
				}),
				RarityAccent = e("Frame", {
					BackgroundColor3 = rarityColor,
					BackgroundTransparency = rarityAccentTransparencyBind,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 1,
				}, {
					UIGradient = e("UIGradient", {
						Color = ColorSequence.new(rarityColor),
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(1, 0.55),
						}),
						Rotation = 90,
					}),
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
				RarityBadge = e("Frame", {
					BackgroundColor3 = rarityColor,
					BackgroundTransparency = 0.78,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 8, 1, -8),
					Size = UDim2.fromOffset(0, BADGE_HEIGHT),
					AutomaticSize = Enum.AutomaticSize.X,
					ZIndex = 3,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 3),
					}),
					UIStroke = e("UIStroke", {
						Color = rarityColor,
						Transparency = 0.5,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = 1,
					}),
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
					}),
					Label = e("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						FontFace = FileController.Get("font", "semi_bold"),
						Text = rarityLabel,
						TextColor3 = rarityColor,
						TextSize = 10,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						Size = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
					}),
				}),
			}),
			AccentBar = e("Frame", {
				BackgroundColor3 = rarityColor,
				BackgroundTransparency = accentBarTransparencyBind,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.new(0, 10, 0, IMAGE_HEIGHT + 1),
				Size = accentBarSizeBind,
				ZIndex = 2,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
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
					PaddingTop = UDim.new(0, 12),
					PaddingBottom = UDim.new(0, 10),
				}),
				UIListLayout = e("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Top,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 2),
				}),
				Subtitle = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					FontFace = FileController.Get("font", "semi_bold"),
					Text = string.upper(subtitleText),
					TextColor3 = weaponNameColor,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					Size = UDim2.new(1, 0, 0, 12),
					LayoutOrder = 0,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				Skin = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					FontFace = FileController.Get("font", "semi_bold"),
					Text = props.Skin,
					TextColor3 = skinNameColor,
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

local SkinCard = memo(SkinCardComponent, function(prev, next)
	return prev.Weapon == next.Weapon
		and prev.Skin == next.Skin
		and prev.LayoutOrder == next.LayoutOrder
		and prev.OnSelect == next.OnSelect
end)

return SkinCard
