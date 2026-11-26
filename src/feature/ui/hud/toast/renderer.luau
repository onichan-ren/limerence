local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local toastState = require("@ui/hud/toast/toastState")
local SPRING = require("@ui/util/spring")

local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useSpring = ReactRipple.useSpring
local memo = React.memo
local e = React.createElement

local colors = themeState.colors.toast

local DEFAULT_FONT = Font.fromEnum(Enum.Font.GothamMedium)

local function resolveFont(): Font
	return FileController.Get("font", "semi_bold") or DEFAULT_FONT
end

local function colorToHex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local HEIGHT = 26
local HEIGHT_UNDERLINE = 32
local GAP = 6
local EDGE_PADDING = 10
local SLIDE_OFFSET = 24
local CORNER = 6

local SHADOW_MARGIN_X = 18
local SHADOW_MARGIN_Y = 10

local FULL_SIZE = UDim2.fromScale(1, 1)
local UDIM_CORNER = UDim.new(0, CORNER)
local PILL_SIZE = UDim2.fromOffset(0, HEIGHT)
local PILL_SIZE_UNDERLINE = UDim2.fromOffset(0, HEIGHT_UNDERLINE)
local OUTER_SIZE = UDim2.fromOffset(0, HEIGHT + SHADOW_MARGIN_Y * 2)
local OUTER_SIZE_UNDERLINE = UDim2.fromOffset(0, HEIGHT_UNDERLINE + SHADOW_MARGIN_Y * 2)
local SHADOW_PAD_X = UDim.new(0, SHADOW_MARGIN_X)
local SHADOW_PAD_Y = UDim.new(0, SHADOW_MARGIN_Y)
local SHADOW_CORNER = UDim.new(0, 4)
local ACCENT_SIZE = UDim2.new(0, 4, 1, 0)
local ACCENT_SIZE_H = UDim2.new(1, 10, 0, 4)
local ACCENT_POS_BOTTOM = UDim2.new(0.5, 0, 1, 7)
local ANCHOR_BOTTOM_CENTER = Vector2.new(0.5, 1)
local ACCENT_CORNER = UDim.new(1, 0)
local PAD_3 = UDim.new(0, 3)
local PAD_4 = UDim.new(0, 4)
local PAD_10 = UDim.new(0, 10)
local PAD_11 = UDim.new(0, 11)
local TEXT_SIZE = UDim2.fromOffset(0, HEIGHT - 8)

local ICON_WIDTH = 34
local ICON_HEIGHT = 18

type AccentSide = "left" | "right" | "bottom"

type ModeConfig = {
	anchor: Vector2,
	xScale: number,
	xOffset: number,
	yScale: number,
	yBase: number,
	ySign: number,
	slideX: number,
	slideY: number,
	bottom: boolean,
	accent: AccentSide,
}

local MODES: { [string]: ModeConfig } = {
	top_left = {
		anchor = Vector2.new(0, 0),
		xScale = 0,
		xOffset = EDGE_PADDING - SHADOW_MARGIN_X,
		yScale = 0,
		yBase = EDGE_PADDING - SHADOW_MARGIN_Y,
		ySign = 1,
		slideX = -1,
		slideY = 0,
		bottom = false,
		accent = "left",
	},
	top_right = {
		anchor = Vector2.new(1, 0),
		xScale = 1,
		xOffset = SHADOW_MARGIN_X - EDGE_PADDING,
		yScale = 0,
		yBase = EDGE_PADDING - SHADOW_MARGIN_Y,
		ySign = 1,
		slideX = 1,
		slideY = 0,
		bottom = false,
		accent = "right",
	},
	bottom_center = {
		anchor = Vector2.new(0.5, 1),
		xScale = 0.5,
		xOffset = 0,
		yScale = 1,
		yBase = SHADOW_MARGIN_Y - EDGE_PADDING,
		ySign = -1,
		slideX = 0,
		slideY = 1,
		bottom = true,
		accent = "bottom",
	},
}

local ToastIcon = memo(function(props: {
	icon: toastState.ToastIcon,
	visible: boolean,
	order: number,
	tint: Color3,
}): React.Element<any>
	local icon = props.icon
	local shown = props.visible and not icon.removing

	local widthBind, widthSpring = useSpring(0, SPRING.smoothPrecise)
	useEffect(function()
		widthSpring:setGoal((shown and ICON_WIDTH) or 0)
	end, { shown })

	local size = useMemo(function()
		return widthBind:map(function(width: number): UDim2
			return UDim2.new(0, math.max(width, 0), 0, ICON_HEIGHT)
		end)
	end, { widthBind })

	local image = icon.image
	if string.find(image, "://", 1, true) == nil then
		image = FileController.Get("image", image)
	end

	return e("ImageLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = image,
		ImageColor3 = props.tint,
		LayoutOrder = props.order,
		ScaleType = Enum.ScaleType.Fit,
		Size = size,
	})
end)

local ToastRow = memo(function(props: {
	toast: toastState.Toast,
	slot: number?,
	mode: toastState.ToastPosition,
}): React.Element<any>
	local t = props.toast
	local cfg = MODES[props.mode] or MODES.top_left

	local accentSide = cfg.accent
	local accentVertical = accentSide == "left" or accentSide == "right"
	local rowHeight = accentVertical and HEIGHT or HEIGHT_UNDERLINE
	local pillSize = accentVertical and PILL_SIZE or PILL_SIZE_UNDERLINE
	local outerSize = accentVertical and OUTER_SIZE or OUTER_SIZE_UNDERLINE

	local bgPack = useAt(colors.background)
	local bgColor = bgPack[1] :: Color3
	local bgAlpha = bgPack[2] :: number

	local strokePack = useAt(colors.stroke)
	local strokeColor = strokePack[1] :: Color3
	local strokeAlpha = strokePack[2] :: number

	local shadowPack = useAt(colors.shadow)
	local shadowColor = shadowPack[1] :: Color3
	local shadowAlpha = shadowPack[2] :: number

	local textColor = useAt(colors.text)
	local themeAccent = useAt(colors.accent)
	local accent = t.accent or themeAccent
	local highlightColor = useAt(colors.highlight)

	local displayText = useMemo(function(): string
		local hex = colorToHex(highlightColor)
		return (t.text:gsub("<hl>", '<font color="' .. hex .. '">'):gsub("</hl>", "</font>"))
	end, { t.text, highlightColor } :: { any })

	local visible = props.slot ~= nil
	local lastSlotRef = useRef(props.slot or 0)
	if props.slot ~= nil then
		lastSlotRef.current = props.slot
	end
	local targetOffset = lastSlotRef.current * (rowHeight + GAP)

	local yBind, ySpring = useSpring(targetOffset, SPRING.smoothPrecise)
	useEffect(function()
		ySpring:setGoal(targetOffset)
	end, { targetOffset })

	local visBind, visSpring = useSpring(0, SPRING.smoothPrecise)
	useEffect(function()
		visSpring:setGoal(visible and 1 or 0)
	end, { visible })

	local position = useMemo(function()
		return React.joinBindings({ yBind, visBind }):map(function(values)
			local offset = values[1]
			local v = values[2]
			local slide = (1 - v) * SLIDE_OFFSET
			local x = cfg.xOffset + cfg.slideX * slide
			local y = cfg.yBase + cfg.ySign * offset + cfg.slideY * slide
			return UDim2.new(cfg.xScale, x, cfg.yScale, y)
		end)
	end, { yBind, visBind, cfg } :: { any })

	local outerVisible = useMemo(function()
		return visBind:map(function(v: number): boolean
			return v > 0.001
		end)
	end, { visBind })
	local groupTransparency = useMemo(function()
		return visBind:map(function(v: number): number
			return 1 - v
		end)
	end, { visBind })
	local pillBgTransparency = useMemo(function()
		return visBind:map(function(v: number): number
			return 1 - (1 - bgAlpha) * v
		end)
	end, { visBind, bgAlpha } :: { any })
	local strokeTransparency = useMemo(function()
		return visBind:map(function(v: number): number
			return 1 - (1 - strokeAlpha) * v
		end)
	end, { visBind, strokeAlpha } :: { any })
	local shadowTransparency = useMemo(function()
		return visBind:map(function(v: number): number
			return 1 - (1 - shadowAlpha) * v
		end)
	end, { visBind, shadowAlpha } :: { any })

	local resolvedFont = useMemo(resolveFont, {})

	local accentElement
	if accentVertical then
		accentElement = e("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Size = ACCENT_SIZE,
			LayoutOrder = accentSide == "left" and 0 or 1000,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = ACCENT_CORNER,
			}),
		})
	else
		accentElement = e("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			AnchorPoint = ANCHOR_BOTTOM_CENTER,
			Position = ACCENT_POS_BOTTOM,
			Size = ACCENT_SIZE_H,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = ACCENT_CORNER,
			}),
		})
	end

	local paddingLeft = PAD_11
	local paddingRight = PAD_11
	local paddingBottom = PAD_4
	if accentSide == "left" then
		paddingLeft = PAD_3
	elseif accentSide == "right" then
		paddingRight = PAD_3
	else
		paddingBottom = PAD_10
	end

	local pillChildren: { [string]: any } = {
		UICorner = e("UICorner", {
			CornerRadius = UDIM_CORNER,
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor,
			Transparency = strokeTransparency,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = paddingLeft,
			PaddingRight = paddingRight,
			PaddingTop = PAD_4,
			PaddingBottom = paddingBottom,
		}),
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Accent = accentVertical and accentElement or nil,
		Text = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = resolvedFont,
			Text = displayText,
			TextColor3 = textColor,
			TextSize = 14,
			RichText = true,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 1,
		}, not accentVertical and { Accent = accentElement } or nil),
	}

	local icons = t.icons
	if icons then
		for index = 1, #icons do
			local icon = icons[index]
			pillChildren["icon_" .. icon.key] = e(ToastIcon, {
				icon = icon,
				visible = visible,
				order = 1 + index,
				tint = highlightColor,
			})
		end
	end

	return e("ImageLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = cfg.anchor,
		Position = position,
		Size = outerSize,
		AutomaticSize = Enum.AutomaticSize.X,
		Image = FileController.Get("image", "shadow"),
		ImageColor3 = shadowColor,
		ImageTransparency = shadowTransparency,
		ScaleType = Enum.ScaleType.Stretch,
		Visible = outerVisible,
		ZIndex = 1,
	}, {
		ShadowCorner = e("UICorner", {
			CornerRadius = SHADOW_CORNER,
		}),
		ShadowPadding = e("UIPadding", {
			PaddingLeft = SHADOW_PAD_X,
			PaddingRight = SHADOW_PAD_X,
			PaddingTop = SHADOW_PAD_Y,
			PaddingBottom = SHADOW_PAD_Y,
		}),
		Pill = e("CanvasGroup", {
			BackgroundColor3 = bgColor,
			BackgroundTransparency = pillBgTransparency,
			BorderSizePixel = 0,
			Size = pillSize,
			AutomaticSize = Enum.AutomaticSize.X,
			GroupTransparency = groupTransparency,
			ZIndex = 1,
		}, pillChildren),
	})
end)

return LPH_NO_VIRTUALIZE(function(): React.Element<any>
	local toasts = useAt(toastState.toasts)
	local mode = useAt(toastState.position)

	local rendered = useMemo(function()
		local cfg = MODES[mode] or MODES.top_left
		local active = 0
		for _, t in next, toasts do
			if not t.removing then
				active += 1
			end
		end

		local children: { [string]: React.Element<any> } = {}
		local index = 0
		for _, t in next, toasts do
			local slot: number? = nil
			if not t.removing then
				slot = index
				if cfg.bottom then
					slot = active - 1 - index
				end
				index += 1
			end
			children[t.id] = e(ToastRow, {
				toast = t,
				slot = slot,
				mode = mode,
			})
		end
		return children
	end, { toasts, mode } :: { any })

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = FULL_SIZE,
		ZIndex = 1,
	}, rendered)
end)
