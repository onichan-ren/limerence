local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local useLabelHover = require("@ui/hook/useLabelHover")
local useClickOutside = require("@ui/hook/useClickOutside")

local useRef = React.useRef
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useAt = ReactCharm.useAtom
local e = React.createElement

local colors = themeState.colors.window.element

export type TextboxRendererProperties = {
	Textbox: any,
	TextRef: { current: TextButton? }?,
	LayoutOrder: number?,
}

return function(properties: TextboxRendererProperties): React.Element<any>
	local textbox = properties.Textbox
	local textRef = properties.TextRef
	local layoutOrder = properties.LayoutOrder or 2

	local value = useAt(textbox._state) or ""
	local placeholder = useAt(textbox._placeholder)

	local textboxRef = useRef(nil :: TextBox?)
	local boxRef = useRef(nil :: GuiObject?)
	local isFocused = useAt(textbox._focused)

	local boxColor = useAdvColor(colors.panel, colors.surface, textbox._focused)
	local strokeColor = useAdvColor(colors.panelStroke, colors.accentStrong, textbox._focused)
	local textColor = useAdvColor(colors.caption, colors.text, textbox._active)
	local placeholderColor = useAt(colors.caption)

	local textboxObj = useRef(textbox)
	textboxObj.current = textbox

	local boxEnter = useMemo(function()
		return function()
			boxColor.onMouseEnter()
			strokeColor.onMouseEnter()
			textColor.onMouseEnter()
		end
	end, { boxColor, strokeColor, textColor } :: { any })

	local boxLeave = useMemo(function()
		return function()
			boxColor.onMouseLeave()
			strokeColor.onMouseLeave()
			textColor.onMouseLeave()
		end
	end, { boxColor, strokeColor, textColor } :: { any })

	local boxClick = useCallback(function()
		if textboxRef.current then
			textboxRef.current:CaptureFocus()
		end
	end, {})

	local clickOutsideHandler = useCallback(function()
		if textboxRef.current then
			textboxRef.current:ReleaseFocus()
		end
	end, {})

	local labelHoverColors = useMemo(function()
		return { boxColor, strokeColor, textColor }
	end, { boxColor, strokeColor, textColor } :: { any })

	local labelHoverOptions = useMemo(function()
		return {
			onClick = function()
				if textboxRef.current then
					textboxRef.current:CaptureFocus()
				end
			end,
		}
	end, {})

	useEffect(function()
		local box = textboxRef.current
		if not box then
			return
		end

		local connections = {
			box.Focused:Connect(function()
				textboxObj.current._focused(true)
			end),
			box.FocusLost:Connect(function()
				textboxObj.current._focused(false)
			end),
			box:GetPropertyChangedSignal("Text"):Connect(function()
				local raw = box.Text
				if textboxObj.current._numeric then
					local cleaned = string.gsub(raw, "[^%d]", "")
					if cleaned ~= raw then
						box.Text = cleaned
						return
					end
				end
				textboxObj.current._state(raw)
			end),
		}

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, {})

	useClickOutside(boxRef, isFocused, clickOutsideHandler)
	useLabelHover(textRef, labelHoverColors, labelHoverOptions)

	return e("TextButton", {
		ref = boxRef,
		Size = UDim2.new(0, 114, 0, 16),
		BackgroundColor3 = boxColor.binding,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		AutoButtonColor = false,
		Text = "",
		Active = false,
		ClipsDescendants = true,
		[React.Event.MouseEnter] = boxEnter,
		[React.Event.MouseLeave] = boxLeave,
		[React.Event.MouseButton1Click] = boxClick,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		Input = e("TextBox", {
			ref = textboxRef,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ClearTextOnFocus = false,
			Text = value,
			PlaceholderText = placeholder,
			PlaceholderColor3 = placeholderColor,
			TextColor3 = textColor.binding,
			FontFace = FileController.Get("font", "semi_bold"),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextEditable = true,
			MultiLine = false,
			TextWrapped = false,
			Interactable = true,
		}),
	})
end
