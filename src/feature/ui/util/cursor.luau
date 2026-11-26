local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local GuiService = cloneref(game:GetService("GuiService")) :: GuiService

local Charm = require("@pkg/Charm")
local dpiState = require("@ui/util/dpiState")

local cursor = {}

local function currentScale(): number
	local scale = Charm.peek(dpiState.scale)
	return scale > 0 and scale or 1
end

cursor.getPosition = LPH_NO_VIRTUALIZE(function(input: InputObject?): UDim2
	local screenX: number
	local screenY: number

	if input then
		screenX = input.Position.X
		screenY = input.Position.Y + (GuiService:GetGuiInset().Y :: number)
	else
		local mouse = UserInputService:GetMouseLocation()
		screenX = mouse.X
		screenY = mouse.Y
	end

	local scale = currentScale()
	return UDim2.fromOffset(screenX / scale, screenY / scale)
end)

return cursor
