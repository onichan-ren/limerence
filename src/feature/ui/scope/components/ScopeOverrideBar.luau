local Charm = require("@pkg/Charm")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")

local themeState = require("@ui/theme/themeState")
local FileController = require("@feature/file/FileController")
local ScopeController = require("@ui/scope/ScopeController")
local scopeState = require("@ui/scope/scopeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local SPRING = require("@ui/util/spring")

local at = Charm.atom
local useSpring = ReactRipple.useSpring
local useEffect = React.useEffect
local useRef = React.useRef
local useAt = ReactCharm.useAtom
local e = React.createElement

local elementColors = themeState.colors.window.element

local BAR_HEIGHT = 26
local TOGGLE_WIDTH = 28
local TOGGLE_HEIGHT = 14
local CIRCLE_SIZE = 10

export type ScopeOverrideBarProperties = {
	ScopeId: string?,
	Progress: any,
}

return function(properties: ScopeOverrideBarProperties): React.Element<any>?
	local scopeId = properties.ScopeId
	local progress = properties.Progress

	local enabledMap = useAt(scopeState.enabled)
	local scopes = useAt(scopeState.scopes)

	local panel = useAt(elementColors.panel)
	local panelStroke = useAt(elementColors.panelStroke)
	local activeText = useAt(elementColors.textActive)
	local mutedText = useAt(elementColors.caption)

	local activeAtomRef = useRef(nil :: any)
	if not activeAtomRef.current then
		activeAtomRef.current = at(false)
	end
	local activeAtom = activeAtomRef.current :: Charm.Atom<boolean>

	local backgroundColor = useAdvColor(elementColors.surface, elementColors.accent, activeAtom, true)
	local circleColor = useAdvColor(elementColors.thumb, elementColors.thumbActive, activeAtom, true)
	local strokeColor = useAdvColor(elementColors.surfaceStroke, elementColors.accentStrong, activeAtom)

	local circleBind, circleSpring = useSpring(0, SPRING.quick)

	local def = scopeId and scopes[scopeId] or nil
	local isEnabled = scopeId ~= nil and enabledMap[scopeId] == true

	useEffect(function()
		activeAtom(isEnabled)
		circleSpring:setGoal(isEnabled and 1 or 0)
	end, { isEnabled })

	if not def or not scopeId or scopeId == ScopeController.GLOBAL_ID then
		return nil
	end

	local capturedScopeId = scopeId

	return e("CanvasGroup", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
		Position = progress:map(function(value: number)
			return UDim2.fromOffset(0, math.floor((1 - value) * -10))
		end),
		GroupTransparency = progress:map(function(value: number)
			return 1 - value
		end),
	}, {
		Panel = e("Frame", {
			BackgroundColor3 = panel,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -2, 1, -2),
			Position = UDim2.fromOffset(1, 1),
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 5),
			}),
			UIStroke = e("UIStroke", {
				Color = panelStroke,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 8),
			}),
			UIListLayout = e("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			}),
			Editing = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = "Editing",
				TextColor3 = mutedText,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				FontFace = FileController.Get("font", "semi_bold"),
				LayoutOrder = 1,
			}),
			ScopeName = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = def.label,
				TextColor3 = activeText,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				FontFace = FileController.Get("font", "semi_bold"),
				LayoutOrder = 2,
			}),
			Spacer = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = 3,
			}, {
				UIFlexItem = e("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
			}),
			ToggleGroup = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(0, TOGGLE_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 4,
			}, {
				UIListLayout = e("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 5),
				}),
				Label = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = "Override Global",
					TextColor3 = mutedText,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					FontFace = FileController.Get("font", "semi_bold"),
					LayoutOrder = 1,
				}),
				Switch = e("TextButton", {
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(TOGGLE_WIDTH, TOGGLE_HEIGHT),
					BackgroundColor3 = backgroundColor.binding,
					Text = "",
					Active = false,
					AutoButtonColor = false,
					LayoutOrder = 2,
					[React.Event.MouseEnter] = function()
						backgroundColor.onMouseEnter()
						circleColor.onMouseEnter()
					end,
					[React.Event.MouseLeave] = function()
						backgroundColor.onMouseLeave()
						circleColor.onMouseLeave()
					end,
					[React.Event.MouseButton1Click] = function()
						ScopeController.ToggleScopeEnabled(capturedScopeId)
					end,
				}, {
					UIStroke = e("UIStroke", {
						Color = strokeColor.binding,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = 1,
					}),
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 8),
					}),
					UIPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 2),
						PaddingRight = UDim.new(0, 2),
						PaddingTop = UDim.new(0, 2),
						PaddingBottom = UDim.new(0, 2),
					}),
					Circle = e("Frame", {
						BackgroundTransparency = 0,
						BackgroundColor3 = circleColor.binding,
						Position = circleBind:map(function(value: number)
							return UDim2.fromScale(value, 0)
						end),
						AnchorPoint = circleBind:map(function(value: number)
							return Vector2.new(value, 0)
						end),
						BorderSizePixel = 0,
						Size = UDim2.fromOffset(CIRCLE_SIZE, CIRCLE_SIZE),
					}, {
						UICorner = e("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),
					}),
				}),
			}),
		}),
	})
end
