local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local inventoryAdapter = require("@feature/inventory/inventoryAdapter")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local cursor = require("@ui/util/cursor")
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
local ICON_SIZE = 56
local OPTIONS_ICON_SIZE = 12
local BADGE_HEIGHT = 16
local HOVER_LIFT = 3
local IMAGE_HOVER_SCALE = 1.06

local RARITY_LABELS: { [string]: string } = {
	common = "Consumer",
	uncommon = "Mil-Spec",
	restricted = "Restricted",
	classified = "Classified",
	covert = "Covert",
	extraordinary = "Extraordinary",
	master = "Master",
}

export type InventoryCardProps = {
	Item: inventoryAdapter.UIItem,
	LayoutOrder: number,
	OnDelete: ((id: string) -> ())?,
	GetMenuItems: ((item: inventoryAdapter.UIItem) -> { any })?,
}

local function InventoryCardComponent(props: InventoryCardProps): React.Element<any>
	local item = props.Item

	local hovered, setHovered = useState(false)
	local optionsHovered, setOptionsHovered = useState(false)

	local hoverAtom = useMemo(function()
		return Charm.atom(false)
	end, {})
	local optionsHoverAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		hoverAtom(hovered)
	end, { hovered })

	useEffect(function()
		optionsHoverAtom(optionsHovered)
	end, { optionsHovered })

	local rarityAtom = (inventoryColors.rarity[item.rarity] or inventoryColors.rarity.common) :: Charm.Atom<Color3>
	local rarityColor = useAt(rarityAtom)

	local backgroundColor = useAdvColor(inventoryColors.cardBackground, inventoryColors.cardBackgroundHover, hoverAtom)
	local imageBgColor = useAt(inventoryColors.cardImageBg)
	local skinNameColor = useAt(inventoryColors.cardSkinName)
	local weaponNameColor = useAt(inventoryColors.cardWeaponName)
	local optionsIconColor = useAdvColor(elementColors.icon, elementColors.iconActive, optionsHoverAtom)
	local shadowPack = useAt(windowColors.shadow)
	local shadowColor = shadowPack[1] :: Color3
	local shadowAlpha = shadowPack[2] :: number

	local baseStroke = useAt(elementColors.panelStroke)

	local hoverBind, hoverSpring = useSpring(0, SPRING.smoothPreciser)
	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	local positionBind = useMemo(function()
		return React.joinBindings({ hoverBind }):map(function(values)
			local hover: number = values[1]
			local lift = -hover * HOVER_LIFT * 1
			return UDim2.fromOffset(0, lift)
		end)
	end, { hoverBind } :: { any })

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

	local accentBarSizeBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return UDim2.new(0.20 + value * 0.7, 0, 0, 2)
		end)
	end, { hoverBind } :: { any })

	local accentBarTransparencyBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return 1 - (0.55 + value * 0.45)
		end)
	end, { hoverBind } :: { any })

	local iconBaseImage = item.icon

	local onMouseEnter = useCallback(function()
		setHovered(true)
		backgroundColor.onMouseEnter()
	end, { backgroundColor } :: { any })

	local onMouseLeave = useCallback(function()
		setHovered(false)
		backgroundColor.onMouseLeave()
	end, { backgroundColor } :: { any })

	local openMenu = useCallback(function(input: InputObject?)
		local items
		if props.GetMenuItems then
			items = props.GetMenuItems(item)
		else
			items = {
				{
					Label = "Delete",
					Icon = FileController.Get("image", "trash"),
					Callback = function(): ()
						if props.OnDelete then
							props.OnDelete(item.id)
						end
					end,
				},
			}
		end
		SubwindowController.OpenContext(items, cursor.getPosition(input))
	end, { props.OnDelete, props.GetMenuItems, item } :: { any })

	local onOptionsClick = useCallback(function(_rbx: any, input: InputObject)
		openMenu(input)
	end, { openMenu } :: { any })

	local onOptionsEnter = useCallback(function()
		setOptionsHovered(true)
		optionsIconColor.onMouseEnter()
	end, { optionsIconColor } :: { any })

	local onOptionsLeave = useCallback(function()
		setOptionsHovered(false)
		optionsIconColor.onMouseLeave()
	end, { optionsIconColor } :: { any })

	local onCardInput = useCallback(function(_rbx: any, input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			openMenu(input)
		end
	end, { openMenu } :: { any })

	local rarityLabel = RARITY_LABELS[item.rarity] or item.rarity

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
	}, {
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
				Position = UDim2.fromOffset(0, 0),
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
					Image = iconBaseImage or "",
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
				Options = e("TextButton", {
					BackgroundColor3 = imageBgMixBind,
					BackgroundTransparency = 0.4,
					BorderSizePixel = 0,
					Text = "",
					Active = false,
					AutoButtonColor = false,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 8),
					Size = UDim2.fromOffset(22, 22),
					ZIndex = 3,
					[React.Event.MouseEnter] = onOptionsEnter,
					[React.Event.MouseLeave] = onOptionsLeave,
					[React.Event.MouseButton1Click] = onOptionsClick :: any,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 4),
					}),
					Icon = e("ImageLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(OPTIONS_ICON_SIZE, OPTIONS_ICON_SIZE),
						Image = FileController.Get("image", "options") or "",
						ImageColor3 = optionsIconColor.binding,
					}),
				}),
			}),
			AccentBar = e("Frame", {
				BackgroundColor3 = rarityColor,
				BackgroundTransparency = accentBarTransparencyBind,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.new(0.05, 0, 0, IMAGE_HEIGHT + 1),
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
				Weapon = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					FontFace = FileController.Get("font", "semi_bold"),
					Text = string.upper(item.weapon),
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
					Text = item.skin,
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

local InventoryCard = memo(InventoryCardComponent, function(prev, next)
	return prev.Item.id == next.Item.id
		and prev.LayoutOrder == next.LayoutOrder
		and prev.Item.float == next.Item.float
		and prev.Item.skin == next.Item.skin
		and prev.OnDelete == next.OnDelete
		and prev.GetMenuItems == next.GetMenuItems
end)

return InventoryCard
