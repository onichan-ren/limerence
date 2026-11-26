local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")
local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local cursor = require("@ui/util/cursor")
local SPRING = require("@ui/util/spring")

local e = React.createElement
local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useMemo = React.useMemo
local useSpring = ReactRipple.useSpring
local useState = React.useState

local colors = themeState.colors.window.element

local COLUMNS = 2
local CELL_HEIGHT = 20
local CELL_GAP = 4

local ALWAYS_ON = Charm.atom(true)

export type EspElementsRendererProperties = {
	EspElements: any,
	LayoutOrder: number?,
}

type ChipProperties = {
	Entry: any,
	Accent: Color3,
	AccentStrong: Color3,
	Surface: Color3,
	SurfaceStroke: Color3,
	Text: Color3,
	TextActive: Color3,
	Caption: Color3,
	LayoutOrder: number,
}

local function Chip(properties: ChipProperties): React.Element<any>
	local entry = properties.Entry
	local sourceElement = entry.enabledElement
	local submenuElement = entry.submenuElement

	useAt(sourceElement._displaySelection or ALWAYS_ON)
	local enabledElement = sourceElement._displayResolver and sourceElement._displayResolver() or sourceElement

	local baseEnabled = useAt(sourceElement._state, { sourceElement }) == true
	local resolvedEnabled = useAt(enabledElement._state, { enabledElement }) == true
	local isStateView = enabledElement ~= sourceElement
	local locked = isStateView and not baseEnabled
	local enabled = resolvedEnabled and (not isStateView or baseEnabled)
	local hovered, setHovered = useState(false)

	local enabledBind, enabledSpring = useSpring(enabled and 1 or 0, SPRING.subtle)
	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)

	useEffect(function()
		enabledSpring:setGoal(enabled and 1 or 0)
	end, { enabled })

	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	local visualBind = useMemo(function()
		return React.joinBindings({ enabledBind, hoverBind })
	end, { enabledBind, hoverBind } :: { any })

	local hasSettings = submenuElement ~= nil

	return e("TextButton", {
		Size = UDim2.new(1 / COLUMNS, -CELL_GAP, 0, CELL_HEIGHT),
		BackgroundColor3 = visualBind:map(function(values: { number }): Color3
			local on = values[1]
			local hover = values[2]
			return properties.Surface:Lerp(properties.Accent, on):Lerp(Color3.new(1, 1, 1), hover * 0.06)
		end),
		BackgroundTransparency = locked and 0.55 or 0,
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		LayoutOrder = properties.LayoutOrder,
		[React.Event.MouseEnter] = function()
			if locked then
				return
			end
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
		[React.Event.MouseButton1Click] = function()
			if locked then
				return
			end
			enabledElement:Toggle()
		end,
		[React.Event.MouseButton2Click] = function()
			if submenuElement then
				submenuElement:Open(cursor.getPosition())
			end
		end,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
		UIStroke = e("UIStroke", {
			Color = enabledBind:map(function(value: number): Color3
				return properties.SurfaceStroke:Lerp(properties.AccentStrong, value)
			end),
			Transparency = locked and 0.5 or 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 7),
			PaddingRight = UDim.new(0, 5),
		}),
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Label = e("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = entry.label,
			FontFace = FileController.Get("font", "semi_bold"),
			TextSize = 11,
			TextColor3 = enabledBind:map(function(value: number): Color3
				return properties.Text:Lerp(properties.TextActive, value)
			end),
			TextTransparency = locked and 0.45 or 0,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 0,
		}, {
			UIFlexItem = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
			}),
		}),
		Gear = hasSettings and e("TextButton", {
			Size = UDim2.fromOffset(13, 13),
			BackgroundTransparency = 1,
			Text = "",
			Active = false,
			AutoButtonColor = false,
			LayoutOrder = 1,
			[React.Event.MouseButton1Click] = function()
				submenuElement:Open(cursor.getPosition())
			end,
		}, {
			Icon = e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = FileController.Get("image", "options"),
				ImageColor3 = enabledBind:map(function(value: number): Color3
					return properties.Caption:Lerp(properties.TextActive, value)
				end),
				Size = UDim2.fromOffset(10, 10),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			}),
		}) or nil,
	})
end

return function(properties: EspElementsRendererProperties): React.Element<any>
	local element = properties.EspElements
	local config = element._config

	local accent = useAt(colors.accent)
	local accentStrong = useAt(colors.accentStrong)
	local surface = useAt(colors.surface)
	local surfaceStroke = useAt(colors.surfaceStroke)
	local text = useAt(colors.text)
	local textActive = useAt(colors.textActive)
	local caption = useAt(colors.caption)

	local masterOn = useAt(config.enabledMaster or ALWAYS_ON)

	local entries = config.elements
	local rows = math.ceil(#entries / COLUMNS)
	local gridHeight = rows * CELL_HEIGHT + math.max(0, rows - 1) * CELL_GAP

	local dimBind, dimSpring = useSpring(1, SPRING.quick)
	useEffect(function()
		dimSpring:setGoal(masterOn and 1 or 0)
	end, { masterOn })

	local chips: { [string]: any } = {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 1),
			PaddingRight = UDim.new(0, 1),
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 1),
		}),
		UIGridLayout = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
			CellSize = UDim2.new(1 / COLUMNS, -(CELL_GAP * (COLUMNS - 1)) / COLUMNS, 0, CELL_HEIGHT),
			FillDirectionMaxCells = COLUMNS,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, entry in next, entries do
		chips["Chip_" .. entry.id] = e(Chip, {
			Entry = entry,
			Accent = accent,
			AccentStrong = accentStrong,
			Surface = surface,
			SurfaceStroke = surfaceStroke,
			Text = text,
			TextActive = textActive,
			Caption = caption,
			LayoutOrder = index,
		})
	end

	return e("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, gridHeight + 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = dimBind:map(function(value: number): number
			return (1 - value) * 0.5
		end),
		LayoutOrder = properties.LayoutOrder,
	}, chips)
end
