local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Sift = require("@pkg/Sift")

local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local GuiService = cloneref(game:GetService("GuiService")) :: GuiService
local RunService = cloneref(game:GetService("RunService")) :: RunService

local themeState = require("@ui/theme/themeState")
local FileController = require("@feature/file/FileController")
local useSubwindowAnimation = require("@ui/hook/useSubwindowAnimation")
local useShadow = require("@ui/hook/useShadow")
local useDraggable = require("@ui/hook/useDraggable")
local floatingController = require("@ui/floating/floatingController")
local SPRING = require("@ui/util/spring")
local dpiState = require("@ui/util/dpiState")
local preview = require("@ui/subwindow/characterEditor/preview")
local catalog = require("@ui/subwindow/characterEditor/catalog")

local e = React.createElement
local useRef = React.useRef
local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useBinding = React.useBinding
local useAt = ReactCharm.useAtom
local useSpring = ReactRipple.useSpring
local peek = Charm.peek

local subwindowColors = themeState.colors.subwindow
local elementColors = themeState.colors.window.element

local WIDTH = 648
local HEIGHT = 620
local PADDING = 12
local HEADER_HEIGHT = 30
local FOOTER_HEIGHT = 26
local LEFT_WIDTH = 250
local VIEWPORT_HEIGHT = 172
local SLIDERS_HEIGHT = 116
local TABS_HEIGHT = 24
local SUBTABS_HEIGHT = 22
local SEARCH_HEIGHT = 24
local COLORS_HEIGHT = 32
local RIG_HEIGHT = 22

local RESULT_COLUMNS = 4
local RESULT_GAP = 8
local RESULTS_WIDTH = WIDTH - PADDING * 2 - LEFT_WIDTH - 8
local RESULT_CELL = math.floor((RESULTS_WIDTH - 16 - (RESULT_COLUMNS - 1) * RESULT_GAP) / RESULT_COLUMNS)

local GRID_CELL = 24
local GRID_LINE = 1
local GRID_TRANSPARENCY = 0.72
local GRID_COLUMNS = math.ceil(LEFT_WIDTH / GRID_CELL) + 1
local GRID_ROWS = math.ceil(VIEWPORT_HEIGHT / GRID_CELL) + 1

local function buildGrid(color: Color3): { [string]: React.Element<any> }
	local children: { [string]: React.Element<any> } = {}
	for i = 1, GRID_COLUMNS do
		children[`VLine_{i}`] = e("Frame", {
			Size = UDim2.new(0, GRID_LINE, 1, 0),
			Position = UDim2.fromOffset(i * GRID_CELL, 0),
			BackgroundColor3 = color,
			BackgroundTransparency = GRID_TRANSPARENCY,
			BorderSizePixel = 0,
		})
	end
	for i = 1, GRID_ROWS do
		children[`HLine_{i}`] = e("Frame", {
			Size = UDim2.new(1, 0, 0, GRID_LINE),
			Position = UDim2.fromOffset(0, i * GRID_CELL),
			BackgroundColor3 = color,
			BackgroundTransparency = GRID_TRANSPARENCY,
			BorderSizePixel = 0,
		})
	end
	return children
end

local CLOTHING_SLOTS: { { key: string, label: string } } = {
	{ key = "Shirt", label = "Shirt" },
	{ key = "Pants", label = "Pants" },
	{ key = "GraphicTShirt", label = "T-Shirt" },
	{ key = "Face", label = "Face" },
	{ key = "Head", label = "Head" },
	{ key = "Torso", label = "Torso" },
	{ key = "LeftArm", label = "Left Arm" },
	{ key = "RightArm", label = "Right Arm" },
	{ key = "LeftLeg", label = "Left Leg" },
	{ key = "RightLeg", label = "Right Leg" },
}

local INDICATOR_HEIGHT = 2
local STRIP_END_PADDING = 4

type StripTab = { id: string, label: string }
type StripSlot = { x: number, width: number }

local function StripButton(props: {
	Id: string,
	Label: string,
	Selected: boolean,
	TextSize: number,
	LayoutOrder: number,
	OnPick: (id: string) -> (),
	OnMeasure: (id: string, x: number, width: number) -> (),
}): React.Element<any>
	local hovering, setHovering = useState(false)
	local caption = useAt(elementColors.caption)
	local textActive = useAt(elementColors.textActive)

	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	local selBind, selSpring = useSpring(props.Selected and 1 or 0, SPRING.quick)
	useEffect(function()
		hoverSpring:setGoal(hovering and 1 or 0)
	end, { hovering })
	useEffect(function()
		selSpring:setGoal(props.Selected and 1 or 0)
	end, { props.Selected })

	local buttonRef = useRef(nil :: TextButton?)
	useEffect(function()
		local btn = buttonRef.current
		if not btn then
			return
		end
		local function measure(): ()
			local parent = btn.Parent :: GuiObject?
			if not parent then
				return
			end
			local scale = peek(dpiState.scale)
			if scale <= 0 then
				scale = 1
			end
			props.OnMeasure(
				props.Id,
				(btn.AbsolutePosition.X - parent.AbsolutePosition.X) / scale,
				btn.AbsoluteSize.X / scale
			)
		end
		measure()
		local c1 = btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(measure)
		local c2 = btn:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		return function()
			c1:Disconnect()
			c2:Disconnect()
		end
	end, { props.Id, props.OnMeasure } :: { any })

	local stateBind = React.joinBindings({ hoverBind, selBind })
	return e("TextButton", {
		ref = buttonRef,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Text = props.Label,
		TextColor3 = stateBind:map(function(values)
			return caption:Lerp(textActive, math.max(values[1] * 0.6, values[2]))
		end),
		TextSize = props.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = FileController.Get("font", "semi_bold"),
		AutoButtonColor = false,
		Active = false,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
		[React.Event.MouseButton1Click] = function()
			props.OnPick(props.Id)
		end,
	})
end

local function TabStrip(props: {
	Tabs: { StripTab },
	Selected: string,
	TextSize: number,
	Height: number,
	BottomInset: number,
	ScrollBarThickness: number,
	Divider: boolean?,
	LayoutOrder: number,
	OnPick: (id: string) -> (),
}): React.Element<any>
	local accentStrong = useAt(elementColors.accentStrong)
	local fieldStroke = useAt(elementColors.fieldStroke)
	local scrollThumb = useAt(elementColors.icon)

	local slots, setSlots = useState({} :: { [string]: StripSlot })
	local onMeasure = useCallback(function(id: string, x: number, width: number)
		setSlots(function(prev: { [string]: StripSlot }): { [string]: StripSlot }
			local existing = prev[id]
			if existing and existing.x == x and existing.width == width then
				return prev
			end
			local copy = table.clone(prev)
			copy[id] = { x = x, width = width }
			return copy
		end)
	end, {})

	local target = slots[props.Selected]
	local targetX = target and target.x or 0
	local targetWidth = target and target.width or 0

	local xBind, xSpring = useSpring(targetX, SPRING.smoothPreciser)
	local widthBind, widthSpring = useSpring(targetWidth, SPRING.smoothPreciser)
	local visBind, visSpring = useSpring(target and 1 or 0, SPRING.smoothPreciser)
	useEffect(function()
		if target then
			xSpring:setGoal(targetX)
			widthSpring:setGoal(targetWidth)
		end
		visSpring:setGoal(target and 1 or 0)
	end, { targetX, targetWidth, target ~= nil } :: { any })

	local tabs: { [string]: React.Element<any> } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 16),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, STRIP_END_PADDING),
			PaddingRight = UDim.new(0, STRIP_END_PADDING),
		}),
	}
	for i = 1, #props.Tabs do
		local tab = props.Tabs[i]
		tabs[`Tab_{tab.id}`] = e(StripButton, {
			Id = tab.id,
			Label = tab.label,
			Selected = props.Selected == tab.id,
			TextSize = props.TextSize,
			LayoutOrder = i,
			OnPick = props.OnPick,
			OnMeasure = onMeasure,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, props.Height),
		LayoutOrder = props.LayoutOrder,
	}, {
		Scroller = e("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, props.Divider and -1 or 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = props.ScrollBarThickness,
			ScrollBarImageColor3 = scrollThumb,
		}, {
			TabRow = e("Frame", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, -props.BottomInset),
			}, tabs),
			Indicator = e("Frame", {
				BackgroundColor3 = accentStrong,
				BackgroundTransparency = visBind:map(function(value: number)
					return 1 - value
				end),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = xBind:map(function(value: number)
					return UDim2.new(0, math.round(value), 1, -props.BottomInset)
				end),
				Size = widthBind:map(function(value: number)
					return UDim2.new(0, math.max(math.round(value), 0), 0, INDICATOR_HEIGHT)
				end),
				ZIndex = 2,
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}),
		Divider = props.Divider and e("Frame", {
			BackgroundColor3 = fieldStroke,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 2, 1, 0),
			Size = UDim2.new(1, 0, 0, 1),
		}) or nil,
	})
end

local function PillButton(props: {
	Text: string,
	Primary: boolean?,
	Danger: boolean?,
	Width: number,
	Height: number?,
	LayoutOrder: number,
	OnClick: () -> (),
}): React.Element<any>
	local hovering, setHovering = useState(false)
	local surface = useAt(elementColors.surface)
	local fieldBackgroundActive = useAt(elementColors.fieldBackgroundActive)
	local surfaceStroke = useAt(elementColors.surfaceStroke)
	local accent = useAt(elementColors.accent)
	local accentStrong = useAt(elementColors.accentStrong)
	local text = useAt(elementColors.text)
	local textActive = useAt(elementColors.textActive)
	local danger = useAt(themeState.colors.status.danger)

	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	useEffect(function()
		hoverSpring:setGoal(hovering and 1 or 0)
	end, { hovering })

	return e("TextButton", {
		BackgroundColor3 = hoverBind:map(function(value: number)
			if props.Danger then
				return surface:Lerp(danger, value * 0.18)
			end
			if props.Primary then
				return accent:Lerp(accentStrong, value * 0.2)
			end
			return surface:Lerp(fieldBackgroundActive, value)
		end),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(props.Width, props.Height or 22),
		Text = props.Text,
		TextColor3 = hoverBind:map(function(value: number)
			if props.Danger then
				return text:Lerp(danger, 0.55 + value * 0.45)
			end
			return props.Primary and textActive or text:Lerp(textActive, value)
		end),
		TextSize = 12,
		FontFace = FileController.Get("font", "semi_bold"),
		AutoButtonColor = false,
		Active = false,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
		[React.Event.MouseButton1Click] = props.OnClick,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = e("UIStroke", {
			Color = hoverBind:map(function(value: number)
				if props.Danger then
					return surfaceStroke:Lerp(danger, 0.35 + value * 0.65)
				end
				return props.Primary and accentStrong or surfaceStroke:Lerp(accentStrong, value * 0.45)
			end),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

local function SegButton(
	props: { Label: string, Selected: boolean, Width: number, LayoutOrder: number, OnClick: () -> () }
): React.Element<any>
	local hovering, setHovering = useState(false)
	local surface = useAt(elementColors.surface)
	local fieldBackgroundActive = useAt(elementColors.fieldBackgroundActive)
	local accent = useAt(elementColors.accent)
	local accentStrong = useAt(elementColors.accentStrong)
	local caption = useAt(elementColors.caption)
	local textActive = useAt(elementColors.textActive)

	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	local selBind, selSpring = useSpring(props.Selected and 1 or 0, SPRING.quick)
	useEffect(function()
		hoverSpring:setGoal(hovering and 1 or 0)
	end, { hovering })
	useEffect(function()
		selSpring:setGoal(props.Selected and 1 or 0)
	end, { props.Selected })

	local stateBind = React.joinBindings({ hoverBind, selBind })
	return e("TextButton", {
		BackgroundColor3 = stateBind:map(function(values)
			return surface:Lerp(fieldBackgroundActive, values[1] * 0.6):Lerp(accent, values[2])
		end),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(props.Width, RIG_HEIGHT - 4),
		Text = props.Label,
		TextColor3 = selBind:map(function(value: number)
			return caption:Lerp(textActive, value)
		end),
		TextSize = 11,
		FontFace = FileController.Get("font", "semi_bold"),
		AutoButtonColor = false,
		Active = false,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
		[React.Event.MouseButton1Click] = props.OnClick,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = e("UIStroke", {
			Color = selBind:map(function(value: number)
				return accentStrong
			end),
			Transparency = selBind:map(function(value: number)
				return 1 - value
			end),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

local function RigToggle(props: { Editor: any, Value: string, LayoutOrder: number }): React.Element<any>
	local caption = useAt(elementColors.caption)
	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, RIG_HEIGHT),
		LayoutOrder = props.LayoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -104, 1, 0),
			Text = "Preview rig",
			TextColor3 = caption,
			TextSize = 11,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
		}),
		R6 = e(SegButton, {
			Label = "R6",
			Selected = props.Value == "R6",
			Width = 44,
			LayoutOrder = 1,
			OnClick = function()
				props.Editor:SetRigType("R6")
			end,
		}),
		R15 = e(SegButton, {
			Label = "R15",
			Selected = props.Value ~= "R6",
			Width = 44,
			LayoutOrder = 2,
			OnClick = function()
				props.Editor:SetRigType("R15")
			end,
		}),
	})
end

local function ResultButton(props: { Editor: any, Item: any, Equipped: boolean, LayoutOrder: number }): React.Element<any>
	local hovering, setHovering = useState(false)
	local fieldBackground = useAt(elementColors.fieldBackground)
	local fieldStroke = useAt(elementColors.fieldStroke)
	local accentStrong = useAt(elementColors.accentStrong)
	local caption = useAt(elementColors.caption)
	local textActive = useAt(elementColors.textActive)

	local equipped = props.Equipped
	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	useEffect(function()
		hoverSpring:setGoal(hovering and 1 or 0)
	end, { hovering })

	return e("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.fromScale(1, 1),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
		[React.Event.MouseButton1Click] = function()
			if equipped then
				props.Editor:RemoveCatalogItem(props.Item)
			else
				props.Editor:AddCatalogItem(props.Item)
			end
		end,
	}, {
		Thumb = e("ImageLabel", {
			BackgroundColor3 = fieldBackground,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, RESULT_CELL),
			Image = props.Item.isBundle and `rbxthumb://type=BundleThumbnail&id={props.Item.id}&w=150&h=150`
				or `rbxthumb://type=Asset&id={props.Item.id}&w=150&h=150`,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			UIStroke = e("UIStroke", {
				Color = equipped and accentStrong or hoverBind:map(function(value: number)
					return fieldStroke:Lerp(accentStrong, value)
				end),
				Thickness = equipped and 1.5 or 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Tint = equipped and e("Frame", {
				BackgroundColor3 = accentStrong,
				BackgroundTransparency = 0.82,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			}) or nil,
			Badge = equipped and e("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -3, 0, 3),
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = accentStrong,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Check = e("ImageLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(10, 10),
					Image = FileController.Get("image", "checkmark") or "",
					ImageColor3 = textActive,
					ZIndex = 2,
				}),
			}) or nil,
		}),
		Name = e("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, RESULT_CELL + 2),
			Size = UDim2.new(1, 0, 0, 14),
			Text = props.Item.name,
			TextColor3 = equipped and textActive or hoverBind:map(function(value: number)
				return caption:Lerp(textActive, value)
			end),
			TextSize = 10,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
	})
end

local function WornItem(props: { Editor: any, Entry: any, LayoutOrder: number }): React.Element<any>
	local hovering, setHovering = useState(false)
	local surface = useAt(elementColors.surface)
	local surfaceStroke = useAt(elementColors.surfaceStroke)
	local fieldBackground = useAt(elementColors.fieldBackground)
	local textColor = useAt(elementColors.text)

	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	useEffect(function()
		hoverSpring:setGoal(hovering and 1 or 0)
	end, { hovering })

	local entry = props.Entry
	return e("Frame", {
		BackgroundColor3 = hoverBind:map(function(value: number)
			return surface:Lerp(surfaceStroke, value * 0.5)
		end),
		BackgroundTransparency = hoverBind:map(function(value: number)
			return 0.5 - value * 0.2
		end),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIPadding = e("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Thumb = e("ImageLabel", {
			BackgroundColor3 = fieldBackground,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(18, 18),
			Image = `rbxthumb://type=Asset&id={entry.assetId}&w=150&h=150`,
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = 0,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -88, 1, 0),
			Text = entry.label,
			TextColor3 = textColor,
			TextSize = 11,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 1,
		}),
		Remove = e(PillButton, {
			Text = "Remove",
			Danger = true,
			Width = 52,
			Height = 18,
			LayoutOrder = 2,
			OnClick = function()
				if entry.kind == "clothing" then
					props.Editor:RemoveClothing(entry.key)
				else
					props.Editor:RemoveWornAsset(entry.assetId)
				end
			end,
		}),
	})
end

local function ColorCell(props: { Label: string, Picker: any, LayoutOrder: number }): React.Element<any>
	local caption = useAt(elementColors.caption)
	local fieldBackground = useAt(elementColors.fieldBackground)
	local fieldStroke = useAt(elementColors.fieldStroke)
	return e("Frame", {
		BackgroundColor3 = fieldBackground,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		LayoutOrder = props.LayoutOrder,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
		UIStroke = e("UIStroke", {
			Color = fieldStroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 8),
		}),
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Swatch = props.Picker:RenderInternal({ layoutOrder = 0 }),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			Text = props.Label,
			TextColor3 = caption,
			TextSize = 11,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 1,
		}),
	})
end

local function SliderRow(props: { Entry: any, LayoutOrder: number }): React.Element<any>
	local caption = useAt(elementColors.caption)
	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = props.LayoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -121, 1, 0),
			Text = props.Entry.label,
			TextColor3 = caption,
			TextSize = 12,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
		}),
		Slider = props.Entry.slider:RenderInternal({ layoutOrder = 1 }),
	})
end

local function wornLabel(names: any, assetId: any, typeLabel: string): string
	local name = type(names) == "table" and names[tostring(assetId)] or nil
	if type(name) == "string" and name ~= "" then
		if #name > 60 then
			name = string.sub(name, 1, 60)
		end
		return `{name} ({typeLabel})`
	end
	return typeLabel
end

local function SortRow(
	props: { Label: string, Selected: boolean, LayoutOrder: number, OnClick: () -> () }
): React.Element<any>
	local hovering, setHovering = useState(false)
	local fieldBackgroundActive = useAt(elementColors.fieldBackgroundActive)
	local accent = useAt(elementColors.accent)
	local caption = useAt(elementColors.caption)
	local textActive = useAt(elementColors.textActive)

	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	useEffect(function()
		hoverSpring:setGoal(hovering and 1 or 0)
	end, { hovering })

	return e("TextButton", {
		BackgroundColor3 = props.Selected and accent or fieldBackgroundActive,
		BackgroundTransparency = props.Selected and 0.1 or hoverBind:map(function(value: number)
			return 1 - value * 0.8
		end),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 20),
		Text = props.Label,
		TextColor3 = props.Selected and textActive or hoverBind:map(function(value: number)
			return caption:Lerp(textActive, value)
		end),
		TextSize = 11,
		FontFace = FileController.Get("font", "semi_bold"),
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		Active = false,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
		[React.Event.MouseButton1Click] = props.OnClick,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
		UIPadding = e("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
end

local SORT_WIDTH = 98

local function SortDropdown(
	props: { Editor: any, Current: string, LayoutOrder: number, WindowRef: { current: GuiObject? } }
): React.Element<any>
	local open, setOpen = useState(false)
	local mounted, setMounted = useState(false)
	local hovering, setHovering = useState(false)
	local surface = useAt(elementColors.surface)
	local fieldBackground = useAt(elementColors.fieldBackground)
	local fieldBackgroundActive = useAt(elementColors.fieldBackgroundActive)
	local fieldStroke = useAt(elementColors.fieldStroke)
	local accentStrong = useAt(elementColors.accentStrong)
	local caption = useAt(elementColors.caption)
	local textActive = useAt(elementColors.textActive)

	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)
	local openBind, openSpring = useSpring(0, SPRING.quick)
	useEffect(function()
		hoverSpring:setGoal((hovering or open) and 1 or 0)
	end, { hovering, open } :: { any })
	useEffect(function()
		if open then
			setMounted(true)
			openSpring:setGoal(1)
			return
		end
		openSpring:setGoal(0)
		local handle = task.delay(0.2, function()
			setMounted(false)
		end)
		return function()
			task.cancel(handle)
		end
	end, { open })
	useEffect(function()
		if not open then
			return
		end
		local conn = UserInputService.InputBegan:Connect(function(io: InputObject): ()
			if
				io.UserInputType ~= Enum.UserInputType.MouseButton1
				and io.UserInputType ~= Enum.UserInputType.MouseButton2
				and io.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local win = props.WindowRef.current
			if win then
				local layer = win:FindFirstAncestorWhichIsA("LayerCollector")
				local inset = if layer and layer.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
				local mx = io.Position.X - inset.X
				local my = io.Position.Y - inset.Y
				local pos = win.AbsolutePosition
				local size = win.AbsoluteSize
				if mx >= pos.X and mx <= pos.X + size.X and my >= pos.Y and my <= pos.Y + size.Y then
					return
				end
			end
			setOpen(false)
		end)
		return function()
			conn:Disconnect()
		end
	end, { open })

	local currentLabel = ""
	for i = 1, #catalog.SORT_OPTIONS do
		if catalog.SORT_OPTIONS[i].id == props.Current then
			currentLabel = catalog.SORT_OPTIONS[i].label
		end
	end

	local menuChildren: { [string]: React.Element<any> } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	}
	for i = 1, #catalog.SORT_OPTIONS do
		local opt = catalog.SORT_OPTIONS[i]
		menuChildren[`Opt_{opt.id}`] = e(SortRow, {
			Label = opt.label,
			Selected = props.Current == opt.id,
			LayoutOrder = i,
			OnClick = function()
				setOpen(false)
				props.Editor:SetSort(opt.id)
			end,
		})
	end

	local menuHeight = #catalog.SORT_OPTIONS * 22 + 8

	return e("TextButton", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(0, SORT_WIDTH, 1, 0),
		BackgroundColor3 = hoverBind:map(function(value: number)
			return fieldBackground:Lerp(fieldBackgroundActive, value)
		end),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		LayoutOrder = props.LayoutOrder,
		ZIndex = 2,
		[React.Event.MouseEnter] = function()
			setHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovering(false)
		end,
		[React.Event.MouseButton1Click] = function()
			setOpen(not open)
		end,
	}, {
		Catcher = open and e("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			Active = false,
			AutoButtonColor = false,
			Size = UDim2.fromOffset(4000, 4000),
			Position = UDim2.fromOffset(-2000, -2000),
			ZIndex = 99,
			[React.Event.MouseButton1Click] = function()
				setOpen(false)
			end,
		}) or nil,
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = e("UIStroke", {
			Color = hoverBind:map(function(value: number)
				return fieldStroke:Lerp(accentStrong, value * 0.6)
			end),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = e("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 6) }),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(1, -14, 1, 0),
			Text = currentLabel,
			TextColor3 = hoverBind:map(function(value: number)
				return caption:Lerp(textActive, value)
			end),
			TextSize = 11,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Arrow = e("ImageLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(9, 9),
			Image = FileController.Get("image", "down_arrow") or "",
			ImageColor3 = hoverBind:map(function(value: number)
				return caption:Lerp(textActive, value)
			end),
			Rotation = openBind:map(function(value: number)
				return value * 180
			end),
		}),
		Menu = mounted and e(
			"CanvasGroup",
			{
				AnchorPoint = Vector2.new(1, 0),
				Position = openBind:map(function(value: number)
					return UDim2.new(1, 0, 1, 4 - (1 - value) * 6)
				end),
				Size = UDim2.new(0, 132, 0, menuHeight),
				BackgroundColor3 = surface,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				GroupTransparency = openBind:map(function(value: number)
					return 1 - value
				end),
				ZIndex = 100,
			},
			Sift.Dictionary.join({
				UICorner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
				UIStroke = e("UIStroke", {
					Color = fieldStroke,
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Transparency = openBind:map(function(value: number)
						return 1 - value
					end),
				}),
			}, menuChildren)
		) or nil,
	})
end

local function ShakeMessage(props: {
	Text: string,
	IsError: boolean,
	Nonce: number,
	DangerColor: Color3,
	MutedColor: Color3,
}): React.Element<any>
	local offset, setOffset = useBinding(0)
	useEffect(function()
		if not props.IsError then
			setOffset(0)
			return
		end
		local elapsed = 0
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function(dt: number): ()
			elapsed += dt
			if elapsed >= 0.35 then
				setOffset(0)
				conn:Disconnect()
				return
			end
			local decay = 1 - elapsed / 0.35
			setOffset(math.round(math.sin(elapsed * 55) * 5 * decay))
		end)
		return function()
			conn:Disconnect()
			setOffset(0)
		end
	end, { props.Nonce, props.IsError } :: { any })

	return e("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = offset:map(function(x: number)
			return UDim2.new(0.5, x, 0.5, 0)
		end),
		Size = UDim2.new(1, -24, 0, 40),
		Text = props.Text,
		TextColor3 = props.IsError and props.DangerColor or props.MutedColor,
		TextSize = 11,
		FontFace = FileController.Get("font", "semi_bold"),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
end

local TOAST_SHAKE = 0.35
local TOAST_HOLD = 2.6
local TOAST_FADE = 0.4

local function ErrorToast(props: { Text: string, Nonce: number }): React.Element<any>
	local danger = useAt(themeState.colors.status.danger)
	local surface = useAt(subwindowColors.background)

	local offset, setOffset = useBinding(0)
	local fade, setFade = useBinding(0)
	useEffect(function()
		setFade(0)
		local elapsed = 0
		local settled = false
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function(dt: number): ()
			elapsed += dt
			if elapsed < TOAST_SHAKE then
				local decay = 1 - elapsed / TOAST_SHAKE
				setOffset(math.round(math.sin(elapsed * 55) * 5 * decay))
				return
			end
			if not settled then
				settled = true
				setOffset(0)
			end
			if elapsed < TOAST_HOLD then
				return
			end
			local alpha = math.min((elapsed - TOAST_HOLD) / TOAST_FADE, 1)
			setFade(alpha)
			if alpha >= 1 then
				conn:Disconnect()
			end
		end)
		return function()
			conn:Disconnect()
			setOffset(0)
			setFade(0)
		end
	end, { props.Nonce })

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = offset:map(function(x: number)
			return UDim2.new(0.5, x, 1, -(PADDING + FOOTER_HEIGHT + 4))
		end),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 22),
		BackgroundColor3 = surface,
		BackgroundTransparency = fade:map(function(alpha: number)
			return 0.05 + 0.95 * alpha
		end),
		BorderSizePixel = 0,
		ZIndex = 30,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
		UIStroke = e("UIStroke", {
			Color = danger,
			Transparency = fade:map(function(alpha: number)
				return 0.35 + 0.65 * alpha
			end),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Text = props.Text,
			TextColor3 = danger,
			TextTransparency = fade,
			TextSize = 11,
			FontFace = FileController.Get("font", "semi_bold"),
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

local STRING_ACCESSORY_SLOTS: { { key: string, label: string } } = {
	{ key = "HatAccessory", label = "Hat" },
	{ key = "HairAccessory", label = "Hair" },
	{ key = "FaceAccessory", label = "Face" },
	{ key = "NeckAccessory", label = "Neck" },
	{ key = "ShouldersAccessory", label = "Shoulders" },
	{ key = "FrontAccessory", label = "Front" },
	{ key = "BackAccessory", label = "Back" },
	{ key = "WaistAccessory", label = "Waist" },
}

local function deriveWorn(manifest: { [string]: any }): { any }
	local worn: { any } = {}
	local names = manifest.itemNames
	local seen: { [number]: boolean } = {}
	local accessories = manifest.accessories
	if type(accessories) == "table" then
		for i = 1, #accessories do
			local accessory = accessories[i]
			seen[accessory.AssetId] = true
			worn[#worn + 1] = {
				kind = "accessory",
				index = i,
				assetId = accessory.AssetId,
				label = wornLabel(names, accessory.AssetId, tostring(accessory.AccessoryType or "Accessory")),
			}
		end
	end
	for i = 1, #STRING_ACCESSORY_SLOTS do
		local slot = STRING_ACCESSORY_SLOTS[i]
		local raw = manifest[slot.key]
		if type(raw) == "string" and raw ~= "" then
			for token in string.gmatch(raw, "%d+") do
				local id = tonumber(token)
				if id and id > 0 and not seen[id] then
					seen[id] = true
					worn[#worn + 1] = {
						kind = "stringacc",
						key = slot.key,
						assetId = id,
						label = wornLabel(names, id, slot.label),
					}
				end
			end
		end
	end
	for i = 1, #CLOTHING_SLOTS do
		local slot = CLOTHING_SLOTS[i]
		local value = manifest[slot.key]
		if type(value) == "number" and value > 0 then
			worn[#worn + 1] = {
				kind = "clothing",
				key = slot.key,
				assetId = value,
				label = wornLabel(names, value, slot.label),
			}
		end
	end
	return worn
end

local function buildEquippedSet(manifest: { [string]: any }): { [number]: boolean }
	local set: { [number]: boolean } = {}
	local accessories = manifest.accessories
	if type(accessories) == "table" then
		for i = 1, #accessories do
			set[accessories[i].AssetId] = true
		end
	end
	for i = 1, #STRING_ACCESSORY_SLOTS do
		local raw = manifest[STRING_ACCESSORY_SLOTS[i].key]
		if type(raw) == "string" then
			for token in string.gmatch(raw, "%d+") do
				local id = tonumber(token)
				if id then
					set[id] = true
				end
			end
		end
	end
	for i = 1, #CLOTHING_SLOTS do
		local value = manifest[CLOTHING_SLOTS[i].key]
		if type(value) == "number" and value > 0 then
			set[value] = true
		end
	end
	return set
end

local function isEquipped(item: any, set: { [number]: boolean }): boolean
	if item.isBundle then
		local parts = catalog.resolveBundleParts(item)
		if not parts then
			return false
		end
		local any = false
		for _, id in next, parts do
			any = true
			if not set[id] then
				return false
			end
		end
		return any
	end
	return set[item.id] == true
end

return function(properties: { Editor: any }): React.Element<any>
	local editor = properties.Editor

	local title = useAt(editor._title)
	local subtitle = useAt(editor._subtitle)
	local name = useAt(editor._name)
	local importField = useAt(editor._importField)
	local manifest = useAt(editor._manifest)
	local errorText = useAt(editor._error)
	local errorNonce = useAt(editor._errorNonce)
	local busy = useAt(editor._busy)
	local searchField = useAt(editor._searchField)
	local searchResults = useAt(editor._searchResults)
	local searchError = useAt(editor._searchError)
	local searchErrorNonce = useAt(editor._searchErrorNonce)
	local searching = useAt(editor._searching)
	local group = useAt(editor._group)
	local category = useAt(editor._category)
	local colorsReady = useAt(editor._colorsReady)
	local rigType = useAt(editor._rigType)
	local sortId = useAt(editor._sortId)

	local backgroundColor = useAt(subwindowColors.background)
	local strokeColor = useAt(subwindowColors.stroke)
	local titleColor = useAt(subwindowColors.title)
	local subtitleColor = useAt(elementColors.caption)
	local fieldBackground = useAt(elementColors.fieldBackground)
	local fieldStroke = useAt(elementColors.fieldStroke)
	local textColor = useAt(elementColors.textActive)
	local captionColor = useAt(elementColors.caption)
	local mutedColor = useAt(themeState.colors.hud.textMuted)
	local scrollThumb = useAt(elementColors.icon)
	local dangerColor = useAt(themeState.colors.status.danger)

	local anim = useSubwindowAnimation(editor, {
		slideOffset = 18,
		floatingId = "subwindow.characterEditor",
		floatingPriority = floatingController.PRIORITY.MODAL,
	})
	local onDragStart = useDraggable(editor._position)

	local viewportRef = useRef(nil :: ViewportFrame?)
	local cameraRef = useRef(nil :: Camera?)
	local worldModelRef = useRef(nil :: WorldModel?)
	local inputRef = useRef(nil :: Frame?)
	local previewRef = useRef(nil :: preview.Preview?)
	local debounceRef = useRef(nil :: any)

	useEffect(function()
		local viewport = viewportRef.current
		local camera = cameraRef.current
		local worldModel = worldModelRef.current
		local input = inputRef.current
		if not viewport or not camera or not worldModel or not input then
			return
		end
		local controller = preview.new()
		previewRef.current = controller
		controller:mount({
			viewport = viewport,
			camera = camera,
			worldModel = worldModel,
			input = input,
		})
		return function(): ()
			controller:unmount()
			previewRef.current = nil
		end
	end, {})

	useEffect(function()
		local controller = previewRef.current
		if not controller then
			return
		end
		local token = {}
		debounceRef.current = token
		task.delay(0.3, function(): ()
			if debounceRef.current == token and previewRef.current == controller then
				controller:setManifest(manifest, rigType)
			end
		end)
	end, { manifest, rigType } :: { any })

	local gridChildren = useMemo(function()
		return buildGrid(fieldStroke)
	end, { fieldStroke })

	local sliders = useMemo(function()
		local children: { [string]: React.Element<any> } = {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
		}
		local entries = editor._sliders
		for i = 1, #entries do
			children[`Slider_{i}`] = e(SliderRow, { Entry = entries[i], LayoutOrder = i })
		end
		return children
	end, {})

	local worn = deriveWorn(manifest)
	local wornChildren = useMemo(function()
		if #worn == 0 then
			return {}
		end
		local children: { [string]: React.Element<any> } = {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),
		}
		for i = 1, #worn do
			children[`Worn_{i}`] = e(WornItem, { Editor = editor, Entry = worn[i], LayoutOrder = i })
		end
		return children
	end, { manifest } :: { any })

	local onPickGroup = useCallback(function(id: string)
		editor:SelectGroup(id)
	end, { editor })
	local onPickTab = useCallback(function(id: string)
		editor:SelectTab(id)
	end, { editor })
	local activeGroup = catalog.getGroup(group)

	local colorCells = useMemo(function()
		local children: { [string]: React.Element<any> } = {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, 1),
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
			}),
		}
		if colorsReady and editor._allColor then
			children.All = e(ColorCell, { Label = "All", Picker = editor._allColor, LayoutOrder = 0 })
			local entries = editor._colors
			for i = 1, #entries do
				children[`Color_{i}`] =
					e(ColorCell, { Label = entries[i].label, Picker = entries[i].picker, LayoutOrder = i })
			end
		end
		return children
	end, { colorsReady } :: { any })

	local results = useMemo(function()
		if #searchResults == 0 then
			return {}
		end
		local children: { [string]: React.Element<any> } = {
			UIGridLayout = e("UIGridLayout", {
				CellSize = UDim2.fromOffset(RESULT_CELL, RESULT_CELL + 18),
				CellPadding = UDim2.fromOffset(RESULT_GAP, RESULT_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			}),
		}
		local equippedSet = buildEquippedSet(manifest)
		for i = 1, #searchResults do
			children[`Result_{i}`] = e(ResultButton, {
				Editor = editor,
				Item = searchResults[i],
				Equipped = isEquipped(searchResults[i], equippedSet),
				LayoutOrder = i,
			})
		end
		return children
	end, { searchResults, manifest } :: { any })

	return e("Frame", {
		ref = anim.frameRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Position = anim.position,
		Visible = anim.visible,
		ZIndex = anim.zIndex,
	}, {
		Shadow = useShadow({ transparency = anim.transparency, zIndex = 0 }),
		UIStroke = e("UIStroke", { Color = strokeColor, Transparency = anim.strokeTransparency, Thickness = 1 }),
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		ErrorToast = errorText and e(ErrorToast, { Text = errorText, Nonce = errorNonce }) or nil,
		Inner = e("CanvasGroup", {
			BackgroundColor3 = backgroundColor,
			BackgroundTransparency = 0,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = anim.transparency,
			ZIndex = 1,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, PADDING),
				PaddingRight = UDim.new(0, PADDING),
				PaddingTop = UDim.new(0, PADDING),
				PaddingBottom = UDim.new(0, PADDING),
			}),
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			Header = e("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
				LayoutOrder = 0,
				[React.Event.InputBegan] = function(_: any, input: InputObject)
					onDragStart(input)
				end,
			}, {
				Title = e("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 17),
					Text = title,
					TextColor3 = titleColor,
					TextSize = 15,
					FontFace = FileController.Get("font", "semi_bold"),
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Subtitle = e("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 17),
					Size = UDim2.new(1, 0, 0, 13),
					Text = subtitle,
					TextColor3 = subtitleColor,
					TextSize = 11,
					FontFace = FileController.Get("font", "semi_bold"),
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),
			Body = e("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				LayoutOrder = 1,
			}, {
				UIFlexItem = e("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10),
				}),
				Left = e("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(0, LEFT_WIDTH, 1, 0),
					LayoutOrder = 0,
				}, {
					UIListLayout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, -1),
					}),
					TopFields = e("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 50),
						LayoutOrder = 0,
					}, {
						UIListLayout = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 6),
						}),
						Name = e("TextBox", {
							BackgroundColor3 = fieldBackground,
							BackgroundTransparency = 0.18,
							BorderSizePixel = 0,
							Size = UDim2.new(1, 0, 0, 22),
							Text = name,
							PlaceholderText = "Character name",
							PlaceholderColor3 = captionColor,
							TextColor3 = textColor,
							TextSize = 12,
							FontFace = FileController.Get("font", "semi_bold"),
							TextXAlignment = Enum.TextXAlignment.Left,
							ClearTextOnFocus = false,
							LayoutOrder = 0,
							[React.Change.Text] = function(rbx: TextBox)
								editor:SetName(rbx.Text)
							end,
						}, {
							UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
							UIStroke = e("UIStroke", {
								Color = fieldStroke,
								Thickness = 1,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							}),
							UIPadding = e("UIPadding", {
								PaddingLeft = UDim.new(0, 6),
								PaddingRight = UDim.new(0, 6),
							}),
						}),
						ImportRow = e("Frame", {
							BackgroundTransparency = 1,
							Size = UDim2.new(1, 0, 0, 22),
							LayoutOrder = 1,
						}, {
							UIListLayout = e("UIListLayout", {
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 6),
							}),
							Input = e("TextBox", {
								BackgroundColor3 = fieldBackground,
								BackgroundTransparency = 0.18,
								BorderSizePixel = 0,
								Size = UDim2.new(1, -68, 1, 0),
								Text = importField,
								PlaceholderText = "Import user id or username",
								PlaceholderColor3 = captionColor,
								TextColor3 = textColor,
								TextSize = 11,
								FontFace = FileController.Get("font", "semi_bold"),
								TextXAlignment = Enum.TextXAlignment.Left,
								ClearTextOnFocus = false,
								LayoutOrder = 0,
								[React.Change.Text] = function(rbx: TextBox)
									editor:SetImportField(rbx.Text)
								end,
								[React.Event.FocusLost] = function(rbx: TextBox, enterPressed: boolean)
									if enterPressed then
										editor:ImportFromInput(rbx.Text)
									end
								end,
							}, {
								UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
								UIStroke = e("UIStroke", {
									Color = fieldStroke,
									Thickness = 1,
									ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								}),
								UIPadding = e("UIPadding", {
									PaddingLeft = UDim.new(0, 6),
									PaddingRight = UDim.new(0, 6),
								}),
							}),
							Button = e(PillButton, {
								Text = busy and "..." or "Import",
								Width = 62,
								Height = 22,
								LayoutOrder = 1,
								OnClick = function()
									editor:ImportFromInput(importField)
								end,
							}),
						}),
					}),
					Viewport = e("Frame", {
						Size = UDim2.new(1, 0, 0, VIEWPORT_HEIGHT),
						BackgroundTransparency = 1,
						LayoutOrder = 1,
					}, {
						Box = e("Frame", {
							Position = UDim2.fromOffset(2, 3),
							Size = UDim2.new(1, -1, 1, 0),
							BackgroundColor3 = fieldBackground,
							BorderSizePixel = 0,
							ClipsDescendants = true,
						}, {
							UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
							UIStroke = e("UIStroke", {
								Color = fieldStroke,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Thickness = 1,
							}),
							Grid = e("Frame", {
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								ClipsDescendants = true,
								ZIndex = 0,
							}, gridChildren),
							World = e("ViewportFrame", {
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								Ambient = Color3.fromRGB(170, 170, 170),
								LightColor = Color3.fromRGB(255, 255, 255),
								LightDirection = Vector3.new(-0.4, -1, -0.5),
								Active = false,
								ZIndex = 1,
								ref = viewportRef,
							}, {
								Camera = e("Camera", { FieldOfView = 50, ref = cameraRef }),
								Model = e("WorldModel", { ref = worldModelRef }),
							}),
							Input = e("Frame", {
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Active = false,
								ZIndex = 5,
								ref = inputRef,
							}),
						}),
					}),
					Rig = e(RigToggle, { Editor = editor, Value = rigType, LayoutOrder = 2 }),
					Sliders = e("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, SLIDERS_HEIGHT),
						LayoutOrder = 3,
					}, sliders),
					WornHeading = e("TextLabel", {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 12),
						Text = "WEARING",
						TextColor3 = mutedColor,
						TextSize = 10,
						FontFace = FileController.Get("font", "semi_bold"),
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 4,
					}),
					Worn = e(
						"ScrollingFrame",
						{
							BackgroundColor3 = fieldBackground,
							BackgroundTransparency = 0.55,
							BorderSizePixel = 0,
							Size = UDim2.new(1, 0, 1, 0),
							CanvasSize = UDim2.new(),
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
							ScrollingDirection = Enum.ScrollingDirection.Y,
							ScrollBarThickness = #worn > 0 and 3 or 0,
							ScrollBarImageColor3 = scrollThumb,
							LayoutOrder = 5,
						},
						Sift.Dictionary.join({
							UIFlexItem = e("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
							UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
							UIStroke = e("UIStroke", {
								Color = fieldStroke,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Thickness = 1,
							}),
							Empty = #worn == 0 and e("TextLabel", {
								BackgroundTransparency = 1,
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.new(1, -8, 0, 16),
								Text = "Nothing added yet",
								TextColor3 = mutedColor,
								TextSize = 11,
								FontFace = FileController.Get("font", "semi_bold"),
								TextXAlignment = Enum.TextXAlignment.Center,
							}) or nil,
						}, wornChildren)
					),
				}),
				Right = e("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 0, 1, 0),
					LayoutOrder = 1,
				}, {
					UIFlexItem = e("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
					UIListLayout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					Groups = e(TabStrip, {
						Tabs = catalog.GROUPS,
						Selected = group,
						TextSize = 13,
						Height = TABS_HEIGHT,
						BottomInset = 0,
						ScrollBarThickness = 0,
						Divider = true,
						LayoutOrder = 0,
						OnPick = onPickGroup,
					}),
					Colors = group == "Body" and colorsReady and e("ScrollingFrame", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 0, COLORS_HEIGHT),
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.X,
						ScrollingDirection = Enum.ScrollingDirection.X,
						ScrollBarThickness = 0,
						LayoutOrder = 2,
					}, colorCells) or nil,
					SubTabs = activeGroup and #activeGroup.tabs > 1 and e(TabStrip, {
						Tabs = activeGroup.tabs,
						Selected = category,
						TextSize = 11,
						Height = SUBTABS_HEIGHT,
						BottomInset = 5,
						ScrollBarThickness = 2,
						LayoutOrder = 3,
						OnPick = onPickTab,
					}) or nil,
					Search = e("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, SEARCH_HEIGHT),
						LayoutOrder = 4,
						ZIndex = 10,
					}, {
						UIListLayout = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 8),
						}),
						Input = e("TextBox", {
							BackgroundColor3 = fieldBackground,
							BackgroundTransparency = 0.18,
							BorderSizePixel = 0,
							Size = UDim2.new(0, 0, 1, 0),
							Text = searchField,
							PlaceholderText = "Search the catalog",
							PlaceholderColor3 = captionColor,
							TextColor3 = textColor,
							TextSize = 11,
							FontFace = FileController.Get("font", "semi_bold"),
							TextXAlignment = Enum.TextXAlignment.Left,
							ClearTextOnFocus = false,
							LayoutOrder = 0,
							[React.Change.Text] = function(rbx: TextBox)
								editor:SetSearchField(rbx.Text)
							end,
							[React.Event.FocusLost] = function(_: any, enterPressed: boolean)
								if enterPressed then
									editor:Search()
								end
							end,
						}, {
							UIFlexItem = e("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
							UICorner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
							UIStroke = e("UIStroke", {
								Color = fieldStroke,
								Thickness = 1,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							}),
							UIPadding = e("UIPadding", {
								PaddingLeft = UDim.new(0, 6),
								PaddingRight = UDim.new(0, 6),
							}),
						}),
						Sort = e(SortDropdown, {
							Editor = editor,
							Current = sortId,
							LayoutOrder = 1,
							WindowRef = anim.frameRef,
						}),
						Button = e(PillButton, {
							Text = "Search",
							Width = 84,
							Height = SEARCH_HEIGHT,
							LayoutOrder = 2,
							OnClick = function()
								editor:Search()
							end,
						}),
					}),
					Results = e(
						"ScrollingFrame",
						{
							BackgroundColor3 = fieldBackground,
							BackgroundTransparency = 0.55,
							BorderSizePixel = 0,
							Size = UDim2.new(1, 0, 1, 0),
							CanvasSize = UDim2.new(),
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
							ScrollingDirection = Enum.ScrollingDirection.Y,
							ScrollBarThickness = #searchResults > 0 and 3 or 0,
							ScrollBarImageColor3 = scrollThumb,
							LayoutOrder = 6,
							[React.Change.CanvasPosition] = function(rbx: ScrollingFrame)
								if
									rbx.CanvasPosition.Y + rbx.AbsoluteWindowSize.Y
									>= rbx.AbsoluteCanvasSize.Y - 120
								then
									editor:LoadMore()
								end
							end,
						},
						Sift.Dictionary.join({
							UIFlexItem = e("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
							UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
							UIStroke = e("UIStroke", {
								Color = fieldStroke,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Thickness = 1,
							}),
							Empty = #searchResults == 0 and e(ShakeMessage, {
								Text = searching and "Searching..." or searchError or "No items found",
								IsError = (not searching) and searchError ~= nil,
								Nonce = searchErrorNonce,
								DangerColor = dangerColor,
								MutedColor = mutedColor,
							}) or nil,
						}, results)
					),
				}),
			}),
			Footer = e("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
				LayoutOrder = 2,
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				UIPadding = e("UIPadding", {
					PaddingTop = UDim.new(0, 6),
					PaddingRight = UDim.new(0, -1),
				}),
				Status = busy and e("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -160, 0, FOOTER_HEIGHT),
					Text = "Importing...",
					TextColor3 = mutedColor,
					TextSize = 11,
					FontFace = FileController.Get("font", "semi_bold"),
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 0,
				}) or nil,
				Cancel = e(PillButton, {
					Text = "Close",
					Width = 68,
					LayoutOrder = 1,
					OnClick = function()
						editor:Cancel()
					end,
				}),
				Save = e(PillButton, {
					Text = "Save",
					Primary = true,
					Width = 68,
					LayoutOrder = 2,
					OnClick = function()
						editor:Save()
					end,
				}),
			}),
		}),
	})
end
