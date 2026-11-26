local RunService = cloneref(game:GetService("RunService")) :: RunService

local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local Sift = require("@pkg/Sift")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local notifyState = require("@ui/hud/notify/notifyState")
local dpiState = require("@ui/util/dpiState")
local SPRING = require("@ui/util/spring")
local useShadow = require("@ui/hook/useShadow")

local useAt = ReactCharm.useAtom
local useBinding = React.useBinding
local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useSpring = ReactRipple.useSpring
local peek = Charm.peek
local memo = React.memo
local e = React.createElement

local colors = themeState.colors.notify

local DEFAULT_FONT = Font.fromEnum(Enum.Font.GothamBold)

local function resolveFont(): Font
	return FileController.Get("font", "semi_bold") or DEFAULT_FONT
end

local NOTIF_W = 240
local NOTIF_ZINDEX = 1
local NOTIF_MIN_H = 44
local NOTIF_GAP = 4
local EDGE_PADDING = 10
local SLIDE_OFFSET = 24
local CORNER = 6
local PROGRESS_HEIGHT = 3
local PILL_PAD_X = 12
local PILL_PAD_Y = 8
local ICON_GAP = 10

local ANCHOR_TOP_RIGHT = Vector2.new(1, 0)
local ANCHOR_BOTTOM_LEFT = Vector2.new(0, 1)
local FULL_SIZE = UDim2.fromScale(1, 1)
local SHADOW_MULT = Vector2.new(1.3, 1.5)
local UDIM_ZERO = UDim.new(0, 0)
local UDIM_1 = UDim.new(0, 1)
local UDIM_PAD_X = UDim.new(0, PILL_PAD_X)
local UDIM_PAD_Y = UDim.new(0, PILL_PAD_Y)
local UDIM_ICON_GAP = UDim.new(0, ICON_GAP)
local UDIM_CORNER = UDim.new(0, CORNER)
local PROGRESS_POSITION = UDim2.new(0, 0, 1, 0)
local PROGRESS_SIZE = UDim2.new(1, 0, 0, PROGRESS_HEIGHT)
local ICON_SIZE = UDim2.fromOffset(20, 20)
local TEXT_WRAPPED_SIZE = UDim2.new(1, 0, 0, 0)
local PILL_SIZE = UDim2.new(1, 0, 0, 0)
local OUTER_SIZE = UDim2.fromOffset(NOTIF_W, 0)

local function visToOpaque(v: number): number
	return 1 - v
end

local function progressToSize(p: number): UDim2
	return UDim2.new(math.clamp(p, 0, 1), 0, 1, 0)
end

local NotificationRow = memo(function(props: {
	notification: notifyState.Notification,
	slotY: number?,
}): React.Element<any>
	local n = props.notification

	local bgPack = useAt(colors.background)
	local bgColor = bgPack[1] :: Color3
	local bgAlpha = bgPack[2] :: number

	local trackPack = useAt(colors.backgroundSecondary)
	local trackColor = trackPack[1] :: Color3
	local trackAlpha = trackPack[2] :: number

	local strokePack = useAt(colors.stroke)
	local strokeColor = strokePack[1] :: Color3
	local strokeAlpha = strokePack[2] :: number

	local shadowPack = useAt(colors.shadow)
	local shadowColor = shadowPack[1] :: Color3
	local shadowAlpha = shadowPack[2] :: number

	local imageColor = useAt(colors.image)
	local titleColor = useAt(colors.title)
	local textColor = useAt(colors.text)
	local progressColor = useAt(colors.progress)

	local visible = props.slotY ~= nil
	local lastSlotRef = useRef(props.slotY or EDGE_PADDING)
	if props.slotY ~= nil then
		lastSlotRef.current = props.slotY
	end
	local targetY = lastSlotRef.current

	local outerRef = useRef(nil :: Frame?)

	useEffect(function()
		local frame = outerRef.current
		if not frame then
			return
		end

		local function update(): ()
			local current = peek(notifyState.heights)
			local s = peek(dpiState.scale)
			if s <= 0 then
				s = 1
			end
			local newHeight = frame.AbsoluteSize.Y / s
			if newHeight > 0 and current[n.id] ~= newHeight then
				notifyState.heights(Sift.Dictionary.merge(current, { [n.id] = newHeight }))
			end
		end

		update()
		local conn = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
		return function(): ()
			conn:Disconnect()
		end
	end, {})

	local yBind, ySpring = useSpring(targetY, SPRING.smoothPrecise)
	useEffect(function()
		ySpring:setGoal(targetY)
	end, { targetY })

	local visBind, visSpring = useSpring(0, SPRING.smoothPrecise)
	useEffect(function()
		visSpring:setGoal(visible and 1 or 0)
	end, { visible })

	local progressBind, progressSpring = useSpring(n.progress or 0, SPRING.progress)
	useEffect(function()
		progressSpring:setGoal(n.progress or 0)
	end, { n.progress })

	local timerBind, setTimer = useBinding(0)
	useEffect(function()
		if not n.timer then
			return
		end
		local duration = n.duration
		if not duration or duration <= 0 then
			setTimer(1)
			return
		end
		local startedAt = os.clock()
		local done = false
		local conn = RunService.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function(): ()
			if done then
				return
			end
			local alpha = math.clamp((os.clock() - startedAt) / duration, 0, 1)
			setTimer(alpha)
			if alpha >= 1 then
				done = true
			end
		end))
		return function(): ()
			conn:Disconnect()
		end
	end, {})

	local fillBind = n.timer and timerBind or progressBind

	local position = useMemo(function()
		return React.joinBindings({ yBind, visBind }):map(function(values)
			local y = values[1]
			local v = values[2]
			local slideX = (1 - v) * SLIDE_OFFSET
			return UDim2.new(1, -EDGE_PADDING + slideX, 0, y)
		end)
	end, { yBind, visBind } :: { any })

	local outerVisible = useMemo(function()
		return visBind:map(function(v: number)
			return v > 0.001
		end)
	end, { visBind })

	local groupTransparency = useMemo(function()
		return visBind:map(visToOpaque)
	end, { visBind })

	local pillBgTransparency = useMemo(function()
		return visBind:map(function(v: number)
			return 1 - (1 - bgAlpha) * v
		end)
	end, { visBind, bgAlpha } :: { any })

	local strokeTransparency = useMemo(function()
		return visBind:map(function(v: number)
			return 1 - (1 - strokeAlpha) * v
		end)
	end, { visBind, strokeAlpha } :: { any })

	local trackTransparency = useMemo(function()
		return visBind:map(function(v: number)
			return 1 - (1 - trackAlpha) * v
		end)
	end, { visBind, trackAlpha } :: { any })

	local shadowTransparency = useMemo(function()
		return visBind:map(function(v: number)
			return 1 - (1 - shadowAlpha) * v
		end)
	end, { visBind, shadowAlpha } :: { any })

	local resolvedFont = useMemo(resolveFont, {})

	local resolvedIcon = n.icon and (FileController.Get("image", n.icon)) or nil

	local progressBar: React.Element<any>? = nil
	if n.showProgress then
		progressBar = e("Frame", {
			BackgroundColor3 = trackColor,
			BackgroundTransparency = trackTransparency,
			BorderSizePixel = 0,
			AnchorPoint = ANCHOR_BOTTOM_LEFT,
			Position = PROGRESS_POSITION,
			Size = PROGRESS_SIZE,
			ZIndex = 2,
		}, {
			Fill = e("Frame", {
				BackgroundColor3 = progressColor,
				BackgroundTransparency = groupTransparency,
				BorderSizePixel = 0,
				Size = fillBind:map(progressToSize),
			}),
		})
	end

	local titleEl = e("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = resolvedFont,
		Text = n.title,
		TextColor3 = titleColor,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = TEXT_WRAPPED_SIZE,
		LayoutOrder = 0,
	})

	local subtextEl: React.Element<any>? = nil
	if n.subtext and n.subtext ~= "" then
		subtextEl = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = resolvedFont,
			Text = n.subtext,
			TextColor3 = textColor,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = TEXT_WRAPPED_SIZE,
			LayoutOrder = 1,
		})
	end

	local textChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDIM_1,
		}),
		Title = titleEl,
	}
	if subtextEl then
		textChildren.Subtext = subtextEl
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
		Inner = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 1,
		}, {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDIM_PAD_X,
				PaddingRight = UDIM_PAD_X,
				PaddingTop = UDIM_PAD_Y,
				PaddingBottom = UDIM_PAD_Y,
			}),
			UIListLayout = e("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDIM_ICON_GAP,
			}),
			Icon = resolvedIcon and e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = ICON_SIZE,
				Image = resolvedIcon,
				ImageColor3 = imageColor,
				LayoutOrder = 0,
			}) or nil,
			Text = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
			}, {
				UIFlexItem = e("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Fill,
					ItemLineAlignment = Enum.ItemLineAlignment.Center,
				}),
				Content = e("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				}, textChildren),
			}),
		}),
	}

	if progressBar then
		pillChildren.Progress = progressBar
	end

	return e("Frame", {
		ref = outerRef,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = ANCHOR_TOP_RIGHT,
		Position = position,
		Size = OUTER_SIZE,
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = outerVisible,
		ZIndex = NOTIF_ZINDEX,
	}, {
		Shadow = useShadow({
			color = shadowColor,
			transparency = shadowTransparency,
			multiplier = SHADOW_MULT,
			zIndex = 0,
		}),
		Pill = e("CanvasGroup", {
			BackgroundColor3 = bgColor,
			BackgroundTransparency = pillBgTransparency,
			BorderSizePixel = 0,
			Size = PILL_SIZE,
			AutomaticSize = Enum.AutomaticSize.Y,
			GroupTransparency = groupTransparency,
			ZIndex = 1,
		}, pillChildren),
		UISizeConstraint = e("UISizeConstraint", {
			MinSize = Vector2.new(NOTIF_MIN_H, NOTIF_MIN_H),
		}),
	})
end)

return LPH_NO_VIRTUALIZE(function(): React.Element<any>
	local notifications = useAt(notifyState.notifications)
	local heights = useAt(notifyState.heights)

	local rendered = useMemo(function()
		local children: { [string]: React.Element<any> } = {}
		local cumulativeY = EDGE_PADDING
		for _, n in next, notifications do
			local slotY: number? = nil
			if not n.removing then
				slotY = cumulativeY
				cumulativeY = cumulativeY + (heights[n.id] or NOTIF_MIN_H) + NOTIF_GAP
			end
			children[n.id] = e(NotificationRow, {
				notification = n,
				slotY = slotY,
			})
		end
		return children
	end, { notifications, heights } :: { any })

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = FULL_SIZE,
		ZIndex = NOTIF_ZINDEX,
	}, rendered)
end)
