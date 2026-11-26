local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local SPRING = require("@ui/util/spring")

local e = React.createElement
local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useMemo = React.useMemo
local useSpring = ReactRipple.useSpring
local useState = React.useState

local colors = themeState.colors.window.element
local COLUMNS = 4
local CELL_HEIGHT = 18
local CELL_GAP = 3

export type StateColorsRendererProperties = {
	StateColors: any,
	LayoutOrder: number?,
}

type ProfileButtonProperties = {
	Definition: any,
	Selected: boolean,
	Accent: Color3,
	AccentStrong: Color3,
	Surface: Color3,
	SurfaceStroke: Color3,
	Text: Color3,
	TextActive: Color3,
	LayoutOrder: number,
	OnClick: () -> (),
}

local function ProfileButton(properties: ProfileButtonProperties): React.Element<any>
	local hovered, setHovered = useState(false)
	local selectedBind, selectedSpring = useSpring(properties.Selected and 1 or 0, SPRING.quick)
	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)

	useEffect(function()
		selectedSpring:setGoal(properties.Selected and 1 or 0)
	end, { properties.Selected })

	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	local visualBind = useMemo(function()
		return React.joinBindings({ selectedBind, hoverBind })
	end, { selectedBind, hoverBind } :: { any })

	return e("TextButton", {
		Size = UDim2.new(1 / COLUMNS, -3, 0, CELL_HEIGHT),
		BackgroundColor3 = visualBind:map(function(values: { number }): Color3
			local selected = values[1]
			local hover = values[2]
			return properties.Surface:Lerp(properties.Accent, selected):Lerp(Color3.new(1, 1, 1), hover * 0.06)
		end),
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		LayoutOrder = properties.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
		[React.Event.MouseButton1Click] = properties.OnClick,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
		UIStroke = e("UIStroke", {
			Color = selectedBind:map(function(value: number): Color3
				return properties.SurfaceStroke:Lerp(properties.AccentStrong, value)
			end),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		Label = e("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = properties.Definition.label,
			FontFace = FileController.Get("font", "semi_bold"),
			TextSize = 11,
			TextColor3 = selectedBind:map(function(value: number): Color3
				return properties.Text:Lerp(properties.TextActive, value)
			end),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

return function(properties: StateColorsRendererProperties): React.Element<any>
	local element = properties.StateColors
	local config = element._config
	local selectedId = useAt(config.selectedState) :: string

	local accent = useAt(colors.accent)
	local accentStrong = useAt(colors.accentStrong)
	local surface = useAt(colors.surface)
	local surfaceStroke = useAt(colors.surfaceStroke)
	local text = useAt(colors.text)
	local textActive = useAt(colors.textActive)

	local states = config.states
	local rows = math.ceil(#states / COLUMNS)
	local gridHeight = rows * CELL_HEIGHT + math.max(0, rows - 1) * CELL_GAP
	local buttons: { [string]: any } = {
		UIGridLayout = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
			CellSize = UDim2.new(1 / COLUMNS, -3, 0, CELL_HEIGHT),
			FillDirectionMaxCells = COLUMNS,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, definition in states do
		local id = definition.id
		buttons["Profile_" .. id] = e(ProfileButton, {
			Definition = definition,
			Selected = selectedId == id,
			Accent = accent,
			AccentStrong = accentStrong,
			Surface = surface,
			SurfaceStroke = surfaceStroke,
			Text = text,
			TextActive = textActive,
			LayoutOrder = index,
			OnClick = function(): ()
				config.selectedState(id)
			end,
		})
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, gridHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = properties.LayoutOrder,
	}, {
		Profiles = e("Frame", {
			Size = UDim2.new(1, 0, 0, gridHeight),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, buttons),
	})
end
