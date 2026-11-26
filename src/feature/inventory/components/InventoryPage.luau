local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local windowState = require("@ui/window/windowState")
local inventoryState = require("@feature/inventory/inventoryState")
local inventoryAdapter = require("@feature/inventory/inventoryAdapter")
local InventoryChanger = require("@game/bloxstrike/feature/inventory/InventoryChanger")
local inventoryGameState = require("@game/bloxstrike/feature/inventory/inventoryGameState")

local InventoryCategoryBar = require("@feature/inventory/components/InventoryCategoryBar")
local InventoryGrid = require("@feature/inventory/components/InventoryGrid")
local InventoryPagination = require("@feature/inventory/components/InventoryPagination")
local addSkinState = require("@feature/inventory/addSkin/addSkinState")
local addSkinData = require("@feature/inventory/addSkin/addSkinData")
local AddSkinHeader = require("@feature/inventory/addSkin/components/AddSkinHeader")
local WeaponSelectionGrid = require("@feature/inventory/addSkin/components/WeaponSelectionGrid")
local SkinSelectionGrid = require("@feature/inventory/addSkin/components/SkinSelectionGrid")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local SPRING = require("@ui/util/spring")

local useEffect = React.useEffect
local useLayoutEffect = React.useLayoutEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useState = React.useState
local useRef = React.useRef
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local e = React.createElement

local windowColors = themeState.colors.window
local elementColors = themeState.colors.window.element

local gridLayout = require("@feature/inventory/gridLayout")

local CATEGORY_HEIGHT = 32
local META_HEIGHT = 30
local FOOTER_HEIGHT = 31
local SECTION_GAP = 8
local PAD_X = gridLayout.PADDING_X

local TEAM_LABEL: { [string]: string } = {
	["Counter-Terrorists"] = "CT",
	Terrorists = "T",
}

local RARITY_RANK: { [string]: number } = {
	master = 7,
	extraordinary = 6,
	covert = 5,
	classified = 4,
	restricted = 3,
	uncommon = 2,
	common = 1,
}

type AnimatedViewProps = {
	Active: boolean,
	SlideDirection: number,
	Children: { [string]: any },
}

local function AnimatedView(props: AnimatedViewProps): React.Element<any>
	local bind, spring = useSpring(props.Active and 1 or 0, SPRING.smoothPrecise)
	local settled, setSettled = useState(true)
	local lastActiveRef = useRef(props.Active)
	local canvasRef = useRef(nil :: CanvasGroup?)
	local frameRef = useRef(nil :: Frame?)
	local holderRef = useRef(nil :: Frame?)

	local animating = not settled
	if lastActiveRef.current ~= props.Active then
		lastActiveRef.current = props.Active
		animating = true
		if settled then
			setSettled(false)
		end
	end

	useEffect(function()
		spring:setGoal(props.Active and 1 or 0)
	end, { props.Active })

	useEffect(function()
		local disconnect = spring:onComplete(function()
			setSettled(true)
		end)
		return disconnect
	end, { spring } :: { any })

	useLayoutEffect(function()
		local holder = holderRef.current
		local target: Instance?
		if animating then
			target = canvasRef.current
		else
			target = frameRef.current
		end
		if holder and target and holder.Parent ~= target then
			holder.Parent = target
		end
	end, { animating })

	local position = useMemo(function()
		return bind:map(function(v: number)
			return UDim2.fromOffset(0, math.floor((1 - v) * 12 * props.SlideDirection))
		end)
	end, { bind, props.SlideDirection } :: { any })

	local transparency = useMemo(function()
		return bind:map(function(v: number)
			return 1 - v
		end)
	end, { bind } :: { any })

	local visible = useMemo(function()
		return bind:map(function(v: number)
			return v > 0.01
		end)
	end, { bind } :: { any })

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = visible,
	}, {
		Canvas = e("CanvasGroup", {
			ref = canvasRef,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Position = position,
			GroupTransparency = transparency,
		}),
		Static = e("Frame", {
			ref = frameRef,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Position = position,
		}, {
			Holder = e("Frame", {
				ref = holderRef,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
			}, props.Children),
		}),
	})
end

local function sortItems(items: { inventoryAdapter.UIItem }, mode: string): { inventoryAdapter.UIItem }
	local copy: { inventoryAdapter.UIItem } = table.clone(items)
	if mode == "rarity" then
		table.sort(copy, function(a, b)
			local ra = RARITY_RANK[a.rarity] or 0
			local rb = RARITY_RANK[b.rarity] or 0
			if ra ~= rb then
				return ra > rb
			end
			return a.skin < b.skin
		end)
	elseif mode == "name" then
		table.sort(copy, function(a, b)
			return a.skin < b.skin
		end)
	elseif mode == "weapon" then
		table.sort(copy, function(a, b)
			if a.weapon == b.weapon then
				return a.skin < b.skin
			end
			return a.weapon < b.weapon
		end)
	end
	return copy
end

return function(): React.Element<any>
	local addSkinMode = useAt(addSkinState.mode)
	local selectedWeapon = useAt(addSkinState.selectedWeapon)
	local configOpen = useAt(addSkinState.configOpen)
	local configWeapon = useAt(addSkinState.configWeapon)
	local configSkin = useAt(addSkinState.configSkin)

	local activeCategory = useAt(inventoryState.activeCategory)
	local currentPage = useAt(inventoryState.currentPage)
	local pageSize = useAt(inventoryState.pageSize)
	local sortMode = useAt(inventoryState.sortMode)
	local searchQuery = useAt(windowState.searchQuery)

	local fakeItems = useAt(inventoryGameState.fakeItems)

	local dividerColor = useAt(windowColors.divider)
	local mutedColor = useAt(elementColors.caption)
	local strongColor = useAt(elementColors.textActive)

	local adapted = useMemo(function()
		local items: { any } = {}
		for _, fake in next, fakeItems do
			items[#items + 1] = fake
		end
		return inventoryAdapter.adaptAll(items)
	end, { fakeItems } :: { any })

	local filtered = useMemo(function()
		local query = string.lower(searchQuery or "")
		local pool: { inventoryAdapter.UIItem } = {}
		for _, ui in next, adapted do
			if activeCategory ~= "all" and ui.category ~= activeCategory then
				continue
			end
			if query ~= "" then
				local w = string.lower(ui.weapon)
				local s = string.lower(ui.skin)
				if not (string.find(w, query, 1, true) or string.find(s, query, 1, true)) then
					continue
				end
			end
			pool[#pool + 1] = ui
		end
		return sortItems(pool, sortMode)
	end, { adapted, activeCategory, sortMode, searchQuery } :: { any })

	local totalItems = #filtered
	local totalPages = math.max(1, math.ceil(totalItems / pageSize))
	local clampedPage = math.clamp(currentPage, 1, totalPages)

	useEffect(function()
		if currentPage ~= clampedPage then
			inventoryState.currentPage(clampedPage)
		end
	end, { currentPage, clampedPage })

	local startIndex = (clampedPage - 1) * pageSize + 1
	local endIndex = math.min(totalItems, clampedPage * pageSize)

	local pageItems: { inventoryAdapter.UIItem } = {}
	for i = startIndex, endIndex do
		pageItems[#pageItems + 1] = filtered[i]
	end

	local onDelete = useCallback(function(id: string)
		InventoryChanger.RemoveItem(id)
	end, {})

	local getMenuItems = useCallback(function(item: inventoryAdapter.UIItem): { any }
		local entries: { any } = {}

		for _, team in next, InventoryChanger.GetTeamsForFake(item.id) do
			local label = TEAM_LABEL[team] or team
			local equipped = InventoryChanger.IsEquippedForTeam(item.id, team)
			entries[#entries + 1] = {
				Label = (equipped and "Unequip " or "Equip ") .. label,
				Icon = FileController.Get("image", equipped and "undo" or "checkmark"),
				Callback = function(): ()
					InventoryChanger.SetEquippedForTeam(item.id, team, not equipped)
				end,
			}
		end

		entries[#entries + 1] = {
			Label = "Edit",
			Icon = FileController.Get("image", "pencil"),
			Callback = function(): ()
				local teams = InventoryChanger.GetTeamsForFake(item.id)
				local wasEquipped: { [string]: boolean } = {}
				for _, team in next, teams do
					wasEquipped[team] = InventoryChanger.IsEquippedForTeam(item.id, team)
				end
				SubwindowController.OpenSkinConfig({
					weapon = item.weapon,
					skin = item.skin,
					rarity = item.rarity,
					icon = item.icon,
					submitLabel = "Save Changes",
					float = item.float,
					seed = type(item.raw) == "table" and tonumber(item.raw.Seed) or nil,
					nameTag = type(item.nameTag) == "string" and item.nameTag or "",
					statTrack = item.statTrack == true or (type(item.statTrack) == "number" and item.statTrack ~= 0),
					onSubmit = function(payload)
						local newId = InventoryChanger.AddItem(payload.weapon, {
							skin = payload.skin,
							float = payload.float,
							statTrack = payload.statTrack and 1 or nil,
							nameTag = (payload.nameTag ~= "" and payload.nameTag) or nil,
							seed = payload.seed,
							rarity = item.rarity,
						})
						for _, team in next, InventoryChanger.GetTeamsForFake(newId) do
							if not wasEquipped[team] then
								InventoryChanger.SetEquippedForTeam(newId, team, false)
							end
						end
					end,
				})
			end,
		}

		entries[#entries + 1] = { Divider = true }

		entries[#entries + 1] = {
			Label = "Delete",
			Icon = FileController.Get("image", "trash"),
			Callback = function(): ()
				InventoryChanger.RemoveItem(item.id)
			end,
		}

		return entries
	end, {})

	useEffect(function()
		if not configOpen then
			SubwindowController.CloseSkinConfig()
			return
		end
		local weapon = configWeapon
		local skin = configSkin
		if not weapon or not skin then
			return
		end
		local skins = addSkinData.getSkinsForWeapon(weapon)
		local rarity = "common"
		local icon: string? = nil
		for _, s in next, skins do
			if s.skin == skin then
				rarity = s.rarity
				icon = s.icon
				break
			end
		end
		if not icon then
			icon = addSkinData.resolveWeaponIcon(weapon)
		end
		SubwindowController.OpenSkinConfig({
			weapon = weapon,
			skin = skin,
			rarity = rarity,
			icon = icon,
			onSubmit = function(payload)
				InventoryChanger.AddItem(payload.weapon, {
					skin = payload.skin,
					float = payload.float,
					statTrack = payload.statTrack and 1 or nil,
					nameTag = (payload.nameTag ~= "" and payload.nameTag) or nil,
					seed = payload.seed,
					rarity = rarity,
				})
				addSkinState.closeConfig()
				addSkinState.close()
			end,
			onCancel = function()
				addSkinState.closeConfig()
			end,
		})
	end, { configOpen, configWeapon, configSkin } :: { any })

	local metaLabel = `Showing {totalItems == 0 and 0 or startIndex}–{endIndex} of {totalItems} items`
	local headingLabel = `All Items ({totalItems})`

	local inventoryChildren = {
		CategoryBar = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, CATEGORY_HEIGHT),
		}, {
			Bar = e(InventoryCategoryBar, {}),
		}),
		MetaRow = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, CATEGORY_HEIGHT + SECTION_GAP),
			Size = UDim2.new(1, 0, 0, META_HEIGHT),
		}, {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, PAD_X),
				PaddingRight = UDim.new(0, PAD_X),
			}),
			Heading = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = FileController.Get("font", "semi_bold"),
				Text = headingLabel,
				TextColor3 = strongColor,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(1, 0, 1, 0),
			}),
		}),
		Grid = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, CATEGORY_HEIGHT + META_HEIGHT + SECTION_GAP),
			Size = UDim2.new(1, 0, 1, -(CATEGORY_HEIGHT + META_HEIGHT + FOOTER_HEIGHT + SECTION_GAP)),
		}, {
			Inner = e(InventoryGrid, {
				Items = pageItems,
				OnDelete = onDelete,
				GetMenuItems = getMenuItems,
			}),
		}),
		FooterDivider = e("Frame", {
			BackgroundColor3 = dividerColor,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -FOOTER_HEIGHT),
			Size = UDim2.new(1, 0, 0, 1),
		}),
		Footer = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
		}, {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, PAD_X),
				PaddingRight = UDim.new(0, PAD_X),
			}),
			Meta = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = FileController.Get("font", "semi_bold"),
				Text = metaLabel,
				TextColor3 = mutedColor,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(0.6, 0, 1, 0),
			}),
			Pagination = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0.5, 0, 1, 0),
			}, {
				Inner = e(InventoryPagination, {
					TotalPages = totalPages,
				}),
			}),
		}),
	}

	local weaponChildren = {
		Header = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, CATEGORY_HEIGHT),
		}, {
			Inner = e(AddSkinHeader, {
				OnBack = function()
					addSkinState.close()
				end,
			}),
		}),
		Grid = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, CATEGORY_HEIGHT),
			Size = UDim2.new(1, 0, 1, -CATEGORY_HEIGHT),
		}, {
			Inner = e(WeaponSelectionGrid, {}),
		}),
	}

	local skinChildren = (
		selectedWeapon
			and {
				Header = e("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, CATEGORY_HEIGHT),
				}, {
					Inner = e(AddSkinHeader, {
						OnBack = function()
							addSkinState.backToWeapons()
						end,
					}),
				}),
				Grid = e("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, CATEGORY_HEIGHT),
					Size = UDim2.new(1, 0, 1, -CATEGORY_HEIGHT),
				}, {
					Inner = e(SkinSelectionGrid, {
						Weapon = selectedWeapon,
					}),
				}),
			}
		or {}
	)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		Inventory = e(AnimatedView, {
			Active = addSkinMode == "inventory",
			SlideDirection = 1,
			Children = inventoryChildren,
		}),
		WeaponSelect = e(AnimatedView, {
			Active = addSkinMode == "weapon",
			SlideDirection = 1,
			Children = weaponChildren,
		}),
		SkinSelect = e(AnimatedView, {
			Active = addSkinMode == "skin" and selectedWeapon ~= nil,
			SlideDirection = 1,
			Children = skinChildren,
		}),
		UIPadding = e("UIPadding", {
			PaddingBottom = UDim.new(0, 0),
		}),
	})
end
