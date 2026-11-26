local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local dpiState = require("@ui/util/dpiState")

local DEFAULT_PADDING = 10

local clampToViewport = {}

clampToViewport.PADDING = DEFAULT_PADDING

LPH_NO_VIRTUALIZE(function()
	local function getViewportRect(frame: GuiObject?): (Vector2, Vector2)
		if frame then
			local layer = frame:FindFirstAncestorWhichIsA("LayerCollector")
			if layer then
				return layer.AbsolutePosition, layer.AbsoluteSize
			end
		end

		local camera = Workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		return Vector2.zero, size
	end

	clampToViewport.getViewportRect = getViewportRect

	function clampToViewport.computeDelta(
		framePosition: Vector2,
		frameSize: Vector2,
		viewportPosition: Vector2,
		viewportSize: Vector2,
		padding: number?
	): Vector2
		local pad = padding or DEFAULT_PADDING

		local minX = viewportPosition.X + pad
		local minY = viewportPosition.Y + pad
		local maxX = math.max(minX, viewportPosition.X + viewportSize.X - frameSize.X - pad)
		local maxY = math.max(minY, viewportPosition.Y + viewportSize.Y - frameSize.Y - pad)

		local clampedX = math.clamp(framePosition.X, minX, maxX)
		local clampedY = math.clamp(framePosition.Y, minY, maxY)

		return Vector2.new(clampedX - framePosition.X, clampedY - framePosition.Y)
	end

	function clampToViewport.compute(frame: GuiObject, padding: number?): Vector2
		local size = frame.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			return Vector2.zero
		end

		local viewportPosition, viewportSize = getViewportRect(frame)
		local delta =
			clampToViewport.computeDelta(frame.AbsolutePosition, size, viewportPosition, viewportSize, padding)

		local scale = Charm.peek(dpiState.scale)
		if scale <= 0 then
			scale = 1
		end
		return scale == 1 and delta or delta / scale
	end
end)()

return clampToViewport
