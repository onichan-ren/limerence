local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local Charm = require("@pkg/Charm")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local cursor = require("@ui/util/cursor")
local useContext = require("@ui/hook/useContext")
local colorClipboard = require("@ui/util/colorClipboard")
local SPRING = require("@ui/util/spring")
local inputHandler = require("@ui/util/inputHandler")

local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local useState = React.useState
local useRef = React.useRef
local useAt = ReactCharm.useAtom
local useMemo = React.useMemo
local peek = Charm.peek
local e = React.createElement

local EMPTY_DISPLAY_SELECTION = Charm.atom("base")

local function toSequence(color: any): ColorSequence?
	if color == nil then
		return nil
	end
	if typeof(color) == "ColorSequence" then
		return color
	end
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(1, color),
	})
end

export type ColorpickerRendererProps = {
	Colorpicker: any,
	TextRef: { current: TextButton? }?,
	LayoutOrder: number?,
}

return function(properties: ColorpickerRendererProps): React.Element<any>
	local colorpicker = properties.Colorpicker
	useAt(colorpicker._displaySelection or EMPTY_DISPLAY_SELECTION)
	if colorpicker._displayResolver then
		colorpicker = colorpicker._displayResolver()
	end
	local layoutOrder = properties.LayoutOrder or 1

	local isHovered, setHovered = useState(false)
	local color = useAt(colorpicker._state, { colorpicker })
	local clipColor = useAt(colorClipboard.color)
	local clipTrans = useAt(colorClipboard.transparency)

	local previewColor, setPreviewColor = useState(nil :: any)

	local convertedColor = useMemo(function()
		return toSequence(color) :: ColorSequence
	end, { color })

	local previewConverted = useMemo(function()
		return toSequence(previewColor)
	end, { previewColor })

	local hoverBind, hoverSpring = useSpring(0, {
		tension = 750,
		friction = 55,
	})

	local previewBind, previewSpring = useSpring(0, SPRING.subtle)

	useEffect(function()
		hoverSpring:setGoal(isHovered and 1 or 0)
	end, { isHovered })

	useEffect(function()
		previewSpring:setGoal(previewColor and 1 or 0)
	end, { previewColor })

	local buttonRef = useRef(nil :: TextButton?)

	useEffect(function()
		local btn = buttonRef.current
		if btn then
			btn:SetAttribute("ConsumesRightClick", true)
		end
	end, {})

	local onContext = useContext(function()
		local canPasteColor = clipColor
			and (typeof(clipColor) == "ColorSequence") == colorpicker._isSequence

		local items: { any } = {
			{
				Label = "Copy color",
				Callback = function()
					local current = peek(colorpicker._state)
					local trans: number? = nil
					if colorpicker._supportsTransparency then
						trans = peek(colorpicker._transparency)
					end
					colorClipboard.set(current, trans)
				end,
			},
		}
		if canPasteColor then
			table.insert(items, {
				Label = "Paste color",
				Callback = function()
					colorpicker._state(clipColor)
					if colorpicker._supportsTransparency and clipTrans ~= nil then
						colorpicker._transparency(clipTrans)
					end
				end,
				OnHoverEnter = function()
					setPreviewColor(clipColor)
				end,
				OnHoverLeave = function()
					setPreviewColor(nil)
				end,
				HoverDelay = 0.4,
			})
		end
		return items
	end, colorpicker)

	return e("TextButton", {
		ref = buttonRef,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(12, 12),
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
		[React.Event.MouseButton1Click] = function()
			SubwindowController.OpenColorpicker(colorpicker, cursor.getPosition())
		end,
		[React.Event.InputBegan] = inputHandler(onContext),
		Text = "",
		Active = false,
		AutoButtonColor = false,
		LayoutOrder = layoutOrder,
	}, {
		UIGradient = e("UIGradient", {
			Color = convertedColor,
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIStroke = e("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = 0.5,
			Thickness = hoverBind:map(function(value: number)
				return 1.05 + value
			end),
		}, {
			UIGradient = e("UIGradient", {
				Color = convertedColor,
			}),
		}),
		Preview = previewConverted and e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = previewBind:map(function(v: number)
				return 1 - v
			end),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 3),
			}),
			UIGradient = e("UIGradient", {
				Color = previewConverted,
			}),
			UIStroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255),
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Transparency = previewBind:map(function(v: number)
					return 1 - v * 0.5
				end),
				Thickness = hoverBind:map(function(value: number)
					return 1.05 + value
				end),
			}, {
				UIGradient = e("UIGradient", {
					Color = previewConverted,
				}),
			}),
		}) or nil,
	})
end
