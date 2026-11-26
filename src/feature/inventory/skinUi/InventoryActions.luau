local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local SPRING = require("@ui/util/spring")
local layout = require("@feature/inventory/skinUi/layout")

local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useRef = React.useRef
local useSpring = ReactRipple.useSpring
local e = React.createElement

local CLICK_FLASH_DURATION = 0.06

local elementColors = themeState.colors.window.element

local BUTTON_HEIGHT = layout.BUTTON_HEIGHT
local BUTTON_PAD_X = 8
local GAP = layout.ELEMENT_GAP
local SEARCH_ROW_OFFSET_Y = 5

export type ActionSpec = {
	Label: string,
	Width: number,
	OnClick: () -> (),
}

export type InventoryActionsProps = {
	Buttons: { ActionSpec },
}

type ActionButtonProps = {
	Label: string,
	Width: number,
	LayoutOrder: number,
	OnClick: () -> (),
}

local function ActionButton(props: ActionButtonProps): React.Element<any>
	local hoveredRef = useRef(false)
	local pressedRef = useRef(false)
	local flashedRef = useRef(false)
	local flashTimerRef = useRef(nil :: thread?)

	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		return function()
			local timer = flashTimerRef.current
			if timer then
				task.cancel(timer)
				flashTimerRef.current = nil
			end
		end
	end, {})

	local bgColor = useAdvColor(elementColors.surface, elementColors.fieldBackgroundActive, activeAtom, true)
	local textColor = useAdvColor(elementColors.caption, elementColors.textActive, activeAtom)
	local strokeColor = useAdvColor(elementColors.surfaceStroke, elementColors.fieldStrokeActive, activeAtom)
	local accentColor = useAdvColor(elementColors.fieldStrokeActive, elementColors.accentStrong, activeAtom)

	local highlightBind, highlightSpring = useSpring(0, SPRING.smoothPrecise)

	local syncVisual = useCallback(function(): ()
		activeAtom(hoveredRef.current or pressedRef.current or flashedRef.current)
		highlightSpring:setGoal((pressedRef.current or flashedRef.current) and 1 or 0)
	end, {})

	local triggerFlash = useCallback(function(): ()
		local existing = flashTimerRef.current
		if existing then
			task.cancel(existing)
		end
		flashedRef.current = true
		syncVisual()
		flashTimerRef.current = task.delay(CLICK_FLASH_DURATION, function()
			flashTimerRef.current = nil
			flashedRef.current = false
			syncVisual()
		end)
	end, { syncVisual } :: { any })

	local strokeColorBind = useMemo(function()
		return React.joinBindings({
			strokeColor.binding,
			accentColor.binding,
			highlightBind,
		}):map(function(values: { any })
			local base: Color3 = values[1]
			local accent: Color3 = values[2]
			local alpha: number = values[3]
			return base:Lerp(accent, alpha)
		end)
	end, { strokeColor, accentColor, highlightBind } :: { any })

	local onEnter = useCallback(function()
		hoveredRef.current = true
		syncVisual()
		bgColor.onMouseEnter()
		textColor.onMouseEnter()
		strokeColor.onMouseEnter()
	end, { bgColor, textColor, strokeColor, syncVisual } :: { any })

	local onLeave = useCallback(function()
		hoveredRef.current = false
		pressedRef.current = false
		syncVisual()
		bgColor.onMouseLeave()
		textColor.onMouseLeave()
		strokeColor.onMouseLeave()
	end, { bgColor, textColor, strokeColor, syncVisual } :: { any })

	local onPressDown = useCallback(function()
		pressedRef.current = true
		syncVisual()
	end, { syncVisual } :: { any })

	local onPressUp = useCallback(function()
		pressedRef.current = false
		syncVisual()
	end, { syncVisual } :: { any })

	local onClick = useCallback(function()
		triggerFlash()
		props.OnClick()
	end, { props.OnClick, triggerFlash } :: { any })

	return e("TextButton", {
		BackgroundColor3 = bgColor.binding,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Active = false,
		Size = UDim2.fromOffset(props.Width, BUTTON_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = onEnter,
		[React.Event.MouseLeave] = onLeave,
		[React.Event.MouseButton1Down] = onPressDown,
		[React.Event.MouseButton1Up] = onPressUp,
		[React.Event.MouseButton1Click] = onClick,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 5),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColorBind,
			Transparency = 0.2,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = props.Label,
			TextColor3 = textColor.binding,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Position = UDim2.fromOffset(BUTTON_PAD_X, 0),
			Size = UDim2.new(1, -BUTTON_PAD_X * 2, 1, -1),
		}),
	})
end

return function(props: InventoryActionsProps): React.Element<any>
	local buttons = props.Buttons

	local totalWidth = 0
	for i = 1, #buttons do
		totalWidth += buttons[i].Width
	end
	if #buttons > 1 then
		totalWidth += GAP * (#buttons - 1)
	end

	local children: { [string]: React.Element<any> } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),
	}

	for i = 1, #buttons do
		local spec = buttons[i]
		children[`Button_{spec.Label}`] = e(ActionButton, {
			Label = spec.Label,
			Width = spec.Width,
			LayoutOrder = i - 1,
			OnClick = spec.OnClick,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, SEARCH_ROW_OFFSET_Y),
		Size = UDim2.fromOffset(totalWidth, BUTTON_HEIGHT),
		ZIndex = 4,
	}, children)
end
