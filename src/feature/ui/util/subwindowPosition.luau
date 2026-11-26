local Charm = require("@pkg/Charm")

local peek = Charm.peek
local at = Charm.atom

local _menuCenter = at(UDim2.fromScale(0.5, 0.5))

local subwindowPosition = {}

function subwindowPosition.syncMenuPosition(position: UDim2): ()
	_menuCenter(position)
end

function subwindowPosition.menuCenter(): UDim2
	return peek(_menuCenter)
end

return subwindowPosition
