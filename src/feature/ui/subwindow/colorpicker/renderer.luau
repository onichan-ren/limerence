local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local themeState = require("@ui/theme/themeState")
local FileController = require("@src/feature/file/FileController")
local useContext = require("@ui/hook/useContext")
local useDragValue = require("@ui/hook/useDragValue")
local useSubwindowAnimation = require("@ui/hook/useSubwindowAnimation")
local useShadow = require("@ui/hook/useShadow")
local useAdvColor = require("@ui/hook/useAdvColor")
local useClickOutside = require("@ui/hook/useClickOutside")
local cursor = require("@ui/util/cursor")
local colorClipboard = require("@ui/util/colorClipboard")
local inputHandler = require("@ui/util/inputHandler")
local SPRING = require("@ui/util/spring")
local animations = require("@ui/window/element/colorpicker/animations")

local subwindowColors = themeState.colors.subwindow
local elColors = themeState.colors.window.element

local useEffect = React.useEffect
local useState = React.useState
local useRef = React.useRef
local useMemo = React.useMemo
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local joinBindings = React.joinBindings
local peek = Charm.peek
local e = React.createElement
local memo = React.memo

local MAIN_WIDTH = 200
local ADV_WIDTH = 210
local PANEL_GAP = 8

local OUTER_PAD_X = 10
local OUTER_PAD_Y = 10

local TITLE_HEIGHT = 14
local DIVIDER_HEIGHT = 2
local DIVIDER_OFFSET_Y = 18

local SECTION_GAP = 10
local ROW_GAP = 10
local ROW_HEIGHT = 18

local LABEL_TEXT_SIZE = 12
local CONTROL_TEXT_SIZE = 11

local SV_HEIGHT = 140
local HUE_HEIGHT = 6
local TRANSPARENCY_HEIGHT = 8
local KEYPOINTS_HEIGHT = 12

local FIELD_HEIGHT = 18
local HEX_FIELD_WIDTH = 74
local RGB_FIELD_WIDTH = 34

local ROW_LABEL_WIDTH = 56
local ROW_VALUE_MIN = 30
local ROW_VALUE_MAX = 54
local ROW_BAR_HEIGHT = 4

local DROPDOWN_HEIGHT = 18

local function snapScalarSpring(spring: any, value: number): ()
	spring:setPosition(value)
	spring:setGoal(value)
end

local HUE_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(0.166, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(0.666, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
})

local function rgbComponents(c3: Color3): (number, number, number)
	local r = math.clamp(math.round(c3.R * 255), 0, 255)
	local g = math.clamp(math.round(c3.G * 255), 0, 255)
	local b = math.clamp(math.round(c3.B * 255), 0, 255)
	return r, g, b
end

local function formatHex(c3: Color3): string
	local r, g, b = rgbComponents(c3)
	return string.format("%02X%02X%02X", r, g, b)
end

local function useBoolAtom(value: boolean): any
	local atom = useMemo(function()
		return Charm.atom(false)
	end, {})
	useEffect(function()
		atom(value)
	end, { value })
	return atom
end

local Keypoint = memo(function(props: {
	Colorpicker: any,
	Keypoint: ColorSequenceKeypoint,
	Index: number,
	KeypointCount: number,
	IsActive: boolean,
}): React.Element<any>
	local cp = props.Colorpicker
	local kp = props.Keypoint
	local idx = props.Index
	local count = props.KeypointCount
	local isActive = props.IsActive

	local bind, spring = useSpring(isActive and 1 or 0, {
		tension = 700,
		friction = 54,
	})

	useEffect(function()
		spring:setGoal(isActive and 1 or 0)
	end, { isActive })

	local onContext = useContext(function()
		local items: { any } = {}
		table.insert(items, {
			Label = "Copy Color",
			Icon = FileController.Get("image", "copy_link"),
			Callback = function()
				colorClipboard.set(kp.Value)
			end,
		})
		local clipColor = colorClipboard.peek()
		if typeof(clipColor) == "Color3" then
			table.insert(items, {
				Label = "Paste Color",
				Icon = FileController.Get("image", "load"),
				Callback = function()
					local pasted = colorClipboard.peek()
					if typeof(pasted) ~= "Color3" then
						return
					end
					cp:SetActiveKeypoint(idx)
					cp:SetColorFromRGB(rgbComponents(pasted))
				end,
			})
		end
		local canDelete = idx > 1 and idx < count
		if canDelete then
			table.insert(items, {
				Label = "Delete Keypoint",
				Icon = FileController.Get("image", "delete"),
				Callback = function()
					cp:RemoveKeypoint(idx)
				end,
			})
		end
		return items
	end)

	return e("TextButton", {
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = kp.Value,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(kp.Time, 0.5),
		AnchorPoint = Vector2.new(kp.Time, 0.5),
		Text = "",
		AutoButtonColor = false,
		Active = false,
		ZIndex = 2,
		[React.Event.MouseButton1Click] = function()
			cp:SetActiveKeypoint(idx)
		end,
		[React.Event.InputBegan] = inputHandler(onContext),
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		UIStroke = e("UIStroke", {
			Thickness = bind:map(function(value: number)
				return 1 + value * 1.5
			end),
			Color = Color3.fromRGB(255, 255, 255),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end)

local function KeypointsFrame(props: { Colorpicker: any, LayoutOrder: number }): React.Element<any>
	local cp = props.Colorpicker

	local color = useAt(cp._color)
	local activeIdx = useAt(cp._activeKeypoint)
	local keypointIds = useAt(cp._keypointIds)

	local sequence: ColorSequence = typeof(color) == "ColorSequence" and color
		or ColorSequence.new(Color3.fromRGB(255, 255, 255))

	local keypointCount = #sequence.Keypoints
	local renderedKeypoints: { [string]: React.Element<any> } = {}
	for i, kp in sequence.Keypoints do
		local id = keypointIds[i] or i
		renderedKeypoints[`Keypoint_{id}`] = e(Keypoint, {
			Colorpicker = cp,
			Keypoint = kp,
			Index = i,
			KeypointCount = keypointCount,
			IsActive = i == activeIdx,
		})
	end

	local onBarContext = useContext(function(rbx: TextButton, input: InputObject)
		local origin = rbx.AbsolutePosition
		local size = rbx.AbsoluteSize
		local sizeX = size.X > 0 and size.X or 1
		local alpha = math.clamp((input.Position.X - origin.X) / sizeX, 0, 1)

		return {
			{
				Label = "Add Keypoint",
				Icon = FileController.Get("image", "drop"),
				Callback = function()
					cp:AddKeypoint(alpha)
				end,
			},
		}
	end)

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, KEYPOINTS_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
	}, {
		Bar = e(
			"TextButton",
			{
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				Active = false,
				[React.Event.InputBegan] = function(rbx: TextButton, input: InputObject)
					if input.UserInputType == Enum.UserInputType.MouseButton2 then
						onBarContext(rbx, input)
						return
					end
				end,
			},
			Sift.Dictionary.join({
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
				UIGradient = e("UIGradient", {
					Color = sequence,
				}),
			}, renderedKeypoints)
		),
	})
end

local function SVFrame(props: { Colorpicker: any, LayoutOrder: number, SnapEpoch: number }): React.Element<any>
	local cp = props.Colorpicker

	local stroke = useAt(subwindowColors.stroke)
	local hue = useAt(cp._hue)
	local saturation = useAt(cp._saturation) or 0
	local value = useAt(cp._value)

	local hueBind, hueSpring = useSpring(hue, SPRING.snap)
	local satBind, satSpring = useSpring(saturation, SPRING.snap)
	local valBind, valSpring = useSpring(value, SPRING.snap)

	useEffect(function()
		hueSpring:setGoal(hue)
	end, { hue })
	useEffect(function()
		satSpring:setGoal(saturation)
	end, { saturation })
	useEffect(function()
		valSpring:setGoal(value)
	end, { value })

	useEffect(function()
		if props.SnapEpoch < 1 then
			return
		end
		local h = peek(cp._hue)
		local s = peek(cp._saturation) or 0
		local v = peek(cp._value)
		snapScalarSpring(hueSpring, h)
		snapScalarSpring(satSpring, s)
		snapScalarSpring(valSpring, v)
	end, { props.SnapEpoch })

	local bgColorBind = hueBind:map(function(h: number)
		return Color3.fromHSV(h, 1, 1)
	end)

	local posBind = joinBindings({ satBind, valBind }):map(function(values)
		local s = math.clamp(values[1], 0, 1)
		local v = math.clamp(values[2], 0, 1)
		return UDim2.fromScale(s, 1 - v)
	end)
	local anchorBind = joinBindings({ satBind, valBind }):map(function(values)
		local s = math.clamp(values[1], 0, 1)
		local v = math.clamp(values[2], 0, 1)
		return Vector2.new(s, 1 - v)
	end)

	local onDragStart = useDragValue(function(alpha: Vector2)
		cp:SetSaturationValue(alpha.X, 1 - alpha.Y)
	end)

	return e("ImageLabel", {
		Image = FileController.Get("image", "color"),
		Size = UDim2.new(1, 0, 0, SV_HEIGHT),
		BackgroundColor3 = bgColorBind,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		[React.Event.InputBegan] = function(rbx: ImageLabel, input: InputObject)
			onDragStart(rbx, input)
		end,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIStroke = e("UIStroke", {
			Thickness = 1,
			Color = stroke,
		}),
		Dragger = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 8, 0, 8),
			AnchorPoint = anchorBind,
			Position = posBind,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			UIStroke = e("UIStroke", {
				Thickness = 1.5,
				Color = Color3.fromRGB(255, 255, 255),
			}),
		}),
	})
end

local function HueFrame(props: { Colorpicker: any, LayoutOrder: number, SnapEpoch: number }): React.Element<any>
	local cp = props.Colorpicker

	local hue = useAt(cp._hue)
	local hueBind, hueSpring = useSpring(hue, SPRING.snap)

	useEffect(function()
		hueSpring:setGoal(hue)
	end, { hue })

	useEffect(function()
		if props.SnapEpoch < 1 then
			return
		end
		snapScalarSpring(hueSpring, peek(cp._hue))
	end, { props.SnapEpoch })

	local posBind = hueBind:map(function(h: number)
		return UDim2.fromScale(math.clamp(h, 0, 1), 0.5)
	end)
	local anchorBind = hueBind:map(function(h: number)
		return Vector2.new(math.clamp(h, 0, 1), 0.5)
	end)
	local colorBind = hueBind:map(function(h: number)
		return Color3.fromHSV(h, 1, 1)
	end)

	local onDragStart = useDragValue(function(alpha: Vector2)
		cp:SetHue(alpha.X)
	end)

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, HUE_HEIGHT),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		[React.Event.InputBegan] = function(rbx: Frame, input: InputObject)
			onDragStart(rbx, input)
		end,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		UIGradient = e("UIGradient", {
			Color = HUE_GRADIENT,
		}),
		Dragger = e("Frame", {
			BackgroundTransparency = 0,
			BackgroundColor3 = colorBind,
			BorderSizePixel = 0,
			AnchorPoint = anchorBind,
			Position = posBind,
			Size = UDim2.new(0, 8, 0, 8),
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			UIStroke = e("UIStroke", {
				Thickness = 1.5,
				Color = Color3.fromRGB(255, 255, 255),
			}),
		}),
	})
end

local function TransparencyFrame(
	props: { Colorpicker: any, LayoutOrder: number, SnapEpoch: number }
): React.Element<any>
	local cp = props.Colorpicker

	local transparency = useAt(cp._transparency) or 0
	local tBind, tSpring = useSpring(transparency, SPRING.snap)

	useEffect(function()
		tSpring:setGoal(transparency)
	end, { transparency })

	useEffect(function()
		if props.SnapEpoch < 1 then
			return
		end
		snapScalarSpring(tSpring, peek(cp._transparency) or 0)
	end, { props.SnapEpoch })

	local posBind = tBind:map(function(t: number)
		return UDim2.fromScale(math.clamp(t, 0, 1), 0.5)
	end)
	local anchorBind = tBind:map(function(t: number)
		return Vector2.new(math.clamp(t, 0, 1), 0.5)
	end)

	local onDragStart = useDragValue(function(alpha: Vector2)
		cp:SetTransparency(alpha.X)
	end)

	return e("ImageLabel", {
		Size = UDim2.new(1, 0, 0, TRANSPARENCY_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = FileController.Get("image", "transparency"),
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.new(0, 8, 0, 8),
		LayoutOrder = props.LayoutOrder,
		[React.Event.InputBegan] = function(rbx: ImageLabel, input: InputObject)
			onDragStart(rbx, input)
		end,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		UIGradient = e("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
		Dragger = e("Frame", {
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(136, 136, 136),
			AnchorPoint = anchorBind,
			Position = posBind,
			Size = UDim2.new(0, 2, 0, 8),
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			UIStroke = e("UIStroke", {
				Thickness = 1.5,
				Color = Color3.fromRGB(255, 255, 255),
			}),
		}),
	})
end

local function TextField(props: {
	Text: string,
	Width: number,
	OnCommit: (string) -> boolean?,
	Placeholder: string?,
	LayoutOrder: number?,
	Prefix: string?,
}): React.Element<any>
	local mutedColor = useAt(elColors.caption)

	local focused, setFocused = useState(false)
	local activeAtom = useBoolAtom(focused)

	local bg = useAdvColor(elColors.fieldBackground, elColors.fieldBackgroundActive, activeAtom)
	local stroke = useAdvColor(elColors.fieldStroke, elColors.fieldStrokeActive, activeAtom)
	local textColor = useAdvColor(elColors.text, elColors.text, activeAtom)

	local draft, setDraft = useState(props.Text)

	useEffect(function()
		setDraft(props.Text)
	end, { props.Text })

	return e("Frame", {
		BackgroundColor3 = bg.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(props.Width, FIELD_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			bg.onMouseEnter()
			stroke.onMouseEnter()
			textColor.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			bg.onMouseLeave()
			stroke.onMouseLeave()
			textColor.onMouseLeave()
		end,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = e("UIStroke", {
			Color = stroke.binding,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
		Prefix = props.Prefix and e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = props.Prefix,
			TextSize = CONTROL_TEXT_SIZE,
			TextColor3 = mutedColor,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 0,
		}) or nil,
		Input = e("TextBox", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Text = draft,
			TextSize = CONTROL_TEXT_SIZE,
			TextColor3 = textColor.binding,
			PlaceholderText = props.Placeholder or "",
			PlaceholderColor3 = mutedColor,
			FontFace = FileController.Get("font", "semi_bold"),
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 1,
			[React.Change.Text] = function(rbx: TextBox)
				setDraft(rbx.Text)
			end,
			[React.Event.Focused] = function()
				setFocused(true)
			end,
			[React.Event.FocusLost] = function(rbx: TextBox)
				setFocused(false)
				local ok = props.OnCommit(rbx.Text)
				if ok == false then
					setDraft(props.Text)
				end
			end,
		}, {
			UIFlexItem = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
			}),
		}),
	})
end

local function InputsFrame(props: { Colorpicker: any, LayoutOrder: number }): React.Element<any>
	local cp = props.Colorpicker

	local hue = useAt(cp._hue)
	local saturation = useAt(cp._saturation) or 0
	local value = useAt(cp._value)

	local labelColor = useAt(elColors.caption)

	local c3 = Color3.fromHSV(hue, saturation, value)
	local r, g, b = rgbComponents(c3)
	local hex = formatHex(c3)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.LayoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		HexRow = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, FIELD_HEIGHT),
			LayoutOrder = 0,
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 24, 1, 0),
				Text = "Hex",
				TextSize = LABEL_TEXT_SIZE,
				TextColor3 = labelColor,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 0,
			}),
			Field = e(TextField, {
				Text = hex,
				Width = HEX_FIELD_WIDTH,
				Prefix = "#",
				Placeholder = "RRGGBB",
				LayoutOrder = 1,
				OnCommit = function(text: string): boolean
					return cp:SetColorFromHex(text)
				end,
			}),
		}),
		RgbRow = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, FIELD_HEIGHT),
			LayoutOrder = 1,
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 24, 1, 0),
				Text = "RGB",
				TextSize = LABEL_TEXT_SIZE,
				TextColor3 = labelColor,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 0,
			}),
			R = e(TextField, {
				Text = tostring(r),
				Width = RGB_FIELD_WIDTH,
				Placeholder = "R",
				LayoutOrder = 1,
				OnCommit = function(text: string): boolean
					local n = tonumber(text)
					if n == nil then
						return false
					end
					local ri = math.floor(n + 0.5)
					if ri < 0 or ri > 255 then
						return false
					end
					cp:SetColorFromRGB(ri, g, b)
					return true
				end,
			}),
			G = e(TextField, {
				Text = tostring(g),
				Width = RGB_FIELD_WIDTH,
				Placeholder = "G",
				LayoutOrder = 2,
				OnCommit = function(text: string): boolean
					local n = tonumber(text)
					if n == nil then
						return false
					end
					local ri = math.floor(n + 0.5)
					if ri < 0 or ri > 255 then
						return false
					end
					cp:SetColorFromRGB(r, ri, b)
					return true
				end,
			}),
			B = e(TextField, {
				Text = tostring(b),
				Width = RGB_FIELD_WIDTH,
				Placeholder = "B",
				LayoutOrder = 3,
				OnCommit = function(text: string): boolean
					local n = tonumber(text)
					if n == nil then
						return false
					end
					local ri = math.floor(n + 0.5)
					if ri < 0 or ri > 255 then
						return false
					end
					cp:SetColorFromRGB(r, g, ri)
					return true
				end,
			}),
		}),
	})
end

local function SliderRow(props: {
	Label: string,
	Alpha: number,
	FormattedValue: string,
	OnDragAlpha: (alpha: number) -> (),
	OnCommitText: (text: string) -> (),
	OnNudge: (direction: number) -> (),
	IsActive: boolean,
	LayoutOrder: number,
	SnapEpoch: number?,
}): React.Element<any>
	local activeAtom = useBoolAtom(props.IsActive)

	local labelColor = useAt(elColors.text)
	local barColor = useAdvColor(elColors.panel, elColors.panel, activeAtom)
	local fillColor = useAdvColor(elColors.accentSoft, elColors.accent, activeAtom)
	local circleColor = useAdvColor(elColors.thumb, elColors.thumbActive, activeAtom)
	local boxColor = useAdvColor(elColors.fieldBackground, elColors.fieldBackgroundActive, activeAtom)
	local strokeColor = useAdvColor(elColors.fieldStroke, elColors.fieldStrokeActive, activeAtom)
	local textColor = useAdvColor(elColors.caption, elColors.captionActive, activeAtom)

	local alpha = math.clamp(props.Alpha, 0, 1)
	local alphaBind, alphaSpring = useSpring(alpha, SPRING.snap)

	useEffect(function()
		alphaSpring:setGoal(alpha)
	end, { alpha })

	useEffect(function()
		local epoch = props.SnapEpoch or 0
		if epoch < 1 then
			return
		end
		snapScalarSpring(alphaSpring, math.clamp(props.Alpha, 0, 1))
	end, { props.SnapEpoch })

	local onDragStart = useDragValue(function(a: Vector2)
		props.OnDragAlpha(a.X)
	end)

	local textboxRef = useRef(nil :: TextBox?)
	local boxRef = useRef(nil :: GuiObject?)
	local isFocused, setFocused = useState(false)

	local onCommitRef = useRef(props.OnCommitText)
	onCommitRef.current = props.OnCommitText

	useEffect(function()
		local box = textboxRef.current
		if not box then
			return nil
		end

		local connections = {
			box.Focused:Connect(function()
				box.Text = ""
				setFocused(true)
			end),
			box.FocusLost:Connect(function()
				setFocused(false)
				onCommitRef.current(box.Text)
				box.Text = ""
			end),
		}

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end :: any
	end, {})

	useClickOutside(boxRef, isFocused, function()
		if textboxRef.current then
			textboxRef.current:ReleaseFocus()
		end
	end)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = props.LayoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, ROW_LABEL_WIDTH, 1, 0),
			Text = props.Label,
			TextSize = LABEL_TEXT_SIZE,
			TextColor3 = labelColor,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 0,
		}),
		Slider = e("TextButton", {
			Size = UDim2.fromOffset(0, ROW_BAR_HEIGHT),
			BackgroundColor3 = barColor.binding,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Text = "",
			Active = false,
			AutoButtonColor = false,
			LayoutOrder = 1,
			[React.Event.MouseEnter] = function()
				barColor.onMouseEnter()
				fillColor.onMouseEnter()
				circleColor.onMouseEnter()
			end,
			[React.Event.MouseLeave] = function()
				barColor.onMouseLeave()
				fillColor.onMouseLeave()
				circleColor.onMouseLeave()
			end,
			[React.Event.InputBegan] = inputHandler(function(rbx, input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
					return
				end
				onDragStart(rbx, input)
			end),
			[React.Event.MouseWheelForward] = function()
				props.OnNudge(1)
			end,
			[React.Event.MouseWheelBackward] = function()
				props.OnNudge(-1)
			end,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UIFlexItem = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
				ItemLineAlignment = Enum.ItemLineAlignment.Automatic,
			}),
			Fill = e("Frame", {
				Size = alphaBind:map(function(a: number)
					return UDim2.fromScale(a, 1)
				end),
				BackgroundColor3 = fillColor.binding,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			Circle = e("Frame", {
				Size = UDim2.fromOffset(8, 8),
				Position = alphaBind:map(function(a: number)
					return UDim2.fromScale(a, 0.5)
				end),
				AnchorPoint = alphaBind:map(function(a: number)
					return Vector2.new(a, 0.5)
				end),
				BackgroundColor3 = circleColor.binding,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}),
		Box = e("TextButton", {
			ref = boxRef,
			Size = UDim2.fromOffset(0, FIELD_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = boxColor.binding,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			AutoButtonColor = false,
			Text = "",
			Active = false,
			ClipsDescendants = true,
			[React.Event.MouseEnter] = function()
				boxColor.onMouseEnter()
				strokeColor.onMouseEnter()
				textColor.onMouseEnter()
			end,
			[React.Event.MouseLeave] = function()
				boxColor.onMouseLeave()
				strokeColor.onMouseLeave()
				textColor.onMouseLeave()
			end,
			[React.Event.MouseButton1Click] = function()
				if textboxRef.current then
					textboxRef.current:CaptureFocus()
				end
			end,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
			}),
			UISizeConstraint = e("UISizeConstraint", {
				MinSize = Vector2.new(ROW_VALUE_MIN, FIELD_HEIGHT),
				MaxSize = Vector2.new(ROW_VALUE_MAX, FIELD_HEIGHT),
			}),
			UIStroke = e("UIStroke", {
				Color = strokeColor.binding,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			Text = e("TextBox", {
				ref = textboxRef,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 20, 0, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				Text = isFocused and "" or props.FormattedValue,
				FontFace = FileController.Get("font", "semi_bold"),
				TextSize = CONTROL_TEXT_SIZE,
				TextColor3 = textColor.binding,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ClearTextOnFocus = true,
				Interactable = isFocused,
				MultiLine = false,
				TextWrapped = false,
			}),
		}),
	})
end

local function AnimationRow(props: {
	Colorpicker: any,
	IsSequence: boolean,
	HasTransparency: boolean,
	LayoutOrder: number,
}): React.Element<any>
	local cp = props.Colorpicker
	local source = cp._animationSource

	local label = useAt(source._state)
	local isOpen = useAt(source._open)
	local labelTextColor = useAt(elColors.text)

	local bgColor = useAdvColor(elColors.panel, elColors.surface, source._open)
	local strokeColor = useAdvColor(elColors.panelStroke, elColors.accentStrong, source._open)
	local imageColor = useAdvColor(elColors.icon, elColors.iconActive, source._open)
	local textColor = useAdvColor(elColors.caption, elColors.text, source._open)

	local rotationBind, rotationSpring = useSpring(0, SPRING.snap)

	useEffect(function()
		rotationSpring:setGoal(isOpen and 1 or 0)
	end, { isOpen })

	local function toggle(): ()
		if peek(source._open) then
			source.ClosePicker()
			return
		end
		local options = animations.getApplicableLabels(props.IsSequence, props.HasTransparency)
		source.OpenPicker(options, cursor.getPosition())
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = props.LayoutOrder,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, ROW_LABEL_WIDTH, 1, 0),
			Text = "Animation",
			TextSize = LABEL_TEXT_SIZE,
			TextColor3 = labelTextColor,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 0,
		}),
		Button = e("TextButton", {
			BorderSizePixel = 0,
			Size = UDim2.new(1, -(ROW_LABEL_WIDTH + 6), 0, DROPDOWN_HEIGHT),
			LayoutOrder = 1,
			BackgroundColor3 = bgColor.binding,
			Text = "",
			Active = false,
			AutoButtonColor = false,
			[React.Event.MouseEnter] = function()
				bgColor.onMouseEnter()
				strokeColor.onMouseEnter()
				imageColor.onMouseEnter()
				textColor.onMouseEnter()
			end,
			[React.Event.MouseLeave] = function()
				bgColor.onMouseLeave()
				strokeColor.onMouseLeave()
				imageColor.onMouseLeave()
				textColor.onMouseLeave()
			end,
			[React.Event.MouseButton1Click] = toggle,
		}, {
			UIStroke = e("UIStroke", {
				Color = strokeColor.binding,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 3) }),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 2),
				PaddingBottom = UDim.new(0, 2),
			}),
			Image = e("ImageLabel", {
				Size = UDim2.fromOffset(8, 8),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Image = FileController.Get("image", "down_arrow"),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ImageColor3 = imageColor.binding,
				Rotation = rotationBind:map(function(value: number)
					return value * 180
				end),
			}),
			Text = e("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = FileController.Get("font", "semi_bold"),
				TextColor3 = textColor.binding,
				TextSize = CONTROL_TEXT_SIZE,
				Text = label,
				Size = UDim2.new(1, -12, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		}),
	})
end

local function CogButton(props: {
	IsOpen: boolean,
	OnClick: () -> (),
}): React.Element<any>
	local openAtom = useBoolAtom(props.IsOpen)

	local iconColor = useAdvColor(subwindowColors.image, subwindowColors.title, openAtom)

	local rotBind, rotSpring = useSpring(0, SPRING.smooth)
	useEffect(function()
		rotSpring:setGoal(props.IsOpen and 90 or 0)
	end, { props.IsOpen })

	return e("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		[React.Event.MouseEnter] = function()
			iconColor.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			iconColor.onMouseLeave()
		end,
		[React.Event.MouseButton1Click] = props.OnClick,
	}, {
		Icon = e("ImageLabel", {
			BackgroundTransparency = 1,
			Image = FileController.Get("image", "cog"),
			ImageColor3 = iconColor.binding,
			Size = UDim2.fromOffset(12, 12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = rotBind,
		}),
	})
end

local function MainPanel(props: {
	Colorpicker: any,
	IsSequence: boolean,
	HasTransparency: boolean,
	AdvancedOpen: boolean,
	CanShowAdvanced: boolean,
	Anim: any,
	SnapEpoch: number,
}): React.Element<any>
	local cp = props.Colorpicker

	local title = useAt(cp._title)

	local backgroundColor = useAt(subwindowColors.background)
	local strokeColor = useAt(subwindowColors.stroke)
	local titleColor = useAt(subwindowColors.title)
	local dividerColor = useAt(subwindowColors.divider)

	local children: { [string]: React.Element<any>? } = {
		UIStroke = e("UIStroke", {
			Color = strokeColor,
			Transparency = props.Anim.strokeTransparency,
			Thickness = 1,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, OUTER_PAD_X),
			PaddingRight = UDim.new(0, OUTER_PAD_X),
			PaddingTop = UDim.new(0, OUTER_PAD_Y),
			PaddingBottom = UDim.new(0, OUTER_PAD_Y),
		}),
		UIListLayout = e("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, SECTION_GAP),
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		TitleFrame = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, TITLE_HEIGHT + DIVIDER_HEIGHT + 2),
			LayoutOrder = 0,
		}, {
			Title = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -22, 0, TITLE_HEIGHT),
				Text = title,
				TextColor3 = titleColor,
				FontFace = FileController.Get("font", "semi_bold"),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			AdvancedButton = props.CanShowAdvanced and e(CogButton, {
				IsOpen = props.AdvancedOpen,
				OnClick = function()
					cp:ToggleAdvanced()
				end,
			}) or nil,
			Divider = e("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = dividerColor,
				Size = UDim2.new(1, 0, 0, DIVIDER_HEIGHT),
				Position = UDim2.fromOffset(0, DIVIDER_OFFSET_Y),
			}),
		}),
	}

	local layoutOrder = 1

	if props.IsSequence then
		children.KeypointsFrame = e(KeypointsFrame, {
			Colorpicker = cp,
			LayoutOrder = layoutOrder,
		})
		layoutOrder += 1
	end

	children.SVFrame = e(SVFrame, {
		Colorpicker = cp,
		LayoutOrder = layoutOrder,
		SnapEpoch = props.SnapEpoch,
	})
	layoutOrder += 1

	children.HueFrame = e(HueFrame, {
		Colorpicker = cp,
		LayoutOrder = layoutOrder,
		SnapEpoch = props.SnapEpoch,
	})
	layoutOrder += 1

	if props.HasTransparency then
		children.TransparencyFrame = e(TransparencyFrame, {
			Colorpicker = cp,
			LayoutOrder = layoutOrder,
			SnapEpoch = props.SnapEpoch,
		})
		layoutOrder += 1
	end

	children.InputsFrame = e(InputsFrame, {
		Colorpicker = cp,
		LayoutOrder = layoutOrder,
	})

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, MAIN_WIDTH, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 0,
	}, {
		Shadow = useShadow({
			transparency = props.Anim.transparency,
			zIndex = 0,
		}),
		Body = e("CanvasGroup", {
			BackgroundTransparency = 0,
			BackgroundColor3 = backgroundColor,
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.Y,
			GroupTransparency = props.Anim.transparency,
			ZIndex = 1,
		}, children),
	})
end

local function CollapsibleRow(props: {
	Shown: boolean,
	LayoutOrder: number,
	Children: any,
}): React.Element<any>
	local rowSpace = ROW_HEIGHT + ROW_GAP
	local bind, spring = useSpring(props.Shown and 1 or 0, SPRING.smooth)

	useEffect(function()
		spring:setGoal(props.Shown and 1 or 0)
	end, { props.Shown })

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = bind:map(function(v: number)
			return v < 0.999
		end),
		Size = bind:map(function(v: number)
			return UDim2.new(1, 0, 0, math.max(0, math.round(rowSpace * v) - ROW_GAP))
		end),
		Visible = bind:map(function(v: number)
			return rowSpace * v >= ROW_GAP
		end),
		LayoutOrder = props.LayoutOrder,
	}, props.Children)
end

local function AdvancedPanel(props: {
	Colorpicker: any,
	IsSequence: boolean,
	HasTransparency: boolean,
	Anim: any,
	OpenBind: any,
	SnapEpoch: number,
}): React.Element<any>
	local cp = props.Colorpicker

	local rotation = useAt(cp._rotation)
	local speed = useAt(cp._speed)
	local animation = useAt(cp._animation)

	local backgroundColor = useAt(subwindowColors.background)
	local strokeColor = useAt(subwindowColors.stroke)
	local titleColor = useAt(subwindowColors.title)
	local dividerColor = useAt(subwindowColors.divider)

	local rotationAlpha = math.clamp(rotation :: number / 360, 0, 1)
	local speedAlpha = math.clamp((speed :: number - 0.1) / 4.9, 0, 1)
	local hasMotion = animations.hasMotion(animation)

	local bodyTransparency = joinBindings({ props.Anim.transparency, props.OpenBind }):map(function(values)
		local panelT = values[1]
		local open = values[2]
		return 1 - (1 - panelT) * math.clamp(open, 0, 1)
	end)
	local bodyStrokeTransparency = joinBindings({ props.Anim.strokeTransparency, props.OpenBind }):map(function(values)
		local panelT = values[1]
		local open = values[2]
		return 1 - (1 - panelT) * math.clamp(open, 0, 1)
	end)
	local shadowTransparency = joinBindings({ props.Anim.transparency, props.OpenBind }):map(function(values)
		local panelT = values[1]
		local open = values[2]
		return 1 - (1 - panelT) * math.clamp(open, 0, 1)
	end)
	local positionBind = props.OpenBind:map(function(open: number)
		local o = math.clamp(open, 0, 1)
		return UDim2.fromOffset(math.round(-(1 - o) * 10), 0)
	end)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, ADV_WIDTH, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = positionBind,
	}, {
		Shadow = useShadow({
			transparency = shadowTransparency,
			zIndex = 0,
		}),
		Body = e("CanvasGroup", {
			BackgroundTransparency = 0,
			BackgroundColor3 = backgroundColor,
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.Y,
			GroupTransparency = bodyTransparency,
			ZIndex = 1,
		}, {
			UIStroke = e("UIStroke", {
				Color = strokeColor,
				Transparency = bodyStrokeTransparency,
				Thickness = 1,
			}),
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, OUTER_PAD_X),
				PaddingRight = UDim.new(0, OUTER_PAD_X),
				PaddingTop = UDim.new(0, OUTER_PAD_Y),
				PaddingBottom = UDim.new(0, OUTER_PAD_Y),
			}),
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, SECTION_GAP),
			}),
			TitleFrame = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, TITLE_HEIGHT + DIVIDER_HEIGHT + 2),
				LayoutOrder = 0,
			}, {
				Title = e("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
					Text = "Advanced",
					TextColor3 = titleColor,
					FontFace = FileController.Get("font", "semi_bold"),
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Divider = e("Frame", {
					BorderSizePixel = 0,
					BackgroundColor3 = dividerColor,
					Size = UDim2.new(1, 0, 0, DIVIDER_HEIGHT),
					Position = UDim2.fromOffset(0, DIVIDER_OFFSET_Y),
				}),
			}),
			Rows = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, ROW_GAP),
				}),
				Rotation = props.IsSequence and e(SliderRow, {
					Label = "Rotation",
					Alpha = rotationAlpha,
					FormattedValue = string.format("%d°", math.round(rotation)),
					IsActive = rotation > 0,
					OnDragAlpha = function(a: number)
						cp:SetRotation(a * 360)
					end,
					OnCommitText = function(text: string)
						local cleaned = text:gsub("°", ""):gsub("%s", "")
						local n = tonumber(cleaned)
						if n then
							cp:SetRotation(n)
						end
					end,
					OnNudge = function(dir: number)
						cp:SetRotation(rotation + dir * 5)
					end,
					LayoutOrder = 0,
					SnapEpoch = props.SnapEpoch,
				}) or nil,
				Animation = e(AnimationRow, {
					Colorpicker = cp,
					IsSequence = props.IsSequence,
					HasTransparency = props.HasTransparency,
					LayoutOrder = 1,
				}),
				Speed = e(CollapsibleRow, {
					Shown = hasMotion,
					LayoutOrder = 2,
					Children = e(SliderRow, {
						Label = "Speed",
						Alpha = speedAlpha,
						FormattedValue = string.format("%.1fx", speed),
						IsActive = math.abs(speed - 1) > 0.001,
						OnDragAlpha = function(a: number)
							cp:SetSpeed(0.1 + a * 4.9)
						end,
						OnCommitText = function(text: string)
							local cleaned = text:gsub("x", ""):gsub("X", ""):gsub("%s", "")
							local n = tonumber(cleaned)
							if n then
								cp:SetSpeed(n)
							end
						end,
						OnNudge = function(dir: number)
							cp:SetSpeed(speed + dir * 0.1)
						end,
						LayoutOrder = 0,
						SnapEpoch = props.SnapEpoch,
					}),
				}),
			}),
		}),
	})
end

return function(properties: { Colorpicker: any }): React.Element<any>
	local colorpickerWindow = properties.Colorpicker

	local color = useAt(colorpickerWindow._color)
	local transparency = useAt(colorpickerWindow._transparency)
	local advancedOpen = useAt(colorpickerWindow._advancedOpen)

	local isSequence = typeof(color) == "ColorSequence"
	local hasTransparency = transparency ~= nil
	local applicable = animations.getApplicable(isSequence, hasTransparency)
	local canShowAdvanced = #applicable > 1

	local snapEpoch = useAt(colorpickerWindow._sliderSnapEpoch)

	local anim = useSubwindowAnimation(colorpickerWindow, {
		slideOffset = 15,
		floatingId = "subwindow.colorpicker",
		onClickOutside = function()
			colorpickerWindow:Close()
		end,
	})

	local advTarget = canShowAdvanced and advancedOpen and 1 or 0
	local advBind, advSpring = useSpring(advTarget, SPRING.smooth)

	useEffect(function()
		advSpring:setGoal(advTarget)
	end, { advTarget })

	local wrapperVisibleBind = advBind:map(function(v: number)
		return v > 0.01
	end)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = anim.position,
		Visible = anim.visible,
		ZIndex = anim.zIndex,
	}, {
		Wrapper = e("Frame", {
			ref = anim.frameRef,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),
			MainPanel = e(MainPanel, {
				Colorpicker = colorpickerWindow,
				IsSequence = isSequence,
				HasTransparency = hasTransparency,
				AdvancedOpen = advancedOpen,
				CanShowAdvanced = canShowAdvanced,
				Anim = anim,
				SnapEpoch = snapEpoch,
			}),
			Gap = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, PANEL_GAP, 0, 0),
				Visible = wrapperVisibleBind,
				LayoutOrder = 1,
			}),
			AdvancedWrapper = canShowAdvanced and e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, ADV_WIDTH, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Visible = wrapperVisibleBind,
				LayoutOrder = 2,
			}, {
				AdvancedPanel = e(AdvancedPanel, {
					Colorpicker = colorpickerWindow,
					IsSequence = isSequence,
					HasTransparency = hasTransparency,
					Anim = anim,
					OpenBind = advBind,
					SnapEpoch = snapEpoch,
				}),
			}) or nil,
		}),
	})
end
