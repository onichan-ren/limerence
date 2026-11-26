local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")
local Charm = require("@pkg/Charm")

local SPRING = require("@ui/util/spring")
local useClickOutside = require("@ui/hook/useClickOutside")
local sharedRefs = require("@ui/subwindow/sharedRefs")
local clampToViewport = require("@ui/util/clampToViewport")
local floatingController = require("@ui/floating/floatingController")

local useSpring = ReactRipple.useSpring
local useEffect = React.useEffect
local useState = React.useState
local useMemo = React.useMemo
local useBinding = React.useBinding
local useRef = React.useRef
local useAt = ReactCharm.useAtom

local Z_BASE = 10

type Subwindow = {
	_isOpen: Charm.Atom<boolean>,
	_position: Charm.Atom<UDim2>,
}

export type SubwindowAnimationOptions = {
	preset: SPRING.SpringPreset?,
	slideOffset: number?,
	strokeIntensity: number?,
	onClickOutside: (() -> ())?,
	clampPadding: number?,
	clampToViewport: boolean?,
	floatingId: string?,
	floatingPriority: number?,
}

export type SubwindowAnimation = {
	frameRef: { current: GuiObject? },
	isOpen: boolean,
	bind: any,
	position: any,
	visible: any,
	transparency: any,
	strokeTransparency: any,
	zIndex: number,
}

local function useSubwindowAnimation(subwindow: Subwindow, options: SubwindowAnimationOptions?): SubwindowAnimation
	local opts = options or {} :: SubwindowAnimationOptions
	local preset = opts.preset or SPRING.smooth
	local slideOffset = opts.slideOffset or 12
	local strokeIntensity = opts.strokeIntensity or 1
	local clampEnabled = opts.clampToViewport ~= false
	local clampPadding = opts.clampPadding or clampToViewport.PADDING
	local onClickOutsideRef = useRef(opts.onClickOutside)
	onClickOutsideRef.current = opts.onClickOutside

	local isOpen = useAt(subwindow._isOpen)
	local position = useAt(subwindow._position)

	local bind, spring = useSpring(0, preset)

	useEffect(function()
		spring:setGoal(isOpen and 1 or 0)
	end, { isOpen })

	local frameRef = useRef(nil :: GuiObject?)

	useClickOutside(frameRef, isOpen, function()
		local cb = onClickOutsideRef.current
		if cb then
			cb()
		end
	end)

	local zIndex, setZIndex = useState(Z_BASE)

	useEffect(function()
		if not isOpen then
			return
		end
		local nextZ = Z_BASE + sharedRefs.getNextOrder()
		setZIndex(nextZ)
		sharedRefs.add(frameRef, nextZ)
		return function()
			sharedRefs.remove(frameRef)
		end
	end, { isOpen })

	local floatingId = opts.floatingId
	local floatingPriority = opts.floatingPriority or floatingController.PRIORITY.MENU
	local closeRef = useRef(opts.onClickOutside)
	closeRef.current = opts.onClickOutside

	useEffect(function()
		if not isOpen or not floatingId then
			return
		end
		floatingController.Register(floatingId, floatingPriority, function(): ()
			local cb = closeRef.current
			if cb then
				cb()
			end
		end)
		return function()
			floatingController.Unregister(floatingId)
		end
	end, { isOpen, floatingId, floatingPriority })

	local clampBind, setClampBind = useBinding(Vector2.zero)

	useEffect(function()
		setClampBind(Vector2.zero)
	end, { position })

	useEffect(function()
		if not clampEnabled or not isOpen then
			return
		end

		local frame = frameRef.current
		if not frame then
			return
		end

		local conns: { RBXScriptConnection } = {}

		local function recompute(): ()
			local current = frameRef.current
			if not current then
				return
			end

			local delta = clampToViewport.compute(current, clampPadding)
			if delta.X == 0 and delta.Y == 0 then
				return
			end

			setClampBind(clampBind:getValue() + delta)
		end

		table.insert(conns, frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(recompute))

		local layer = frame:FindFirstAncestorWhichIsA("LayerCollector")
		if layer then
			table.insert(conns, layer:GetPropertyChangedSignal("AbsoluteSize"):Connect(recompute))
		end

		local camera = Workspace.CurrentCamera
		if camera then
			table.insert(conns, camera:GetPropertyChangedSignal("ViewportSize"):Connect(recompute))
		end

		recompute()

		return function()
			for _, conn in next, conns do
				conn:Disconnect()
			end
		end
	end, { isOpen, clampEnabled, clampPadding, position } :: { any })

	local positionBind = useMemo(function()
		return React.joinBindings({
			alpha = bind,
			clamp = clampBind,
		}):map(function(values: { alpha: number, clamp: Vector2 })
			local value = values.alpha
			local clampOffset = values.clamp
			local offset = (1 - value) * slideOffset
			return UDim2.new(
				position.X.Scale,
				(position.X.Offset :: number) + clampOffset.X,
				position.Y.Scale,
				(position.Y.Offset :: number) + offset + clampOffset.Y
			)
		end)
	end, { bind, clampBind, position, slideOffset })

	return {
		frameRef = frameRef,
		isOpen = isOpen,
		bind = bind,
		zIndex = zIndex,
		position = positionBind,
		visible = bind:map(function(value: number)
			return value > 0.01
		end),
		transparency = bind:map(function(value: number)
			return 1 - value
		end),
		strokeTransparency = bind:map(function(value: number)
			return 1 - value * strokeIntensity
		end),
	}
end

return useSubwindowAnimation
