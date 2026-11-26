local Charm = require("@pkg/Charm")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")
local themeState = require("@ui/theme/themeState")
local FileController = require("@src/feature/file/FileController")
local useAdvColor = require("@ui/hook/useAdvColor")
local useSubwindowAnimation = require("@ui/hook/useSubwindowAnimation")
local useShadow = require("@ui/hook/useShadow")
local useDraggable = require("@ui/hook/useDraggable")
local useScrollFade = require("@ui/hook/useScrollFade")
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
local HEIGHT = 480
local PADDING = 12
local TITLE_HEIGHT = 18
local FOOTER_HEIGHT = 28
local DIVIDER_HEIGHT = 1
local SECTION_PADDING = 10
local SUBWINDOW_ELEMENT_RENDER = { textOffsetY = -1 }

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
		Size = UDim2.new(0, 70, 0, 22),
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

return function(properties: { ThemeEditor: any }): React.Element<any>
	local editor = properties.ThemeEditor

	local title = useAt(editor._title)
	local sections = useAt(editor._sections)

	local backgroundColor = useAt(subwindowColors.background)
	local dividerColor = useAt(subwindowColors.divider)
	local strokeColor = useAt(subwindowColors.stroke)
	local titleColor = useAt(subwindowColors.title)
	local scrollThumbColor = useAt(elementColors.scrollThumb)

	local renderedSections = useMemo(function()
		local rendered = {}
		for index, section in next, sections do
			rendered[`Section_{index}_{tostring(section)}`] = section:Render(SUBWINDOW_ELEMENT_RENDER)
		end
		return rendered
	end, { sections })

	local anim = useSubwindowAnimation(editor, {
		slideOffset = 18,
		floatingId = "subwindow.themeEditor",
		floatingPriority = floatingController.PRIORITY.MODAL,
	})

	local onDragStart = useDraggable(editor._position)

	local scrollRef, contentRef, needsScroll, fadeGradient = useScrollFade()

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
			}),
			TitleDivider = e("Frame", {
				BackgroundColor3 = dividerColor,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(PADDING, PADDING + TITLE_HEIGHT + 4),
				Size = UDim2.new(1, -PADDING * 2, 0, DIVIDER_HEIGHT),
			}),
			ScrollFade = e("CanvasGroup", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(PADDING, PADDING + TITLE_HEIGHT + 4 + DIVIDER_HEIGHT + 6),
				Size = UDim2.new(
					1,
					-PADDING * 2,
					1,
					-(
							PADDING
							+ TITLE_HEIGHT
							+ 4
							+ DIVIDER_HEIGHT
							+ 6
							+ FOOTER_HEIGHT
							+ 6
							+ DIVIDER_HEIGHT
							+ 6
							+ PADDING
						)
				),
				ZIndex = 1,
			}, {
				Gradient = fadeGradient,
				Scroll = e("ScrollingFrame", {
					ref = scrollRef,
					Active = false,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, 1),
					ClipsDescendants = true,
					ScrollingEnabled = needsScroll,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.fromOffset(0, 0),
					VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
					ScrollBarImageColor3 = scrollThumbColor,
					ScrollBarImageTransparency = needsScroll and 0.1 or 1,
					ScrollBarThickness = needsScroll and 3 or 0,
				}, {
					Inner = e(
						"Frame",
						{
							ref = contentRef,
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							Size = UDim2.new(1, 0, 0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
						},
						Sift.Dictionary.join({
							UIListLayout = e("UIListLayout", {
								VerticalAlignment = Enum.VerticalAlignment.Top,
								HorizontalAlignment = Enum.HorizontalAlignment.Left,
								FillDirection = Enum.FillDirection.Vertical,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, SECTION_PADDING),
							}),
							UIPadding = e("UIPadding", {
								PaddingLeft = UDim.new(0, 2),
								PaddingRight = UDim.new(0, 4),
								PaddingBottom = UDim.new(0, 4),
							}),
						}, renderedSections)
					),
				}),
			}),
			TitleDragStrip = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(PADDING, PADDING),
				Size = UDim2.new(1, -PADDING * 2, 0, TITLE_HEIGHT + 4 + DIVIDER_HEIGHT),
				ZIndex = 5,
				Active = false,
				[React.Event.InputBegan] = function(_: any, input: InputObject)
					onDragStart(input)
				end,
			}),
			FooterDivider = e("Frame", {
				BackgroundColor3 = dividerColor,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, PADDING, 1, -(PADDING + FOOTER_HEIGHT + 6)),
				Size = UDim2.new(1, -PADDING * 2, 0, DIVIDER_HEIGHT),
			}),
			Footer = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, PADDING, 1, -PADDING),
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
