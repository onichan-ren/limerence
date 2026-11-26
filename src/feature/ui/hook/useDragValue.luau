local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local React = require("@pkg/React")

local useEffect = React.useEffect
local useRef = React.useRef

type DragCallback = (alpha: Vector2) -> ()

local function computeAlpha(frame: GuiObject, position: Vector3): Vector2
	local origin = frame.AbsolutePosition
	local size = frame.AbsoluteSize
	local sizeX = size.X > 0 and size.X or 1
	local sizeY = size.Y > 0 and size.Y or 1
	return Vector2.new(
		math.clamp((position.X - origin.X) / sizeX, 0, 1),
		math.clamp((position.Y - origin.Y) / sizeY, 0, 1)
	)
end

local useDragValue = LPH_NO_VIRTUALIZE(function(callback: DragCallback): (frame: GuiObject, input: InputObject) -> ()
	local callbackRef = useRef(callback)
	callbackRef.current = callback

	local activeFrameRef = useRef(nil :: GuiObject?)
	local draggingRef = useRef(false)

	useEffect(function()
		local moveConn = UserInputService.InputChanged:Connect(function(input: InputObject)
			if not draggingRef.current then
				return
			end
			if
				input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			local frame = activeFrameRef.current
			if not frame then
				return
			end

			callbackRef.current(computeAlpha(frame, input.Position))
		end)

		local endConn = UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				draggingRef.current = false
				activeFrameRef.current = nil
			end
		end)

		return function()
			moveConn:Disconnect()
			endConn:Disconnect()
		end
	end, {})

	return function(frame: GuiObject, input: InputObject)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		draggingRef.current = true
		activeFrameRef.current = frame
		callbackRef.current(computeAlpha(frame, input.Position))
	end
end)

return useDragValue
