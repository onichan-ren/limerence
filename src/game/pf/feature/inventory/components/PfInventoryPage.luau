local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local SPRING = require("@ui/util/spring")

local pfSkinState = require("@game/pf/feature/inventory/pfSkinState")
local skinCatalog = require("@game/pf/feature/inventory/skinCatalog")
local SkinChanger = require("@game/pf/feature/inventory/SkinChanger")

local WeaponSelector = require("@feature/inventory/skinUi/WeaponSelector")
local InventoryActions = require("@feature/inventory/skinUi/InventoryActions")
local CardGrid = require("@feature/inventory/skinUi/CardGrid")
local SkinCard = require("@feature/inventory/skinUi/SkinCard")
local FolderCard = require("@feature/inventory/skinUi/FolderCard")
local SearchField = require("@feature/inventory/skinUi/SearchField")
local MetaRow = require("@feature/inventory/skinUi/MetaRow")
local layout = require("@feature/inventory/skinUi/layout")

local SlotTabs = require("@game/pf/feature/inventory/components/SlotTabs")
local CustomizePanel = require("@game/pf/feature/inventory/components/CustomizePanel")

local useState = React.useState
local useMemo = React.useMemo
local useCallback = React.useCallback
local useEffect = React.useEffect
local useAt = ReactCharm.useAtom
local useSpring = ReactRipple.useSpring
local e = React.createElement

local windowColors = themeState.colors.window
local elementColors = themeState.colors.window.element

local SIDEBAR_WIDTH = layout.SIDEBAR_WIDTH
local META_HEIGHT = layout.META_HEIGHT
local SEARCH_HEIGHT = layout.SEARCH_HEIGHT
local SLOT_ROW_HEIGHT = 22
local CUSTOMIZE_HEADER_HEIGHT = 24
local CUSTOMIZE_PANEL_HEIGHT = 176
local PAD = layout.SECTION_GAP
local CONTENT_PAD_X = layout.CONTENT_PAD_X
local FIELD_PAD_X = layout.FIELD_PAD_X
local ELEMENT_GAP = layout.ELEMENT_GAP
local ACTIONS_WIDTH = 70

local ACTION_BUTTONS = {
	{
		Label = "Clear All",
		Width = ACTIONS_WIDTH,
		OnClick = function()
			SkinChanger.ClearAll()
		end,
	},
}

local function getSkinPreview(entry: skinCatalog.SkinEntry): skinCatalog.SkinPreview?
	return skinCatalog.getPreview(entry.name)
end

local function getFolderPreview(entry: skinCatalog.FolderEntry): skinCatalog.SkinPreview?
	return skinCatalog.getPreview(entry.sample)
end

local function useWeapons(): WeaponSelector.WeaponListResult
	local ready = useAt(pfSkinState.ready)
	local weapons = useMemo(function()
		return skinCatalog.getWeapons()
	end, {})
	local pinned = useMemo(function()
		return skinCatalog.getEquippedWeapons()
	end, { ready } :: { any })
	return { list = weapons, pinned = pinned }
end

type CustomizeHeaderProps = {
	Label: string,
	ArrowRotation: any,
	Open: boolean,
	OnToggle: () -> (),
}

local function CustomizeHeader(props: CustomizeHeaderProps): React.Element<any>
	local hovered, setHovered = useState(false)

	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		activeAtom(hovered or props.Open)
	end, { hovered, props.Open })

	local backgroundColor = useAdvColor(elementColors.panel, elementColors.surface, activeAtom, true)
	local strokeColor = useAdvColor(elementColors.panelStroke, elementColors.accentStrong, activeAtom)
	local textColor = useAdvColor(elementColors.caption, elementColors.textActive, activeAtom)
	local arrowColor = useAdvColor(elementColors.icon, elementColors.iconActive, activeAtom)

	local onEnter = useCallback(function()
		setHovered(true)
		backgroundColor.onMouseEnter()
		strokeColor.onMouseEnter()
		textColor.onMouseEnter()
		arrowColor.onMouseEnter()
	end, { backgroundColor, strokeColor, textColor, arrowColor } :: { any })

	local onLeave = useCallback(function()
		setHovered(false)
		backgroundColor.onMouseLeave()
		strokeColor.onMouseLeave()
		textColor.onMouseLeave()
		arrowColor.onMouseLeave()
	end, { backgroundColor, strokeColor, textColor, arrowColor } :: { any })

	return e("TextButton", {
		BackgroundColor3 = backgroundColor.binding,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 0, CUSTOMIZE_HEADER_HEIGHT),
		[React.Event.MouseEnter] = onEnter,
		[React.Event.MouseLeave] = onLeave,
		[React.Event.MouseButton1Click] = props.OnToggle,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 5),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor.binding,
			Transparency = 0.6,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, FIELD_PAD_X),
			PaddingRight = UDim.new(0, FIELD_PAD_X),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = `Customize: {props.Label}`,
			TextColor3 = textColor.binding,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -14, 1, 0),
		}),
		Arrow = e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(9, 9),
			Image = FileController.Get("image", "down_arrow") or "",
			ImageColor3 = arrowColor.binding,
			Rotation = props.ArrowRotation,
		}),
	})
end

return function(): React.Element<any>
	local selectedWeapon = useAt(pfSkinState.selectedWeapon)
	local activeSlot = useAt(pfSkinState.activeSlot)
	local weaponInventory = useAt(pfSkinState.weaponInventory)
	local searchQuery = useAt(pfSkinState.inventorySearch)
	local folder = useAt(pfSkinState.inventoryFolder)
	local ready = useAt(pfSkinState.ready)

	local customizeOpen, setCustomizeOpen = useState(false)

	local dividerColor = useAt(windowColors.divider)

	local searching = (searchQuery or "") ~= ""
	local showSkins = searching or folder ~= nil

	local skinEntries = useMemo(function()
		if not showSkins then
			return {}
		end
		local list = skinCatalog.listSkins()
		local query = string.lower(searchQuery or "")
		local out = {}
		for _, entry in next, list do
			if query == "" then
				if folder and entry.collection ~= folder then
					continue
				end
			elseif
				not (
					string.find(string.lower(entry.name), query, 1, true)
					or string.find(string.lower(entry.collection), query, 1, true)
				)
			then
				continue
			end
			out[#out + 1] = entry
		end
		return out
	end, { searchQuery, folder, showSkins } :: { any })

	local folderEntries = useMemo(function()
		return skinCatalog.listFolders()
	end, {})

	local slots = useMemo(function()
		if not selectedWeapon then
			return {} :: { skinCatalog.CamoSlot }
		end
		return skinCatalog.getCamoSlots(selectedWeapon)
	end, { selectedWeapon } :: { any })

	local activeTag = useMemo(function(): string?
		if activeSlot then
			for _, slot in next, slots do
				if slot.tag == activeSlot then
					return activeSlot
				end
			end
		end
		return slots[1] and slots[1].tag or nil
	end, { activeSlot, slots } :: { any })

	useEffect(function()
		if activeTag ~= activeSlot then
			pfSkinState.activeSlot(activeTag)
		end
	end, { activeTag, activeSlot } :: { any })

	local slotData = useMemo(function(): pfSkinState.SlotData?
		if not selectedWeapon or not activeTag then
			return nil
		end
		local entry = weaponInventory[selectedWeapon]
		return entry and entry.slots[activeTag] or nil
	end, { selectedWeapon, activeTag, weaponInventory } :: { any })

	local equippedName = useMemo(function()
		return slotData and slotData.skin or nil
	end, { slotData } :: { any })

	local customizable = useMemo(function()
		return equippedName ~= nil and skinCatalog.isCustomizable(equippedName)
	end, { equippedName } :: { any })

	local equippedFolder = useMemo(function()
		return equippedName and skinCatalog.collectionOf(equippedName) or nil
	end, { equippedName } :: { any })

	local onSelectSlot = useCallback(function(tag: string)
		pfSkinState.activeSlot(tag)
	end, {})

	local onEquip = useCallback(function(name: string)
		if not selectedWeapon or not activeTag then
			return
		end
		local newName: string? = (equippedName ~= name and name or nil)
		SkinChanger.Equip(selectedWeapon, activeTag, newName)
	end, { selectedWeapon, activeTag, equippedName } :: { any })

	local buildContextItems = useCallback(function(entry: skinCatalog.SkinEntry)
		if not activeTag then
			return nil
		end
		return {
			{
				Label = "Apply to All",
				Callback = function()
					SkinChanger.ApplyToAll(activeTag, entry.name)
				end,
			},
			{
				Label = "Unapply from All",
				Callback = function()
					SkinChanger.UnapplyFromAll(activeTag, entry.name)
				end,
			},
		}
	end, { activeTag } :: { any })

	local onToggleCustomize = useCallback(function()
		setCustomizeOpen(function(prev: boolean): boolean
			return not prev
		end)
	end, {})

	local onOpenFolder = useCallback(function(name: string)
		pfSkinState.inventoryFolder(name)
	end, {})

	local onBack = useCallback(function()
		pfSkinState.inventoryFolder(nil)
	end, {})

	local renderSkinCard = useCallback(function(entry: skinCatalog.SkinEntry, index: number)
		return e(SkinCard, {
			Entry = entry,
			LayoutOrder = index,
			Equipped = entry.name == equippedName,
			OnClick = onEquip,
			GetPreview = getSkinPreview,
			BuildContextItems = buildContextItems,
		})
	end, { equippedName, onEquip, buildContextItems } :: { any })

	local renderFolderCard = useCallback(function(entry: skinCatalog.FolderEntry, index: number)
		return e(FolderCard, {
			Entry = entry,
			LayoutOrder = index,
			Active = entry.name == equippedFolder,
			OnOpen = onOpenFolder,
			GetPreview = getFolderPreview,
		})
	end, { equippedFolder, onOpenFolder } :: { any })

	local showBack = folder ~= nil and not searching
	local headingLabel = (
		searching and `Results ({#skinEntries})`
		or folder and `{folder} ({#skinEntries})`
		or `Collections ({#folderEntries})`
	)
	local metaLabel = (
		not ready and "Loading inventory..."
		or equippedName and `Equipped: {equippedName}`
		or "Nothing equipped"
	)

	local contentTop = SEARCH_HEIGHT + META_HEIGHT + PAD * 2

	local hasSlots = #slots >= 2
	local slotRowBlock = hasSlots and (SLOT_ROW_HEIGHT + PAD) or 0
	local gridTop = contentTop + slotRowBlock
	local showCustomize = customizable
	local headerBlock = CUSTOMIZE_HEADER_HEIGHT + 2
	local headerReserve = headerBlock + PAD * 2
	local openExtra = PAD + CUSTOMIZE_PANEL_HEIGHT

	local progressBind, progressSpring = useSpring(0, SPRING.smooth)
	local headerProgressBind, headerSpring = useSpring(0, SPRING.smooth)
	useEffect(function()
		progressSpring:setGoal((showCustomize and customizeOpen) and 1 or 0)
	end, { showCustomize, customizeOpen })
	useEffect(function()
		headerSpring:setGoal(showCustomize and 1 or 0)
	end, { showCustomize })

	local gridSizeBind = useMemo(function()
		return React.joinBindings({ headerProgressBind, progressBind }):map(function(values): UDim2
			local hp, ep = values[1], values[2]
			return UDim2.new(1, 0, 1, -(gridTop + hp * headerReserve + ep * openExtra))
		end)
	end, { headerProgressBind, progressBind, gridTop, headerReserve, openExtra } :: { any })

	local blockSizeBind = useMemo(function()
		return React.joinBindings({ headerProgressBind, progressBind }):map(function(values): UDim2
			local hp, ep = values[1], values[2]
			return UDim2.new(1, 0, 0, hp * headerBlock + ep * openExtra)
		end)
	end, { headerProgressBind, progressBind, headerBlock, openExtra } :: { any })

	local headerFadeBind = useMemo(function()
		return headerProgressBind:map(function(p: number): number
			return 1 - p
		end)
	end, { headerProgressBind } :: { any })

	local arrowRotationBind = useMemo(function()
		return progressBind:map(function(p: number): number
			return p * 180
		end)
	end, { progressBind } :: { any })

	local panelFadeBind = useMemo(function()
		return progressBind:map(function(p: number): number
			return 1 - p
		end)
	end, { progressBind } :: { any })

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		Sidebar = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
		}, {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 1),
				PaddingRight = UDim.new(0, 1),
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
			}),
			Inner = e(WeaponSelector, {
				SelectedAtom = pfSkinState.selectedWeapon,
				SearchAtom = pfSkinState.weaponSearch,
				UseWeapons = useWeapons,
				DisplayName = skinCatalog.displayName,
			}),
		}),
		SidebarDivider = e("Frame", {
			BackgroundColor3 = dividerColor,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(SIDEBAR_WIDTH + PAD, 0),
			Size = UDim2.new(0, 1, 1, 0),
		}),
		Main = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(SIDEBAR_WIDTH + PAD * 2 + 1, 0),
			Size = UDim2.new(1, -(SIDEBAR_WIDTH + PAD * 2 + 1), 1, 0),
		}, {
			SearchRow = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(1, 0, 0, SEARCH_HEIGHT),
			}, {
				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, CONTENT_PAD_X),
					PaddingRight = UDim.new(0, CONTENT_PAD_X),
				}),
				Actions = e(InventoryActions, {
					Buttons = ACTION_BUTTONS,
				}),
				SearchBox = e(SearchField, {
					Atom = pfSkinState.inventorySearch,
					Placeholder = "Search skins...",
					Size = UDim2.new(1, -(ACTIONS_WIDTH + ELEMENT_GAP), 1, 0),
					Position = UDim2.fromOffset(0, 5),
				}),
			}),
			MetaRow = e(MetaRow, {
				Heading = headingLabel,
				Meta = metaLabel,
				Top = SEARCH_HEIGHT + PAD,
				ShowBack = showBack,
				OnBack = onBack,
			}),
			SlotRow = hasSlots and e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, contentTop),
				Size = UDim2.new(1, 0, 0, SLOT_ROW_HEIGHT),
			}, {
				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, CONTENT_PAD_X),
					PaddingRight = UDim.new(0, CONTENT_PAD_X),
				}),
				Inner = e(SlotTabs, {
					Weapon = selectedWeapon,
					ActiveTag = activeTag,
					OnSelect = onSelectSlot,
				}),
			}) or nil,
			Grid = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, gridTop),
				Size = gridSizeBind,
			}, {
				Inner = showSkins and e(CardGrid, {
					Entries = skinEntries,
					RenderCard = renderSkinCard,
				}) or e(CardGrid, {
					Entries = folderEntries,
					RenderCard = renderFolderCard,
				}),
			}),
			Customize = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = blockSizeBind,
			}, {
				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, CONTENT_PAD_X),
					PaddingRight = UDim.new(0, CONTENT_PAD_X),
				}),
				HeaderWrap = e("CanvasGroup", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					GroupTransparency = headerFadeBind,
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.new(1, 0, 0, headerBlock),
				}, {
					Header = e(CustomizeHeader, {
						Label = equippedName or "",
						ArrowRotation = arrowRotationBind,
						Open = customizeOpen,
						OnToggle = onToggleCustomize,
					}),
				}),
				Panel = e("CanvasGroup", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					GroupTransparency = panelFadeBind,
					Position = UDim2.fromOffset(0, CUSTOMIZE_HEADER_HEIGHT + 1 + PAD),
					Size = UDim2.new(1, 0, 0, CUSTOMIZE_PANEL_HEIGHT),
				}, {
					Inner = e(CustomizePanel, {
						Weapon = selectedWeapon,
						SlotTag = activeTag,
						Skin = equippedName,
						SlotData = slotData,
					}),
				}),
			}),
		}),
	})
end
