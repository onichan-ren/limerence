local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")

local CardViewport = require("@feature/inventory/skinUi/CardViewport")
local viewportThumb = require("@feature/inventory/skinUi/viewportThumb")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local cursor = require("@ui/util/cursor")
local contextApi = require("@ui/subwindow/context/contextApi")
local SPRING = require("@ui/util/spring")

local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local memo = React.memo
local e = React.createElement

local elementColors = themeState.colors.window.element
local inventoryColors = themeState.colors.inventory

local CARD_HEIGHT = 178
local IMAGE_HEIGHT = 104
local CORNER = 6
local BADGE_HEIGHT = 16
local HOVER_LIFT = 3

export type SkinCardEntry = {
	name: string,
	displayName: string,
	collection: string,
	rarityColor: Color3?,
	image: string?,
	color: Color3?,
}

export type SkinPreview = {
	image: string?,
	color: Color3?,
}

export type SkinCardProps = {
	Entry: SkinCardEntry,
	LayoutOrder: number,
	Equipped: boolean,
	OnClick: (name: string) -> (),
	GetPreview: ((entry: any) -> SkinPreview?)?,
	GetPreviewThumb: ((entry: any) -> viewportThumb.Thumb?)?,
	BuildContextItems: ((entry: any, unlocked: boolean?) -> { contextApi.ContextItem }?)?,
	Unlocked: boolean?,
	ShowSwatch: boolean?,
	ImageScaleType: Enum.ScaleType?,
}

local function SkinCardComponent(props: SkinCardProps): React.Element<any>
	local entry = props.Entry
	local equipped = props.Equipped

	local hoverAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	local preview = useMemo(function(): SkinPreview?
		local getPreview = props.GetPreview
		if getPreview then
			return getPreview(entry)
		end
		return entry
	end, { entry, props.GetPreview } :: { any })

	local thumb = useMemo(function(): viewportThumb.Thumb?
		local getThumb = props.GetPreviewThumb
		if getThumb then
			return getThumb(entry)
		end
		return nil
	end, { entry, props.GetPreviewThumb } :: { any })

	local accentColor = useAt(elementColors.textActive)
	local rarityColor = entry.rarityColor or accentColor
	local backgroundColor = useAdvColor(inventoryColors.cardBackground, inventoryColors.cardBackgroundHover, hoverAtom)
	local imageBgColor = useAt(inventoryColors.cardImageBg)
	local skinNameColor = useAt(inventoryColors.cardSkinName)
	local weaponNameColor = useAt(inventoryColors.cardWeaponName)
	local baseStroke = useAt(elementColors.panelStroke)

	local hoverBind, hoverSpring = useSpring(0, SPRING.smoothPreciser)

	local equippedBind, equippedSpring = useSpring(equipped and 1 or 0, SPRING.smoothPreciser)
	useEffect(function()
		equippedSpring:setGoal(equipped and 1 or 0)
	end, { equipped })

	local positionBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return UDim2.fromOffset(0, -value * HOVER_LIFT)
		end)
	end, { hoverBind } :: { any })

	local strokeMixBind = useMemo(function()
		return React.joinBindings({ hoverBind, equippedBind }):map(function(values)
			local hover: number = values[1]
			local eq: number = values[2]
			local mix = math.max(hover * 0.6, eq)
			return baseStroke:Lerp(rarityColor, 0.18 + mix * 0.55)
		end)
	end, { hoverBind, equippedBind, baseStroke, rarityColor } :: { any })

	local strokeTransparencyBind = useMemo(function()
		return React.joinBindings({ hoverBind, equippedBind }):map(function(values)
			local hover: number = values[1]
			local eq: number = values[2]
			return 0.45 - math.max(hover * 0.35, eq * 0.42)
		end)
	end, { hoverBind, equippedBind } :: { any })

	local strokeThicknessBind = useMemo(function()
		return equippedBind:map(function(value: number)
			return 1 + value
		end)
	end, { equippedBind } :: { any })

	local accentBarSizeBind = useMemo(function()
		return React.joinBindings({ hoverBind, equippedBind }):map(function(values)
			local hover: number = values[1]
			local eq: number = values[2]
			return UDim2.new(0.20 + math.max(hover, eq) * 0.7, 0, 0, 2)
		end)
	end, { hoverBind, equippedBind } :: { any })

	local accentBarTransparencyBind = useMemo(function()
		return React.joinBindings({ hoverBind, equippedBind }):map(function(values)
			local hover: number = values[1]
			local eq: number = values[2]
			return 1 - (0.55 + math.max(hover, eq) * 0.45)
		end)
	end, { hoverBind, equippedBind } :: { any })

	local onMouseEnter = useCallback(function()
		hoverAtom(true)
		hoverSpring:setGoal(1)
		backgroundColor.onMouseEnter()
	end, { backgroundColor } :: { any })

	local onMouseLeave = useCallback(function()
		hoverAtom(false)
		hoverSpring:setGoal(0)
		backgroundColor.onMouseLeave()
	end, { backgroundColor } :: { any })

	local onClick = useCallback(function()
		props.OnClick(entry.name)
	end, { props.OnClick, entry.name } :: { any })

	local onContextMenu = useCallback(function(_rbx: GuiObject, input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end
		local build = props.BuildContextItems
		if not build then
			return
		end
		local items = build(entry, props.Unlocked)
		if not items or #items == 0 then
			return
		end
		contextApi.Open(items, cursor.getPosition(input))
	end, { props.BuildContextItems, props.Unlocked, entry } :: { any })

	local previewImage = preview and preview.image or ""
	local previewTint = preview and preview.color or Color3.new(1, 1, 1)

	return e("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Selectable = false,
		Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		Position = positionBind,
		[React.Event.MouseEnter] = onMouseEnter,
		[React.Event.MouseLeave] = onMouseLeave,
		[React.Event.MouseButton1Click] = onClick,
		[React.Event.InputBegan] = onContextMenu :: any,
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
				Thickness = strokeThicknessBind,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
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
				Viewport = thumb and e(CardViewport, {
					Thumb = thumb,
					HoverAtom = hoverAtom,
					Corner = CORNER,
					ZIndex = 2,
				}) or nil,
				Icon = (not thumb and previewImage ~= "") and e("ImageLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					Image = previewImage,
					ImageColor3 = previewTint,
					ScaleType = props.ImageScaleType or Enum.ScaleType.Crop,
					ZIndex = 2,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, CORNER),
					}),
				}) or nil,
				Swatch = (props.ShowSwatch and not thumb and previewImage == "") and e("Frame", {
					BackgroundColor3 = previewTint,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.62, 0.58),
					ZIndex = 2,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, CORNER),
					}),
					UIStroke = e("UIStroke", {
						Color = Color3.new(1, 1, 1),
						Transparency = 0.82,
						Thickness = 1,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					UIGradient = e("UIGradient", {
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.05),
							NumberSequenceKeypoint.new(1, 0.28),
						}),
					}),
				}) or nil,
				UnlockedBadge = props.Unlocked and e("Frame", {
					BackgroundColor3 = accentColor,
					BackgroundTransparency = 0.2,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.fromOffset(8, 8),
					Size = UDim2.fromOffset(0, BADGE_HEIGHT),
					AutomaticSize = Enum.AutomaticSize.X,
					ZIndex = 3,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 3),
					}),
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
					}),
					Label = e("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						FontFace = FileController.Get("font", "semi_bold"),
						Text = "UNLOCKED",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 10,
						Size = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
					}),
				}) or nil,
				EquippedBadge = equipped and e("Frame", {
					BackgroundColor3 = accentColor,
					BackgroundTransparency = 0.2,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 8),
					Size = UDim2.fromOffset(0, BADGE_HEIGHT),
					AutomaticSize = Enum.AutomaticSize.X,
					ZIndex = 3,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 3),
					}),
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
					}),
					Label = e("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						FontFace = FileController.Get("font", "semi_bold"),
						Text = "EQUIPPED",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 10,
						Size = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
					}),
				}) or nil,
			}),
			AccentBar = e("Frame", {
				BackgroundColor3 = rarityColor,
				BackgroundTransparency = accentBarTransparencyBind,
				BorderSizePixel = 0,
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
				Collection = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					FontFace = FileController.Get("font", "semi_bold"),
					Text = string.upper(entry.collection),
					TextColor3 = weaponNameColor,
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
					Text = entry.displayName,
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

local SkinCard = memo(SkinCardComponent, function(prev, nextProps)
	return prev.Entry.name == nextProps.Entry.name
		and prev.Entry.image == nextProps.Entry.image
		and prev.Entry.rarityColor == nextProps.Entry.rarityColor
		and prev.LayoutOrder == nextProps.LayoutOrder
		and prev.Equipped == nextProps.Equipped
		and prev.Unlocked == nextProps.Unlocked
		and prev.OnClick == nextProps.OnClick
		and prev.GetPreview == nextProps.GetPreview
		and prev.GetPreviewThumb == nextProps.GetPreviewThumb
		and prev.BuildContextItems == nextProps.BuildContextItems
		and prev.ShowSwatch == nextProps.ShowSwatch
		and prev.ImageScaleType == nextProps.ImageScaleType
end)

return SkinCard
