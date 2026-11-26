local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local cursor = require("@ui/util/cursor")
local contextApi = require("@ui/subwindow/context/contextApi")
local cosmeticLibraryAccess = require("@game/rivals/feature/inventory/cosmeticLibraryAccess")
local rankCharms = require("@game/rivals/feature/inventory/rankCharms")
local rivalsInventoryState = require("@game/rivals/feature/inventory/rivalsInventoryState")
local InventoryChanger = require("@game/rivals/feature/inventory/InventoryChanger")
local cosmeticUnlock = require("@game/rivals/feature/inventory/cosmeticUnlock")
local customWrapStore = require("@game/rivals/feature/inventory/customWrapStore")
local customWrapController = require("@game/rivals/feature/inventory/customWrapController")
local customCharmController = require("@game/rivals/feature/inventory/customCharmController")
local SPRING = require("@ui/util/spring")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local memo = React.memo
local e = React.createElement

local windowColors = themeState.colors.window
local elementColors = themeState.colors.window.element
local inventoryColors = themeState.colors.inventory

local CARD_HEIGHT = 178
local IMAGE_HEIGHT = 104
local CORNER = 6
local BADGE_HEIGHT = 16
local HOVER_LIFT = 3
local IMAGE_HOVER_SCALE = 1.06
local SKIN_ICON_FILL = 3
local DEFAULT_ICON_FILL = 0.7

export type CosmeticCardProps = {
	Entry: cosmeticLibraryAccess.CosmeticEntry,
	LayoutOrder: number,
	Equipped: boolean,
	OnClick: (name: string) -> (),
	OnApplyToAll: ((name: string) -> ())?,
	OnUnapplyAll: ((name: string) -> ())?,
}

local function CosmeticCardComponent(props: CosmeticCardProps): React.Element<any>
	local entry = props.Entry
	local equipped = props.Equipped

	local hovered, setHovered = useState(false)

	local hoverAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		hoverAtom(hovered)
	end, { hovered })

	local rarityColor = entry.rarityColor

	local backgroundColor = useAdvColor(inventoryColors.cardBackground, inventoryColors.cardBackgroundHover, hoverAtom)
	local imageBgColor = useAt(inventoryColors.cardImageBg)
	local skinNameColor = useAt(inventoryColors.cardSkinName)
	local weaponNameColor = useAt(inventoryColors.cardWeaponName)
	local baseStroke = useAt(elementColors.panelStroke)

	local hoverBind, hoverSpring = useSpring(0, SPRING.smoothPreciser)
	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	local equippedBind, equippedSpring = useSpring(equipped and 1 or 0, SPRING.smoothPreciser)
	useEffect(function()
		equippedSpring:setGoal(equipped and 1 or 0)
	end, { equipped })

	local positionBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return UDim2.fromOffset(0, -value * HOVER_LIFT)
		end)
	end, { hoverBind } :: { any })

	local imageScaleBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return 1 + (IMAGE_HOVER_SCALE - 1) * value
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

	local imageBgMixBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return imageBgColor:Lerp(rarityColor, value * 0.06)
		end)
	end, { hoverBind, imageBgColor, rarityColor } :: { any })

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
		setHovered(true)
		backgroundColor.onMouseEnter()
	end, { backgroundColor } :: { any })

	local onMouseLeave = useCallback(function()
		setHovered(false)
		backgroundColor.onMouseLeave()
	end, { backgroundColor } :: { any })

	local onClick = useCallback(function()
		props.OnClick(entry.name)
	end, { props.OnClick, entry.name } :: { any })

	local onContextMenu = useCallback(function(_rbx: GuiObject, input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end
		local apply = entry.type ~= "Skin" and props.OnApplyToAll or nil
		local allowUnlock = not (entry.isCustom == true)
			and not (entry.isRankCharm == true)
			and not (entry.isArchnemesis == true)
		local items: { contextApi.ContextItem } = {}
		if allowUnlock then
			if cosmeticUnlock.IsUnlocked(entry.name) then
				items[#items + 1] = {
					Label = "Lock",
					Callback = function()
						cosmeticUnlock.Lock(entry.name)
					end,
				}
			else
				items[#items + 1] = {
					Label = "Unlock",
					Callback = function()
						cosmeticUnlock.Unlock(entry.name)
					end,
				}
			end
		end
		if #items > 0 and apply then
			items[#items + 1] = { Divider = true }
		end
		if apply then
			items[#items + 1] = {
				Label = "Apply to All",
				Callback = function()
					apply(entry.name)
				end,
			}
		end
		if #items == 0 then
			return
		end
		contextApi.Open(items, cursor.getPosition(input))
	end, { props.OnApplyToAll, entry.name } :: { any })

	local isRankCharm = entry.isRankCharm == true
	local isArchnemesis = entry.isArchnemesis == true
	local seasonMap = useAt(rivalsInventoryState.rankCharmSeasons)
	local archRank = useAt(rivalsInventoryState.rankCharmArchRank)
	local selectedSeason = seasonMap[entry.name]

	local unlockedSet = useAt(rivalsInventoryState.unlockedCosmetics)
	local canUnlock = not (entry.isCustom == true) and not isRankCharm and not isArchnemesis
	local isUnlocked = canUnlock and unlockedSet[entry.name] == true

	local seasonLabel = useMemo(function()
		local season = selectedSeason or rankCharms.getLatestSeason()
		return season and ("Season " .. season) or "Season ?"
	end, { selectedSeason } :: { any })

	local onSeasonClick = useCallback(function()
		local seasons = rankCharms.getSeasons()
		if #seasons == 0 then
			return
		end
		local current = selectedSeason or rankCharms.getLatestSeason() or seasons[#seasons]
		local idx: number? = nil
		for i, v in next, seasons do
			if v == current then
				idx = i
				break
			end
		end
		local nextIdx = (idx and (idx % #seasons) + 1 or 1)
		local map = table.clone(seasonMap)
		map[entry.name] = seasons[nextIdx]
		rivalsInventoryState.rankCharmSeasons(map)
		InventoryChanger.RefreshLoadout()
	end, { seasonMap, entry.name } :: { any })

	local onArchFocusLost = useCallback(function(rbx: TextBox)
		local n = tonumber(rbx.Text)
		if n then
			n = math.clamp(math.floor(n), 1, 200)
			rivalsInventoryState.rankCharmArchRank(n)
			rbx.Text = tostring(n)
			InventoryChanger.RefreshLoadout()
		else
			rbx.Text = tostring(archRank)
		end
	end, { archRank } :: { any })

	local selectedWeapon = useAt(rivalsInventoryState.selectedWeapon)
	local weaponInventory = useAt(rivalsInventoryState.weaponInventory)
	local isWrap = entry.type == "Wrap"
	local showInvert = isWrap
		and not (entry.isCustom == true)
		and equipped
		and cosmeticLibraryAccess.getWrapGroupCount(entry.name) >= 2
	local wrapInverted = false
	if showInvert and selectedWeapon then
		local inv = weaponInventory[selectedWeapon]
		wrapInverted = inv ~= nil and inv.wrapInverted == true
	end

	local onInvertClick = useCallback(function()
		if not selectedWeapon then
			return
		end
		InventoryChanger.SetWrapInverted(selectedWeapon, not wrapInverted)
	end, { selectedWeapon, wrapInverted } :: { any })

	local isCustom = entry.isCustom == true

	local iconScale = entry.imageScale > 0 and entry.imageScale or 1
	local iconFill = (entry.type == "Skin" and SKIN_ICON_FILL or DEFAULT_ICON_FILL)
	local iconSize = isCustom and UDim2.fromScale(1, 1)
		or UDim2.new(iconFill / math.max(1, iconScale), 0, iconFill / math.max(1, iconScale), 0)
	local iconScaleType = isCustom and Enum.ScaleType.Crop or Enum.ScaleType.Fit

	local resolvedImage = entry.image
	if resolvedImage == nil or resolvedImage == "" then
		resolvedImage = cosmeticLibraryAccess.getTypeImage(entry.type) or ""
	end
	local wrapColor: Color3? = nil
	if entry.type == "Wrap" and not isCustom then
		wrapColor = cosmeticLibraryAccess.getWrapColor(entry.name)
	end
	local imageTint: Color3 = wrapColor or Color3.new(1, 1, 1)

	local onEditClick = useCallback(function(): ()
		if entry.customId then
			customWrapStore.openEdit(entry.customId, entry.type)
		end
	end, { entry.customId, entry.type } :: { any })

	local onDeleteClick = useCallback(function(): ()
		local id = entry.customId
		if not id then
			return
		end
		if entry.type == "Charm" then
			for weaponName, eq in next, weaponInventory do
				if eq.charm == id then
					InventoryChanger.Unequip(weaponName, "Charm")
				end
			end
			customCharmController.delete(id)
		else
			for weaponName, eq in next, weaponInventory do
				if eq.wrap == id then
					InventoryChanger.Unequip(weaponName, "Wrap")
				end
			end
			customWrapController.delete(id)
		end
	end, { entry.customId, entry.type, weaponInventory } :: { any })

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
				Icon = e("ImageLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = iconSize,
					Image = resolvedImage,
					ImageColor3 = imageTint,
					ScaleType = iconScaleType,
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
						Text = entry.rarity,
						TextColor3 = rarityColor,
						TextSize = 10,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						Size = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
					}),
				}),
				EquippedBadge = equipped and e("Frame", {
					BackgroundColor3 = rarityColor,
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
				UnlockedBadge = isUnlocked and e("Frame", {
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.35,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, equipped and (8 + BADGE_HEIGHT + 4) or 8),
					Size = UDim2.fromOffset(0, BADGE_HEIGHT),
					AutomaticSize = Enum.AutomaticSize.X,
					ZIndex = 3,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 3),
					}),
					UIStroke = e("UIStroke", {
						Color = rarityColor,
						Transparency = 0.4,
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
						Text = "UNLOCKED",
						TextColor3 = rarityColor,
						TextSize = 10,
						Size = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				}) or nil,
				SeasonControl = isRankCharm and e("TextButton", {
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.35,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Active = false,
					Text = "",
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.new(0, 8, 0, 8),
					Size = UDim2.fromOffset(0, BADGE_HEIGHT),
					AutomaticSize = Enum.AutomaticSize.X,
					ZIndex = 4,
					[React.Event.MouseButton1Click] = onSeasonClick,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 3),
					}),
					UIStroke = e("UIStroke", {
						Color = rarityColor,
						Transparency = 0.5,
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
						Text = seasonLabel,
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 10,
						Size = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				}) or nil,
				ArchControl = isArchnemesis and e("Frame", {
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.35,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.new(0, 8, 0, 8 + BADGE_HEIGHT + 4),
					Size = UDim2.fromOffset(52, BADGE_HEIGHT),
					ZIndex = 4,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 3),
					}),
					UIStroke = e("UIStroke", {
						Color = rarityColor,
						Transparency = 0.5,
						Thickness = 1,
					}),
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
					}),
					UIListLayout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 1),
					}),
					Hash = e("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						FontFace = FileController.Get("font", "semi_bold"),
						Text = "#",
						TextColor3 = rarityColor,
						TextSize = 10,
						Size = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						LayoutOrder = 0,
						ZIndex = 4,
					}),
					Input = e("TextBox", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ClearTextOnFocus = false,
						FontFace = FileController.Get("font", "semi_bold"),
						Text = tostring(archRank),
						PlaceholderText = "1",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 10,
						Size = UDim2.new(1, -8, 1, 0),
						LayoutOrder = 1,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
						ZIndex = 4,
						[React.Event.FocusLost] = onArchFocusLost,
					}),
				}) or nil,
				InvertControl = showInvert and e("TextButton", {
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.35,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Text = "",
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.new(0, 8, 0, 8),
					Size = UDim2.fromOffset(0, BADGE_HEIGHT),
					AutomaticSize = Enum.AutomaticSize.X,
					Active = false,
					ZIndex = 4,
					[React.Event.MouseButton1Click] = onInvertClick,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 3),
					}),
					UIStroke = e("UIStroke", {
						Color = rarityColor,
						Transparency = wrapInverted and 0.2 or 0.6,
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
						Text = wrapInverted and "INVERTED" or "INVERT",
						TextColor3 = wrapInverted and rarityColor or Color3.new(1, 1, 1),
						TextSize = 10,
						Size = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				}) or nil,
			}),
			CustomActions = (isCustom and hovered) and e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.new(0, 8, 0, 8),
				Size = UDim2.fromOffset(44, 18),
				ZIndex = 4,
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				Edit = e("TextButton", {
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.35,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Text = "",
					Size = UDim2.fromOffset(18, 18),
					LayoutOrder = 0,
					ZIndex = 4,
					[React.Event.MouseButton1Click] = onEditClick,
				}, {
					UICorner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
					Icon = e("ImageLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(11, 11),
						Image = FileController.Get("image", "pencil"),
						ImageColor3 = Color3.new(1, 1, 1),
						ScaleType = Enum.ScaleType.Fit,
						ZIndex = 4,
					}),
				}),
				Delete = e("TextButton", {
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.35,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Text = "",
					Size = UDim2.fromOffset(18, 18),
					LayoutOrder = 1,
					ZIndex = 4,
					[React.Event.MouseButton1Click] = onDeleteClick,
				}, {
					UICorner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
					Icon = e("ImageLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(11, 11),
						Image = FileController.Get("image", "trash"),
						ImageColor3 = rarityColor,
						ScaleType = Enum.ScaleType.Fit,
						ZIndex = 4,
					}),
				}),
			}) or nil,
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
				Type = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					FontFace = FileController.Get("font", "semi_bold"),
					Text = string.upper(entry.type),
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

local CosmeticCard = memo(CosmeticCardComponent, function(prev, next)
	return prev.Entry.name == next.Entry.name
		and prev.Entry.displayName == next.Entry.displayName
		and prev.Entry.image == next.Entry.image
		and prev.Entry.isCustom == next.Entry.isCustom
		and prev.LayoutOrder == next.LayoutOrder
		and prev.Equipped == next.Equipped
		and prev.OnClick == next.OnClick
		and prev.OnApplyToAll == next.OnApplyToAll
		and prev.OnUnapplyAll == next.OnUnapplyAll
end)

return CosmeticCard
