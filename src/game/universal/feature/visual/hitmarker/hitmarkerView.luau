local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")

local Charm = require("@pkg/Charm")
local SPRING = require("@ui/util/spring")

local e = React.createElement
local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring

local SIZE = 16
local ARM = 5
local DIAG_OFFSET = 5

local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local CENTER_POSITION = UDim2.new(0.5, 0, 0.5, 0)
local BURST_SIZE = UDim2.fromOffset(SIZE, SIZE)

local BOUNCE = {
	dampingRatio = 0.38,
	frequency = 3.25,
	precision = 0.01,
}

local FADE_START = {
	start = false,
	tension = SPRING.smoothPrecise.tension,
	friction = SPRING.smoothPrecise.friction,
	precision = SPRING.smoothPrecise.precision,
}

local FADE_TOP = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.6, 0),
	NumberSequenceKeypoint.new(1, 0),
})
local FADE_BOTTOM = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.4, 0),
	NumberSequenceKeypoint.new(1, 1),
})

local burst = LPH_NO_VIRTUALIZE(
	function(props: {
		color: any,
		outlineColor: any,
		outlineTransparency: any,
		thickness: number,
	}): React.Element<any>
		local scaleBind, scaleSpring = useSpring(0.32, BOUNCE)
		local fadeBind, fadeSpring = useSpring(0, FADE_START)

		local strokeTransparency = React.joinBindings({ props.outlineTransparency, fadeBind })
			:map(function(values: { number }): number
				local base = values[1] or 0
				return base + (1 - base) * values[2]
			end)

		useEffect(function()
			scaleSpring:setGoal(1)

			local disconnectComplete: (() -> ())?
			disconnectComplete = scaleSpring:onComplete(function()
				local d = disconnectComplete
				if d then
					disconnectComplete = nil
					d()
				end
				scaleSpring:configure({
					tension = SPRING.smoothPrecise.tension,
					friction = SPRING.smoothPrecise.friction,
					precision = SPRING.smoothPrecise.precision,
				})
				scaleSpring:setGoal(1.52)
				fadeSpring:start()
				fadeSpring:setGoal(1)
			end)

			return function()
				if disconnectComplete then
					disconnectComplete()
				end
			end
		end, {})

		local c = props.color
		local t = fadeBind
		local armSize = UDim2.fromOffset(props.thickness, ARM)

		local function arm(offX: number, offY: number, rot: number, topOuter: boolean): React.Element<any>
			local fade = topOuter and FADE_TOP or FADE_BOTTOM
			return e("Frame", {
				Name = "Arm",
				BorderSizePixel = 0,
				BackgroundColor3 = c,
				BackgroundTransparency = t,
				Size = armSize,
				AnchorPoint = CENTER_ANCHOR,
				Position = UDim2.new(0.5, offX, 0.5, offY),
				Rotation = rot,
			}, {
				Gradient = e("UIGradient", {
					Rotation = 90,
					Transparency = fade,
				}),
				Stroke = e("UIStroke", {
					Color = props.outlineColor,
					Transparency = strokeTransparency,
					Thickness = 1,
					LineJoinMode = Enum.LineJoinMode.Miter,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}, {
					Gradient = e("UIGradient", {
						Rotation = 90,
						Transparency = fade,
					}),
				}),
			})
		end

		return e("Frame", {
			Size = BURST_SIZE,
			AnchorPoint = CENTER_ANCHOR,
			Position = CENTER_POSITION,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, {
			Scale = e("UIScale", {
				Scale = scaleBind,
			}),
			NE = arm(DIAG_OFFSET, -DIAG_OFFSET, 45, true),
			SW = arm(-DIAG_OFFSET, DIAG_OFFSET, 45, false),
			NW = arm(-DIAG_OFFSET, -DIAG_OFFSET, -45, true),
			SE = arm(DIAG_OFFSET, DIAG_OFFSET, -45, false),
		})
	end
)

export type Pulse = { seq: number, headshot: boolean }

local root = LPH_NO_VIRTUALIZE(function(props: {
	pulseAtom: Charm.Atom<Pulse>,
	enabledLink: any,
	hitColorLink: any,
	headshotColorLink: any,
	outlineColorLink: any,
	thicknessLink: any,
}): React.Element<any>?
	local enabled = useAt(props.enabledLink._state) :: boolean
	local pulse = useAt(props.pulseAtom) :: Pulse
	local thickness = useAt(props.thicknessLink._state) :: number

	if not enabled or pulse.seq == 0 then
		return nil
	end

	local picker = (pulse.headshot and props.headshotColorLink or props.hitColorLink)

	return e(burst, {
		key = pulse.seq,
		color = picker._currentColor,
		outlineColor = props.outlineColorLink._currentColor,
		outlineTransparency = props.outlineColorLink._currentTransparency,
		thickness = thickness or 2,
	})
end)

return root
