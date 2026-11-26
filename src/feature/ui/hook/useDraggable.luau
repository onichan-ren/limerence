local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local RunService = cloneref(game:GetService("RunService")) :: RunService

local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local dpiState = require("@ui/util/dpiState")

local useEffect = React.useEffect
local useRef = React.useRef
local useCallback = React.useCallback
local useBinding = React.useBinding

local activeDragOwner: any = nil

local useDraggable = LPH_NO_VIRTUALIZE(function(positionAtom: Charm.Atom<UDim2>)
	local initial = Charm.peek(positionAtom)
	local positionBind, setPositionBind = useBinding(initial)

	local ownerId = useRef({})
	local dragging = useRef(false)
	local dragStart = useRef(Vector2.zero)
	local startScale = useRef(Vector2.zero)
	local startOffset = useRef(Vector2.zero)
	local pendingPos = useRef(nil :: UDim2?)
	local lastWritten = useRef(initial)
	local positionAtomRef = useRef(positionAtom)
	positionAtomRef.current = positionAtom
	local setPositionBindRef = useRef(setPositionBind)
	setPositionBindRef.current = setPositionBind

	useEffect(function()
		local unsub = Charm.subscribe(positionAtomRef.current, function(value: UDim2)
			if dragging.current then
				return
			end
			if lastWritten.current ~= value then
				lastWritten.current = value
				setPositionBindRef.current(value)
			end
		end)
		return unsub
	end, {})

	local onInputBegan = useCallback(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if activeDragOwner ~= nil then
			return
		end

		activeDragOwner = ownerId.current
		dragging.current = true
		dragStart.current = Vector2.new(input.Position.X, input.Position.Y)

		local current = Charm.peek(positionAtomRef.current)
		startScale.current = Vector2.new(current.X.Scale, current.Y.Scale)
		startOffset.current = Vector2.new(current.X.Offset, current.Y.Offset)
		lastWritten.current = current
	end, {})

	useEffect(function()
		local moveConn = UserInputService.InputChanged:Connect(function(input: InputObject)
			if not dragging.current then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end

			local rawDelta = Vector2.new(input.Position.X, input.Position.Y) - dragStart.current
			local scale = Charm.peek(dpiState.scale)
			if scale <= 0 then
				scale = 1
			end
			local delta = rawDelta / scale
			pendingPos.current = UDim2.new(
				startScale.current.X,
				startOffset.current.X + delta.X,
				startScale.current.Y,
				startOffset.current.Y + delta.Y
			)
		end)

		local flushConn = RunService.Heartbeat:Connect(function()
			local pending = pendingPos.current
			if pending == nil then
				return
			end
			pendingPos.current = nil
			if lastWritten.current ~= pending then
				lastWritten.current = pending
				setPositionBindRef.current(pending)
				positionAtomRef.current(pending)
			end
		end)

		local endConn = UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			if not dragging.current then
				return
			end
			dragging.current = false
			if activeDragOwner == ownerId.current then
				activeDragOwner = nil
			end
			local pending = pendingPos.current
			pendingPos.current = nil
			if pending and lastWritten.current ~= pending then
				lastWritten.current = pending
				setPositionBindRef.current(pending)
				positionAtomRef.current(pending)
			end
		end)

		return function()
			moveConn:Disconnect()
			flushConn:Disconnect()
			endConn:Disconnect()
			if activeDragOwner == ownerId.current then
				activeDragOwner = nil
			end
			dragging.current = false
		end
	end, {})

	return onInputBegan, positionBind
end)

return useDraggable
