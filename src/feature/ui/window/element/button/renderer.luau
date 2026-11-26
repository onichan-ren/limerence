local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local Sift = require("@pkg/Sift")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local SPRING = require("@ui/util/spring")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useRef = React.useRef
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local e = React.createElement

local CLICK_FLASH_DURATION = 0.06

local colors = themeState.colors.window.element

local BUTTON_HEIGHT = 24
local ICON_SIZE = 12
local PADDING_X = 8
local CORNER_RADIUS = 5

export type ButtonRendererProperties = {
	Button: any,
	LayoutOrder: number?,
	Solo: boolean?,
}

type SingleButtonProps = {
	Button: any,
	LayoutOrder: number,
}

local function SingleButton(props: SingleButtonProps): React.Element<any>
	local button = props.Button

	local text = useAt(button._text)
	local icon = useAt(button._icon)
	local armed = useAt(button._armed)
	local confirmText = useAt(button._confirmText)
	local hasIcon = icon ~= nil and icon ~= ""
	local displayText = armed and confirmText or text

	local pressed, setPressed = useState(false)
	local flashed, setFlashed = useState(false)
	local flashTimerRef = useRef(nil :: thread?)

	local active = useAt(button._active)
	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		activeAtom(active or armed or pressed or flashed)
	end, { active, armed, pressed, flashed } :: { any })

	local backgroundColor = useAdvColor(colors.surface, colors.accentStrong, activeAtom, true)
	local baseStrokeColor = useAt(colors.surfaceStroke)
	local accentColor = useAt(colors.accentStrong)
	local textColor = useAdvColor(colors.text, colors.textActive, activeAtom)
	local iconColor = useAdvColor(colors.icon, colors.iconActive, activeAtom)

	local highlightActive = pressed or flashed
	local highlightBind, highlightSpring = useSpring(0, SPRING.smooth)

	useEffect(function()
		highlightSpring:setGoal(highlightActive and 1 or 0)
	end, { highlightActive })

	useEffect(function()
		return function()
			local timer = flashTimerRef.current
			if timer then
				task.cancel(timer)
				flashTimerRef.current = nil
			end
		end
	end, {})

	local triggerFlash = useCallback(function(): ()
		local existing = flashTimerRef.current
		if existing then
			task.cancel(existing)
		end
		setFlashed(true)
		flashTimerRef.current = task.delay(CLICK_FLASH_DURATION, function()
			flashTimerRef.current = nil
			setFlashed(false)
		end)
	end, {})

	local strokeColorBind = useMemo(function()
		return highlightBind:map(function(value: number)
			return baseStrokeColor:Lerp(accentColor, value)
		end)
	end, { highlightBind, baseStrokeColor, accentColor } :: { any })

	local buttonRef = useRef(button)
	buttonRef.current = button

	local onMouseEnter = useMemo(function()
		return function()
			backgroundColor.onMouseEnter()
			textColor.onMouseEnter()
			iconColor.onMouseEnter()
		end
	end, { backgroundColor, textColor, iconColor } :: { any })

	local onMouseLeave = useMemo(function()
		return function()
			setPressed(false)
			backgroundColor.onMouseLeave()
			textColor.onMouseLeave()
			iconColor.onMouseLeave()
		end
	end, { backgroundColor, textColor, iconColor } :: { any })

	local onPressDown = useCallback(function()
		setPressed(true)
	end, {})

	local onPressUp = useCallback(function()
		setPressed(false)
	end, {})

	local onClick = useCallback(function()
		triggerFlash()
		buttonRef.current:Click()
	end, { triggerFlash } :: { any })

	local children: { [string]: React.Element<any> } = {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, CORNER_RADIUS),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColorBind,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, PADDING_X),
			PaddingRight = UDim.new(0, PADDING_X),
		}),
		UIFlexItem = e("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Fill,
			ItemLineAlignment = Enum.ItemLineAlignment.Stretch,
		}),
		Content = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, ICON_SIZE),
			AutomaticSize = Enum.AutomaticSize.X,
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Icon = hasIcon and e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = icon,
				ImageColor3 = iconColor.binding,
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				LayoutOrder = 0,
			}) or nil,
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = FileController.Get("font", "semi_bold"),
				TextColor3 = textColor.binding,
				TextSize = 12,
				Text = displayText,
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 1,
			}),
		}),
	}

	return e("TextButton", {
		BackgroundColor3 = backgroundColor.binding,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.new(0, 0, 0, BUTTON_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = onMouseEnter,
		[React.Event.MouseLeave] = onMouseLeave,
		[React.Event.MouseButton1Down] = onPressDown,
		[React.Event.MouseButton1Up] = onPressUp,
		[React.Event.MouseButton1Click] = onClick,
	}, children)
end

local function rowRenderer(properties: ButtonRendererProperties): React.Element<any>
	local button = properties.Button
	local layoutOrder = properties.LayoutOrder or 1

	local extras = useAt(button._extras)

	local renderedExtras = useMemo(function()
		local rendered: { [string]: React.Element<any> } = {}
		for index, extra in extras do
			rendered[`Extra_{index}`] = e(SingleButton, {
				Button = extra,
				LayoutOrder = index,
			})
		end
		return rendered
	end, { extras })

	local primary = e(SingleButton, {
		Button = button,
		LayoutOrder = 0,
	})

	return e(
		"Frame",
		{
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
			LayoutOrder = layoutOrder,
		},
		Sift.Dictionary.join({
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Primary = primary,
		}, renderedExtras)
	)
end

return {
	row = rowRenderer,
	single = SingleButton,
}
