local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local SPRING = require("@ui/util/spring")

local e = React.createElement
local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useMemo = React.useMemo
local useSpring = ReactRipple.useSpring
local useState = React.useState

local colors = themeState.colors.window.element

local INDICATOR_SIZE = 18
local INDICATOR_COLUMN = 26
local CHIP_HEIGHT = 20

export type GuideRendererProperties = {
	Guide: any,
	LayoutOrder: number?,
}

type Palette = {
	accent: Color3,
	accentSoft: Color3,
	accentStrong: Color3,
	caption: Color3,
	fieldBackground: Color3,
	fieldStroke: Color3,
	panel: Color3,
	panelStroke: Color3,
	text: Color3,
	textActive: Color3,
	hoverTint: number,
}

type ActionChipProperties = {
	Action: any,
	Palette: Palette,
	LayoutOrder: number,
}

local function ActionChip(properties: ActionChipProperties): React.Element<any>
	local palette = properties.Palette
	local hovered, setHovered = useState(false)
	local hoverBind, hoverSpring = useSpring(0, SPRING.subtle)

	useEffect(function()
		hoverSpring:setGoal(hovered and 1 or 0)
	end, { hovered })

	local icon = properties.Action.icon
	local children: { [string]: any } = {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
		UIStroke = e("UIStroke", {
			Color = hoverBind:map(function(value: number): Color3
				return palette.fieldStroke:Lerp(palette.accent, value * 0.6)
			end),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 7),
			PaddingRight = UDim.new(0, 7),
		}),
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Label = e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = properties.Action.label,
			FontFace = FileController.Get("font", "semi_bold"),
			TextSize = 11,
			TextColor3 = hoverBind:map(function(value: number): Color3
				return palette.text:Lerp(palette.textActive, value)
			end),
			LayoutOrder = 2,
		}),
	}
	if icon then
		children.Icon = e("ImageLabel", {
			Size = UDim2.fromOffset(12, 12),
			BackgroundTransparency = 1,
			Image = icon,
			ImageColor3 = hoverBind:map(function(value: number): Color3
				return palette.caption:Lerp(palette.textActive, value)
			end),
			LayoutOrder = 1,
		})
	end

	return e("TextButton", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, CHIP_HEIGHT),
		BackgroundColor3 = hoverBind:map(function(value: number): Color3
			return palette.fieldBackground:Lerp(Color3.new(1, 1, 1), value * palette.hoverTint)
		end),
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		LayoutOrder = properties.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
		[React.Event.MouseButton1Click] = properties.Action.onClick,
	}, children)
end

type StepRowProperties = {
	Step: any,
	Index: number,
	Done: boolean,
	Current: boolean,
	Palette: Palette,
	LayoutOrder: number,
}

local function StepRow(properties: StepRowProperties): React.Element<any>
	local palette = properties.Palette
	local doneBind, doneSpring = useSpring(properties.Done and 1 or 0, SPRING.smooth)
	local currentBind, currentSpring = useSpring(properties.Current and 1 or 0, SPRING.smooth)

	useEffect(function()
		doneSpring:setGoal(properties.Done and 1 or 0)
	end, { properties.Done })

	useEffect(function()
		currentSpring:setGoal(properties.Current and 1 or 0)
	end, { properties.Current })

	local stateBind = useMemo(function()
		return React.joinBindings({ doneBind, currentBind })
	end, { doneBind, currentBind } :: { any })

	local content: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Title = e("TextLabel", {
			Size = UDim2.new(1, 0, 0, INDICATOR_SIZE),
			BackgroundTransparency = 1,
			Text = properties.Step.title,
			FontFace = FileController.Get("font", "semi_bold"),
			TextSize = 12,
			TextColor3 = stateBind:map(function(values: { number }): Color3
				return palette.text:Lerp(palette.textActive, math.max(values[1], values[2]))
			end),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 1,
		}),
		Body = e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			Text = properties.Step.body,
			FontFace = FileController.Get("font", "light"),
			TextSize = 12,
			TextColor3 = palette.caption,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
		}),
	}
	if properties.Step.action then
		content.Action = e(ActionChip, {
			Action = properties.Step.action,
			Palette = palette,
			LayoutOrder = 3,
		})
	end

	return e("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = properties.LayoutOrder,
	}, {
		Indicator = e("Frame", {
			Size = UDim2.fromOffset(INDICATOR_SIZE, INDICATOR_SIZE),
			BackgroundColor3 = doneBind:map(function(value: number): Color3
				return palette.fieldBackground:Lerp(palette.accent, value)
			end),
			BorderSizePixel = 0,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Number = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = tostring(properties.Index),
				FontFace = FileController.Get("font", "semi_bold"),
				TextSize = 12,
				TextColor3 = currentBind:map(function(value: number): Color3
					return palette.caption:Lerp(palette.accent, value)
				end),
				TextTransparency = doneBind:map(function(value: number): number
					return value
				end),
			}),
			Check = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(10, 10),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, {
				UIScale = e("UIScale", {
					Scale = doneBind:map(function(value: number): number
						return 0.6 + value * 0.4
					end),
				}),
				Short = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(2, 6),
					Size = UDim2.fromOffset(5, 2),
					Rotation = 45,
					BackgroundColor3 = palette.panel,
					BackgroundTransparency = doneBind:map(function(value: number): number
						return 1 - value
					end),
					BorderSizePixel = 0,
				}, {
					UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
				Long = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(6, 5),
					Size = UDim2.fromOffset(10, 2),
					Rotation = -45,
					BackgroundColor3 = palette.panel,
					BackgroundTransparency = doneBind:map(function(value: number): number
						return 1 - value
					end),
					BorderSizePixel = 0,
				}, {
					UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
			}),
		}),
		Content = e("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(INDICATOR_COLUMN, 0),
			Size = UDim2.new(1, -INDICATOR_COLUMN, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, content),
	})
end

type BadgeProperties = {
	Config: any,
	Stage: number,
	Palette: Palette,
}

local function Badge(properties: BadgeProperties): React.Element<any>
	local palette = properties.Palette
	local badge = properties.Config
	local done = properties.Stage >= badge.doneAt
	local doneBind, doneSpring = useSpring(done and 1 or 0, SPRING.smooth)

	useEffect(function()
		doneSpring:setGoal(done and 1 or 0)
	end, { done })

	local colorBind = doneBind:map(function(value: number): Color3
		return palette.caption:Lerp(palette.accent, value)
	end)

	return e("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -1, 0, 1),
		Size = UDim2.new(0, 0, 0, 16),
		BackgroundColor3 = colorBind,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = e("UIStroke", {
			Color = colorBind,
			Transparency = 0.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		Label = e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = string.upper(done and badge.doneText or badge.pendingText),
			FontFace = FileController.Get("font", "bold"),
			TextSize = 10,
			TextColor3 = colorBind,
			ZIndex = 2,
		}),
	})
end

return function(properties: GuideRendererProperties): React.Element<any>
	local element = properties.Guide
	local config = element._config
	local stage = useAt(config.stage) :: number

	local palette: Palette = {
		accent = useAt(colors.accent),
		accentSoft = useAt(colors.accentSoft),
		accentStrong = useAt(colors.accentStrong),
		caption = useAt(colors.caption),
		fieldBackground = useAt(colors.fieldBackground),
		fieldStroke = useAt(colors.fieldStroke),
		panel = useAt(colors.panel),
		panelStroke = useAt(colors.panelStroke),
		text = useAt(colors.text),
		textActive = useAt(colors.textActive),
		hoverTint = useAt(themeState.other.hoverTint),
	}

	local steps = config.steps
	local currentIndex = #steps + 1
	for i = 1, #steps do
		if stage < steps[i].doneAt then
			currentIndex = i
			break
		end
	end

	local stepChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 9),
		}),
	}

	for i = 1, #steps do
		stepChildren[`Step_{i}`] = e(StepRow, {
			Step = steps[i],
			Index = i,
			Done = stage >= steps[i].doneAt,
			Current = i == currentIndex,
			Palette = palette,
			LayoutOrder = i,
		})
	end

	return e("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = palette.panel,
		BorderSizePixel = 0,
		LayoutOrder = properties.LayoutOrder,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = e("UIStroke", {
			Color = palette.panelStroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0, 9),
			PaddingBottom = UDim.new(0, 9),
			PaddingLeft = UDim.new(0, 9),
			PaddingRight = UDim.new(0, 9),
		}),
		Badge = config.badge and e(Badge, {
			Config = config.badge,
			Stage = stage,
			Palette = palette,
		}) or nil,
		Steps = e("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, stepChildren),
	})
end
