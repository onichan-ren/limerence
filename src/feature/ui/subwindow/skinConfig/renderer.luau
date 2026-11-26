local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local Charm = require("@pkg/Charm")

local FileController = require("@src/feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local useSubwindowAnimation = require("@ui/hook/useSubwindowAnimation")
local useShadow = require("@ui/hook/useShadow")
local useDraggable = require("@ui/hook/useDraggable")
local SPRING = require("@ui/util/spring")
local floatingController = require("@ui/floating/floatingController")

local useEffect = React.useEffect
local useMemo = React.useMemo
local useState = React.useState
local useCallback = React.useCallback
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local e = React.createElement

local subwindowColors = themeState.colors.subwindow
local elementColors = themeState.colors.window.element
local inventoryColors = themeState.colors.inventory

local WIDTH = 360
local HEIGHT = 303
local PADDING = 11
local TITLE_HEIGHT = 18
local DIVIDER_HEIGHT = 1
local PREVIEW_HEIGHT = 118
local FIELD_ROW_GAP = 6
local FOOTER_HEIGHT = 25
local SUBWINDOW_ELEMENT_RENDER = { textOffsetY = -1 }

type FooterButtonProps = {
	Text: string,
	Variant: "primary" | "secondary",
	LayoutOrder: number,
	OnClick: () -> (),
}

local function FooterButton(props: FooterButtonProps): React.Element<any>
	local hovered, setHovered = useState(false)
	local pressed, setPressed = useState(false)

	local activeAtom = useMemo(function()
		return Charm.atom(props.Variant == "primary")
	end, {})

	useEffect(function()
		if props.Variant == "primary" then
			activeAtom(true)
		else
			activeAtom(hovered or pressed)
		end
	end, { hovered, pressed, props.Variant })

	local backgroundColor = useAdvColor(elementColors.surface, elementColors.accentStrong, activeAtom, true)
	local strokeColor = useAt(elementColors.surfaceStroke)
	local textColor = useAdvColor(elementColors.text, elementColors.textActive, activeAtom)

	local pressBind, pressSpring = useSpring(0, SPRING.quick)
	useEffect(function()
		pressSpring:setGoal(pressed and 1 or 0)
	end, { pressed })

	local scaleBind = useMemo(function()
		return pressBind:map(function(value: number)
			return 1 - value * 0.04
		end)
	end, { pressBind } :: { any })

	return e("TextButton", {
		BackgroundColor3 = backgroundColor.binding,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.fromOffset(96, 24),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = function()
			setHovered(true)
			if props.Variant ~= "primary" then
				backgroundColor.onMouseEnter()
				textColor.onMouseEnter()
			end
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			setPressed(false)
			if props.Variant ~= "primary" then
				backgroundColor.onMouseLeave()
				textColor.onMouseLeave()
			end
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
		UIScale = e("UIScale", {
			Scale = scaleBind,
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

return function(properties: { SkinConfig: any }): React.Element<any>
	local config = properties.SkinConfig

	local weapon = useAt(config._weapon)
	local skin = useAt(config._skin)
	local rarity = useAt(config._rarity)
	local icon = useAt(config._icon)
	local submitLabel = useAt(config._submitLabel)

	local backgroundColor = useAt(subwindowColors.background)
	local dividerColor = useAt(subwindowColors.divider)
	local strokeColor = useAt(subwindowColors.stroke)
	local titleColor = useAt(subwindowColors.title)
	local imageBgColor = useAt(inventoryColors.cardImageBg)

	local rarityAtom = (inventoryColors.rarity[rarity] or inventoryColors.rarity.common) :: Charm.Atom<Color3>
	local rarityColor = useAt(rarityAtom)

	local anim = useSubwindowAnimation(config, {
		slideOffset = 18,
		floatingId = "subwindow.skinConfig",
		floatingPriority = floatingController.PRIORITY.MODAL,
	})

	local onDragStart = useDraggable(config._position)

	local onCancel = useCallback(function()
		config:Cancel()
	end, { config } :: { any })

	local onSubmit = useCallback(function()
		config:Submit(config:BuildPayload())
	end, { config } :: { any })

	local floatRendered = useMemo(function()
		return config._floatEl:Render(0, SUBWINDOW_ELEMENT_RENDER)
	end, { config._floatEl } :: { any })

	local seedRendered = useMemo(function()
		return config._seedEl:Render(1, SUBWINDOW_ELEMENT_RENDER)
	end, { config._seedEl } :: { any })

	local nameTagRendered = useMemo(function()
		return config._nameTagEl:Render(2, SUBWINDOW_ELEMENT_RENDER)
	end, { config._nameTagEl } :: { any })

	local statTrackRendered = useMemo(function()
		return config._statTrackEl:Render(3, SUBWINDOW_ELEMENT_RENDER)
	end, { config._statTrackEl } :: { any })

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
			Title = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(PADDING, PADDING),
				Size = UDim2.new(1, -PADDING * 2, 0, TITLE_HEIGHT),
				Text = `{weapon}  /  {skin}`,
				TextColor3 = titleColor,
				TextSize = 14,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			TitleDivider = e("Frame", {
				BackgroundColor3 = dividerColor,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(PADDING, PADDING + TITLE_HEIGHT + 4),
				Size = UDim2.new(1, -PADDING * 2, 0, DIVIDER_HEIGHT),
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
			Preview = e("Frame", {
				BackgroundColor3 = imageBgColor,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(PADDING, PADDING + TITLE_HEIGHT + 4 + DIVIDER_HEIGHT + 8),
				Size = UDim2.new(1, -PADDING * 2, 0, PREVIEW_HEIGHT),
				ClipsDescendants = true,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
				UIStroke = e("UIStroke", {
					Color = strokeColor,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = 1,
				}),
				RarityAccent = e("Frame", {
					BackgroundColor3 = rarityColor,
					BackgroundTransparency = 0.85,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
				}, {
					UIGradient = e("UIGradient", {
						Color = ColorSequence.new(rarityColor),
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(1, 0.55),
						}),
						Rotation = 90,
					}),
				}),
				Icon = e("ImageLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(0.78, 0, 0.78, 0),
					Image = icon or "",
					ScaleType = Enum.ScaleType.Fit,
				}),
				RarityBar = e("Frame", {
					BackgroundColor3 = rarityColor,
					BackgroundTransparency = 0.25,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 2),
				}),
			}),
			Form = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, PADDING, 1, -(11 + FOOTER_HEIGHT + 10 + DIVIDER_HEIGHT + 11)),
				Size = UDim2.new(1, -PADDING * 2, 0, 4 * 14 + 3 * FIELD_ROW_GAP),
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, FIELD_ROW_GAP),
				}),
				Float = floatRendered,
				Seed = seedRendered,
				Nametag = nameTagRendered,
				StatTrak = statTrackRendered,
			}),
			FooterDivider = e("Frame", {
				BackgroundColor3 = dividerColor,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, PADDING, 1, -(10 + FOOTER_HEIGHT + 10)),
				Size = UDim2.new(1, -PADDING * 2, 0, DIVIDER_HEIGHT),
			}),
			Footer = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, PADDING, 1, -11),
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
					LayoutOrder = 0,
					OnClick = onCancel,
				}),
				Add = e(FooterButton, {
					Text = submitLabel,
					Variant = "primary",
					LayoutOrder = 1,
					OnClick = onSubmit,
				}),
			}),
		}),
	})
end
