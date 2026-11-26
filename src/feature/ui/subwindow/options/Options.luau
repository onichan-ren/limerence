local Charm = require("@pkg/Charm")
local React = require("@pkg/React")

local Subwindow = require("@ui/subwindow/Subwindow")
local renderer = require("@ui/subwindow/options/renderer")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement

local Options = {}
Options.__index = Options

setmetatable(Options, { __index = Subwindow })

local function constructor(): Options
	local self = Subwindow.new() :: any

	setmetatable(self, Options)

	self._title = at("")
	self._showTitle = at(true)
	self._elements = at({} :: { [number]: any })
	self._sidePane = at(nil :: any)
	self._source = at(nil :: any)

	sub(self._isOpen, function(isOpen: boolean)
		if isOpen then
			return
		end
		local current = peek(self._source)
		if current and current._open then
			current._open(false)
		end
		self._source(nil :: any)
	end)

	return self
end

function Options.Open(self: Options, source: any, position: UDim2?): ()
	local previous = peek(self._source)
	local selfElements = peek(self._elements)
	local elements = peek(source._elements)

	if previous == source and selfElements == elements and peek(self._isOpen) then
		return
	end

	if previous and previous ~= source and previous._open then
		previous._open(false)
	end

	if source._open then
		source._open(true)
	end

	local sourceShowTitle = source._showTitle
	self._source(source)
	self._title(peek(source._text))
	self._showTitle(sourceShowTitle ~= nil and peek(sourceShowTitle) or true)
	self._elements(elements)
	self._sidePane(source._sidePaneComponent and { component = source._sidePaneComponent } or nil)

	self:SetPosition(position or UDim2.new(0.5, 0, 0.5, 0))
	self:SetOpen(true)
end

function Options.Close(self: Options): ()
	self:SetOpen(false)
end

function Options.Render(self: Options): React.Element<any>
	return e(renderer, {
		Options = self,
	})
end

export type Subwindow = Subwindow.Subwindow
export type Options =
	typeof(setmetatable(
		{} :: {
			_title: Charm.Atom<string>,
			_showTitle: Charm.Atom<boolean>,
			_elements: Charm.Atom<{ [number]: any }>,
			_sidePane: Charm.Atom<any>,
			_source: Charm.Atom<any>,
		},
		Options
	))
	& Subwindow

return constructor
