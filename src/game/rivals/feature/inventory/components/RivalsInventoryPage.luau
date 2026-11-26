local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local themeState = require("@ui/theme/themeState")

local rivalsInventoryState = require("@game/rivals/feature/inventory/rivalsInventoryState")
local cosmeticLibraryAccess = require("@game/rivals/feature/inventory/cosmeticLibraryAccess")
local InventoryChanger = require("@game/rivals/feature/inventory/InventoryChanger")
local cosmeticUnlock = require("@game/rivals/feature/inventory/cosmeticUnlock")
local customWrapStore = require("@game/rivals/feature/inventory/customWrapStore")
local ClientState = require("@game/rivals/client/clientState")

local WeaponSelector = require("@feature/inventory/skinUi/WeaponSelector")
local InventoryActions = require("@feature/inventory/skinUi/InventoryActions")
local TypeTabs = require("@feature/inventory/skinUi/TypeTabs")
local CardGrid = require("@feature/inventory/skinUi/CardGrid")
local SearchField = require("@feature/inventory/skinUi/SearchField")
local MetaRow = require("@feature/inventory/skinUi/MetaRow")
local layout = require("@feature/inventory/skinUi/layout")

local CosmeticCard = require("@game/rivals/feature/inventory/components/CosmeticCard")
local CreateWrapCard = require("@game/rivals/feature/inventory/components/CreateWrapCard")
local CustomCosmeticModal = require("@game/rivals/feature/inventory/components/CustomCosmeticModal")

local useMemo = React.useMemo
local useCallback = React.useCallback
local useAt = ReactCharm.useAtom
local e = React.createElement

local windowColors = themeState.colors.window

local SIDEBAR_WIDTH = layout.SIDEBAR_WIDTH
local TYPE_BAR_HEIGHT = layout.TAB_HEIGHT
local META_HEIGHT = layout.META_HEIGHT
local SEARCH_HEIGHT = layout.SEARCH_HEIGHT
local PAD = layout.SECTION_GAP
local CONTENT_PAD_X = layout.CONTENT_PAD_X
local ELEMENT_GAP = layout.ELEMENT_GAP

local UNLOCK_WIDTH = 76
local LOCK_WIDTH = 66
local ACTIONS_WIDTH = UNLOCK_WIDTH + LOCK_WIDTH + ELEMENT_GAP

local TYPE_TABS = {
	{ id = "Skin", label = "Skin" },
	{ id = "Wrap", label = "Wrap" },
	{ id = "Charm", label = "Charm" },
	{ id = "Finisher", label = "Finisher" },
}

local ACTION_BUTTONS = {
	{
		Label = "Unlock All",
		Width = UNLOCK_WIDTH,
		OnClick = function()
			cosmeticUnlock.UnlockAll()
		end,
	},
	{
		Label = "Lock All",
		Width = LOCK_WIDTH,
		OnClick = function()
			cosmeticUnlock.LockAll()
		end,
	},
}

local function resetPage()
	rivalsInventoryState.currentPage(1)
end

local function useWeapons(): WeaponSelector.WeaponListResult
	local loadout = useAt(ClientState.items)

	local weapons = useMemo(function()
		return cosmeticLibraryAccess.getWeapons()
	end, {})

	local ordered = useMemo(function()
		if type(loadout) ~= "table" or #loadout == 0 then
			return weapons
		end
		local available: { [string]: boolean } = {}
		for _, name in next, weapons do
			available[name] = true
		end
		local pinned: { string } = {}
		local seen: { [string]: boolean } = {}
		for _, name in next, loadout do
			if available[name] and not seen[name] then
				seen[name] = true
				pinned[#pinned + 1] = name
			end
		end
		if #pinned == 0 then
			return weapons
		end
		local out: { string } = pinned
		for _, name in next, weapons do
			if not seen[name] then
				out[#out + 1] = name
			end
		end
		return out
	end, { weapons, loadout } :: { any })

	return { list = ordered }
end

return function(): React.Element<any>
	local selectedWeapon = useAt(rivalsInventoryState.selectedWeapon)
	local selectedType = useAt(rivalsInventoryState.selectedType)
	local weaponInventory = useAt(rivalsInventoryState.weaponInventory)
	local searchQuery = useAt(rivalsInventoryState.inventorySearch)
	local ready = useAt(rivalsInventoryState.ready)
	local customWrapsRev = useAt(rivalsInventoryState.customWrapsRev)

	local dividerColor = useAt(windowColors.divider)

	local entries = useMemo(function()
		if not selectedWeapon then
			return {}
		end
		local list = cosmeticLibraryAccess.listByType(selectedType, selectedWeapon)
		local query = string.lower(searchQuery or "")
		if query == "" then
			return list
		end
		local out = {}
		for _, entry in next, list do
			if string.find(string.lower(entry.name), query, 1, true) then
				out[#out + 1] = entry
			end
		end
		return out
	end, { selectedWeapon, selectedType, searchQuery, customWrapsRev } :: { any })

	local equippedName = useMemo(function()
		if not selectedWeapon then
			return nil
		end
		local entry = weaponInventory[selectedWeapon]
		if not entry then
			return nil
		end
		if selectedType == "Skin" then
			return entry.skin
		elseif selectedType == "Wrap" then
			return entry.wrap
		elseif selectedType == "Charm" then
			return entry.charm
		elseif selectedType == "Finisher" then
			return entry.finisher
		end
		return nil
	end, { selectedWeapon, selectedType, weaponInventory } :: { any })

	local onEquip = useCallback(function(name: string)
		if not selectedWeapon then
			return
		end
		local currentEquipped = equippedName
		local newName: string? = (currentEquipped ~= name and name or nil)
		InventoryChanger.Equip(selectedWeapon, selectedType, newName)
	end, { selectedWeapon, selectedType, equippedName } :: { any })

	local onApplyToAll = useCallback(function(name: string)
		InventoryChanger.ApplyToAll(selectedType, name)
	end, { selectedType } :: { any })

	local onUnapplyAll = useCallback(function(name: string)
		InventoryChanger.UnapplyFromAll(selectedType, name)
	end, { selectedType } :: { any })

	local renderCard = useCallback(function(entry: cosmeticLibraryAccess.CosmeticEntry, index: number)
		return e(CosmeticCard, {
			Entry = entry,
			LayoutOrder = index,
			Equipped = entry.name == equippedName,
			OnClick = onEquip,
			OnApplyToAll = onApplyToAll,
			OnUnapplyAll = onUnapplyAll,
		})
	end, { equippedName, onEquip, onApplyToAll, onUnapplyAll } :: { any })

	local renderCreateCard = useCallback(function(order: number)
		return e(CreateWrapCard, {
			LayoutOrder = order,
			Label = selectedType == "Charm" and "Create Custom Charm" or "Create Custom Wrap",
			OnClick = function(): ()
				customWrapStore.openCreate(selectedType)
			end,
		})
	end, { selectedType } :: { any })

	local prependCreate = selectedType == "Wrap" or selectedType == "Charm"

	local equippedDisplay = useMemo(function(): string?
		if not equippedName then
			return nil
		end
		local entry = cosmeticLibraryAccess.getCosmetic(equippedName)
		if entry then
			return entry.displayName
		end
		return equippedName
	end, { equippedName, customWrapsRev } :: { any })

	local headingLabel = selectedWeapon and `{selectedWeapon} - {selectedType} ({#entries})` or "Select a weapon"
	local metaLabel = (
		not ready and "Loading inventory..."
		or equippedDisplay and `Equipped: {equippedDisplay}`
		or "Nothing equipped"
	)

	local contentTop = TYPE_BAR_HEIGHT + SEARCH_HEIGHT + META_HEIGHT + PAD * 3

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
				SelectedAtom = rivalsInventoryState.selectedWeapon,
				SearchAtom = rivalsInventoryState.weaponSearch,
				UseWeapons = useWeapons,
				GetIcon = cosmeticLibraryAccess.getWeaponImage,
				OnPicked = resetPage,
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
			TypeBar = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(1, 0, 0, TYPE_BAR_HEIGHT),
			}, {
				Inner = e(TypeTabs, {
					Tabs = TYPE_TABS,
					SelectedAtom = rivalsInventoryState.selectedType,
					OnPicked = resetPage,
				}),
			}),
			SearchRow = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, TYPE_BAR_HEIGHT + PAD),
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
					Atom = rivalsInventoryState.inventorySearch,
					Placeholder = "Search...",
					Size = UDim2.new(1, -(ACTIONS_WIDTH + ELEMENT_GAP), 1, 0),
					Position = UDim2.fromOffset(0, 5),
				}),
			}),
			MetaRow = e(MetaRow, {
				Heading = headingLabel,
				Meta = metaLabel,
				Top = TYPE_BAR_HEIGHT + SEARCH_HEIGHT + PAD * 2,
			}),
			Grid = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, contentTop),
				Size = UDim2.new(1, 0, 1, -contentTop),
			}, {
				Inner = e(CardGrid, {
					Entries = entries,
					RenderCard = renderCard,
					LeadingCard = prependCreate and renderCreateCard or nil,
				}),
			}),
		}),
		Modal = e(CustomCosmeticModal, {}),
	})
end
