local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")

local e = React.createElement
local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local peek = Charm.peek
local sub = Charm.subscribe

export type Props = {
	enabledAtom: Charm.Atom<boolean>,
	gapLink: any,
	lengthLink: any,
	thicknessLink: any,
	colorLink: any,
	spreadAtom: Charm.Atom<number>,
}

local FADE_OUT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.6, 0.4),
	NumberSequenceKeypoint.new(1, 1),
})

local FADE_IN = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.4, 0.4),
	NumberSequenceKeypoint.new(1, 0),
})

local SHOW_SPRING = {
	tension = 900,
	friction = 55,
	precision = 0.01,
}

local SPREAD_SPRING = {
	tension = 1600,
	friction = 55,
	precision = 0.05,
}

local arm = LPH_NO_VIRTUALIZE(
	function(
		direction: string,
		gapBind: any,
		length: number,
		thickness: number,
		color: any,
		rotation: any,
		visibleBind: any
	): React.Element<any>
		local horizontal = direction == "Left" or direction == "Right"
		local positive = direction == "Bottom" or direction == "Right"

		local size = (horizontal and UDim2.fromOffset(length, thickness) or UDim2.fromOffset(thickness, length))

		local anchor: Vector2
		if direction == "Top" then
			anchor = Vector2.new(0.5, 1)
		elseif direction == "Bottom" then
			anchor = Vector2.new(0.5, 0)
		elseif direction == "Left" then
			anchor = Vector2.new(1, 0.5)
		else
			anchor = Vector2.new(0, 0.5)
		end

		local position = gapBind:map(function(g: number): UDim2
			if direction == "Top" then
				return UDim2.new(0.5, 0, 0.5, -g)
			elseif direction == "Bottom" then
				return UDim2.new(0.5, 0, 0.5, g)
			elseif direction == "Left" then
				return UDim2.new(0.5, -g, 0.5, 0)
			else
				return UDim2.new(0.5, g, 0.5, 0)
			end
		end)

		local baseRotation = (horizontal and 0 or 90)
		local rotationBind = rotation:map(function(r: number): number
			return baseRotation + r
		end)

		return e("Frame", {
			Name = direction,
			Size = size,
			AnchorPoint = anchor,
			Position = position,
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = visibleBind:map(function(v: number): number
				return 1 - math.clamp(v, 0, 1)
			end),
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			UIGradient = e("UIGradient", {
				Color = color,
				Rotation = rotationBind,
				Transparency = (positive and FADE_IN or FADE_OUT)
			}),
		})
	end
)

return function(props: Props): React.Element<any>
	local enabled = useAt(props.enabledAtom)
	local gap = useAt(props.gapLink._state) :: number
	local length = useAt(props.lengthLink._state) :: number
	local thickness = useAt(props.thicknessLink._state) :: number

	local visibleBind, visibleSpring = useSpring(0, SHOW_SPRING)
	local spreadBind, spreadSpring = useSpring(0, SPREAD_SPRING)

	useEffect(function()
		visibleSpring:setGoal(enabled and 1 or 0)
	end, { enabled })

	useEffect(function()
		spreadSpring:setPosition(peek(props.spreadAtom))
		local unsub = sub(props.spreadAtom, function(value: number): ()
			spreadSpring:setGoal(value)
		end)
		return unsub
	end, {})

	local colorpicker = props.colorLink

	local gapBind = spreadBind:map(function(s: number): number
		return math.max(0, gap + s)
	end)

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, {
		Top = arm("Top", gapBind, length, thickness, colorpicker._currentGradient, colorpicker._currentRotation, visibleBind),
		Bottom = arm("Bottom", gapBind, length, thickness, colorpicker._currentGradient, colorpicker._currentRotation, visibleBind),
		Left = arm("Left", gapBind, length, thickness, colorpicker._currentGradient, colorpicker._currentRotation, visibleBind),
		Right = arm("Right", gapBind, length, thickness, colorpicker._currentGradient, colorpicker._currentRotation, visibleBind),
	})
end
