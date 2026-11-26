local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local Charm = require("@pkg/Charm")
local themeState = require("@ui/theme/themeState")
local SPRING = require("@ui/util/spring")

local useSpring = ReactRipple.useSpring
local useEffect = React.useEffect
local useMemo = React.useMemo
local useBinding = React.useBinding
local useAt = ReactCharm.useAtom

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local EMPTY_COLOR_ATOM = Charm.atom(nil :: Color3?)
local EMPTY_BOOL_ATOM = Charm.atom(false)

local LUMINANCE_PIVOT = 0.5
local LUMINANCE_BAND = 0.25

local luminance = LPH_NO_VIRTUALIZE(function(color: Color3): number
	return color.R * 0.299 + color.G * 0.587 + color.B * 0.114
end)

local function useAdvColor(
	baseColorAtom: Charm.Atom<Color3>,
	activeColorAtom: Charm.Atom<Color3>?,
	activeAtom: Charm.Atom<boolean>?,
	_invertTintWhenActive: boolean?
)
	local isHovered, setHovered = React.useState(false)
	local baseColor = useAt(baseColorAtom)
	local activeColorRaw = useAt(activeColorAtom or EMPTY_COLOR_ATOM)
	local activeColor = activeColorAtom and activeColorRaw or nil
	local activeSource = activeAtom or EMPTY_BOOL_ATOM
	local isActiveRaw = useAt(activeSource, { activeSource })
	local isActive = activeAtom and isActiveRaw or false
	local hoverTint = useAt(themeState.other.hoverTint) :: number
	local darkHoverTint = useAt(themeState.other.darkHoverTint) :: number

	local hoverBinding, hoverSpring = useSpring(0, SPRING.subtle)
	local activeBinding, activeSpring = useSpring(0, SPRING.quick)

	local baseColorBinding, setBaseColorBinding = useBinding(baseColor)
	local activeColorBinding, setActiveColorBinding = useBinding(activeColor or baseColor)
	local tintBinding, setTintBinding = useBinding(Vector2.new(hoverTint, darkHoverTint))

	useEffect(function()
		hoverSpring:setGoal(isHovered and 1 or 0)
	end, { isHovered })

	useEffect(function()
		activeSpring:setGoal(isActive and 1 or 0)
	end, { isActive })

	useEffect(function()
		setBaseColorBinding(baseColor)
	end, { baseColor })

	useEffect(function()
		setActiveColorBinding(activeColor or baseColor)
	end, { activeColor, baseColor })

	useEffect(function()
		setTintBinding(Vector2.new(hoverTint, darkHoverTint))
	end, { hoverTint, darkHoverTint })

	local colorBinding = useMemo(function()
		return React.joinBindings({
			hoverBinding,
			activeBinding,
			baseColorBinding,
			activeColorBinding,
			tintBinding,
		}):map(function(values)
			local hover: number = values[1]
			local active: number = values[2]
			local base: Color3 = values[3]
			local act: Color3 = values[4]
			local tints: Vector2 = values[5]

			local hasActive = activeColorAtom ~= nil
			local color = (hasActive and base:Lerp(act, active) or base)
			local baseLum = luminance(base)
			local lum = (hasActive and baseLum + (luminance(act) - baseLum) * active or baseLum)

			local lightWeight = math.clamp((lum - LUMINANCE_PIVOT) / LUMINANCE_BAND + 0.5, 0, 1)
			local darkResult = color:Lerp(WHITE, hover * tints.X)
			local lightResult = color:Lerp(BLACK, hover * tints.Y)

			return darkResult:Lerp(lightResult, lightWeight)
		end)
	end, { hoverBinding, activeBinding, baseColorBinding, activeColorBinding, tintBinding } :: { any })

	local handlers = useMemo(function()
		return {
			onMouseEnter = function()
				setHovered(true)
			end,
			onMouseLeave = function()
				setHovered(false)
			end,
		}
	end, {})

	return useMemo(function()
		return {
			binding = colorBinding,
			onMouseEnter = handlers.onMouseEnter,
			onMouseLeave = handlers.onMouseLeave,
		}
	end, { colorBinding, handlers } :: { any })
end

return useAdvColor
