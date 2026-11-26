local Charm = require("@pkg/Charm")
local React = require("@pkg/React")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local useAdvColor = require("@ui/hook/useAdvColor")
local skinCatalog = require("@game/pf/feature/inventory/skinCatalog")

local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local e = React.createElement

local elementColors = themeState.colors.window.element

local TAB_HEIGHT = 22
local TAB_GAP = 6

type TabProps = {
	Label: string,
	Tag: string,
	Active: boolean,
	LayoutOrder: number,
	OnSelect: (tag: string) -> (),
}

local function SlotTab(props: TabProps): React.Element<any>
	local hovered, setHovered = useState(false)

	local activeAtom = useMemo(function()
		return Charm.atom(false)
	end, {})

	useEffect(function()
		activeAtom(props.Active or hovered)
	end, { props.Active, hovered })

	local backgroundColor = useAdvColor(elementColors.panel, elementColors.accentStrong, activeAtom, true)
	local textColor = useAdvColor(elementColors.caption, elementColors.textActive, activeAtom)
	local strokeColor = useAdvColor(elementColors.panelStroke, elementColors.accentStrong, activeAtom)

	local onEnter = useCallback(function()
		setHovered(true)
		backgroundColor.onMouseEnter()
		textColor.onMouseEnter()
		strokeColor.onMouseEnter()
	end, { backgroundColor, textColor, strokeColor } :: { any })

	local onLeave = useCallback(function()
		setHovered(false)
		backgroundColor.onMouseLeave()
		textColor.onMouseLeave()
		strokeColor.onMouseLeave()
	end, { backgroundColor, textColor, strokeColor } :: { any })

	local onClick = useCallback(function()
		props.OnSelect(props.Tag)
	end, { props.OnSelect, props.Tag } :: { any })

	return e("TextButton", {
		BackgroundColor3 = backgroundColor.binding,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(72, TAB_HEIGHT),
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = onEnter,
		[React.Event.MouseLeave] = onLeave,
		[React.Event.MouseButton1Click] = onClick,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIStroke = e("UIStroke", {
			Color = strokeColor.binding,
			Transparency = 0.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = props.Label,
			TextColor3 = textColor.binding,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		}),
	})
end

export type SlotTabsProps = {
	Weapon: string?,
	ActiveTag: string?,
	OnSelect: (tag: string) -> (),
}

return function(props: SlotTabsProps): React.Element<any>?
	local weapon = props.Weapon

	local slots = useMemo(function()
		if not weapon then
			return {} :: { skinCatalog.CamoSlot }
		end
		return skinCatalog.getCamoSlots(weapon)
	end, { weapon } :: { any })

	if #slots < 2 then
		return nil
	end

	local tabs: { [string]: React.Element<any> } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, TAB_GAP),
		}),
	}

	for index, slot in next, slots do
		tabs[`Tab_{slot.tag}`] = e(SlotTab, {
			Label = slot.label,
			Tag = slot.tag,
			Active = slot.tag == props.ActiveTag,
			LayoutOrder = index,
			OnSelect = props.OnSelect,
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
	}, tabs)
end
