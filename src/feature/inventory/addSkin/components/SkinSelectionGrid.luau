local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local themeState = require("@ui/theme/themeState")
local windowState = require("@ui/window/windowState")
local addSkinData = require("@feature/inventory/addSkin/addSkinData")
local addSkinState = require("@feature/inventory/addSkin/addSkinState")
local SkinCard = require("@feature/inventory/addSkin/components/SkinCard")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useCallback = React.useCallback
local useAt = ReactCharm.useAtom
local e = React.createElement

local colors = themeState.colors.window.element
local gridLayout = require("@feature/inventory/gridLayout")
local Charm = require("@pkg/Charm")
local dpiState = require("@ui/util/dpiState")

local function localSize(absolute: Vector2): Vector2
	local scale = Charm.peek(dpiState.scale)
	if scale <= 0 then
		scale = 1
	end
	return absolute / scale
end

local CARD_MIN_WIDTH = 118
local CARD_HEIGHT = 178

local RARITY_RANK: { [string]: number } = {
	master = 7,
	extraordinary = 6,
	covert = 5,
	classified = 4,
	restricted = 3,
	uncommon = 2,
	common = 1,
}

export type SkinSelectionGridProps = {
	Weapon: string,
}

return function(props: SkinSelectionGridProps): React.Element<any>
	local scrollThumb = useAt(colors.scrollThumb)
	local searchQuery = useAt(windowState.searchQuery)

	local skins = useMemo(function()
		return addSkinData.getSkinsForWeapon(props.Weapon)
	end, { props.Weapon })

	local filtered = useMemo(function()
		local query = string.lower(searchQuery or "")
		local pool: { addSkinData.SkinEntry } = {}
		for _, s in next, skins do
			if query == "" or string.find(string.lower(s.skin), query, 1, true) then
				pool[#pool + 1] = s
			end
		end
		table.sort(pool, function(a, b): boolean
			local ra = RARITY_RANK[a.rarity] or 0
			local rb = RARITY_RANK[b.rarity] or 0
			if ra ~= rb then
				return ra > rb
			end
			return a.skin < b.skin
		end)
		return pool
	end, { skins, searchQuery } :: { any })

	local scrollRef = useRef(nil :: ScrollingFrame?)
	local containerSize, setContainerSize = useState(Vector2.new(0, 0))

	useEffect(function()
		local scroll = scrollRef.current
		if not scroll then
			return
		end
		setContainerSize(localSize(scroll.AbsoluteSize))
		local conn = scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			setContainerSize(localSize(scroll.AbsoluteSize))
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	local onSelect = useCallback(function(weapon: string, skin: string)
		addSkinState.openConfig(weapon, skin)
	end, {})

	local layoutProbe = gridLayout.compute(containerSize.X, CARD_MIN_WIDTH, CARD_HEIGHT, #filtered, nil, false)
	local needsScroll = layoutProbe.contentHeight > containerSize.Y
	local layout = (needsScroll and gridLayout.compute(containerSize.X, CARD_MIN_WIDTH, CARD_HEIGHT, #filtered, nil, true) or layoutProbe)
	local columns = layout.columns
	local cellWidth = layout.cellWidth
	local contentHeight = layout.contentHeight

	local rendered = useMemo(function()
		local children: { [string]: React.Element<any> } = {}
		for index, skin in next, filtered do
			children[`Card_{skin.weapon}_{skin.skin}`] = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, math.floor(cellWidth), 0, CARD_HEIGHT),
				LayoutOrder = index,
			}, {
				Card = e(SkinCard, {
					Weapon = skin.weapon,
					Skin = skin.skin,
					Rarity = skin.rarity,
					Collection = skin.collection,
					Icon = skin.icon,
					LayoutOrder = index,
					OnSelect = onSelect,
				}),
			})
		end
		return children
	end, { filtered, cellWidth, onSelect } :: { any })

	return e("ScrollingFrame", {
		ref = scrollRef,
		Active = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, contentHeight),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollingEnabled = needsScroll,
		ScrollBarThickness = needsScroll and 3 or 0,
		ScrollBarImageColor3 = scrollThumb,
		ScrollBarImageTransparency = needsScroll and 0.1 or 1,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
	}, {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, gridLayout.PADDING_X),
			PaddingRight = UDim.new(0, gridLayout.PADDING_X),
			PaddingTop = UDim.new(0, gridLayout.PADDING_Y),
			PaddingBottom = UDim.new(0, gridLayout.PADDING_Y),
		}),
		UIGridLayout = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(gridLayout.GAP_X, gridLayout.GAP_Y),
			CellSize = UDim2.new(0, math.floor(cellWidth), 0, CARD_HEIGHT),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = columns,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			StartCorner = Enum.StartCorner.TopLeft,
		}),
		Content = e(React.Fragment, nil, rendered),
	})
end
