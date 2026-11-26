local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local elementBindController = require("@ui/bind/elementBindController")
local useAdvColor = require("@ui/hook/useAdvColor")
local useLabelHover = require("@ui/hook/useLabelHover")
local SPRING = require("@ui/util/spring")

local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useState = React.useState
local e = React.createElement

local elColors = themeState.colors.window.element

local CHIP_W = 50
local CHIP_H = 16

export type KeyRendererProperties = {
	Key: any,
	TextRef: { current: TextButton? }?,
	LayoutOrder: number?,
}

return function(properties: KeyRendererProperties): React.Element<any>
	local key = properties.Key
	local textRef = properties.TextRef
	local layoutOrder = properties.LayoutOrder or 2

	local input = useAt(key._state)
	local listening = useAt(key._listening)

	local backgroundColor = useAdvColor(elColors.fieldBackground, elColors.fieldBackgroundActive, key._listening)
	local strokeColor = useAdvColor(elColors.fieldStroke, elColors.fieldStrokeActive, key._listening)

	local activeText = useAt(elColors.textActive)
	local boundText = useAt(elColors.text)
	local emptyText = useAt(elColors.caption)

	local isHovered, setHovered = useState(false)
	local listenBind, listenSpring = useSpring(listening and 1 or 0, SPRING.snap)
	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)

	useEffect(function()
		listenSpring:setGoal(listening and 1 or 0)
	end, { listening })

	useEffect(function()
		hoverSpring:setGoal(isHovered and 1 or 0)
	end, { isHovered })

	useEffect(function()
		if not listening then
			return
		end

		local conn = UserInputService.InputBegan:Connect(function(rawInput: InputObject): ()
			if rawInput.UserInputType == Enum.UserInputType.Keyboard then
				if rawInput.KeyCode == Enum.KeyCode.Escape or rawInput.KeyCode == Enum.KeyCode.Backspace then
					key._state(nil)
					key:SetListening(false)
					return
				end
				key._state(rawInput.KeyCode)
				key:SetListening(false)
			elseif
				rawInput.UserInputType == Enum.UserInputType.MouseButton1
				or rawInput.UserInputType == Enum.UserInputType.MouseButton2
				or rawInput.UserInputType == Enum.UserInputType.MouseButton3
			then
				key._state(rawInput.UserInputType)
				key:SetListening(false)
			end
		end)

		return function()
			conn:Disconnect()
		end
	end, { listening })

	local hasInput = typeof(input) == "EnumItem"
	local label = listening and "..." or not hasInput and "—" or elementBindController.GetInputLabel(input)
	local restText: Color3 = hasInput and boundText or emptyText

	local textColorBinding = useMemo(function()
		return listenBind:map(function(v: number)
			return restText:Lerp(activeText, v)
		end)
	end, { listenBind, restText, activeText } :: { any })

	local toggleListening = useCallback(function(): ()
		key:SetListening(not listening)
	end, { listening } :: { any })

	local hoverColors = useMemo(function()
		return { backgroundColor, strokeColor }
	end, { backgroundColor, strokeColor } :: { any })

	local hoverOptions = useMemo(function()
		return { onClick = toggleListening }
	end, { toggleListening } :: { any })

	useLabelHover(textRef, hoverColors, hoverOptions)

	local onMouseEnter = useMemo(function()
		return function()
			setHovered(true)
			backgroundColor.onMouseEnter()
			strokeColor.onMouseEnter()
		end
	end, { backgroundColor, strokeColor } :: { any })

	local onMouseLeave = useMemo(function()
		return function()
			setHovered(false)
			backgroundColor.onMouseLeave()
			strokeColor.onMouseLeave()
		end
	end, { backgroundColor, strokeColor } :: { any })

	local strokeThickness = useMemo(function()
		return hoverBind:map(function(v: number)
			return 1 + v * 0.75
		end)
	end, { hoverBind } :: { any })

	return e("TextButton", {
		BackgroundColor3 = backgroundColor.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(CHIP_W, CHIP_H),
		Text = label,
		TextSize = 11,
		TextColor3 = textColorBinding,
		FontFace = FileController.Get("font", "semi_bold"),
		AutoButtonColor = false,
		Active = false,
		LayoutOrder = layoutOrder,
		[React.Event.MouseEnter] = onMouseEnter,
		[React.Event.MouseLeave] = onMouseLeave,
		[React.Event.MouseButton1Click] = toggleListening,
		[React.Event.MouseButton2Click] = function()
			key:SetListening(false)
			key._state(nil)
		end,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = e("UIStroke", {
			Color = strokeColor.binding,
			Thickness = strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end
