local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local themeState = require("@ui/theme/themeState")
local useShadow = require("@ui/hook/useShadow")
local SPRING = require("@ui/util/spring")

local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local useState = React.useState
local useEffect = React.useEffect
local useCallback = React.useCallback

local GLOW_STRENGTH = 0.48
local GLOW_MULTIPLIER = Vector2.new(1.19, 1.33)

local useHudHover = function(enabled: boolean)
	local hovered, setHovered = useState(false)
	local bind, spring = useSpring(0, SPRING.smooth)
	local accentColor = useAt(themeState.colors.window.element.accentStrong)

	useEffect(function()
		spring:setGoal((enabled and hovered) and 1 or 0)
	end, { enabled, hovered } :: { any })

	local onEnter = useCallback(function(): ()
		setHovered(true)
	end, {})

	local onLeave = useCallback(function(): ()
		setHovered(false)
	end, {})

	local glow = useShadow({
		color = accentColor,
		transparency = bind:map(function(v: number)
			return 1 - v * GLOW_STRENGTH
		end),
		zIndex = 0,
		multiplier = GLOW_MULTIPLIER,
	})

	return onEnter, onLeave, glow
end

return useHudHover
