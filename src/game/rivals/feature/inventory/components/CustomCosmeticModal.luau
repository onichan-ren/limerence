local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local ColorpickerElement = require("@ui/window/element/colorpicker/Colorpicker")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local cursor = require("@ui/util/cursor")
local ViewportPreview = require("@feature/inventory/customSkins/ViewportPreview")
local modelPreview = require("@feature/inventory/customSkins/modelPreview")
local customAssets = require("@game/rivals/feature/inventory/customAssets")
local customWrapStore = require("@game/rivals/feature/inventory/customWrapStore")
local customWrapController = require("@game/rivals/feature/inventory/customWrapController")
local customCharmStore = require("@game/rivals/feature/inventory/customCharmStore")
local customCharmController = require("@game/rivals/feature/inventory/customCharmController")
local customPreview = require("@game/rivals/feature/inventory/customPreview")
local cosmeticLibraryAccess = require("@game/rivals/feature/inventory/cosmeticLibraryAccess")
local rivalsInventoryState = require("@game/rivals/feature/inventory/rivalsInventoryState")
local InventoryChanger = require("@game/rivals/feature/inventory/InventoryChanger")
local SPRING = require("@ui/util/spring")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useRef = React.useRef
local useAt = ReactCharm.useAtom
local useSpring = ReactRipple.useSpring
local e = React.createElement

local inventoryColors = themeState.colors.inventory
local subwindowColors = themeState.colors.subwindow
local elementColors = themeState.colors.window.element

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local MAX_PANEL_WIDTH = 680
local MAX_PANEL_HEIGHT = 560
local MIN_PANEL_WIDTH = 500
local MIN_PANEL_HEIGHT = 486
local SCREEN_MARGIN = 16
local OUTER_PAD = 14
local SECTION_GAP = 10
local TITLE_HEIGHT = 22
local FOOTER_HEIGHT = 30
local COLUMN_GAP = 10

local CARD_PAD = 10
local CARD_PAD_Y = 8
local CARD_GAP = 8
local CARD_CONTENT_GAP = 6
local LABEL_HEIGHT = 12
local CONTROL_HEIGHT = 24
local HEADER_TITLE_HEIGHT = 14
local HEADER_SUBTITLE_HEIGHT = 12
local IDENTITY_CARD_HEIGHT = CARD_PAD_Y * 2 + LABEL_HEIGHT + CARD_CONTENT_GAP + CONTROL_HEIGHT
local MOTION_CARD_HEIGHT = CARD_PAD_Y * 2 + CONTROL_HEIGHT * 2 + CARD_CONTENT_GAP
local SURFACE_CARD_HEIGHT = CARD_PAD_Y * 2 + LABEL_HEIGHT + CONTROL_HEIGHT * 2 + CARD_CONTENT_GAP * 2
local APPEARANCE_CARD_HEIGHT = SURFACE_CARD_HEIGHT
local IMPORT_ROW_HEIGHT = CONTROL_HEIGHT
local THUMB_GAP = 8
local GRID_PAD = 2
local SCROLLBAR_INSET = 3

local CONTROL_TEXT_SIZE = 12
local COMPACT_TEXT_SIZE = 11
local LABEL_TEXT_SIZE = 10
local CONTROL_CORNER = 5

local MATERIALS = { "ForceField", "Plastic", "Glass" }

local function trimText(value: string): string
	return value:match("^%s*(.-)%s*$") or ""
end

local function formatColor(color: Color3?): string
	if not color then
		return "No tint"
	end

	local r = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255)
	local g = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255)
	local b = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
	return string.format("#%02X%02X%02X", r, g, b)
end

type ActionButtonProps = {
	Text: string,
	Primary: boolean?,
	Enabled: boolean?,
	LayoutOrder: number?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextSize: number?,
	OnClick: () -> (),
}

local function ActionButton(props: ActionButtonProps): React.Element<any>
	local accent = useAt(inventoryColors.customWrap)
	local surface = useAt(elementColors.surface)
	local surfaceStroke = useAt(elementColors.surfaceStroke)
	local textColor = useAt(elementColors.text)
	local textActive = useAt(elementColors.textActive)
	local caption = useAt(elementColors.caption)
	local hoverTint = useAt(themeState.other.hoverTint) :: number

	local enabled = props.Enabled ~= false
	local primary = props.Primary == true
	local hovered, setHovered = useState(false)
	local pressed, setPressed = useState(false)

	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	useEffect(function()
		hoverSpring:setGoal(hovered and enabled and 1 or 0)
	end, { hovered, enabled } :: { any })

	local pressBind, pressSpring = useSpring(0, SPRING.quick)
	useEffect(function()
		pressSpring:setGoal(pressed and 1 or 0)
	end, { pressed })

	local backgroundBind = useMemo(function()
		return React.joinBindings({ hoverBind, pressBind }):map(function(values)
			local hover = values[1]
			local press = values[2]
			local base = surface
			if primary and enabled then
				base = accent
			end
			return base:Lerp(WHITE, hover * hoverTint):Lerp(BLACK, press * 0.12)
		end)
	end, { hoverBind, pressBind, primary, enabled, accent, surface, hoverTint } :: { any })

	local strokeColor: Color3
	if primary and enabled then
		strokeColor = accent
	else
		strokeColor = surfaceStroke
	end

	local textColorBind = useMemo(function()
		return hoverBind:map(function(value: number)
			if not enabled then
				return caption
			end
			if primary then
				return WHITE
			end
			return textColor:Lerp(textActive, value)
		end)
	end, { hoverBind, primary, enabled, textColor, textActive, caption } :: { any })

	local onClick = useCallback(function()
		if enabled then
			props.OnClick()
		end
	end, { enabled, props.OnClick } :: { any })

	return e("TextButton", {
		BackgroundColor3 = backgroundBind,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = false,
		Selectable = false,
		FontFace = FileController.Get("font", "semi_bold"),
		Text = props.Text,
		TextColor3 = textColorBind,
		TextSize = props.TextSize or CONTROL_TEXT_SIZE,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder or 0,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			setPressed(false)
		end,
		[React.Event.MouseButton1Down] = function()
			setPressed(true)
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
		end,
		[React.Event.MouseButton1Click] = onClick,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, CONTROL_CORNER) }),
		UIStroke = e("UIStroke", {
			Color = strokeColor,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

type ChoiceButtonProps = {
	Text: string,
	Selected: boolean,
	LayoutOrder: number,
	Width: number,
	Height: number?,
	TextSize: number?,
	OnClick: () -> (),
}

local function ChoiceButton(props: ChoiceButtonProps): React.Element<any>
	local accent = useAt(inventoryColors.customWrap)
	local surface = useAt(elementColors.surface)
	local surfaceStroke = useAt(elementColors.surfaceStroke)
	local textColor = useAt(elementColors.text)
	local textActive = useAt(elementColors.textActive)
	local hoverTint = useAt(themeState.other.hoverTint) :: number

	local hovered, setHovered = useState(false)
	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	local selectedBind, selectedSpring = useSpring(props.Selected and 1 or 0, SPRING.quick)
	useEffect(function()
		selectedSpring:setGoal(props.Selected and 1 or 0)
	end, { props.Selected })

	local backgroundBind = useMemo(function()
		return React.joinBindings({ hoverBind, selectedBind }):map(function(values)
			local hover = values[1]
			local selected = values[2]
			return surface:Lerp(accent, selected):Lerp(WHITE, hover * hoverTint)
		end)
	end, { hoverBind, selectedBind, surface, accent, hoverTint } :: { any })

	local strokeBind = useMemo(function()
		return selectedBind:map(function(value: number)
			return surfaceStroke:Lerp(accent, value)
		end)
	end, { selectedBind, surfaceStroke, accent } :: { any })

	local textColorBind = useMemo(function()
		return React.joinBindings({ hoverBind, selectedBind }):map(function(values)
			local hover = values[1]
			local selected = values[2]
			return textColor:Lerp(textActive, hover):Lerp(WHITE, selected)
		end)
	end, { hoverBind, selectedBind, textColor, textActive } :: { any })

	return e("TextButton", {
		BackgroundColor3 = backgroundBind,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = false,
		Selectable = false,
		FontFace = FileController.Get("font", "semi_bold"),
		Text = props.Text,
		TextColor3 = textColorBind,
		TextSize = props.TextSize or COMPACT_TEXT_SIZE,
		Size = UDim2.fromOffset(props.Width, props.Height or 22),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
		[React.Event.MouseButton1Click] = props.OnClick,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, CONTROL_CORNER) }),
		UIStroke = e("UIStroke", {
			Color = strokeBind,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

type TogglePillProps = {
	Label: string,
	Value: boolean,
	LayoutOrder: number,
	OnToggle: () -> (),
}

local function TogglePill(props: TogglePillProps): React.Element<any>
	local accent = useAt(inventoryColors.customWrap)
	local surface = useAt(elementColors.surface)
	local surfaceStroke = useAt(elementColors.surfaceStroke)
	local textColor = useAt(elementColors.text)
	local textActive = useAt(elementColors.textActive)
	local caption = useAt(elementColors.caption)
	local hoverTint = useAt(themeState.other.hoverTint) :: number

	local hovered, setHovered = useState(false)
	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	local onBind, onSpring = useSpring(props.Value and 1 or 0, SPRING.quick)
	useEffect(function()
		onSpring:setGoal(props.Value and 1 or 0)
	end, { props.Value })

	local backgroundBind = useMemo(function()
		return React.joinBindings({ hoverBind, onBind }):map(function(values)
			local hover = values[1]
			local on = values[2]
			return surface:Lerp(accent, on):Lerp(WHITE, hover * hoverTint)
		end)
	end, { hoverBind, onBind, surface, accent, hoverTint } :: { any })

	local strokeBind = useMemo(function()
		return onBind:map(function(value: number)
			return surfaceStroke:Lerp(accent, value)
		end)
	end, { onBind, surfaceStroke, accent } :: { any })

	local labelColorBind = useMemo(function()
		return React.joinBindings({ hoverBind, onBind }):map(function(values)
			local hover = values[1]
			local on = values[2]
			return textColor:Lerp(textActive, hover):Lerp(WHITE, on)
		end)
	end, { hoverBind, onBind, textColor, textActive } :: { any })

	local stateColorBind = useMemo(function()
		return onBind:map(function(value: number)
			return caption:Lerp(WHITE, value)
		end)
	end, { onBind, caption } :: { any })

	return e("TextButton", {
		BackgroundColor3 = backgroundBind,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = false,
		Selectable = false,
		Text = "",
		Size = UDim2.new(1, 0, 0, CONTROL_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
		[React.Event.MouseButton1Click] = props.OnToggle,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, CONTROL_CORNER) }),
		UIStroke = e("UIStroke", {
			Color = strokeBind,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = props.Label,
			TextColor3 = labelColorBind,
			TextSize = CONTROL_TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -62, 1, 0),
		}),
		State = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = props.Value and "ON" or "OFF",
			TextColor3 = stateColorBind,
			TextSize = LABEL_TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.fromOffset(42, CONTROL_HEIGHT),
		}),
	})
end

type InputBoxProps = {
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Text: string?,
	Placeholder: string?,
	TextSize: number?,
	TextXAlignment: Enum.TextXAlignment?,
	BoxRef: { current: TextBox? }?,
	OnTextChanged: ((TextBox) -> ())?,
	OnFocusLost: ((TextBox) -> ())?,
}

local function InputBox(props: InputBoxProps): React.Element<any>
	local accent = useAt(inventoryColors.customWrap)
	local fieldBg = useAt(elementColors.fieldBackground)
	local fieldBgActive = useAt(elementColors.fieldBackgroundActive)
	local fieldStroke = useAt(elementColors.fieldStroke)
	local caption = useAt(elementColors.caption)
	local textColor = useAt(subwindowColors.text)
	local hoverTint = useAt(themeState.other.hoverTint) :: number

	local hovered, setHovered = useState(false)
	local focused, setFocused = useState(false)
	local innerRef = useRef(nil :: TextBox?)

	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	local focusBind, focusSpring = useSpring(0, SPRING.quick)
	useEffect(function()
		focusSpring:setGoal(focused and 1 or 0)
	end, { focused })

	local backgroundBind = useMemo(function()
		return React.joinBindings({ hoverBind, focusBind }):map(function(values)
			local hover = values[1]
			local focus = values[2]
			return fieldBg:Lerp(fieldBgActive, focus):Lerp(WHITE, hover * hoverTint)
		end)
	end, { hoverBind, focusBind, fieldBg, fieldBgActive, hoverTint } :: { any })

	local strokeBind = useMemo(function()
		return focusBind:map(function(value: number)
			return fieldStroke:Lerp(accent, value)
		end)
	end, { focusBind, fieldStroke, accent } :: { any })

	local boxRef = props.BoxRef
	local assignRef = useCallback(function(rbx: TextBox?)
		innerRef.current = rbx
		if boxRef then
			boxRef.current = rbx
		end
	end, { boxRef } :: { any })

	local onFocusLost = props.OnFocusLost
	local onTextChanged = props.OnTextChanged

	return e("TextButton", {
		BackgroundColor3 = backgroundBind,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = false,
		Selectable = false,
		Text = "",
		ClipsDescendants = true,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
		[React.Event.MouseButton1Click] = function()
			local box = innerRef.current
			if box then
				box:CaptureFocus()
			end
		end,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, CONTROL_CORNER) }),
		UIStroke = e("UIStroke", {
			Color = strokeBind,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		Input = e("TextBox", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			FontFace = FileController.Get("font", "semi_bold"),
			PlaceholderText = props.Placeholder,
			PlaceholderColor3 = caption,
			Text = props.Text or "",
			TextColor3 = textColor,
			TextSize = props.TextSize or CONTROL_TEXT_SIZE,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			ref = assignRef,
			[React.Event.Focused] = function()
				setFocused(true)
			end,
			[React.Event.FocusLost] = function(rbx: TextBox): ()
				setFocused(false)
				if onFocusLost then
					onFocusLost(rbx)
				end
			end,
			[React.Change.Text] = onTextChanged,
		}),
	})
end

type NumberFieldProps = {
	Label: string,
	Value: number,
	Size: UDim2,
	LayoutOrder: number,
	OnCommit: (number) -> (),
}

local function NumberField(props: NumberFieldProps): React.Element<any>
	local caption = useAt(elementColors.caption)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = props.Label,
			TextColor3 = caption,
			TextSize = LABEL_TEXT_SIZE,
			Size = UDim2.fromOffset(44, CONTROL_HEIGHT),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
		}),
		Box = e(InputBox, {
			Size = UDim2.new(1, -50, 0, CONTROL_HEIGHT),
			LayoutOrder = 1,
			Text = tostring(props.Value),
			TextSize = COMPACT_TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Center,
			OnFocusLost = function(rbx: TextBox): ()
				local number = tonumber(rbx.Text)
				if number then
					props.OnCommit(number)
					rbx.Text = tostring(number)
				else
					rbx.Text = tostring(props.Value)
				end
			end,
		}),
	})
end

type TileCardProps = {
	Asset: string?,
	Label: string?,
	Selected: boolean,
	LayoutOrder: number,
	OnClick: () -> (),
}

local function TileCard(props: TileCardProps): React.Element<any>
	local accent = useAt(inventoryColors.customWrap)
	local imageBg = useAt(inventoryColors.cardImageBg)
	local fieldStroke = useAt(elementColors.fieldStroke)
	local caption = useAt(elementColors.caption)
	local strong = useAt(elementColors.textActive)

	local hovered, setHovered = useState(false)
	local pressed, setPressed = useState(false)

	local hoverBind, hoverSpring = useSpring(0, SPRING.smoothPrecise)
	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	local pressBind, pressSpring = useSpring(0, SPRING.quick)
	useEffect(function()
		pressSpring:setGoal(pressed and 1 or 0)
	end, { pressed })

	local selectedBind, selectedSpring = useSpring(props.Selected and 1 or 0, SPRING.quick)
	useEffect(function()
		selectedSpring:setGoal(props.Selected and 1 or 0)
	end, { props.Selected })

	local backgroundTransparencyBind = useMemo(function()
		return React.joinBindings({ hoverBind, pressBind }):map(function(values)
			local hover = values[1]
			local press = values[2]
			return 0.2 - hover * 0.08 + press * 0.08
		end)
	end, { hoverBind, pressBind } :: { any })

	local strokeColorBind = useMemo(function()
		return selectedBind:map(function(value: number)
			return fieldStroke:Lerp(accent, value)
		end)
	end, { selectedBind, fieldStroke, accent } :: { any })

	local strokeTransparencyBind = useMemo(function()
		return React.joinBindings({ hoverBind, selectedBind }):map(function(values)
			local hover = values[1]
			local selected = values[2]
			return 0.55 - hover * 0.2 - selected * 0.55
		end)
	end, { hoverBind, selectedBind } :: { any })

	local imageSizeBind = useMemo(function()
		return hoverBind:map(function(value: number)
			local scale = 1 + value * 0.045
			return UDim2.fromScale(scale, scale)
		end)
	end, { hoverBind } :: { any })

	return e("TextButton", {
		BackgroundColor3 = imageBg,
		BackgroundTransparency = backgroundTransparencyBind,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Selectable = false,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			setPressed(false)
		end,
		[React.Event.MouseButton1Down] = function()
			setPressed(true)
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
		end,
		[React.Event.MouseButton1Click] = props.OnClick,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		UIStroke = e("UIStroke", {
			Color = strokeColorBind,
			Transparency = strokeTransparencyBind,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Thumb = props.Asset and e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = imageSizeBind,
			Image = props.Asset,
			ImageColor3 = WHITE,
			ScaleType = Enum.ScaleType.Crop,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		}) or nil,
		Label = props.Label and e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = props.Label,
			TextColor3 = props.Selected and strong or caption,
			TextSize = LABEL_TEXT_SIZE,
			TextWrapped = true,
			Size = UDim2.new(1, -8, 1, -8),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		}) or nil,
	})
end

type TintPickerProps = {
	Value: Color3?,
	LayoutOrder: number,
	OnChange: (Color3?) -> (),
}

local function TintPicker(props: TintPickerProps): React.Element<any>
	local fieldBg = useAt(elementColors.fieldBackground)
	local fieldBgActive = useAt(elementColors.fieldBackgroundActive)
	local fieldStroke = useAt(elementColors.fieldStroke)
	local caption = useAt(elementColors.caption)
	local strong = useAt(elementColors.textActive)
	local hoverTint = useAt(themeState.other.hoverTint) :: number

	local hovered, setHovered = useState(false)
	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	local backgroundBind = useMemo(function()
		return hoverBind:map(function(value: number)
			return fieldBg:Lerp(fieldBgActive, value * 0.6):Lerp(WHITE, value * hoverTint)
		end)
	end, { hoverBind, fieldBg, fieldBgActive, hoverTint } :: { any })

	local picker = useMemo(function()
		return ColorpickerElement("Tint", props.Value or Color3.fromRGB(255, 255, 255))
	end, {})

	local current = useAt(picker._state)
	local currentColor = typeof(current) == "Color3" and current or Color3.fromRGB(255, 255, 255)
	local swatchColor = props.Value or currentColor
	local isTinted = props.Value ~= nil

	useEffect(function()
		return picker:OnColorChange(function(color: Color3 | ColorSequence)
			if typeof(color) == "Color3" then
				props.OnChange(color)
			end
		end)
	end, { picker, props.OnChange } :: { any })

	useEffect(function()
		if props.Value then
			local existing = picker:PeekColor()
			if typeof(existing) == "Color3" and existing ~= props.Value then
				picker:SetState(props.Value)
			end
		end
	end, { props.Value or false } :: { any })

	local openPicker = useCallback(function()
		if not props.Value then
			props.OnChange(currentColor)
		end
		SubwindowController.OpenColorpicker(picker, cursor.getPosition())
	end, { picker, props.Value, props.OnChange, currentColor } :: { any })

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, CONTROL_HEIGHT),
		LayoutOrder = props.LayoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, CARD_CONTENT_GAP),
		}),
		Picker = e("TextButton", {
			BackgroundColor3 = backgroundBind,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Active = false,
			Selectable = false,
			Text = "",
			Size = UDim2.new(1, -58, 1, 0),
			LayoutOrder = 0,
			[React.Event.MouseEnter] = function()
				setHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				setHovered(false)
			end,
			[React.Event.MouseButton1Click] = openPicker,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, CONTROL_CORNER) }),
			UIStroke = e("UIStroke", {
				Color = fieldStroke,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Swatch = e("Frame", {
				BackgroundColor3 = isTinted and swatchColor or fieldBg,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(3, 3),
				Size = UDim2.fromOffset(CONTROL_HEIGHT - 6, CONTROL_HEIGHT - 6),
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				UIStroke = e("UIStroke", {
					Color = fieldStroke,
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			}),
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = FileController.Get("font", "semi_bold"),
				Text = isTinted and formatColor(swatchColor) or "Choose tint",
				TextColor3 = isTinted and strong or caption,
				TextSize = COMPACT_TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(CONTROL_HEIGHT + 3, 0),
				Size = UDim2.new(1, -(CONTROL_HEIGHT + 9), 1, 0),
			}),
		}),
		Clear = e(ActionButton, {
			Text = "Off",
			Enabled = isTinted,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(52, CONTROL_HEIGHT),
			TextSize = COMPACT_TEXT_SIZE,
			OnClick = function()
				props.OnChange(nil)
			end,
		}),
	})
end

type ImportRowProps = {
	LayoutOrder: number,
	OnImported: () -> (),
	OnStatus: (string?) -> (),
}

local function ImportRow(props: ImportRowProps): React.Element<any>
	local boxRef = useRef(nil :: TextBox?)

	local onImported = props.OnImported
	local onStatus = props.OnStatus

	local onImport = useCallback(function(): ()
		local box = boxRef.current
		if not box then
			return
		end
		local source = box.Text
		if trimText(source) == "" then
			onStatus("Enter a link or file path")
			return
		end
		local fullName, err = customAssets.import(source)
		if fullName then
			box.Text = ""
			onStatus(`Imported {fullName}`)
			onImported()
		else
			onStatus(err)
		end
	end, { onImported, onStatus } :: { any })

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, IMPORT_ROW_HEIGHT),
		LayoutOrder = props.LayoutOrder,
	}, {
		Box = e(InputBox, {
			Size = UDim2.new(1, -66, 0, IMPORT_ROW_HEIGHT),
			Placeholder = "Link or file path",
			TextSize = COMPACT_TEXT_SIZE,
			BoxRef = boxRef,
		}),
		Import = e(ActionButton, {
			Text = "Import",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(60, IMPORT_ROW_HEIGHT),
			TextSize = COMPACT_TEXT_SIZE,
			OnClick = onImport,
		}),
	})
end

return function(): React.Element<any>?
	local modal = useAt(customWrapStore.modal)
	local open = modal.open == true
	local mode = modal.mode
	local editId = modal.editId

	local panelColor = useAt(subwindowColors.background)
	local strokeColor = useAt(subwindowColors.stroke)
	local titleColor = useAt(subwindowColors.title)
	local textColor = useAt(subwindowColors.text)
	local imageBg = useAt(inventoryColors.cardImageBg)
	local fieldStroke = useAt(elementColors.fieldStroke)
	local caption = useAt(elementColors.caption)
	local scrollThumb = useAt(elementColors.scrollThumb)

	local kind, setKind = useState("Wrap")
	local name, setName = useState("")
	local selectedImage, setSelectedImage = useState(nil :: string?)
	local animated, setAnimated = useState(false)
	local speedU, setSpeedU = useState(0)
	local speedV, setSpeedV = useState(0)
	local tint, setTint = useState(nil :: Color3?)
	local material, setMaterial = useState("Plastic")
	local selectedMesh, setSelectedMesh = useState(nil :: string?)
	local selectedTexture, setSelectedTexture = useState(nil :: string?)
	local charmScale, setCharmScale = useState(1)
	local refreshTick, setRefreshTick = useState(0)
	local importStatus, setImportStatus = useState(nil :: string?)

	local selectedWeapon = useAt(rivalsInventoryState.selectedWeapon)

	local previewController = useMemo(function()
		return modelPreview.new()
	end, {})

	local overlayRef = useRef(nil :: TextButton?)
	local containerSize, setContainerSize = useState(Vector2.new(MAX_PANEL_WIDTH, MAX_PANEL_HEIGHT))

	useEffect(function(): (() -> ())?
		local overlay = overlayRef.current
		if not open or not overlay then
			return nil
		end
		local function update(): ()
			local size = overlay.AbsoluteSize
			if size.X > 0 and size.Y > 0 then
				setContainerSize(size)
			end
		end
		update()
		local conn = overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
		return function(): ()
			conn:Disconnect()
		end
	end, { open })

	local openBind, openSpring = useSpring(0, SPRING.smoothPrecise)
	useEffect(function()
		openSpring:setGoal(open and 1 or 0)
	end, { open })

	useEffect(function()
		if not open then
			return
		end
		setImportStatus(nil)
		setKind(modal.kind == "Charm" and "Charm" or "Wrap")
		if mode == "edit" and editId then
			if modal.kind == "Charm" then
				local charm = customCharmStore.get(editId)
				if charm then
					setName(charm.name)
					setSelectedMesh(charm.mesh)
					setSelectedTexture(charm.texture)
					setTint(charm.tint)
					setCharmScale(charm.scale)
					return
				end
			else
				local wrap = customWrapStore.get(editId)
				if wrap then
					setName(wrap.name)
					setSelectedImage(wrap.image)
					setAnimated(wrap.animated)
					setSpeedU(wrap.speedU)
					setSpeedV(wrap.speedV)
					setTint(wrap.tint)
					setMaterial(wrap.material)
					return
				end
			end
		end
		setName("")
		setSelectedImage(nil)
		setAnimated(false)
		setSpeedU(0)
		setSpeedV(0)
		setTint(nil)
		setMaterial("Plastic")
		setSelectedMesh(nil)
		setSelectedTexture(nil)
		setCharmScale(1)
	end, { open, mode, editId, modal.kind } :: { any })

	local images = useMemo(function()
		return customAssets.list("image")
	end, { open, refreshTick } :: { any })

	local meshes = useMemo(function()
		return customAssets.list("mesh")
	end, { open, refreshTick } :: { any })

	local thumbs = useMemo(function()
		local out: { [string]: string } = {}
		for _, entry in next, images do
			local asset = getcustomasset(entry.path)
			if type(asset) == "string" then
				out[entry.fullName] = asset
			end
		end
		return out
	end, { images } :: { any })

	local charmAvailable = useMemo(function()
		return customCharmController.available()
	end, { open, refreshTick } :: { any })

	local previewWeapon = useMemo(function(): string?
		if selectedWeapon then
			return selectedWeapon
		end
		local weapons = cosmeticLibraryAccess.getWeapons()
		return weapons[1]
	end, { selectedWeapon } :: { any })

	useEffect(function()
		if not open then
			return
		end
		local model: Model? = nil
		if kind == "Wrap" then
			model = customPreview.buildWrapModel(previewWeapon, {
				image = selectedImage,
				animated = animated,
				speedU = speedU,
				speedV = speedV,
				tint = tint,
				material = material,
			})
		elseif selectedMesh and customCharmStore.meshAvailable(selectedMesh) then
			model = customPreview.buildCharmModel({
				id = "custompreview_charm",
				name = "Preview",
				mesh = selectedMesh,
				texture = selectedTexture,
				tint = tint,
				scale = charmScale,
				version = 1,
			})
		end
		previewController:setModel(model)
	end, {
		open,
		kind,
		previewWeapon,
		selectedImage,
		animated,
		speedU,
		speedV,
		tint or false,
		material,
		selectedMesh or false,
		selectedTexture or false,
		charmScale,
	} :: { any })

	local onViewportMount = useCallback(function(parts: modelPreview.MountParts): () -> ()
		previewController:mount(parts)
		return function(): ()
			previewController:unmount()
		end
	end, { previewController } :: { any })

	local onClose = useCallback(function(): ()
		customWrapStore.closeModal()
	end, {})

	local onRefresh = useCallback(function(): ()
		setRefreshTick(function(previous: number)
			return previous + 1
		end)
	end, {})

	local onSave = useCallback(function(): ()
		local trimmed = trimText(name :: string)
		if trimmed == "" then
			return
		end

		if kind == "Wrap" then
			if not selectedImage or not customWrapStore.imageExists(selectedImage) then
				return
			end
			local id: string
			if mode == "edit" and editId then
				id = editId
			else
				id = customWrapStore.newId()
			end
			customWrapController.save({
				id = id,
				name = trimmed,
				image = selectedImage,
				animated = animated,
				speedU = speedU,
				speedV = speedV,
				tint = tint,
				material = material,
				version = 1,
			})
		else
			if not selectedMesh or not customCharmStore.meshAvailable(selectedMesh) then
				return
			end
			local id: string
			if mode == "edit" and editId then
				id = editId
			else
				id = customCharmStore.newId()
			end
			customCharmController.save({
				id = id,
				name = trimmed,
				mesh = selectedMesh,
				texture = selectedTexture,
				tint = tint,
				scale = charmScale,
				version = 1,
			})
		end

		if mode == "edit" then
			InventoryChanger.RefreshLoadout()
		end
		customWrapStore.closeModal()
	end, {
		kind,
		name,
		selectedImage,
		animated,
		speedU,
		speedV,
		tint or false,
		material,
		selectedMesh or false,
		selectedTexture or false,
		charmScale,
		mode,
		editId,
	} :: { any })

	if not open then
		return nil
	end

	local isWrap = kind == "Wrap"
	local canSave = trimText(name :: string) ~= ""
		and (
			isWrap and selectedImage ~= nil
			or not isWrap and charmAvailable and selectedMesh ~= nil and customCharmStore.meshAvailable(selectedMesh)
		)

	local overlayTransparencyBind = openBind:map(function(value: number)
		return 0.58 - value * 0.2
	end)
	local panelGroupTransparencyBind = openBind:map(function(value: number)
		return 1 - value
	end)
	local panelPositionBind = openBind:map(function(value: number)
		return UDim2.new(0.5, 0, 0.5, math.floor((1 - value) * 8))
	end)
	local panelScaleBind = openBind:map(function(value: number)
		return 0.94 + value * 0.06
	end)

	local panelWidth = math.clamp(math.floor(containerSize.X) - SCREEN_MARGIN * 2, MIN_PANEL_WIDTH, MAX_PANEL_WIDTH)
	local panelHeight = math.clamp(math.floor(containerSize.Y) - SCREEN_MARGIN * 2, MIN_PANEL_HEIGHT, MAX_PANEL_HEIGHT)
	local bodyHeight = panelHeight - OUTER_PAD * 2 - TITLE_HEIGHT - FOOTER_HEIGHT - SECTION_GAP * 2
	local previewWidth = math.clamp(math.floor(panelWidth * 0.42), 230, 300)
	local rightWidth = panelWidth - OUTER_PAD * 2 - COLUMN_GAP - previewWidth
	local rightInner = rightWidth - CARD_PAD * 2
	local gridInner = rightInner - GRID_PAD * 2 - SCROLLBAR_INSET
	local thumbWidth = math.floor((gridInner - THUMB_GAP * 2) / 3)
	local thumbHeight = math.floor(thumbWidth * 0.72)
	local cellSize = UDim2.fromOffset(thumbWidth, thumbHeight)
	local textureThumbHeight = math.min(thumbHeight, 52)
	local textureCellSize = UDim2.fromOffset(thumbWidth, textureThumbHeight)
	local importHeight = IMPORT_ROW_HEIGHT
	local headerWithSubtitle = HEADER_TITLE_HEIGHT + HEADER_SUBTITLE_HEIGHT
	local textureGridHeight = textureThumbHeight + GRID_PAD * 2
	local textureCardHeight = CARD_PAD_Y * 2 + HEADER_TITLE_HEIGHT + CARD_CONTENT_GAP + textureGridHeight
	local libraryHeight = bodyHeight - IDENTITY_CARD_HEIGHT - MOTION_CARD_HEIGHT - SURFACE_CARD_HEIGHT - CARD_GAP * 3
	local meshHeight = bodyHeight - textureCardHeight - IDENTITY_CARD_HEIGHT - APPEARANCE_CARD_HEIGHT - CARD_GAP * 3
	local libraryGridHeight = libraryHeight
		- CARD_PAD_Y * 2
		- headerWithSubtitle
		- importHeight
		- CARD_CONTENT_GAP * 2
	local meshGridHeight = meshHeight - CARD_PAD_Y * 2 - headerWithSubtitle - importHeight - CARD_CONTENT_GAP * 2

	local function editorCard(
		layoutOrder: number,
		height: number,
		children: { [string]: React.Element<any>? }
	): React.Element<any>
		local cardChildren: { [string]: any } = {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 7) }),
			UIStroke = e("UIStroke", {
				Color = fieldStroke,
				Thickness = 1,
				Transparency = 0.56,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, CARD_PAD),
				PaddingRight = UDim.new(0, CARD_PAD),
				PaddingTop = UDim.new(0, CARD_PAD_Y),
				PaddingBottom = UDim.new(0, CARD_PAD_Y),
			}),
		}
		for childKey, child in next, children do
			cardChildren[childKey] = child
		end

		return e("Frame", {
			BackgroundColor3 = imageBg,
			BackgroundTransparency = 0.42,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = layoutOrder,
		}, cardChildren)
	end

	local function cardHeader(title: string, subtitle: string?): React.Element<any>
		return e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, subtitle and headerWithSubtitle or HEADER_TITLE_HEIGHT),
			LayoutOrder = 0,
		}, {
			Title = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = FileController.Get("font", "semi_bold"),
				Text = title,
				TextColor3 = textColor,
				TextSize = CONTROL_TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Size = UDim2.new(1, 0, 0, HEADER_TITLE_HEIGHT),
			}),
			Subtitle = subtitle and e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = FileController.Get("font", "light"),
				Text = subtitle,
				TextColor3 = caption,
				TextSize = LABEL_TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(0, HEADER_TITLE_HEIGHT),
				Size = UDim2.new(1, 0, 0, HEADER_SUBTITLE_HEIGHT),
			}) or nil,
		})
	end

	local function assetGrid(
		height: number,
		cell: UDim2,
		cards: { [string]: React.Element<any> },
		emptyText: string,
		isEmpty: boolean
	): React.Element<any>
		if isEmpty then
			return e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = FileController.Get("font", "semi_bold"),
				Text = emptyText,
				TextColor3 = caption,
				TextSize = COMPACT_TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.new(1, 0, 0, height),
				LayoutOrder = 1,
			})
		end
		return e("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, height),
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = SCROLLBAR_INSET,
			ScrollBarImageColor3 = scrollThumb,
			ScrollBarImageTransparency = 0.1,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			Active = false,
			Selectable = false,
			LayoutOrder = 1,
		}, {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, GRID_PAD),
				PaddingRight = UDim.new(0, GRID_PAD),
				PaddingTop = UDim.new(0, GRID_PAD),
				PaddingBottom = UDim.new(0, GRID_PAD),
			}),
			UIGridLayout = e("UIGridLayout", {
				CellSize = cell,
				CellPadding = UDim2.fromOffset(THUMB_GAP, THUMB_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Cards = e(React.Fragment, nil, cards),
		})
	end

	local function fieldLabel(text: string, layoutOrder: number): React.Element<any>
		return e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = text,
			TextColor3 = caption,
			TextSize = LABEL_TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.new(1, 0, 0, LABEL_HEIGHT),
			LayoutOrder = layoutOrder,
		})
	end

	local rightCards: { [string]: React.Element<any> } = {}

	if isWrap then
		local imageCards: { [string]: React.Element<any> } = {}
		for index, entry in next, images do
			imageCards[`img_{entry.fullName}`] = e(TileCard, {
				Asset = thumbs[entry.fullName],
				Selected = selectedImage == entry.fullName,
				LayoutOrder = index,
				OnClick = function(): ()
					setSelectedImage(entry.fullName)
					if trimText(name :: string) == "" then
						setName(entry.name or entry.fullName)
					end
				end,
			})
		end

		local materialWidth = math.floor((rightInner - CARD_CONTENT_GAP * (#MATERIALS - 1)) / #MATERIALS)
		local materialButtons: { [string]: React.Element<any> } = {}
		for index, mat in next, MATERIALS do
			materialButtons[`mat_{mat}`] = e(ChoiceButton, {
				Text = mat,
				Selected = material == mat,
				LayoutOrder = index,
				Width = materialWidth,
				Height = CONTROL_HEIGHT,
				OnClick = function(): ()
					setMaterial(mat)
				end,
			})
		end

		rightCards.Library = editorCard(0, libraryHeight, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, CARD_CONTENT_GAP),
			}),
			Header = cardHeader(
				"Textures",
				importStatus
					or (#images > 0 and `{#images} image{#images == 1 and "" or "s"} available`
						or "Drop PNG/JPG into assets/inventory/rivals")
			),
			Grid = assetGrid(libraryGridHeight, cellSize, imageCards, "No images found", #images == 0),
			Import = e(ImportRow, { LayoutOrder = 2, OnImported = onRefresh, OnStatus = setImportStatus }),
		})
		rightCards.Identity = editorCard(1, IDENTITY_CARD_HEIGHT, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, CARD_CONTENT_GAP),
			}),
			Label = fieldLabel("Wrap Name", 0),
			NameBox = e(InputBox, {
				Size = UDim2.new(1, 0, 0, CONTROL_HEIGHT),
				LayoutOrder = 1,
				Text = name,
				Placeholder = "Wrap name",
				OnTextChanged = function(rbx: TextBox): ()
					setName(rbx.Text)
				end,
			}),
		})
		rightCards.Motion = editorCard(2, MOTION_CARD_HEIGHT, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, CARD_CONTENT_GAP),
			}),
			Animated = e(TogglePill, {
				Label = "Animation",
				Value = animated,
				LayoutOrder = 0,
				OnToggle = function(): ()
					setAnimated(not animated)
				end,
			}),
			Speeds = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, CONTROL_HEIGHT),
				LayoutOrder = 1,
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, CARD_CONTENT_GAP),
				}),
				U = e(NumberField, {
					Label = "U Speed",
					Value = speedU,
					Size = UDim2.new(0.5, -CARD_CONTENT_GAP / 2, 0, CONTROL_HEIGHT),
					LayoutOrder = 0,
					OnCommit = function(value: number): ()
						setSpeedU(value)
					end,
				}),
				V = e(NumberField, {
					Label = "V Speed",
					Value = speedV,
					Size = UDim2.new(0.5, -CARD_CONTENT_GAP / 2, 0, CONTROL_HEIGHT),
					LayoutOrder = 1,
					OnCommit = function(value: number): ()
						setSpeedV(value)
					end,
				}),
			}),
		})
		rightCards.Surface = editorCard(3, SURFACE_CARD_HEIGHT, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, CARD_CONTENT_GAP),
			}),
			Label = fieldLabel("Surface", 0),
			Materials = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, CONTROL_HEIGHT),
				LayoutOrder = 1,
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, CARD_CONTENT_GAP),
				}),
				Buttons = e(React.Fragment, nil, materialButtons),
			}),
			Tint = e(TintPicker, {
				Value = tint,
				LayoutOrder = 2,
				OnChange = function(nextTint: Color3?): ()
					setTint(nextTint)
				end,
			}),
		})
	else
		local meshCards: { [string]: React.Element<any> } = {}
		for index, entry in next, meshes do
			meshCards[`mesh_{entry.fullName}`] = e(TileCard, {
				Label = entry.name,
				Selected = selectedMesh == entry.fullName,
				LayoutOrder = index,
				OnClick = function(): ()
					setSelectedMesh(entry.fullName)
					if trimText(name :: string) == "" then
						setName(entry.name or entry.fullName)
					end
				end,
			})
		end

		local textureCards: { [string]: React.Element<any> } = {
			tex_none = e(TileCard, {
				Label = "None",
				Selected = selectedTexture == nil,
				LayoutOrder = 0,
				OnClick = function(): ()
					setSelectedTexture(nil)
				end,
			}),
		}
		for index, entry in next, images do
			textureCards[`tex_{entry.fullName}`] = e(TileCard, {
				Asset = thumbs[entry.fullName],
				Selected = selectedTexture == entry.fullName,
				LayoutOrder = index,
				OnClick = function(): ()
					setSelectedTexture(entry.fullName)
				end,
			})
		end

		rightCards.Mesh = editorCard(0, meshHeight, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, CARD_CONTENT_GAP),
			}),
			Header = cardHeader(
				"Meshes",
				importStatus
					or (#meshes > 0 and `{#meshes} mesh{#meshes == 1 and "" or "es"} available`
						or "Drop MESH/OBJ into assets/inventory/rivals")
			),
			Grid = assetGrid(meshGridHeight, cellSize, meshCards, "No meshes found", #meshes == 0),
			Import = e(ImportRow, { LayoutOrder = 2, OnImported = onRefresh, OnStatus = setImportStatus }),
		})
		rightCards.Texture = editorCard(1, textureCardHeight, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, CARD_CONTENT_GAP),
			}),
			Header = cardHeader("Texture", nil),
			Grid = assetGrid(textureGridHeight, textureCellSize, textureCards, "", false),
		})
		rightCards.Identity = editorCard(2, IDENTITY_CARD_HEIGHT, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, CARD_CONTENT_GAP),
			}),
			Label = fieldLabel("Charm Name", 0),
			NameBox = e(InputBox, {
				Size = UDim2.new(1, 0, 0, CONTROL_HEIGHT),
				LayoutOrder = 1,
				Text = name,
				Placeholder = "Charm name",
				OnTextChanged = function(rbx: TextBox): ()
					setName(rbx.Text)
				end,
			}),
		})
		rightCards.Appearance = editorCard(3, APPEARANCE_CARD_HEIGHT, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, CARD_CONTENT_GAP),
			}),
			Label = fieldLabel("Appearance", 0),
			Scale = e(NumberField, {
				Label = "Scale",
				Value = charmScale,
				Size = UDim2.new(1, 0, 0, CONTROL_HEIGHT),
				LayoutOrder = 1,
				OnCommit = function(value: number): ()
					setCharmScale(math.clamp(value, 0.05, 10))
				end,
			}),
			Tint = e(TintPicker, {
				Value = tint,
				LayoutOrder = 2,
				OnChange = function(nextTint: Color3?): ()
					setTint(nextTint)
				end,
			}),
		})
	end

	local previewCaption: string
	if isWrap then
		previewCaption = previewWeapon and `Previewing on {previewWeapon}` or "Select a weapon"
	elseif not charmAvailable then
		previewCaption = "Charm assets are still loading"
	elseif not selectedMesh then
		previewCaption = "Select a mesh"
	else
		previewCaption = "Drag to rotate, scroll to zoom"
	end

	local title: string
	if mode == "edit" then
		title = isWrap and "Edit Custom Wrap" or "Edit Custom Charm"
	else
		title = "Create Custom Cosmetic"
	end

	return e("TextButton", {
		BackgroundColor3 = BLACK,
		BackgroundTransparency = overlayTransparencyBind,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = false,
		Selectable = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
		ref = overlayRef,
		[React.Event.MouseButton1Click] = onClose,
	}, {
		PanelCatch = e("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Active = false,
			Selectable = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = panelPositionBind,
			Size = UDim2.fromOffset(panelWidth, panelHeight),
			ZIndex = 61,
			[React.Event.MouseButton1Click] = function(): () end,
		}, {
			UIScale = e("UIScale", {
				Scale = panelScaleBind,
			}),
			Panel = e("CanvasGroup", {
				BackgroundColor3 = panelColor,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				GroupTransparency = panelGroupTransparencyBind,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 61,
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(0, 9) }),
				UIStroke = e("UIStroke", {
					Color = strokeColor,
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, OUTER_PAD),
					PaddingRight = UDim.new(0, OUTER_PAD),
					PaddingTop = UDim.new(0, OUTER_PAD),
					PaddingBottom = UDim.new(0, OUTER_PAD),
				}),
				Header = e("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
					ZIndex = 62,
				}, {
					Title = e("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						FontFace = FileController.Get("font", "semi_bold"),
						Text = title,
						TextColor3 = titleColor,
						TextSize = 15,
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.new(1, -200, 1, 0),
						ZIndex = 62,
					}),
					Kinds = mode ~= "edit" and e("Frame", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -30, 0, 0),
						Size = UDim2.fromOffset(126, TITLE_HEIGHT),
						ZIndex = 62,
					}, {
						UIListLayout = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Right,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, CARD_CONTENT_GAP),
						}),
						Wrap = e(ChoiceButton, {
							Text = "Wrap",
							Selected = isWrap,
							LayoutOrder = 0,
							Width = 60,
							OnClick = function(): ()
								setKind("Wrap")
							end,
						}),
						Charm = e(ChoiceButton, {
							Text = "Charm",
							Selected = not isWrap,
							LayoutOrder = 1,
							Width = 60,
							OnClick = function(): ()
								setKind("Charm")
							end,
						}),
					}) or nil,
					Close = e("TextButton", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						FontFace = FileController.Get("font", "semi_bold"),
						Text = "X",
						TextColor3 = caption,
						TextSize = 13,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(22, TITLE_HEIGHT),
						AutoButtonColor = false,
						Active = false,
						Selectable = false,
						ZIndex = 62,
						[React.Event.MouseButton1Click] = onClose,
					}),
				}),
				Body = e("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, TITLE_HEIGHT + SECTION_GAP),
					Size = UDim2.new(1, 0, 0, bodyHeight),
					ZIndex = 62,
				}, {
					PreviewCard = e("Frame", {
						BackgroundColor3 = imageBg,
						BackgroundTransparency = 0.42,
						BorderSizePixel = 0,
						Position = UDim2.fromOffset(0, 0),
						Size = UDim2.fromOffset(previewWidth, bodyHeight),
						ZIndex = 62,
					}, {
						UICorner = e("UICorner", { CornerRadius = UDim.new(0, 7) }),
						UIStroke = e("UIStroke", {
							Color = fieldStroke,
							Thickness = 1,
							Transparency = 0.56,
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						}),
						Viewport = e(ViewportPreview, {
							Size = UDim2.new(1, 0, 1, -22),
							ZIndex = 62,
							Corner = 7,
							OnMount = onViewportMount,
						}),
						Badge = e("TextLabel", {
							BackgroundColor3 = BLACK,
							BackgroundTransparency = 0.42,
							BorderSizePixel = 0,
							FontFace = FileController.Get("font", "semi_bold"),
							Text = "Preview",
							TextColor3 = WHITE,
							TextSize = LABEL_TEXT_SIZE,
							Position = UDim2.fromOffset(8, 8),
							Size = UDim2.fromOffset(58, 20),
							ZIndex = 65,
						}, {
							UICorner = e("UICorner", { CornerRadius = UDim.new(0, CONTROL_CORNER) }),
						}),
						Caption = e("TextLabel", {
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							FontFace = FileController.Get("font", "light"),
							Text = previewCaption,
							TextColor3 = caption,
							TextSize = LABEL_TEXT_SIZE,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.new(0, 8, 1, -6),
							Size = UDim2.new(1, -16, 0, 12),
							ZIndex = 65,
						}),
					}),
					Settings = e("Frame", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, 0, 0, 0),
						Size = UDim2.fromOffset(rightWidth, bodyHeight),
						ZIndex = 62,
					}, {
						UIListLayout = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, CARD_GAP),
						}),
						Cards = e(React.Fragment, nil, rightCards),
					}),
				}),
				Footer = e("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, 0),
					Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
					ZIndex = 62,
				}, {
					UIListLayout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, CARD_GAP),
					}),
					Cancel = e(ActionButton, {
						Text = "Cancel",
						Primary = false,
						Enabled = true,
						LayoutOrder = 0,
						Size = UDim2.fromOffset(108, FOOTER_HEIGHT),
						OnClick = onClose,
					}),
					Save = e(ActionButton, {
						Text = mode == "edit" and (isWrap and "Save Wrap" or "Save Charm")
							or (isWrap and "Create Wrap" or "Create Charm"),
						Primary = true,
						Enabled = canSave,
						LayoutOrder = 1,
						Size = UDim2.fromOffset(108, FOOTER_HEIGHT),
						OnClick = onSave,
					}),
				}),
			}),
		}),
	})
end
