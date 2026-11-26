local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local SPRING = require("@ui/util/spring")

local useMemo = React.useMemo
local useEffect = React.useEffect
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

export type FolderCardEntry = {
	name: string,
	count: number,
	sample: string,
}

export type FolderPreview = {
	image: string?,
	color: Color3?,
}

export type FolderCardProps = {
	Entry: FolderCardEntry,
	LayoutOrder: number,
	Active: boolean,
	OnOpen: (name: string) -> (),
	GetPreview: (entry: any) -> FolderPreview?,
}

local function FolderCardComponent(props: FolderCardProps): React.Element<any>
	local entry = props.Entry
	local active = props.Active

	local hoverAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	local preview = useMemo(function(): FolderPreview?
		return props.GetPreview(entry)
	end, { entry, props.GetPreview } :: { any })

	local accentColor = useAt(elementColors.textActive)
	local backgroundColor = useAdvColor(inventoryColors.cardBackground, inventoryColors.cardBackgroundHover, hoverAtom)
	local imageBgColor = useAt(inventoryColors.cardImageBg)
	local skinNameColor = useAt(inventoryColors.cardSkinName)
	local weaponNameColor = useAt(inventoryColors.cardWeaponName)
	local baseStroke = useAt(elementColors.panelStroke)

	local hoverBind, hoverSpring = useSpring(0, SPRING.smoothPreciser)

	local activeBind, activeSpring = useSpring(active and 1 or 0, SPRING.smoothPreciser)
	useEffect(function()
		activeSpring:setGoal(active and 1 or 0)
	end, { active })

	local positionBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return UDim2.fromOffset(0, -value * HOVER_LIFT)
		end)
	end, { hoverBind } :: { any })

	local strokeMixBind = useMemo(function()
		return React.joinBindings({ hoverBind, activeBind }):map(function(values)
			local hover: number = values[1]
			local act: number = values[2]
			local mix = math.max(hover * 0.6, act)
			return baseStroke:Lerp(accentColor, 0.18 + mix * 0.55)
		end)
	end, { hoverBind, activeBind, baseStroke, accentColor } :: { any })

	local strokeTransparencyBind = useMemo(function()
		return React.joinBindings({ hoverBind, activeBind }):map(function(values)
			local hover: number = values[1]
			local act: number = values[2]
			return 0.45 - math.max(hover * 0.35, act * 0.42)
		end)
	end, { hoverBind, activeBind } :: { any })

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
		props.OnOpen(entry.name)
	end, { props.OnOpen, entry.name } :: { any })

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
				Thickness = 1,
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
				Icon = previewImage ~= "" and e("ImageLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					Image = previewImage,
					ImageColor3 = previewTint,
					ImageTransparency = 0.15,
					ScaleType = Enum.ScaleType.Crop,
					ZIndex = 2,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, CORNER),
					}),
				}) or nil,
				CountBadge = e("Frame", {
					BackgroundColor3 = imageBgColor,
					BackgroundTransparency = 0.25,
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
						Text = tostring(entry.count),
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 10,
						Size = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
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
				Kind = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					FontFace = FileController.Get("font", "semi_bold"),
					Text = "COLLECTION",
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
					Text = entry.name,
					TextColor3 = skinNameColor,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					Size = UDim2.new(1, 0, 0, 16),
					LayoutOrder = 1,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				Count = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					FontFace = FileController.Get("font", "light"),
					Text = `{entry.count} skins`,
					TextColor3 = weaponNameColor,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					Size = UDim2.new(1, 0, 0, 14),
					LayoutOrder = 2,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
			}),
		}),
	})
end

local FolderCard = memo(FolderCardComponent, function(prev, nextProps)
	return prev.Entry.name == nextProps.Entry.name
		and prev.Entry.count == nextProps.Entry.count
		and prev.LayoutOrder == nextProps.LayoutOrder
		and prev.Active == nextProps.Active
		and prev.OnOpen == nextProps.OnOpen
		and prev.GetPreview == nextProps.GetPreview
end)

return FolderCard
