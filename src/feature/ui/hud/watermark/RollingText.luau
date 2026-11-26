local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local SPRING = require("@ui/util/spring")

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef
local useMemo = React.useMemo
local memo = React.memo
local joinBindings = React.joinBindings
local useSpring = ReactRipple.useSpring
local sub = Charm.subscribe
local peek = Charm.peek

local CharCell = memo(function(props: {
	char: string,
	color: any,
	transparency: any,
	textSize: number,
	height: number,
	font: any,
	layoutOrder: number,
}): React.Element<any>
	local height = props.height

	local cur, setCur = useState(props.char)
	local prev, setPrev = useState(nil :: string?)

	local rollBind, rollSpring = useSpring(1, SPRING.quick)
	local dirRef = useRef(1)
	local curRef = useRef(props.char)
	local mountedRef = useRef(false)

	useEffect(function()
		return rollSpring:onComplete(function(): ()
			setPrev(nil)
		end)
	end, {})

	useEffect(function()
		if not mountedRef.current then
			mountedRef.current = true
			return
		end
		if props.char == curRef.current then
			return
		end
		local oldNum = tonumber(curRef.current)
		local newNum = tonumber(props.char)
		dirRef.current = (oldNum and newNum and newNum < oldNum) and -1 or 1
		setPrev(curRef.current)
		curRef.current = props.char
		setCur(props.char)
		rollSpring:setPosition(0)
		rollSpring:setGoal(1)
	end, { props.char })

	local incomingPos = useMemo(function()
		return rollBind:map(function(p: number)
			return UDim2.new(0, 0, 0.5, -dirRef.current * (1 - p) * height)
		end)
	end, { rollBind, height } :: { any })

	local outgoingPos = useMemo(function()
		return rollBind:map(function(p: number)
			return UDim2.new(0, 0, 0.5, dirRef.current * p * height)
		end)
	end, { rollBind, height } :: { any })

	local incomingTransparency = useMemo(function()
		return joinBindings({ props.transparency, rollBind }):map(function(values)
			return 1 - (1 - values[1]) * values[2]
		end)
	end, { props.transparency, rollBind } :: { any })

	local outgoingTransparency = useMemo(function()
		return joinBindings({ props.transparency, rollBind }):map(function(values)
			return 1 - (1 - values[1]) * (1 - values[2])
		end)
	end, { props.transparency, rollBind } :: { any })

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		ClipsDescendants = true,
		LayoutOrder = props.layoutOrder,
		Active = false,
	}, {
		Incoming = e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = cur,
			TextSize = props.textSize,
			TextColor3 = props.color,
			TextTransparency = incomingTransparency,
			FontFace = props.font,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = incomingPos,
			Size = UDim2.fromOffset(0, height),
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Active = false,
		}),
		Outgoing = prev and e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = prev,
			TextSize = props.textSize,
			TextColor3 = props.color,
			TextTransparency = outgoingTransparency,
			FontFace = props.font,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = outgoingPos,
			Size = UDim2.fromOffset(0, height),
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Active = false,
		}) or nil,
	})
end)

type RollingTextProps = {
	atom: Charm.Atom<any>,
	format: (value: any) -> string,
	color: any,
	transparency: any,
	textSize: number,
	height: number,
	layoutOrder: number?,
	roll: string?,
}

local RollingText = memo(function(props: RollingTextProps): React.Element<any>
	local format = props.format
	local atom = props.atom
	local height = props.height
	local perChar = props.roll == "char"

	local cur, setCur = useState(function(): string
		return format(peek(atom))
	end)
	local curRef = useRef(cur)

	useEffect(function()
		curRef.current = format(peek(atom))
		setCur(curRef.current)
		return sub(atom, function(state: any): ()
			local newText = format(state)
			if newText == curRef.current then
				return
			end
			curRef.current = newText
			setCur(newText)
		end)
	end, { atom, format })

	local colorBind = props.color

	local font = FileController.Get("font", "semi_bold")

	if perChar then
		local cells: { [string]: React.Element<any> } = {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),
		}
		local n = #cur
		for i = 1, n do
			local rightIndex = n - i
			cells[tostring(rightIndex)] = e(CharCell, {
				key = tostring(rightIndex),
				char = string.sub(cur, i, i),
				color = colorBind,
				transparency = props.transparency,
				textSize = props.textSize,
				height = height,
				font = font,
				layoutOrder = i,
			})
		end

		return e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, height),
			LayoutOrder = props.layoutOrder,
			Active = false,
		}, cells)
	end

	return e("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = cur,
		TextSize = props.textSize,
		TextColor3 = colorBind,
		TextTransparency = props.transparency,
		FontFace = font,
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		LayoutOrder = props.layoutOrder,
		Active = false,
	})
end)

return RollingText
