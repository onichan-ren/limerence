local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/toggle/renderer")

local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement

local Toggle = {}
Toggle.__index = Toggle

setmetatable(Toggle, { __index = Element })

local function constructor(text: string, default: boolean): Toggle
	local self = Element.new(text) :: any

	setmetatable(self, Toggle)

	self._bindable(true)

	sub(self._state, function(state: boolean)
		self._active(state)
	end)

	self._state(default)

	return self
end

function Toggle.Toggle(self: Toggle): ()
	self._state(not peek(self._state))
end

function Toggle.SetState(self: Toggle, state: boolean): ()
	self._state(state)
end

function Toggle.RenderInternal(self: Toggle, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		Toggle = self,
		TextRef = props and props.textRef,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type Toggle = typeof(setmetatable({} :: {}, Toggle)) & Element.Element

return constructor
