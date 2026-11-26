local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local themeState = require("@ui/theme/themeState")
local FileController = require("@feature/file/FileController")
local ScopeController = require("@ui/scope/ScopeController")
local scopeState = require("@ui/scope/scopeState")
local useSubwindowAnimation = require("@ui/hook/useSubwindowAnimation")
local SPRING = require("@ui/util/spring")

local useSpring = ReactRipple.useSpring
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useState = React.useState
local useAt = ReactCharm.useAtom
local e = React.createElement
local memo = React.memo

local colors = themeState.colors.subwindow
local elementColors = themeState.colors.window.element

local ROW_HEIGHT = 24
local GROUP_HEIGHT = 22
local MENU_PAD_X = 6
local MENU_PAD_Y = 6
local MENU_WIDTH = 188
local MENU_MAX_HEIGHT = 210
local ROOT_GROUP_KEY = "__root__"

local GroupLabel = memo(function(props: { Label: string, LayoutOrder: number }): React.Element<any>
	local muted = useAt(elementColors.caption)
	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, GROUP_HEIGHT),
		LayoutOrder = props.LayoutOrder,
	}, {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 2),
		}),
		Text = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Text = string.upper(props.Label),
			TextColor3 = muted,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			FontFace = FileController.Get("font", "semi_bold"),
		}),
	})
end)

local ScopeRow = memo(function(props: {
	Label: string,
	ScopeId: string,
	IsActive: boolean,
	OnSelect: (id: string) -> (),
	LayoutOrder: number,
}): React.Element<any>
	local isHovering, setHovering = useState(false)
	local textColor = useAt(colors.text)
	local activeText = useAt(colors.title)
	local accentColor = useAt(elementColors.thumbActive)
	local rowHoverColor = useAt(elementColors.rowHover)

	local hoverBind, hoverSpring = useSpring(0, SPRING.snap)
	local activeBind, activeSpring = useSpring(0, SPRING.smooth)

	useEffect(function()
		hoverSpring:setGoal(isHovering and 1 or 0)
	end, { isHovering })

	useEffect(function()
		activeSpring:setGoal(props.IsActive and 1 or 0)
	end, { props.IsActive })

	return e("TextButton", {
		BackgroundColor3 = rowHoverColor,
		BackgroundTransparency = React.joinBindings({ hoverBind, activeBind }):map(function(values: { number })
			local hover = values[1]
			local active = values[2]
			return 1 - (hover * 0.04 + active * 0.035)
		end),
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
		[React.Event.MouseButton1Click] = function()
			props.OnSelect(props.ScopeId)
		end,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		ActiveBar = e("Frame", {
			BackgroundColor3 = accentColor,
			BackgroundTransparency = activeBind:map(function(value: number)
				return 1 - value
			end),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(2, 12),
			ZIndex = 2,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 10),
		}),
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Text = props.Label,
			TextColor3 = activeBind:map(function(value: number)
				return textColor:Lerp(activeText, value)
			end),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = FileController.Get("font", "semi_bold"),
			LayoutOrder = 1,
		}, {
			UIFlexItem = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
				ItemLineAlignment = Enum.ItemLineAlignment.Stretch,
			}),
		}),
		Check = props.IsActive and e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(9, 9),
			Image = FileController.Get("image", "checkmark"),
			ImageColor3 = accentColor,
			LayoutOrder = 2,
		}) or nil,
	})
end)

local function buildLayout(
	scopes: { [string]: ScopeController.ScopeDef },
	order: { string }
): {
	groupOrder: { string },
	buckets: { [string]: { ScopeController.ScopeDef } },
	visibleGroupCount: number,
}
	local groupOrder: { string } = {}
	local seen: { [string]: boolean } = {}
	local buckets: { [string]: { ScopeController.ScopeDef } } = {}
	local visibleGroupCount = 0

	for _, id in next, order do
		local def = scopes[id]
		if not def then
			continue
		end
		local key = def.groupLabel or ROOT_GROUP_KEY
		if not seen[key] then
			seen[key] = true
			groupOrder[#groupOrder + 1] = key
			if def.groupLabel then
				visibleGroupCount += 1
			end
		end
		local bucket = buckets[key] or {}
		bucket[#bucket + 1] = def
		buckets[key] = bucket
	end

	return {
		groupOrder = groupOrder,
		buckets = buckets,
		visibleGroupCount = visibleGroupCount,
	}
end

return function(properties: { ScopeMenu: any }): React.Element<any>
	local menu = properties.ScopeMenu

	local backgroundColor = useAt(colors.background)
	local strokeColor = useAt(colors.stroke)

	local scopes = useAt(scopeState.scopes)
	local order = useAt(scopeState.order)
	local current = useAt(scopeState.currentScope)

	local anim = useSubwindowAnimation(menu, {
		preset = SPRING.snap,
		slideOffset = 6,
		strokeIntensity = 0.6,
		floatingId = "subwindow.scopeMenu",
		onClickOutside = function()
			if menu:WasJustClosed() then
				return
			end
			menu:Close()
		end,
	})

	local layout = useMemo(function()
		return buildLayout(scopes, order)
	end, { scopes, order } :: { any })

	local onSelect = useCallback(function(id: string): ()
		ScopeController.SetCurrentScope(id)
		menu:Close()
	end, { menu } :: { any })

	local rows = useMemo(function(): { React.Element<any> }
		local out: { React.Element<any> } = {}
		local layoutOrder = 1

		for _, key in next, layout.groupOrder do
			if key ~= ROOT_GROUP_KEY then
				out[#out + 1] = e(GroupLabel, {
					Label = key,
					LayoutOrder = layoutOrder,
					key = `group_{key}`,
				})
				layoutOrder += 1
			end
			for _, def in next, layout.buckets[key] do
				out[#out + 1] = e(ScopeRow, {
					Label = def.label,
					ScopeId = def.id,
					IsActive = current == def.id,
					LayoutOrder = layoutOrder,
					key = `scope_{def.id}`,
					OnSelect = onSelect,
				})
				layoutOrder += 1
			end
		end

		return out
	end, { layout, current, onSelect } :: { any })

	local renderedChildren: { [string]: React.Element<any> } = {}
	for index, child in next, rows do
		renderedChildren[`Row_{index}`] = child
	end

	local rowCount = 0
	for _, bucket in next, layout.buckets do
		rowCount += #bucket
	end
	local naturalHeight = rowCount * ROW_HEIGHT + layout.visibleGroupCount * GROUP_HEIGHT + MENU_PAD_Y * 2
	local visibleHeight = math.min(naturalHeight, MENU_MAX_HEIGHT)
	local needsScroll = naturalHeight > MENU_MAX_HEIGHT
	local scrollThumbColor = useAt(elementColors.scrollThumb)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(MENU_WIDTH, visibleHeight),
		Position = anim.position,
		Visible = anim.visible,
		ZIndex = anim.zIndex,
	}, {
		Body = e("CanvasGroup", {
			ref = anim.frameRef,
			BackgroundTransparency = 0,
			BackgroundColor3 = backgroundColor,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = anim.transparency,
			ZIndex = 1,
		}, {
			UIStroke = e("UIStroke", {
				Color = strokeColor,
				Transparency = anim.strokeTransparency,
				Thickness = 1,
			}),
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			Items = e(
				"ScrollingFrame",
				{
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollingEnabled = needsScroll,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					VerticalScrollBarInset = Enum.ScrollBarInset.None,
					ScrollBarThickness = needsScroll and 3 or 0,
					ScrollBarImageColor3 = scrollThumbColor,
					ScrollBarImageTransparency = 0.2,
					Active = false,
					ZIndex = 1,
				},
				Sift.Dictionary.join({
					UIPadding = e("UIPadding", {
						PaddingTop = UDim.new(0, MENU_PAD_Y),
						PaddingBottom = UDim.new(0, MENU_PAD_Y),
						PaddingLeft = UDim.new(0, MENU_PAD_X),
						PaddingRight = UDim.new(0, MENU_PAD_X),
					}),
					UIListLayout = e("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Top,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 1),
					}),
				}, renderedChildren)
			),
		}),
	})
end
