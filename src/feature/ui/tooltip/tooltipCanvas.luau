local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local tipMetrics = require("@ui/tooltip/tipMetrics")
local tooltipState = require("@ui/tooltip/tooltipState")
local dpiState = require("@ui/util/dpiState")
local SPRING = require("@ui/util/spring")
local useShadow = require("@ui/hook/useShadow")

local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local e = React.createElement

local colors = themeState.colors.subwindow

local SLIDE_OFFSET = 8
local GAP_FROM_ANCHOR = 8
local EDGE_PAD = 8
local PANEL_PAD_X = 17
local PANEL_PAD_Y = 13
local TITLE_ICON = 12
local TITLE_GAP = 4
local LIST_GAP = 3
local MAX_BODY_WIDTH = tipMetrics.MAX_BODY_WIDTH
local TITLE_TEXT_SIZE = tipMetrics.TITLE_TEXT_SIZE
local BODY_TEXT_SIZE = tipMetrics.BODY_TEXT_SIZE

return function(): React.Element<any>
	local active = useAt(tooltipState.active)
	local info = useAt(tooltipState.info)
	local anchor = useAt(tooltipState.anchor)

	local backgroundColor = useAt(colors.background)
	local strokeColor = useAt(colors.stroke)
	local titleColor = useAt(colors.title)
	local tipIconColor = useAt(colors.tipIcon)
	local textColor = useAt(colors.text)
	local scale = useAt(dpiState.scale)

	local bind, spring = useSpring(0, SPRING.snapPrecise)

	useEffect(function()
		spring:setGoal(active and 1 or 0)
	end, { active })

	local hasTip = info ~= nil and anchor ~= nil

	local visible = bind:map(function(v: number)
		return hasTip and v > 0.01
	end)

	local groupTransparency = bind:map(function(v: number)
		return 1 - v
	end)

	local strokeTransparency = bind:map(function(v: number)
		return 1 - v
	end)

	local title = info and info.title or nil
	local body = info and info.body or ""
	local hasTitle = title ~= nil and title ~= ""

	local bodySize = info and info.bodySize or tipMetrics.estimate(body, BODY_TEXT_SIZE, MAX_BODY_WIDTH)
	local titleSize = info and info.titleSize or tipMetrics.estimate(title or "", TITLE_TEXT_SIZE, MAX_BODY_WIDTH)

	local titleRowWidth = hasTitle and (TITLE_ICON + TITLE_GAP + titleSize.X) or 0
	local panelWidth = math.max(bodySize.X, titleRowWidth) + PANEL_PAD_X
	local titleRowHeight = hasTitle and math.max(TITLE_ICON, titleSize.Y) or 0
	local panelHeight = bodySize.Y + (hasTitle and (titleRowHeight + LIST_GAP) or 0) + PANEL_PAD_Y

	local safeScale = scale > 0 and scale or 1
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local viewWidth = viewport.X / safeScale
	local viewHeight = viewport.Y / safeScale

	local positionX = hasTip and (anchor.position.X + anchor.size.X + GAP_FROM_ANCHOR) or 0
	positionX = math.clamp(positionX, EDGE_PAD, math.max(EDGE_PAD, viewWidth - panelWidth - EDGE_PAD))

	local positionY = hasTip and (anchor.position.Y - 2) or 0
	positionY = math.clamp(positionY, EDGE_PAD, math.max(EDGE_PAD, viewHeight - panelHeight - EDGE_PAD))

	local position = bind:map(function(v: number)
		local offset = (1 - v) * SLIDE_OFFSET
		return UDim2.fromOffset(positionX - offset, positionY)
	end)

	local panelChildren: { [string]: React.Element<any>? } = {
		UIStroke = e("UIStroke", {
			Color = strokeColor,
			Transparency = strokeTransparency,
			Thickness = 1,
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 9),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 7),
		}),
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 3),
		}),
		Body = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = body,
			TextColor3 = textColor,
			TextSize = BODY_TEXT_SIZE,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Size = UDim2.fromOffset(math.ceil(bodySize.X), math.ceil(bodySize.Y)),
			LayoutOrder = 2,
		}),
	}

	if hasTitle then
		panelChildren.Title = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			LayoutOrder = 1,
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			Icon = e("ImageLabel", {
				Image = FileController.Get("image", "light"),
				ImageColor3 = tipIconColor,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(12, 12),
				LayoutOrder = 1,
			}),
			Text = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = FileController.Get("font", "semi_bold"),
				Text = title,
				TextColor3 = titleColor,
				TextSize = TITLE_TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Size = UDim2.fromOffset(math.ceil(titleSize.X), math.ceil(titleSize.Y)),
				LayoutOrder = 2,
			}),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	}, {
		UIScale = e("UIScale", { Scale = scale }),
		Anchor = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Position = position,
			Visible = visible,
			ZIndex = 1,
		}, {
			Shadow = useShadow({
				transparency = groupTransparency,
				zIndex = 0,
			}),
			Body = e("CanvasGroup", {
				BackgroundColor3 = backgroundColor,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				GroupTransparency = groupTransparency,
				ZIndex = 1,
			}, panelChildren),
		}),
	})
end
