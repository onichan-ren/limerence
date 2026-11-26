local Charm = require("@pkg/Charm")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local React = require("@pkg/React")

local themeState = require("@ui/theme/themeState")
local FileController = require("@src/feature/file/FileController")
local useAdvColor = require("@ui/hook/useAdvColor")
local useSubwindowAnimation = require("@ui/hook/useSubwindowAnimation")
local useShadow = require("@ui/hook/useShadow")
local useDraggable = require("@ui/hook/useDraggable")
local SPRING = require("@ui/util/spring")
local floatingController = require("@ui/floating/floatingController")

local subwindowColors = themeState.colors.subwindow
local elementColors = themeState.colors.window.element

local useEffect = React.useEffect
local useMemo = React.useMemo
local useState = React.useState
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local e = React.createElement

local WIDTH = 320
local HEIGHT = 176
local PADDING = 12
local TITLE_HEIGHT = 18
local SUBTITLE_HEIGHT = 14
local FOOTER_HEIGHT = 24
local DIVIDER_HEIGHT = 1
local NOTE_HEIGHT = 80

type FooterButtonProps = {
	Text: string,
	Variant: "primary" | "secondary",
	LayoutOrder: number,
	OnClick: () -> (),
}

local function FooterButton(props: FooterButtonProps): React.Element<any>
	local activeAtom = useMemo(function()
		return Charm.atom(props.Variant == "primary")
	end, {})

	local backgroundColor = useAdvColor(elementColors.surface, elementColors.accentStrong, activeAtom, true)
	local strokeColor = useAt(elementColors.surfaceStroke)
	local textColor = useAdvColor(elementColors.text, elementColors.textActive, activeAtom)

	local pressed, setPressed = useState(false)
	local pressBind, pressSpring = useSpring(0, SPRING.smooth)
	useEffect(function()
		pressSpring:setGoal(pressed and 1 or 0)
	end, { pressed })

	return e("TextButton", {
		BackgroundColor3 = backgroundColor.binding,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.new(0, 72, 0, FOOTER_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			backgroundColor.onMouseEnter()
			textColor.onMouseEnter()
		end,
		[React.Event.MouseLeave] = function()
			setPressed(false)
			backgroundColor.onMouseLeave()
			textColor.onMouseLeave()
		end,
		[React.Event.MouseButton1Down] = function()
			setPressed(true)
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
		end,
		[React.Event.MouseButton1Click] = function()
			props.OnClick()
		end,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 5),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = props.Text,
			TextColor3 = textColor.binding,
			TextSize = 12,
			FontFace = FileController.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

return function(properties: { Editor: any }): React.Element<any>
	local editor = properties.Editor

	local title = useAt(editor._title)
	local subtitle = useAt(editor._subtitle)
	local note = useAt(editor._note)
	local notePlaceholder = useAt(editor._notePlaceholder)

	local backgroundColor = useAt(subwindowColors.background)
	local dividerColor = useAt(subwindowColors.divider)
	local strokeColor = useAt(subwindowColors.stroke)
	local titleColor = useAt(subwindowColors.title)
	local subtitleColor = useAt(elementColors.caption)
	local mutedColor = useAt(elementColors.caption)
	local noteBg = useAt(elementColors.fieldBackground)
	local noteStroke = useAt(elementColors.fieldStroke)
	local noteText = useAt(subwindowColors.text)

	local anim = useSubwindowAnimation(editor, {
		slideOffset = 18,
		floatingId = "subwindow.recordEditor",
		floatingPriority = floatingController.PRIORITY.MODAL,
	})

	local onDragStart = useDraggable(editor._position)

	return e("Frame", {
		ref = anim.frameRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Position = anim.position,
		Visible = anim.visible,
		ZIndex = anim.zIndex,
	}, {
		Shadow = useShadow({
			transparency = anim.transparency,
			zIndex = 0,
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor,
			Transparency = anim.strokeTransparency,
			Thickness = 1,
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		Inner = e("CanvasGroup", {
			BackgroundTransparency = 0,
			BackgroundColor3 = backgroundColor,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = anim.transparency,
			ZIndex = 1,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 1),
				PaddingRight = UDim.new(0, 1),
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
			}),
			Title = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(PADDING, PADDING),
				Size = UDim2.new(1, -PADDING * 2, 0, TITLE_HEIGHT),
				Text = title,
				TextColor3 = titleColor,
				TextSize = 14,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Subtitle = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(PADDING, PADDING + TITLE_HEIGHT),
				Size = UDim2.new(1, -PADDING * 2, 0, SUBTITLE_HEIGHT),
				Text = subtitle,
				TextColor3 = subtitleColor,
				TextSize = 11,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			TitleDivider = e("Frame", {
				BackgroundColor3 = dividerColor,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(PADDING, PADDING + TITLE_HEIGHT + SUBTITLE_HEIGHT + 4),
				Size = UDim2.new(1, -PADDING * 2, 0, DIVIDER_HEIGHT),
			}),
			TitleDragStrip = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(PADDING, PADDING),
				Size = UDim2.new(1, -PADDING * 2, 0, TITLE_HEIGHT + SUBTITLE_HEIGHT + 4),
				ZIndex = 5,
				Active = true,
				[React.Event.InputBegan] = function(_: any, input: InputObject)
					onDragStart(input)
				end,
			}),
			NoteFrame = e("Frame", {
				BackgroundColor3 = noteBg,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(PADDING, PADDING + TITLE_HEIGHT + SUBTITLE_HEIGHT + 12),
				Size = UDim2.new(1, -PADDING * 2, 0, NOTE_HEIGHT),
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),
				UIStroke = e("UIStroke", {
					Color = noteStroke,
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				}),
				Input = e("TextBox", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClearTextOnFocus = false,
					MultiLine = true,
					TextWrapped = true,
					PlaceholderText = notePlaceholder,
					PlaceholderColor3 = mutedColor,
					Text = note,
					TextColor3 = noteText,
					TextSize = 12,
					FontFace = FileController.Get("font", "semi_bold"),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Size = UDim2.fromScale(1, 1),
					[React.Change.Text] = function(rbx: TextBox)
						editor:SetNote(rbx.Text)
					end,
				}),
			}),
			Footer = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, PADDING, 1, -PADDING + 6),
				Size = UDim2.new(1, -PADDING * 2, 0, FOOTER_HEIGHT),
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				Cancel = e(FooterButton, {
					Text = "Cancel",
					Variant = "secondary",
					LayoutOrder = 1,
					OnClick = function()
						editor:Cancel()
					end,
				}),
				Save = e(FooterButton, {
					Text = "Save",
					Variant = "primary",
					LayoutOrder = 2,
					OnClick = function()
						editor:Save()
					end,
				}),
			}),
		}),
	})
end
