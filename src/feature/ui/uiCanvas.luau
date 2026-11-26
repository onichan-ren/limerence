local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local themeState = require("@ui/theme/themeState")
local uiState = require("@ui/uiState")
local dpiState = require("@ui/util/dpiState")

local useSpring = ReactRipple.useSpring
local useEffect = React.useEffect
local useMemo = React.useMemo
local useAt = ReactCharm.useAtom
local e = React.createElement

type Props = {
	Windows: any,
	SubwindowOpen: any,
}

return LPH_NO_VIRTUALIZE(function(props: Props): React.Element<any>
	local menuOpen = useAt(uiState.isOpen)
	local windows = useAt(props.Windows)
	local subwindowOpen = useAt(props.SubwindowOpen)
	local background = useAt(themeState.colors.canvas.background)
	local scale = useAt(dpiState.scale)

	local renderedWindows = useMemo(function()
		return Sift.Array.map(windows, function(window)
			return window:Render()
		end)
	end, { windows })

	local color, transparency = table.unpack(background)

	local bind, spring = useSpring(0, {
		tension = 500,
		friction = 38,
	})

	useEffect(function()
		spring:setGoal(menuOpen and 1 or 0)
	end, { menuOpen })

	return e("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		BackgroundTransparency = bind:map(function(value: number)
			return 1 - value * (1 - transparency)
		end),
		Size = UDim2.fromScale(1, 1),
		Visible = bind:map(function(value: number)
			return value > 0.01
		end),
		ZIndex = 1,
	}, {
		UIScale = e("UIScale", { Scale = scale }),
		Windows = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			Interactable = not subwindowOpen,
		}, renderedWindows),
	})
end)
