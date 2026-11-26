local React = require("@pkg/React")
local Charm = require("@pkg/Charm")

local at = Charm.atom
local e = React.createElement

local Subwindow = {}
Subwindow.__index = Subwindow

function Subwindow.new(): Subwindow
	local self = setmetatable({}, Subwindow) :: Subwindow

	self._isOpen = at(false)
	self._position = at(UDim2.fromScale(0, 0))

	return self
end

function Subwindow.SetPosition(self: Subwindow, position: UDim2): ()
	self._position(position)
end

function Subwindow.SetOpen(self: Subwindow, state: boolean): ()
	self._isOpen(state)
end

function Subwindow.Render(self: Subwindow): React.Element<any>
	return e("Frame", {
		BackgroundTransparency = 1,
	}, {})
end

export type Subwindow = typeof(setmetatable(
	{} :: {
		_isOpen: Charm.Atom<boolean>,
		_position: Charm.Atom<UDim2>,
	},
	Subwindow
))

return Subwindow
