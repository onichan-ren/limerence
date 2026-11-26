local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/textbox/renderer")

local peek = Charm.peek
local sub = Charm.subscribe
local at = Charm.atom
local e = React.createElement

local Textbox = {}
Textbox.__index = Textbox

setmetatable(Textbox, { __index = Element })

local function constructor(text: string, default: string?, placeholder: string?, numeric: boolean?): Textbox
	local self = Element.new(text) :: any

	setmetatable(self, Textbox)

	self._bindable(false)

	self._placeholder = at(placeholder or "")
	self._focused = at(false)
	self._numeric = numeric == true

	sub(self._state, function(state: string)
		self._active(type(state) == "string" and state ~= "")
	end)

	self._state(default or "")

	return self
end

function Textbox.SetValue(self: Textbox, value: string): ()
	if self._numeric then
		value = string.gsub(value, "[^%d]", "")
	end
	self._state(value)
end

function Textbox.SetPlaceholder(self: Textbox, placeholder: string): Textbox
	self._placeholder(placeholder)
	return self
end

function Textbox.RenderInternal(self: Textbox, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		Textbox = self,
		TextRef = props and props.textRef,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type Textbox = typeof(setmetatable(
	{} :: {
		_placeholder: Charm.Atom<string>,
		_focused: Charm.Atom<boolean>,
		_numeric: boolean,
	},
	Textbox
)) & Element.Element

return constructor
