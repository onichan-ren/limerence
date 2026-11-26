local React = require("@pkg/React")

local useEffect = React.useEffect
local useRef = React.useRef

type AdvColor = {
	onMouseEnter: () -> (),
	onMouseLeave: () -> (),
}

export type LabelHoverOptions = {
	onClick: (() -> ())?,
}

local function useLabelHover(textRef: { current: TextButton? }?, colors: { AdvColor }, options: LabelHoverOptions?): ()
	local clickRef = useRef(options and options.onClick)
	clickRef.current = options and options.onClick

	local colorsRef = useRef(colors)
	colorsRef.current = colors

	useEffect(function()
		local labelButton = textRef and textRef.current
		if not labelButton then
			return nil
		end

		local connections: { RBXScriptConnection } = {
			labelButton.MouseEnter:Connect(function()
				for _, color in colorsRef.current do
					color.onMouseEnter()
				end
			end),
			labelButton.MouseLeave:Connect(function()
				for _, color in colorsRef.current do
					color.onMouseLeave()
				end
			end),
			labelButton.MouseButton1Click:Connect(function()
				local cb = clickRef.current
				if cb then
					cb()
				end
			end),
		}

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { textRef })
end

return useLabelHover
