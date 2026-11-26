local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local themeState = require("@ui/theme/themeState")

local ar2InventoryState = require("@game/ar2/feature/inventory/ar2InventoryState")
local skinLibrary = require("@game/ar2/feature/inventory/skinLibrary")
local InventoryChanger = require("@game/ar2/feature/inventory/InventoryChanger")

local WeaponSelector = require("@feature/inventory/skinUi/WeaponSelector")
local InventoryActions = require("@feature/inventory/skinUi/InventoryActions")
local CardGrid = require("@feature/inventory/skinUi/CardGrid")
local SkinCard = require("@feature/inventory/skinUi/SkinCard")
local FolderCard = require("@feature/inventory/skinUi/FolderCard")
local SearchField = require("@feature/inventory/skinUi/SearchField")
local MetaRow = require("@feature/inventory/skinUi/MetaRow")
local layout = require("@feature/inventory/skinUi/layout")

local useMemo = React.useMemo
local useCallback = React.useCallback
local useAt = ReactCharm.useAtom
local e = React.createElement

local windowColors = themeState.colors.window

local SIDEBAR_WIDTH = layout.SIDEBAR_WIDTH
local META_HEIGHT = layout.META_HEIGHT
local SEARCH_HEIGHT = layout.SEARCH_HEIGHT
local PAD = layout.SECTION_GAP
local CONTENT_PAD_X = layout.CONTENT_PAD_X
local ELEMENT_GAP = layout.ELEMENT_GAP
local ACTIONS_WIDTH = 70

local ACTION_BUTTONS = {
	{
		Label = "Clear All",
		Width = ACTIONS_WIDTH,
		OnClick = function()
			InventoryChanger.ClearAll()
		end,
	},
}

local function getSkinPreview(entry: skinLibrary.SkinEntry): skinLibrary.SkinPreview?
	return skinLibrary.getPreview(entry.name)
end

local function getFolderPreview(entry: skinLibrary.FolderEntry): skinLibrary.SkinPreview?
	return skinLibrary.getPreview(entry.sample)
end

local function useWeapons(): WeaponSelector.WeaponListResult
	local weapons = useMemo(function()
		return skinLibrary.getWeapons()
	end, {})
	return { list = weapons }
end

return function(): React.Element<any>
	local selectedWeapon = useAt(ar2InventoryState.selectedWeapon)
	local weaponInventory = useAt(ar2InventoryState.weaponInventory)
	local searchQuery = useAt(ar2InventoryState.inventorySearch)
	local folder = useAt(ar2InventoryState.inventoryFolder)
	local ready = useAt(ar2InventoryState.ready)

	local dividerColor = useAt(windowColors.divider)

	local searching = (searchQuery or "") ~= ""
	local showSkins = searching or folder ~= nil

	local skinEntries = useMemo(function()
		if not showSkins then
			return {}
		end
		local list = skinLibrary.listSkins()
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
		return skinLibrary.listFolders()
	end, {})

	local equippedName = useMemo(function()
		if not selectedWeapon then
			return nil
		end
		local entry = weaponInventory[selectedWeapon]
		return entry and entry.skin or nil
	end, { selectedWeapon, weaponInventory } :: { any })

	local equippedFolder = useMemo(function()
		return equippedName and skinLibrary.collectionOf(equippedName) or nil
	end, { equippedName } :: { any })

	local onEquip = useCallback(function(name: string)
		if not selectedWeapon then
			return
		end
		local newName: string? = (equippedName ~= name and name or nil)
		InventoryChanger.Equip(selectedWeapon, newName)
	end, { selectedWeapon, equippedName } :: { any })

	local buildContextItems = useCallback(function(entry: skinLibrary.SkinEntry)
		return {
			{
				Label = "Apply to All",
				Callback = function()
					InventoryChanger.ApplyToAll(entry.name)
				end,
			},
			{
				Label = "Unapply from All",
				Callback = function()
					InventoryChanger.UnapplyFromAll(entry.name)
				end,
			},
		}
	end, {})

	local onOpenFolder = useCallback(function(name: string)
		ar2InventoryState.inventoryFolder(name)
	end, {})

	local onBack = useCallback(function()
		ar2InventoryState.inventoryFolder(nil)
	end, {})

	local renderSkinCard = useCallback(function(entry: skinLibrary.SkinEntry, index: number)
		return e(SkinCard, {
			Entry = entry,
			LayoutOrder = index,
			Equipped = entry.name == equippedName,
			OnClick = onEquip,
			GetPreview = getSkinPreview,
			BuildContextItems = buildContextItems,
		})
	end, { equippedName, onEquip, buildContextItems } :: { any })

	local renderFolderCard = useCallback(function(entry: skinLibrary.FolderEntry, index: number)
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
				SelectedAtom = ar2InventoryState.selectedWeapon,
				SearchAtom = ar2InventoryState.weaponSearch,
				UseWeapons = useWeapons,
				DisplayName = skinLibrary.displayName,
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
					Atom = ar2InventoryState.inventorySearch,
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
			Grid = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, contentTop),
				Size = UDim2.new(1, 0, 1, -contentTop),
			}, {
				Inner = showSkins and e(CardGrid, {
					Entries = skinEntries,
					RenderCard = renderSkinCard,
				}) or e(CardGrid, {
					Entries = folderEntries,
					RenderCard = renderFolderCard,
				}),
			}),
		}),
	})
end
