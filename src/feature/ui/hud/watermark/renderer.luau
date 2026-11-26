local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")
local fileReady = require("@feature/file/fileReady")
local sessionState = require("@feature/session/sessionState")
local formatPlayTime = require("@feature/session/formatPlayTime")
local watermarkState = require("@ui/hud/watermark/watermarkState")
local watermarkOrder = require("@ui/hud/watermark/watermarkOrder")
local RollingText = require("@ui/hud/watermark/RollingText")
local themeState = require("@ui/theme/themeState")
local uiState = require("@ui/uiState")
local dpiState = require("@ui/util/dpiState")
local contextApi = require("@ui/subwindow/context/contextApi")
local cursor = require("@ui/util/cursor")
local useShadow = require("@ui/hook/useShadow")
local useDraggable = require("@ui/hook/useDraggable")
local useHudHover = require("@ui/hook/useHudHover")
local useAtomBinding = require("@ui/hook/useAtomBinding")
local SPRING = require("@ui/util/spring")

local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useState = React.useState
local useCallback = React.useCallback
local memo = React.memo
local e = React.createElement

local colors = themeState.colors.hud

local FRAME_HEIGHT = 28
local TEXT_HEIGHT = 14
local TEXT_SIZE = 14
local ICON_SIZE = 14
local PADDING_X = 8
local ICON_TEXT_GAP = 4
local ITEM_GAP = 6
local CORNER = 6
local OPEN_OFFSET = 6
local DIM_AMOUNT = 0.42
local DIM_COLOR_BLEND = 0.38

local function formatPing(v: number): string
	return `{v}ms`
end

local function formatFps(v: number): string
	return `{v} fps`
end

type WatermarkItemId = watermarkOrder.WatermarkItemId

local function hitIndexAtIconX(
	order: { WatermarkItemId },
	refs: { [WatermarkItemId]: GuiObject? },
	mouseX: number
): number?
	for index, id in next, order do
		local icon = refs[id]
		if icon then
			local width = icon.AbsoluteSize.X
			if width > 0 then
				local left = icon.AbsolutePosition.X
				if mouseX >= left and mouseX <= left + width then
					return index
				end
			end
		end
	end
	return nil
end

local WatermarkItem = memo(function(props: {
	id: WatermarkItemId,
	icon: string,
	text: any,
	animated: any,
	shown: boolean,
	masterFade: any,
	layoutOrder: number,
	canReorder: boolean,
	draggingId: WatermarkItemId?,
	hoverTargetId: WatermarkItemId?,
	onRegisterIcon: (id: WatermarkItemId, icon: GuiObject?) -> (),
	onIconPress: (id: WatermarkItemId) -> (),
	onContextOpen: (input: InputObject) -> (),
}): React.Element<any>
	local imageColor = useAt(colors.image)
	local textColor = useAt(colors.title)

	local frameRef = useRef(nil :: Frame?)
	local contentRef = useRef(nil :: Frame?)
	local iconRef = useRef(nil :: GuiObject?)
	local measured, setMeasured = useState(0)

	useEffect(function()
		props.onRegisterIcon(props.id, iconRef.current)
		return function()
			props.onRegisterIcon(props.id, nil)
		end
	end, { props.id, props.onRegisterIcon })

	useEffect(function()
		local frame = contentRef.current
		if not frame then
			return
		end
		local function readWidth(): number
			local s = Charm.peek(dpiState.scale)
			if s <= 0 then
				s = 1
			end
			return frame.AbsoluteSize.X / s
		end
		setMeasured(readWidth())
		local conn = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if contentRef.current then
				setMeasured(readWidth())
			end
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	local target = props.shown and (measured + ITEM_GAP) or 0
	local widthBind, widthSpring = useSpring(target, SPRING.smoothPrecise)

	useEffect(function()
		widthSpring:setGoal(target)
	end, { target })

	local fadeBind, fadeSpring = useSpring(not props.shown and 1 or 0, SPRING.smoothPrecise)

	useEffect(function()
		fadeSpring:setGoal(not props.shown and 1 or 0)
	end, { props.shown })

	local isDimmed = props.canReorder
		and props.draggingId ~= nil
		and props.id ~= props.draggingId
		and props.id ~= props.hoverTargetId

	local dimBind, dimSpring = useSpring(0, SPRING.smoothPrecise)

	useEffect(function()
		dimSpring:setGoal(isDimmed and 1 or 0)
	end, { isDimmed })

	local size = useMemo(function()
		return widthBind:map(function(w: number)
			return UDim2.fromOffset(math.max(0, w), FRAME_HEIGHT)
		end)
	end, { widthBind })

	local itemTransparency = useMemo(function()
		return React.joinBindings({ fadeBind, props.masterFade, dimBind }):map(function(values)
			local fade = values[1]
			local master = values[2]
			local dim = values[3]
			local dimMult = 1 - dim * DIM_AMOUNT
			return 1 - (1 - fade) * (1 - master) * dimMult
		end)
	end, { fadeBind, props.masterFade, dimBind } :: { any })

	local imageColorBinding = useMemo(function()
		local dimTarget = imageColor:Lerp(Color3.new(0, 0, 0), DIM_COLOR_BLEND)
		return dimBind:map(function(dim: number)
			return imageColor:Lerp(dimTarget, dim)
		end)
	end, { dimBind, imageColor } :: { any })

	local textColorBinding = useMemo(function()
		local dimTarget = textColor:Lerp(Color3.new(0, 0, 0), DIM_COLOR_BLEND)
		return dimBind:map(function(dim: number)
			return textColor:Lerp(dimTarget, dim)
		end)
	end, { dimBind, textColor } :: { any })

	local onIconInputBegan = useCallback(function(_: any, input: InputObject): ()
		if not props.canReorder or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		props.onIconPress(props.id)
	end, { props.canReorder, props.id, props.onIconPress })

	return e("Frame", {
		ref = frameRef,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = props.layoutOrder,
		Size = size,
		Active = false,
		ZIndex = props.draggingId == props.id and 3 or 1,
	}, {
		Content = e("Frame", {
			ref = contentRef,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, FRAME_HEIGHT),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, ICON_TEXT_GAP),
			}),
			Icon = e("ImageButton", {
				ref = iconRef,
				Active = false,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = props.icon,
				ImageColor3 = imageColorBinding,
				ImageTransparency = itemTransparency,
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				LayoutOrder = 0,
				[React.Event.InputBegan] = onIconInputBegan,
			}),
			Text = props.animated and e(RollingText, {
				atom = props.animated.atom,
				format = props.animated.format,
				color = textColorBinding,
				transparency = itemTransparency,
				textSize = TEXT_SIZE,
				height = TEXT_HEIGHT,
				layoutOrder = 1,
				roll = props.animated.roll,
			}) or e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = props.text,
				TextSize = TEXT_SIZE,
				TextColor3 = textColorBinding,
				TextTransparency = itemTransparency,
				FontFace = FileController.Get("font", "semi_bold"),
				Size = UDim2.fromOffset(0, TEXT_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 1,
				Active = false,
			}),
		}),
	})
end)

local function buildItems(refresh: () -> ()): { contextApi.ContextItem }
	local checkmark = FileController.Get("image", "checkmark")
	local function entry(label: string, atom: Charm.Atom<boolean>): contextApi.ContextItem
		local isOn = Charm.peek(atom)
		return {
			Label = label,
			Icon = isOn and checkmark or nil,
			Callback = function()
				atom(not isOn)
				refresh()
			end,
		}
	end
	return {
		entry("Show Play Time", watermarkState.showPlaytime),
		entry("Show Username", watermarkState.showUsername),
		entry("Show Cheat", watermarkState.showCheat),
		entry("Show Build", watermarkState.showBuild),
		entry("Show Game", watermarkState.showGame),
		entry("Show Ping", watermarkState.showPing),
		entry("Show FPS", watermarkState.showFps),
	}
end

return function(): React.Element<any>
	local enabled = useAt(watermarkState.enabled)
	local menuOpen = useAt(uiState.isOpen)
	local itemOrder = useAt(watermarkState.itemOrder)

	local usernameBind = useAtomBinding(sessionState.username)
	local cheatBind = useAtomBinding(sessionState.cheat)
	local buildBind = useAtomBinding(sessionState.build)
	local gameNameBind = useAtomBinding(sessionState.gameName)

	local animatedDefs = useMemo(function()
		return {
			ping = { atom = sessionState.ping, format = formatPing, roll = "none" },
			fps = { atom = sessionState.fps, format = formatFps, roll = "none" },
			playtime = { atom = sessionState.playTime, format = formatPlayTime.format, roll = "char" },
		}
	end, {})

	local showUsername = useAt(watermarkState.showUsername)
	local showCheat = useAt(watermarkState.showCheat)
	local showBuild = useAt(watermarkState.showBuild)
	local showGame = useAt(watermarkState.showGame)
	local showPing = useAt(watermarkState.showPing)
	local showFps = useAt(watermarkState.showFps)
	local showPlaytime = useAt(watermarkState.showPlaytime)

	local bgPack = useAt(colors.background)
	local bgColor = bgPack[1] :: Color3
	local bgAlpha = bgPack[2] :: number

	local strokePack = useAt(colors.stroke)
	local strokeColor = strokePack[1] :: Color3
	local strokeAlpha = strokePack[2] :: number

	local shadowPack = useAt(colors.shadow)
	local shadowColor = shadowPack[1] :: Color3
	local shadowAlpha = shadowPack[2] :: number

	local widgetBind, widgetSpring = useSpring(0, SPRING.smoothPreciser)

	useEffect(function()
		widgetSpring:setGoal(enabled and 1 or 0)
	end, { enabled })

	local onDragInput, positionBind = useDraggable(watermarkState.position)
	local onHoverEnter, onHoverLeave, hoverGlow = useHudHover(menuOpen and enabled)

	local layoutRef = useRef(nil :: UIListLayout?)
	local iconRefs = useRef({} :: { [WatermarkItemId]: GuiObject? })
	local dragIndexRef = useRef(nil :: number?)
	local draggingId, setDraggingId = useState(nil :: WatermarkItemId?)
	local hoverTargetId, setHoverTargetId = useState(nil :: WatermarkItemId?)

	local lastContextPos = useRef(nil :: UDim2?)
	local contentWidth, setContentWidth = useState(0)

	useEffect(function()
		local layout = layoutRef.current
		if not layout then
			return
		end
		local function readWidth(): number
			local s = Charm.peek(dpiState.scale)
			if s <= 0 then
				s = 1
			end
			return layout.AbsoluteContentSize.X / s
		end
		setContentWidth(readWidth())
		local conn = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			if layoutRef.current then
				setContentWidth(readWidth())
			end
		end)
		return function()
			conn:Disconnect()
		end
	end, { itemOrder })

	local registerIcon = useCallback(function(id: WatermarkItemId, icon: GuiObject?): ()
		iconRefs.current[id] = icon
	end, {})

	local onIconPress = useCallback(function(id: WatermarkItemId): ()
		if not menuOpen or dragIndexRef.current then
			return
		end
		local order = Charm.peek(watermarkState.itemOrder)
		local index = watermarkOrder.indexOf(order, id)
		if not index then
			return
		end
		dragIndexRef.current = index
		setDraggingId(id)
		setHoverTargetId(nil)
	end, { menuOpen })

	useEffect(function()
		if not draggingId then
			return
		end

		local moveConn = UserInputService.InputChanged:Connect(LPH_NO_VIRTUALIZE(function(input: InputObject): ()
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			local dragIndex = dragIndexRef.current
			if not dragIndex then
				return
			end
			local order = Charm.peek(watermarkState.itemOrder)
			local hoverIndex = hitIndexAtIconX(order, iconRefs.current, input.Position.X)
			local hoverId = (hoverIndex and order[hoverIndex] or nil)
			setHoverTargetId(hoverId)

			if hoverIndex and hoverIndex ~= dragIndex then
				local swapped = watermarkOrder.swap(order, dragIndex, hoverIndex)
				watermarkState.itemOrder(swapped)
				dragIndexRef.current = hoverIndex
			end
		end))

		local endConn = UserInputService.InputEnded:Connect(function(input: InputObject): ()
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			dragIndexRef.current = nil
			setDraggingId(nil)
			setHoverTargetId(nil)
		end)

		return function()
			moveConn:Disconnect()
			endConn:Disconnect()
		end
	end, { draggingId })

	local totalWidth = contentWidth + PADDING_X * 2 - ITEM_GAP

	local masterFade = useMemo(function()
		return widgetBind:map(function(v: number)
			return 1 - v
		end)
	end, { widgetBind })

	local outerSize = UDim2.fromOffset(math.max(0, totalWidth), FRAME_HEIGHT)

	local outerPosition = useMemo(function()
		return React.joinBindings({ widgetBind, positionBind }):map(function(values)
			local v: number = values[1]
			local pos: UDim2 = values[2]
			local offset = (1 - v) * OPEN_OFFSET
			return UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, (pos.Y.Offset :: number) - offset)
		end)
	end, { widgetBind, positionBind } :: { any })

	local visible = useMemo(function()
		return widgetBind:map(function(v: number)
			return v > 0.001
		end)
	end, { widgetBind })

	local bgTransparency = useMemo(function()
		return widgetBind:map(function(v: number)
			return 1 - v * (1 - bgAlpha)
		end)
	end, { widgetBind, bgAlpha } :: { any })

	local strokeTransparency = useMemo(function()
		return widgetBind:map(function(v: number)
			return 1 - v * (1 - strokeAlpha)
		end)
	end, { widgetBind, strokeAlpha } :: { any })

	local shadowTransparency = useMemo(function()
		return widgetBind:map(function(v: number)
			return 1 - v * (1 - shadowAlpha)
		end)
	end, { widgetBind, shadowAlpha } :: { any })

	local canReorder = menuOpen and enabled

	local filesReady = useAt(fileReady)

	local icons = useMemo(function()
		return {
			cheat = FileController.Get("image", "logov2"),
			build = FileController.Get("image", "cog"),
			game = FileController.Get("image", "terrain"),
			ping = FileController.Get("image", "latency"),
			fps = FileController.Get("image", "computer"),
			playtime = FileController.Get("image", "clock"),
			username = FileController.Get("image", "person"),
		}
	end, { filesReady })

	local itemDefs = useMemo(
		function()
			return {
				cheat = {
					icon = icons.cheat,
					text = cheatBind,
					shown = showCheat,
				},
				build = {
					icon = icons.build,
					text = buildBind,
					shown = showBuild,
				},
				game = {
					icon = icons.game,
					text = gameNameBind,
					shown = showGame,
				},
				ping = {
					icon = icons.ping,
					animated = animatedDefs.ping,
					shown = showPing,
				},
				fps = {
					icon = icons.fps,
					animated = animatedDefs.fps,
					shown = showFps,
				},
				playtime = {
					icon = icons.playtime,
					animated = animatedDefs.playtime,
					shown = showPlaytime,
				},
				username = {
					icon = icons.username,
					text = usernameBind,
					shown = showUsername,
				},
			}
		end,
		{
			cheatBind,
			buildBind,
			gameNameBind,
			animatedDefs,
			usernameBind,
			showCheat,
			showBuild,
			showGame,
			showPing,
			showFps,
			showPlaytime,
			showUsername,
		} :: { any }
	)

	local openContextMenu = useCallback(function(input: InputObject): ()
		if not enabled then
			return
		end
		local pos = cursor.getPosition(input)
		lastContextPos.current = pos
		local function refresh()
			local p = lastContextPos.current
			if p then
				contextApi.Open(buildItems(refresh), p)
			end
		end
		contextApi.Open(buildItems(refresh), pos)
	end, { enabled })

	local onBodyInputBegan = useCallback(function(_: any, input: InputObject): ()
		if not enabled or not menuOpen or dragIndexRef.current then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onDragInput(input)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			openContextMenu(input)
		end
	end, { enabled, menuOpen, onDragInput })

	local bodyChildren = useMemo(
		function()
			local children: { [string]: React.Element<any> } = {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, CORNER),
				}),
				UIStroke = e("UIStroke", {
					Color = strokeColor,
					Transparency = strokeTransparency,
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, PADDING_X),
					PaddingRight = UDim.new(0, PADDING_X - ITEM_GAP),
				}),
				UIListLayout = e("UIListLayout", {
					ref = layoutRef,
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),
			}

			for layoutIndex, id in next, itemOrder do
				local def = itemDefs[id]
				if def then
					children[id] = e(WatermarkItem, {
						key = id,
						id = id,
						icon = def.icon,
						text = def.text,
						animated = def.animated,
						shown = def.shown,
						masterFade = masterFade,
						layoutOrder = layoutIndex,
						canReorder = canReorder,
						draggingId = draggingId,
						hoverTargetId = hoverTargetId,
						onRegisterIcon = registerIcon,
						onIconPress = onIconPress,
						onContextOpen = openContextMenu,
					})
				end
			end

			return children
		end,
		{
			itemOrder,
			itemDefs,
			masterFade,
			strokeColor,
			strokeTransparency,
			canReorder,
			draggingId,
			hoverTargetId,
			registerIcon,
			onIconPress,
			openContextMenu,
		} :: { any }
	)

	return e("Frame", {
		Active = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = outerPosition,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = outerSize,
		Visible = visible,
	}, {
		Glow = hoverGlow,
		Shadow = useShadow({
			color = shadowColor,
			transparency = shadowTransparency,
			zIndex = 0,
			multiplier = Vector2.new(1.24, 1.46),
		}),
		Body = e("Frame", {
			BackgroundColor3 = bgColor,
			BackgroundTransparency = bgTransparency,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			ClipsDescendants = true,
			Active = false,
			[React.Event.InputBegan] = onBodyInputBegan,
			[React.Event.MouseEnter] = onHoverEnter,
			[React.Event.MouseLeave] = onHoverLeave,
		}, bodyChildren),
	})
end
