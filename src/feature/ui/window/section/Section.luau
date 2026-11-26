local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local renderer = require("@ui/window/section/renderer")
local elements = require("@ui/window/element/elements")

local peek = Charm.peek
local at = Charm.atom
local e = React.createElement

local Section = {}
Section.__index = Section

local function constructor(title: string): Section
	local self = setmetatable({}, Section) :: Section

	self._title = title
	self._elements = at({})
	self._headerAccessory = at(nil :: any?)

	return self
end

function Section.SetHeaderAccessory(self: Section, element: any?): Section
	self._headerAccessory(element)
	return self
end

function Section.AddElement(self: Section, type: string, ...: any): elements.Element?
	local elementType = elements[type]
	if not elementType then
		return nil
	end

	local element = elementType(...)
	local raw = peek(self._elements)
	self._elements(Sift.Array.insert(raw, #raw + 1, element))

	return element
end

function Section.SortByTextLength(self: Section, descending: boolean?): Section
	local current = peek(self._elements)
	local sorted = table.clone(current)
	table.sort(sorted, function(a, b)
		local aLen = #(peek(a._text) or "")
		local bLen = #(peek(b._text) or "")
		if descending then
			return aLen > bLen
		end
		return aLen < bLen
	end)
	self._elements(sorted)
	return self
end

function Section.Render(self: Section, props: RenderOptions?): React.Element<any>
	return e(renderer, {
		Section = self,
		TextOffsetY = props and props.textOffsetY,
	})
end

export type RenderOptions = {
	textOffsetY: number?,
}

export type Section = typeof(setmetatable(
	{} :: {
		_title: string,
		_elements: Charm.Atom<{ [number]: elements.Element }>,
		_headerAccessory: Charm.Atom<any?>,
	},
	Section
))

return constructor
