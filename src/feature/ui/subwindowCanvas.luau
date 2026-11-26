local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local dpiState = require("@ui/util/dpiState")

local useAt = ReactCharm.useAtom
local useMemo = React.useMemo
local e = React.createElement

type Props = {
	Subwindows: any,
}

return LPH_NO_VIRTUALIZE(function(props: Props): React.Element<any>
	local subwindows = useAt(props.Subwindows)
	local scale = useAt(dpiState.scale)

	local renderedSubwindows = useMemo(function()
		return Sift.Dictionary.map(subwindows, function(subwindow)
			return subwindow:Render()
		end)
	end, { subwindows })

	local children: { [string]: React.Element<any> } = {
		UIScale = e("UIScale", { Scale = scale }),
	}
	for key, value in next, renderedSubwindows do
		children[key] = value
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, children)
end)
