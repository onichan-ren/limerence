local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local cursorUtil = require("@ui/util/cursor")
local SPRING = require("@ui/util/spring")

local Badge = require("@ui/window/element/badge")
local playerDetail = require("@feature/record/module/playerDetail")
local playerState = require("@feature/record/module/playerState")
local recordsStore = require("@feature/record/module/recordsStore")

local e = React.createElement
local useAt = ReactCharm.useAtom
local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useSpring = ReactRipple.useSpring

local colors = themeState.colors.window.element

local OUTER_PAD = 10
local SECTION_GAP = 8
local HEADER_HEIGHT = 40
local NOTE_HEIGHT = 18
local INFO_LINE = 18
local ACTIONS_HEIGHT = 24

local function avatarThumbnail(userId: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

local function visibleActions(player: Player, userId: number): { playerDetail.Action }
	local list: { playerDetail.Action } = {}
	for _, action in next, playerDetail.GetActions() do
		if not action.visible or action.visible(player, userId) then
			table.insert(list, action)
		end
	end
	return list
end

local function computeHeight(player: Player, userId: number): number
	local infoCount = #playerDetail.GetInfo()
	local record = recordsStore.Get(userId)
	local hasNote = record ~= nil and record.note ~= nil and record.note ~= ""
	local actionCount = #visibleActions(player, userId)

	local height = OUTER_PAD * 2 + HEADER_HEIGHT
	if hasNote then
		height += SECTION_GAP + NOTE_HEIGHT
	end
	if infoCount > 0 then
		height += SECTION_GAP + infoCount * INFO_LINE
	end
	if actionCount > 0 then
		height += SECTION_GAP + ACTIONS_HEIGHT
	end
	return height
end

type ActionButtonProps = {
	Action: playerDetail.Action,
	Player: Player,
	UserId: number,
	LayoutOrder: number,
}

local ActionButton = React.memo(function(props: ActionButtonProps): React.Element<any>
	local action = props.Action
	local hovered, setHovered = useState(false)
	local pressed, setPressed = useState(false)

	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		activeAtom(hovered or pressed)
	end, { hovered, pressed } :: { any })

	local background = useAdvColor(colors.surface, colors.accentStrong, activeAtom, true)
	local textColor = useAdvColor(colors.text, colors.textActive, activeAtom)
	local iconColor = useAdvColor(colors.icon, colors.iconActive, activeAtom)
	local baseStroke = useAt(colors.surfaceStroke)
	local accent = useAt(colors.accentStrong)

	local highlightBind, highlightSpring = useSpring(0, SPRING.smooth)
	useEffect(function()
		highlightSpring:setGoal((hovered or pressed) and 1 or 0)
	end, { hovered, pressed } :: { any })

	local strokeBind = useMemo(function()
		return highlightBind:map(function(value: number): Color3
			return baseStroke:Lerp(accent, value)
		end)
	end, { highlightBind, baseStroke, accent } :: { any })

	local hasIcon = action.icon ~= nil and action.icon ~= ""

	return e("TextButton", {
		BackgroundColor3 = background.binding,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = false,
		Text = "",
		Size = UDim2.new(0, 0, 0, ACTIONS_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovered(true)
			background.onMouseEnter()
			textColor.onMouseEnter()
			iconColor.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			setPressed(false)
			background.onMouseLeave()
			textColor.onMouseLeave()
			iconColor.onMouseLeave()
		end,
		[React.Event.MouseButton1Down] = function()
			setPressed(true)
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
		end,
		[React.Event.MouseButton1Click] = function()
			action.callback(props.Player, props.UserId, cursorUtil.getPosition())
		end,
	}, {
		UIFlexItem = e("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Fill,
			ItemLineAlignment = Enum.ItemLineAlignment.Stretch,
		}),
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
		UIStroke = e("UIStroke", {
			Color = strokeBind,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
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
			Image = action.icon,
			ImageColor3 = iconColor.binding,
			Size = UDim2.fromOffset(12, 12),
			LayoutOrder = 0,
		}) or nil,
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = textColor.binding,
			TextSize = 12,
			Text = action.label,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 1,
		}),
	})
end)

type InfoRowProps = {
	Field: playerDetail.InfoField,
	Player: Player,
	UserId: number,
	LayoutOrder: number,
}

local function InfoRow(props: InfoRowProps): React.Element<any>
	local field = props.Field
	local captionColor = useAt(colors.caption)
	local valueColor = useAt(field.color or colors.textActive)

	local value = field.value(props.Player, props.UserId)
	local text = value ~= nil and tostring(value) or "-"

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, INFO_LINE),
		LayoutOrder = props.LayoutOrder,
	}, {
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "bold"),
			TextColor3 = captionColor,
			TextSize = 11,
			Text = string.upper(field.label),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.new(0.42, 0, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Value = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = valueColor,
			TextSize = 12,
			Text = text,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Center,
			Position = UDim2.fromScale(0.42, 0),
			Size = UDim2.new(0.58, 0, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
	})
end

type PanelProps = {
	Player: Player,
	UserId: number,
}

local function PlayerDetailPanel(props: PanelProps): React.Element<any>
	local player = props.Player
	local userId = props.UserId

	local _tick, setTick = useState(0)
	useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				task.wait(0.25)
				if not running then
					return
				end
				setTick(function(value: number): number
					return value + 1
				end)
			end
		end)
		return function()
			running = false
		end
	end, {})

	useAt(playerState._assignments)
	useAt(recordsStore._records)
	useAt(playerDetail._providers)

	local panelColor = useAt(colors.fieldBackground)
	local strokeColor = useAt(colors.surfaceStroke)
	local nameColor = useAt(colors.textActive)
	local subColor = useAt(colors.caption)

	local stateDef = playerState.GetStateDef(userId)
	local record = recordsStore.Get(userId)
	local note = record and record.note

	local children: { [string]: React.Element<any>? } = {
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
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, SECTION_GAP),
		}),
	}

	children.Header = e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		LayoutOrder = 0,
	}, {
		Avatar = e("ImageLabel", {
			BackgroundColor3 = panelColor,
			BorderSizePixel = 0,
			Image = avatarThumbnail(userId),
			Size = UDim2.fromOffset(HEADER_HEIGHT, HEADER_HEIGHT),
			Position = UDim2.fromScale(0, 0),
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		}),
		Name = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "bold"),
			TextColor3 = nameColor,
			TextSize = 14,
			Text = player.DisplayName,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			Position = UDim2.new(0, HEADER_HEIGHT + 8, 0, 0),
			Size = UDim2.new(1, -(HEADER_HEIGHT + 8), 0.5, -1),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Sub = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = subColor,
			TextSize = 11,
			Text = `@{player.Name} · {userId}`,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.new(0, HEADER_HEIGHT + 8, 0.5, 1),
			Size = UDim2.new(1, -(HEADER_HEIGHT + 8), 0.5, -1),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Badge = stateDef and e(Badge, {
			Label = stateDef.label,
			Color = stateDef.color,
			Icon = stateDef.icon,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
		}) or nil,
	})

	if note and note ~= "" then
		children.Note = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			TextColor3 = subColor,
			TextSize = 12,
			Text = `Note: {note}`,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.new(1, 0, 0, NOTE_HEIGHT),
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 1,
		})
	end

	local info = playerDetail.GetInfo()
	if #info > 0 then
		local infoChildren: { [string]: React.Element<any> } = {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),
		}
		for index = 1, #info do
			local field = info[index]
			infoChildren[`Info_{field.id}`] = e(InfoRow, {
				Field = field,
				Player = player,
				UserId = userId,
				LayoutOrder = index,
			})
		end
		children.Info = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, #info * INFO_LINE),
			LayoutOrder = 2,
		}, infoChildren)
	end

	local actions = visibleActions(player, userId)
	if #actions > 0 then
		local actionChildren: { [string]: React.Element<any> } = {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		}
		for index = 1, #actions do
			local action = actions[index]
			actionChildren[`Action_{action.id}`] = e(ActionButton, {
				Action = action,
				Player = player,
				UserId = userId,
				LayoutOrder = index,
			})
		end
		children.Actions = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, ACTIONS_HEIGHT),
			LayoutOrder = 100,
		}, actionChildren)
	end

	return e("Frame", {
		BackgroundColor3 = panelColor,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, children)
end

return {
	Panel = PlayerDetailPanel,
	ComputeHeight = computeHeight,
}
