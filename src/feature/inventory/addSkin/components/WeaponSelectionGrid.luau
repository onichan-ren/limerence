local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local themeState = require("@ui/theme/themeState")
local windowState = require("@ui/window/windowState")
local addSkinData = require("@feature/inventory/addSkin/addSkinData")
local addSkinState = require("@feature/inventory/addSkin/addSkinState")
local WeaponCard = require("@feature/inventory/addSkin/components/WeaponCard")

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

local CARD_MIN_WIDTH = 92
local CARD_HEIGHT = 138

return function(): React.Element<any>
	local scrollThumb = useAt(colors.scrollThumb)
	local searchQuery = useAt(windowState.searchQuery)

	local weapons = useMemo(function()
		return addSkinData.getWeapons()
	end, {})

	local filtered = useMemo(function()
		local query = string.lower(searchQuery or "")
		if query == "" then
			return weapons
		end
		local out: { addSkinData.WeaponEntry } = {}
		for _, w in next, weapons do
			local n = string.lower(w.name)
			local g = string.lower(w.group)
			if string.find(n, query, 1, true) or string.find(g, query, 1, true) then
				out[#out + 1] = w
			end
		end
		return out
	end, { weapons, searchQuery } :: { any })

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

	local onSelect = useCallback(function(weapon: string)
		addSkinState.selectWeapon(weapon)
	end, {})

	local layoutProbe = gridLayout.compute(containerSize.X, CARD_MIN_WIDTH, CARD_HEIGHT, #filtered, nil, false)
	local needsScroll = layoutProbe.contentHeight > containerSize.Y
	local layout = (needsScroll and gridLayout.compute(containerSize.X, CARD_MIN_WIDTH, CARD_HEIGHT, #filtered, nil, true) or layoutProbe)
	local columns = layout.columns
	local cellWidth = layout.cellWidth
	local contentHeight = layout.contentHeight

	local rendered = useMemo(function()
		local children: { [string]: React.Element<any> } = {}
		for index, weapon in next, filtered do
			children[`Card_{weapon.name}`] = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, math.floor(cellWidth), 0, CARD_HEIGHT),
				LayoutOrder = index,
			}, {
				Card = e(WeaponCard, {
					Weapon = weapon.name,
					Group = weapon.group,
					Icon = weapon.icon,
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
