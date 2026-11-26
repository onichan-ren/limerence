local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
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
local useAt = ReactCharm.useAtom
local memo = React.memo
local e = React.createElement

local windowColors = themeState.colors.window
local elementColors = themeState.colors.window.element

local ROW_HEIGHT = 28
local SEARCH_ROW_HEIGHT = 38
local ICON_SIZE = 20
local CONTENT_PAD_X = layout.CONTENT_PAD_X
local CONTENT_PAD_Y = layout.CONTENT_PAD_Y
local FIELD_PAD_X = layout.FIELD_PAD_X
local ELEMENT_GAP = layout.ELEMENT_GAP

export type WeaponListResult = {
	list: { string },
	pinned: { [string]: boolean }?,
}

export type WeaponSelectorProps = {
	SelectedAtom: any,
	SearchAtom: any,
	UseWeapons: () -> WeaponListResult,
	DisplayName: ((name: string) -> string)?,
	GetIcon: ((name: string) -> string?)?,
	OnPicked: ((name: string) -> ())?,
	Placeholder: string?,
}

type WeaponRowProps = {
	Name: string,
	Display: string,
	Icon: string?,
	Selected: boolean,
	LayoutOrder: number,
	OnPick: (name: string) -> (),
}

local function WeaponRowComponent(props: WeaponRowProps): React.Element<any>
	local hoveredRef = useRef(false)

	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		activeAtom(props.Selected or hoveredRef.current)
	end, { props.Selected })

	local textColor = useAdvColor(elementColors.text, elementColors.textActive, activeAtom)
	local rowColor = useAdvColor(elementColors.panel, elementColors.surface, activeAtom)
	local indicatorColor = useAt(elementColors.textActive)

	local hoverBind, hoverSpring = useSpring(0, SPRING.smoothPrecise)

	local selectedBind, selectedSpring = useSpring(props.Selected and 1 or 0, SPRING.smoothPrecise)
	useEffect(function()
		selectedSpring:setGoal(props.Selected and 1 or 0)
	end, { props.Selected })

	local pressBind, pressSpring = useSpring(0, SPRING.quick)

	local bgTransparencyBind = useMemo(function()
		return React.joinBindings({ hoverBind, selectedBind }):map(function(values)
			local hover: number = values[1]
			local sel: number = values[2]
			local mix = math.max(hover * 0.6, sel)
			return 1 - mix
		end)
	end, { hoverBind, selectedBind } :: { any })

	local positionBind = useMemo(function()
		return React.joinBindings({ hoverBind, pressBind }):map(function(values)
			local hover: number = values[1]
			local press: number = values[2]
			local x = hover * 3 - press * 1
			return UDim2.fromOffset(x, 0)
		end)
	end, { hoverBind, pressBind } :: { any })

	local indicatorSizeBind = useMemo(function()
		return React.joinBindings({ hoverBind, selectedBind }):map(function(values)
			local hover: number = values[1]
			local sel: number = values[2]
			local h = math.max(sel, hover * 0.4)
			return UDim2.new(0, 2, h, 0)
		end)
	end, { hoverBind, selectedBind } :: { any })

	local indicatorTransparencyBind = useMemo(function()
		return React.joinBindings({ hoverBind, selectedBind }):map(function(values)
			local hover: number = values[1]
			local sel: number = values[2]
			return 1 - math.max(sel, hover * 0.5)
		end)
	end, { hoverBind, selectedBind } :: { any })

	local onEnter = useCallback(function()
		hoveredRef.current = true
		activeAtom(true)
		hoverSpring:setGoal(1)
		textColor.onMouseEnter()
		rowColor.onMouseEnter()
	end, { textColor, rowColor } :: { any })

	local onLeave = useCallback(function()
		hoveredRef.current = false
		activeAtom(props.Selected)
		hoverSpring:setGoal(0)
		pressSpring:setGoal(0)
		textColor.onMouseLeave()
		rowColor.onMouseLeave()
	end, { textColor, rowColor, props.Selected } :: { any })

	local onDown = useCallback(function()
		pressSpring:setGoal(1)
	end, {})

	local onUp = useCallback(function()
		pressSpring:setGoal(0)
	end, {})

	local onClick = useCallback(function()
		props.OnPick(props.Name)
	end, { props.OnPick, props.Name } :: { any })

	local hasIcon = props.Icon ~= nil

	return e("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Selectable = false,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = onEnter,
		[React.Event.MouseLeave] = onLeave,
		[React.Event.MouseButton1Down] = onDown,
		[React.Event.MouseButton1Up] = onUp,
		[React.Event.MouseButton1Click] = onClick,
	}, {
		Bg = e("Frame", {
			BackgroundColor3 = rowColor.binding,
			BackgroundTransparency = bgTransparencyBind,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
		}),
		Indicator = e("Frame", {
			BackgroundColor3 = indicatorColor,
			BackgroundTransparency = indicatorTransparencyBind,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = indicatorSizeBind,
			ZIndex = 2,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
		Content = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = positionBind,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}, {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, CONTENT_PAD_X + 4),
				PaddingRight = UDim.new(0, CONTENT_PAD_X),
			}),
			UIListLayout = hasIcon and e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, ELEMENT_GAP),
			}) or nil,
			Icon = hasIcon and e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				Image = props.Icon,
				ScaleType = Enum.ScaleType.Fit,
				LayoutOrder = 0,
			}) or nil,
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = FileController.Get("font", "semi_bold"),
				Text = props.Display,
				TextColor3 = textColor.binding,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = hasIcon and UDim2.new(1, -ICON_SIZE - ELEMENT_GAP, 1, 0) or UDim2.fromScale(1, 1),
				LayoutOrder = 1,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		}),
	})
end

local WeaponRow = memo(WeaponRowComponent)

return function(props: WeaponSelectorProps): React.Element<any>
	local selectedWeapon = useAt(props.SelectedAtom)
	local searchQuery = useAt(props.SearchAtom)
	local scrollThumb = useAt(elementColors.scrollThumb)
	local sidebarColor = useAt(windowColors.sidebar)
	local strokeColor = useAt(elementColors.panelStroke)
	local dividerColor = useAt(windowColors.divider)
	local searchMuted = useAt(windowColors.searchMuted)
	local panelColor = useAt(elementColors.panel)
	local strongColor = useAt(elementColors.textActive)

	local result = props.UseWeapons()
	local weapons = result.list
	local pinned = result.pinned
	local displayName = props.DisplayName
	local getIcon = props.GetIcon

	local filtered = useMemo(function()
		local query = string.lower(searchQuery or "")
		local matched: { string } = weapons
		if query ~= "" then
			matched = {}
			for _, name in next, weapons do
				if
					string.find(string.lower(name), query, 1, true)
					or (displayName and string.find(string.lower(displayName(name)), query, 1, true))
				then
					matched[#matched + 1] = name
				end
			end
		end

		if not pinned then
			return { list = matched, split = 0 }
		end

		local front: { string } = {}
		local back: { string } = {}
		for _, name in next, matched do
			if pinned[name] then
				front[#front + 1] = name
			else
				back[#back + 1] = name
			end
		end
		local split = #front
		for _, name in next, back do
			front[#front + 1] = name
		end
		return { list = front, split = split }
	end, { weapons, pinned, searchQuery, displayName } :: { any })

	local onPick = useCallback(function(name: string)
		props.SelectedAtom(name)
		local picked = props.OnPicked
		if picked then
			picked(name)
		end
	end, { props.SelectedAtom, props.OnPicked } :: { any })

	local textBoxRef = useRef(nil :: TextBox?)
	local searchDebounce = useRef(nil :: thread?)

	local onSearchChanged = useCallback(function(rbx: TextBox)
		local text = rbx.Text
		if searchDebounce.current then
			task.cancel(searchDebounce.current)
		end
		searchDebounce.current = task.delay(0.12, function()
			searchDebounce.current = nil
			props.SearchAtom(text)
		end)
	end, { props.SearchAtom } :: { any })

	useEffect(function()
		local box = textBoxRef.current
		if box and searchQuery ~= "" then
			box.Text = searchQuery
		end
		return function()
			if searchDebounce.current then
				task.cancel(searchDebounce.current)
				searchDebounce.current = nil
			end
		end
	end, {})

	local children: { [string]: React.Element<any> } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0, CONTENT_PAD_Y),
			PaddingBottom = UDim.new(0, CONTENT_PAD_Y),
			PaddingLeft = UDim.new(0, CONTENT_PAD_X),
			PaddingRight = UDim.new(0, CONTENT_PAD_X),
		}),
	}

	for index, name in next, filtered.list do
		children[`Row_{name}`] = e(WeaponRow, {
			Name = name,
			Display = displayName and displayName(name) or name,
			Icon = getIcon and getIcon(name) or nil,
			Selected = name == selectedWeapon,
			LayoutOrder = index * 2,
			OnPick = onPick,
		})
	end

	if (searchQuery or "") == "" and filtered.split > 0 and filtered.split < #filtered.list then
		children.PinnedDivider = e("Frame", {
			BackgroundColor3 = dividerColor,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			LayoutOrder = filtered.split * 2 + 1,
		})
	end

	return e("Frame", {
		BackgroundColor3 = sidebarColor,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor,
			Transparency = 0.5,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		SearchRow = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, SEARCH_ROW_HEIGHT),
		}, {
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, CONTENT_PAD_X),
				PaddingRight = UDim.new(0, CONTENT_PAD_X),
				PaddingTop = UDim.new(0, CONTENT_PAD_Y),
				PaddingBottom = UDim.new(0, CONTENT_PAD_Y),
			}),
			SearchBox = e("Frame", {
				BackgroundColor3 = panelColor,
				BackgroundTransparency = 0.4,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, 5),
				}),
				UIStroke = e("UIStroke", {
					Color = strokeColor,
					Transparency = 0.6,
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, FIELD_PAD_X),
					PaddingRight = UDim.new(0, FIELD_PAD_X),
				}),
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, ELEMENT_GAP),
				}),
				Icon = e("ImageLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(11, 11),
					Image = FileController.Get("image", "search"),
					ImageColor3 = searchMuted,
					ScaleType = Enum.ScaleType.Fit,
					LayoutOrder = 0,
				}),
				Input = e("TextBox", {
					ref = textBoxRef,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClearTextOnFocus = false,
					PlaceholderText = props.Placeholder or "Search weapons...",
					PlaceholderColor3 = searchMuted,
					TextColor3 = strongColor,
					TextSize = 12,
					FontFace = FileController.Get("font", "light"),
					Text = "",
					Size = UDim2.new(1, -(11 + ELEMENT_GAP), 0, 14),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					LayoutOrder = 1,
					[React.Event.FocusLost] = function(rbx: TextBox)
						if searchDebounce.current then
							task.cancel(searchDebounce.current)
							searchDebounce.current = nil
						end
						props.SearchAtom(rbx.Text)
					end,
					[React.Change.Text] = onSearchChanged,
				}),
			}),
		}),
		SearchDivider = e("Frame", {
			BackgroundColor3 = dividerColor,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, SEARCH_ROW_HEIGHT),
			Size = UDim2.new(1, 0, 0, 1),
		}),
		Scroll = e("ScrollingFrame", {
			Active = false,
			Selectable = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, SEARCH_ROW_HEIGHT + 1),
			Size = UDim2.new(1, 0, 1, -(SEARCH_ROW_HEIGHT + 1)),
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = scrollThumb,
			ScrollBarImageTransparency = 0.1,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			ClipsDescendants = true,
		}, children),
	})
end
