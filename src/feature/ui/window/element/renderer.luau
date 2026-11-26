return LPH_NO_VIRTUALIZE(function()
	local ReactCharm = require("@pkg/ReactCharm")
	local ReactRipple = require("@pkg/ReactRipple")
	local React = require("@pkg/React")
	local Sift = require("@pkg/Sift")
	local FileController = require("@src/feature/file/FileController")
	local themeState = require("@ui/theme/themeState")
	local elementApi = require("@ui/window/element/elementApi")
	local cursor = require("@ui/util/cursor")
	local UserController = require("@feature/config/UserController")
	local configState = require("@feature/config/configState")
	local NotifyController = require("@ui/hud/notify/NotifyController")
	local SPRING = require("@ui/util/spring")

	local elementBindController = require("@ui/bind/elementBindController")
	local rightClickRegistry = require("@ui/window/element/rightClickRegistry")

	local useAdvColor = require("@ui/hook/useAdvColor")
	local useTooltip = require("@ui/hook/useTooltip")
	local useAt = ReactCharm.useAtom
	local useEffect = React.useEffect
	local useMemo = React.useMemo
	local useRef = React.useRef
	local useState = React.useState
	local useSpring = ReactRipple.useSpring
	local e = React.createElement

	local colors = themeState.colors.window.element
	local windowColors = themeState.colors.window

	local EXTRAS_BASE = 1
	local PRIMARY_LAYOUT_ORDER = 100

	export type ElementRendererProperties = {
		Element: any,
		LayoutOrder: number?,
		TextOffsetY: number?,
	}

	return function(properties: ElementRendererProperties): React.Element<any>
		local element = properties.Element
		local textOffsetY = properties.TextOffsetY

		local textColor = useAdvColor(colors.text, colors.textActive, element._active)
		local text = useAt(element._text)
		local extras = useAt(element._extras)
		local bindable = useAt(element._bindable)
		local devMode = useAt(UserController.developerMode)
		local tip = useAt(element._tip)
		local visible = useAt(element._visible)
		local disabled = useAt(element._disabled)
		local disabledBg = useAt(windowColors.background)
		local overrides = useAt(element._overrides)
		local accentColor = useAt(colors.accent)
		local textRef = useRef(nil)
		local rowRef = useRef(nil :: GuiObject?)
		local overrideRef = useRef(nil :: GuiObject?)

		local hasOverride = overrides ~= nil and next(overrides) ~= nil
		local overrideTip = useMemo(function()
			if not hasOverride or not overrides then
				return nil
			end
			local sources: { [string]: boolean } = {}
			local sourceList: { string } = {}
			for _, entry in next, overrides do
				local src = entry.source
				if type(src) == "string" and src ~= "" and not sources[src] then
					sources[src] = true
					sourceList[#sourceList + 1] = src
				end
			end
			local subject: string
			local isPlural: boolean
			if #sourceList == 0 then
				subject = "A script"
				isPlural = false
			elseif #sourceList == 1 then
				subject = sourceList[1]
				isPlural = false
			elseif #sourceList == 2 then
				subject = `{sourceList[1]} and {sourceList[2]}`
				isPlural = true
			else
				local head = table.concat(sourceList, ", ", 1, #sourceList - 1)
				subject = `{head}, and {sourceList[#sourceList]}`
				isPlural = true
			end
			return `{subject} {(isPlural and "are" or "is")} overriding this value.`
		end, { hasOverride, overrides } :: { any })

		local overrideTipHandlers = useTooltip(overrideTip, overrideRef)

		local overrideHovered, setOverrideHovered = useState(false)
		local overrideHoverBinding, overrideHoverSpring = useSpring(0, SPRING.subtle)

		useEffect(function()
			overrideHoverSpring:setGoal(overrideHovered and 1 or 0)
		end, { overrideHovered })

		local overrideSizeBinding = useMemo(function()
			return overrideHoverBinding:map(function(t: number)
				local size = 10 + t * 2
				return UDim2.fromOffset(size, size)
			end)
		end, { overrideHoverBinding } :: { any })

		local overrideTransparencyBinding = useMemo(function()
			return overrideHoverBinding:map(function(t: number)
				return 0.25 - t * 0.25
			end)
		end, { overrideHoverBinding } :: { any })

		local overrideHandlers = useMemo(function()
			return {
				onMouseEnter = function(rbx: GuiObject)
					setOverrideHovered(true)
					overrideTipHandlers.onMouseEnter(rbx)
				end,
				onMouseLeave = function(rbx: GuiObject)
					setOverrideHovered(false)
					overrideTipHandlers.onMouseLeave(rbx)
				end,
			}
		end, { overrideTipHandlers } :: { any })

		local tipHandlers = useTooltip(tip, rowRef)

		local elementRef = useRef(element)
		elementRef.current = element
		local bindableRef = useRef(bindable)
		bindableRef.current = bindable
		local devModeRef = useRef(devMode)
		devModeRef.current = devMode

		useEffect(function()
			local unregister = rightClickRegistry.register(rowRef, function()
				local el = elementRef.current
				local isBindable = bindableRef.current
				local isDev = devModeRef.current

				if not isBindable and not isDev then
					return
				end

				if not isDev then
					elementApi.OpenBindEditor(el, cursor.getPosition())
					return
				end

				local id: string?
				for key, value in next, configState.elements do
					if value == el then
						id = key
						break
					end
				end

				local items: { any } = {}

				if id then
					table.insert(items, {
						Label = "Copy ID",
						Icon = FileController.Get("image", "pencil"),
						Callback = function(): ()
							if setclipboard then
								setclipboard(id)
							end
							NotifyController.Push({
								title = "Copied Id",
								subtext = `Copied {id} to clipboard`,
								duration = 2,
							})
						end,
					})
				elseif isBindable then
					elementApi.OpenBindEditor(el, cursor.getPosition())
					return
				end

				if isBindable then
					table.insert(items, { Divider = true })
					table.insert(items, {
						Label = elementBindController.HasBindFor(el) and "Edit Bind(s)..." or "Bind...",
						Icon = FileController.Get("image", "keybinds"),
						Callback = function(): ()
							elementApi.OpenBindEditor(el, cursor.getPosition())
						end,
					})
				end

				elementApi.OpenContext(items, cursor.getPosition())
			end)

			return unregister
		end, {})

		local renderedElement = useMemo(function()
			return element:RenderInternal({
				textRef = textRef,
				layoutOrder = PRIMARY_LAYOUT_ORDER,
				textOffsetY = textOffsetY,
			})
		end, { element, textOffsetY })

		local renderedExtras = useMemo(function()
			local rendered = {}
			for index, extra in extras do
				rendered["Extra_" .. index] = extra:RenderInternal({
					layoutOrder = EXTRAS_BASE + index - 1,
					textOffsetY = textOffsetY,
				})
			end
			return rendered
		end, { extras, textOffsetY })

		local row = e(
			"Frame",
			{
				ref = rowRef,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 14),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 0,
				[React.Event.MouseEnter] = tipHandlers.onMouseEnter,
				[React.Event.MouseLeave] = tipHandlers.onMouseLeave,
			},
			Sift.Dictionary.join({
				UIListLayout = e("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 7),
				}),
				Text = e("TextButton", {
					ref = textRef,
					BackgroundTransparency = 1,
					FontFace = FileController.Get("font", "semi_bold"),
					TextColor3 = textColor.binding,
					TextSize = 13,
					Text = text,
					Size = UDim2.new(0, 0, 0, 14),
					LayoutOrder = 0,
					AutoButtonColor = false,
					Active = false,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					AutomaticSize = Enum.AutomaticSize.X,
				}, {
					UIPadding = e("UIPadding", {
						PaddingBottom = UDim.new(0, 2),
					}),
					UIFlexItem = e("UIFlexItem", {
						FlexMode = Enum.UIFlexMode.Fill,
						ItemLineAlignment = Enum.ItemLineAlignment.Automatic,
					}),
				}),
				OverrideIndicator = (hasOverride and e("Frame", {
					ref = overrideRef,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(10, 10),
					LayoutOrder = PRIMARY_LAYOUT_ORDER - 1,
					[React.Event.MouseEnter] = overrideHandlers.onMouseEnter,
					[React.Event.MouseLeave] = overrideHandlers.onMouseLeave,
				}, {
					Icon = e("ImageLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Image = FileController.Get("image", "bolt") or "",
						ImageColor3 = accentColor,
						ImageTransparency = overrideTransparencyBinding,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = overrideSizeBinding,
					}),
				}) or nil),
				Element = renderedElement,
			}, renderedExtras)
		)

		return e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = visible,
			LayoutOrder = properties.LayoutOrder,
		}, {
			Row = row,
			DisabledOverlay = disabled and e("Frame", {
				BackgroundColor3 = disabledBg,
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 50,
				Active = true,
			}) or nil,
		})
	end
end)()
