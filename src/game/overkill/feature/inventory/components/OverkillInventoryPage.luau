local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local themeState = require("@ui/theme/themeState")

local overkillInventoryState = require("@game/overkill/feature/inventory/overkillInventoryState")
local cosmeticCatalog = require("@game/overkill/feature/inventory/cosmeticCatalog")
local InventoryChanger = require("@game/overkill/feature/inventory/InventoryChanger")
local ModuleController = require("@game/overkill/module/ModuleController")
local clientState = require("@game/overkill/client/clientState")

local WeaponSelector = require("@feature/inventory/skinUi/WeaponSelector")
local InventoryActions = require("@feature/inventory/skinUi/InventoryActions")
local TypeTabs = require("@feature/inventory/skinUi/TypeTabs")
local CardGrid = require("@feature/inventory/skinUi/CardGrid")
local SkinCard = require("@feature/inventory/skinUi/SkinCard")
local SearchField = require("@feature/inventory/skinUi/SearchField")
local MetaRow = require("@feature/inventory/skinUi/MetaRow")
local layout = require("@feature/inventory/skinUi/layout")

local useMemo = React.useMemo
local useCallback = React.useCallback
local useAt = ReactCharm.useAtom
local e = React.createElement

local windowColors = themeState.colors.window

local SIDEBAR_WIDTH = layout.SIDEBAR_WIDTH
local TAB_HEIGHT = layout.TAB_HEIGHT
local META_HEIGHT = layout.META_HEIGHT
local SEARCH_HEIGHT = layout.SEARCH_HEIGHT
local PAD = layout.SECTION_GAP
local CONTENT_PAD_X = layout.CONTENT_PAD_X
local ELEMENT_GAP = layout.ELEMENT_GAP

local UNLOCK_WIDTH = 74
local LOCK_WIDTH = 64
local ACTIONS_WIDTH = UNLOCK_WIDTH + LOCK_WIDTH + ELEMENT_GAP

local TYPE_FIELD = overkillInventoryState.TYPE_FIELD

local TYPE_TABS = {
	{ id = "Skin", label = "Skin" },
	{ id = "Wrap", label = "Wrap" },
	{ id = "Charm", label = "Charm" },
	{ id = "Finisher", label = "Finisher" },
	{ id = "KillEffect", label = "Kill Effect" },
}

local TYPE_LABEL: { [string]: string } = {
	Skin = "Skins",
	Wrap = "Wraps",
	Charm = "Charms",
	Finisher = "Finishers",
	KillEffect = "Kill Effects",
}

local ACTION_BUTTONS = {
	{
		Label = "Unlock All",
		Width = UNLOCK_WIDTH,
		OnClick = function()
			InventoryChanger.UnlockAll()
		end,
	},
	{
		Label = "Lock All",
		Width = LOCK_WIDTH,
		OnClick = function()
			InventoryChanger.LockAll()
		end,
	},
}

local _clientModule: any = nil

local function currentLoadout(): { string }
	if _clientModule == nil then
		_clientModule = ModuleController.GetModule("clientModule") or false
	end
	local clientModule = _clientModule or nil
	local localChickynoid = clientModule and clientModule.localChickynoid
	local simulation = localChickynoid and localChickynoid.simulation
	local state = simulation and simulation.state
	if type(state) ~= "table" then
		return {}
	end
	local out: { string } = {}
	for slot = 1, 4 do
		local weaponId = state["slot" .. slot .. "_weaponID"]
		if type(weaponId) == "string" and weaponId ~= "" then
			out[#out + 1] = weaponId
		end
	end
	return out
end

local function useWeapons(): WeaponSelector.WeaponListResult
	local equippedWeapon = useAt(clientState.weaponId)
	local equippedSlot = useAt(clientState.equippedSlot)

	local weapons = useMemo(function()
		return cosmeticCatalog.getWeapons()
	end, {})

	local loadout = useMemo(function()
		return currentLoadout()
	end, { equippedWeapon, equippedSlot } :: { any })

	local ordered = useMemo(function()
		if #loadout == 0 then
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
	local selectedWeapon = useAt(overkillInventoryState.selectedWeapon)
	local selectedType = useAt(overkillInventoryState.selectedType)
	local weaponInventory = useAt(overkillInventoryState.weaponInventory)
	local unlockedSkins = useAt(overkillInventoryState.unlockedSkins)
	local unlockedCosmetics = useAt(overkillInventoryState.unlockedCosmetics)
	local searchQuery = useAt(overkillInventoryState.inventorySearch)
	local ready = useAt(overkillInventoryState.ready)

	local dividerColor = useAt(windowColors.divider)

	local entries = useMemo(function()
		if selectedType == "Skin" and not selectedWeapon then
			return {}
		end
		local list = cosmeticCatalog.listByType(selectedType, selectedWeapon)
		local query = string.lower(searchQuery or "")
		if query == "" then
			return list
		end
		local out = {}
		for _, entry in next, list do
			if
				string.find(string.lower(entry.displayName), query, 1, true)
				or string.find(string.lower(entry.collection), query, 1, true)
			then
				out[#out + 1] = entry
			end
		end
		return out
	end, { selectedWeapon, selectedType, searchQuery } :: { any })

	local equippedName = useMemo(function()
		if not selectedWeapon then
			return nil
		end
		local entry = weaponInventory[selectedWeapon]
		return entry and entry[TYPE_FIELD[selectedType]] or nil
	end, { selectedWeapon, selectedType, weaponInventory } :: { any })

	local unlockedSet = useMemo(function()
		if selectedType == "Skin" then
			if not selectedWeapon then
				return {}
			end
			return unlockedSkins[selectedWeapon] or {}
		end
		return unlockedCosmetics[selectedType] or {}
	end, { selectedType, selectedWeapon, unlockedSkins, unlockedCosmetics } :: { any })

	local isSkin = selectedType == "Skin"

	local onEquip = useCallback(function(name: string)
		if not selectedWeapon then
			return
		end
		local newName: string? = (equippedName ~= name and name or nil)
		InventoryChanger.Equip(selectedWeapon, selectedType, newName)
	end, { selectedWeapon, selectedType, equippedName } :: { any })

	local buildContextItems = useCallback(function(entry: cosmeticCatalog.CosmeticEntry, unlocked: boolean?)
		if entry.name == "base" then
			return nil
		end
		local items = {
			{
				Label = unlocked and "Lock" or "Unlock",
				Callback = function()
					InventoryChanger.ToggleUnlock(selectedType, selectedWeapon, entry.name)
				end,
			},
		}
		if selectedType ~= "Skin" then
			items[#items + 1] = {
				Label = "Apply to All",
				Callback = function()
					InventoryChanger.ApplyToAll(selectedType, entry.name)
				end,
			}
			items[#items + 1] = {
				Label = "Unapply from All",
				Callback = function()
					InventoryChanger.UnapplyFromAll(selectedType, entry.name)
				end,
			}
		end
		return items
	end, { selectedType, selectedWeapon } :: { any })

	local renderCard = useCallback(function(entry: cosmeticCatalog.CosmeticEntry, index: number)
		return e(SkinCard, {
			Entry = entry,
			LayoutOrder = index,
			Equipped = entry.name == equippedName,
			Unlocked = unlockedSet[entry.name] == true and entry.name ~= "base",
			OnClick = onEquip,
			BuildContextItems = buildContextItems,
			ShowSwatch = true,
			ImageScaleType = Enum.ScaleType.Fit,
		})
	end, { equippedName, unlockedSet, onEquip, buildContextItems } :: { any })

	local typeLabel = TYPE_LABEL[selectedType] or selectedType
	local headingLabel = `{typeLabel} ({#entries})`
	local metaLabel = (
		not ready and "Loading inventory..."
		or equippedName
			and selectedWeapon
			and `Equipped: {cosmeticCatalog.cosmeticDisplay(selectedType, selectedWeapon, equippedName)}`
		or (isSkin and "Default skin")
		or "Nothing equipped"
	)

	local searchTop = TAB_HEIGHT + PAD
	local metaTop = searchTop + SEARCH_HEIGHT + PAD
	local contentTop = metaTop + META_HEIGHT + PAD

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
				SelectedAtom = overkillInventoryState.selectedWeapon,
				SearchAtom = overkillInventoryState.weaponSearch,
				UseWeapons = useWeapons,
				DisplayName = cosmeticCatalog.displayName,
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
				Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
			}, {
				Tabs = e(TypeTabs, {
					Tabs = TYPE_TABS,
					SelectedAtom = overkillInventoryState.selectedType,
				}),
			}),
			SearchRow = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, searchTop),
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
					Atom = overkillInventoryState.inventorySearch,
					Placeholder = `Search {string.lower(typeLabel)}...`,
					Size = UDim2.new(1, -(ACTIONS_WIDTH + ELEMENT_GAP), 1, 0),
					Position = UDim2.fromOffset(0, 5),
				}),
			}),
			MetaRow = e(MetaRow, {
				Heading = headingLabel,
				Meta = metaLabel,
				Top = metaTop,
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
				}),
			}),
		}),
	})
end
