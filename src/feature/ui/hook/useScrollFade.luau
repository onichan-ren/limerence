local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")

local useRef = React.useRef
local useState = React.useState
local useEffect = React.useEffect
local useMemo = React.useMemo
local useSpring = ReactRipple.useSpring
local e = React.createElement

local FADE_HEIGHT = 20
local EPS = 1

local SPRING = {
	tension = 1050,
	friction = 59,
	precision = 0.04,
}

return function()
	local scrollRef = useRef(nil :: ScrollingFrame?)
	local contentRef = useRef(nil :: Frame?)
	local needsBar, setNeedsBar = useState(false)
	local viewHeight, setViewHeight = useState(0)

	local topBind, topSpring = useSpring(0, SPRING)
	local bottomBind, bottomSpring = useSpring(0, SPRING)

	useEffect(function()
		local conns: { RBXScriptConnection } = {}
		local cancelled = false
		local attempts = 0

		local function recompute()
			if cancelled then
				return
			end
			local sc = scrollRef.current
			local cf = contentRef.current
			if not sc or not cf then
				return
			end
			if sc.AbsoluteSize.Y < 1 then
				return
			end
			local maxScroll = cf.AbsoluteSize.Y - sc.AbsoluteSize.Y
			local need = maxScroll > EPS
			setNeedsBar(need)
			setViewHeight(sc.AbsoluteSize.Y)
			local pos = sc.CanvasPosition.Y
			topSpring:setGoal((need and pos > 2) and 1 or 0)
			bottomSpring:setGoal((need and pos < maxScroll - 2) and 1 or 0)
		end

		local function tryConnect()
			if cancelled then
				return
			end
			for _, c in conns do
				c:Disconnect()
			end
			table.clear(conns)

			local sc = scrollRef.current
			local cf = contentRef.current
			if not sc or not cf then
				attempts += 1
				if attempts <= 300 then
					task.delay(0, tryConnect)
				end
				return
			end

			attempts = 0
			table.insert(conns, sc:GetPropertyChangedSignal("AbsoluteSize"):Connect(recompute))
			table.insert(conns, cf:GetPropertyChangedSignal("AbsoluteSize"):Connect(recompute))
			table.insert(conns, sc:GetPropertyChangedSignal("CanvasSize"):Connect(recompute))
			table.insert(conns, sc:GetPropertyChangedSignal("CanvasPosition"):Connect(recompute))
			task.defer(recompute)
		end

		tryConnect()

		return function()
			cancelled = true
			for _, c in conns do
				c:Disconnect()
			end
		end
	end, {})

	local gradient = useMemo(function()
		local seq = React.joinBindings({ topBind, bottomBind }):map(function(values)
			local top: number = values[1]
			local bottom: number = values[2]
			local h = math.max(viewHeight, 1)
			local f = math.clamp(FADE_HEIGHT / h, 0.001, 0.45)
			return NumberSequence.new({
				NumberSequenceKeypoint.new(0, top),
				NumberSequenceKeypoint.new(f, 0),
				NumberSequenceKeypoint.new(1 - f, 0),
				NumberSequenceKeypoint.new(1, bottom),
			})
		end)
		return e("UIGradient", {
			Rotation = 90,
			Transparency = seq,
		})
	end, { topBind, bottomBind, viewHeight } :: { any })

	return scrollRef, contentRef, needsBar, gradient, topBind, bottomBind
end
