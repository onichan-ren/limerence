local Charm = require("@pkg/Charm")
local React = require("@pkg/React")

local Subwindow = require("@ui/subwindow/Subwindow")
local renderer = require("@ui/subwindow/dropdown/renderer")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement

local CLOSE_GRACE_PERIOD = 0.1

local Dropdown = {}
Dropdown.__index = Dropdown

setmetatable(Dropdown, { __index = Subwindow })

local function constructor(): Dropdown
	local self = Subwindow.new() :: any
	setmetatable(self, Dropdown)

	self._source = at(nil :: any)
	self._lastClosedSource = nil
	self._lastClosedAt = 0

	sub(self._isOpen, function(isOpen: boolean)
		if isOpen then
			return
		end
		local current = peek(self._source)
		if current then
			current._open(false)
			self._lastClosedSource = current
			self._lastClosedAt = os.clock()
		end
		self._source(nil :: any)
	end)

	return self
end

function Dropdown.Open(self: Dropdown, source: any, position: UDim2?): ()
	local previous = peek(self._source)
	if previous and previous ~= source then
		previous._open(false)
	end

	self._source(source)
	source._open(true)

	self:SetPosition(position or UDim2.new(0.5, 0, 0.5, 0))
	self:SetOpen(true)
end

function Dropdown.Close(self: Dropdown): ()
	local source = peek(self._source)
	if source then
		source._open(false)
		self._lastClosedSource = source
		self._lastClosedAt = os.clock()
	end
	self:SetOpen(false)
end

function Dropdown.WasJustClosedFor(self: Dropdown, source: any): boolean
	return self._lastClosedSource == source and os.clock() - self._lastClosedAt < CLOSE_GRACE_PERIOD
end

function Dropdown.Render(self: Dropdown): React.Element<any>
	return e(renderer, {
		Dropdown = self,
	})
end

export type Subwindow = Subwindow.Subwindow
export type Dropdown = typeof(setmetatable(
	{} :: {
		_source: Charm.Atom<any>,
		_lastClosedSource: any,
		_lastClosedAt: number,
	},
	Dropdown
)) & Subwindow

return constructor
