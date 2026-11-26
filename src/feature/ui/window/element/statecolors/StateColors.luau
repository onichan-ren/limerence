local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/statecolors/renderer")

local e = React.createElement

local StateColors = {}
StateColors.__index = StateColors

setmetatable(StateColors, { __index = Element })

local function constructor(text: string, config: any): StateColors
	local self = Element.new(text) :: any

	setmetatable(self, StateColors)

	self._config = config

	return self
end

function StateColors.Render(self: StateColors, layoutOrder: number?, _props: Element.RenderOptions?): React.Element<any>
	return e(renderer, {
		StateColors = self,
		LayoutOrder = layoutOrder,
	})
end

function StateColors.RenderInternal(self: StateColors, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		StateColors = self,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type StateColors = typeof(setmetatable(
	{} :: {
		_config: any,
	},
	StateColors
)) & Element.Element

return constructor
