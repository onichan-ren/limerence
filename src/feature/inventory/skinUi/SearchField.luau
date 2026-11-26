local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local layout = require("@feature/inventory/skinUi/layout")

local useEffect = React.useEffect
local useCallback = React.useCallback
local useRef = React.useRef
local useAt = ReactCharm.useAtom
local e = React.createElement

local windowColors = themeState.colors.window
local elementColors = themeState.colors.window.element

local FIELD_PAD_X = layout.FIELD_PAD_X
local ELEMENT_GAP = layout.ELEMENT_GAP
local ICON_SIZE = 12

export type SearchFieldProps = {
	Atom: any,
	Placeholder: string,
	Size: UDim2?,
	Position: UDim2?,
}

return function(props: SearchFieldProps): React.Element<any>
	local searchQuery = useAt(props.Atom)
	local searchMuted = useAt(windowColors.searchMuted)
	local panelColor = useAt(elementColors.panel)
	local panelStroke = useAt(elementColors.panelStroke)
	local strongColor = useAt(elementColors.textActive)

	local textBoxRef = useRef(nil :: TextBox?)
	local searchDebounce = useRef(nil :: thread?)

	local onSearchChanged = useCallback(function(rbx: TextBox)
		local text = rbx.Text
		if searchDebounce.current then
			task.cancel(searchDebounce.current)
		end
		searchDebounce.current = task.delay(0.12, function()
			searchDebounce.current = nil
			props.Atom(text)
		end)
	end, { props.Atom } :: { any })

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

	return e("Frame", {
		BackgroundColor3 = panelColor,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 5),
		}),
		UIStroke = e("UIStroke", {
			Color = panelStroke,
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
			Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
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
			PlaceholderText = props.Placeholder,
			PlaceholderColor3 = searchMuted,
			TextColor3 = strongColor,
			TextSize = 12,
			Text = "",
			FontFace = FileController.Get("font", "light"),
			Size = UDim2.new(1, -(ICON_SIZE + ELEMENT_GAP), 0, 14),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 1,
			[React.Event.FocusLost] = function(rbx: TextBox)
				if searchDebounce.current then
					task.cancel(searchDebounce.current)
					searchDebounce.current = nil
				end
				props.Atom(rbx.Text)
			end,
			[React.Change.Text] = onSearchChanged,
		}),
	})
end
