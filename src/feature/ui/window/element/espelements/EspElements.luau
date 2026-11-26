local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/espelements/renderer")

local e = React.createElement

local EspElements = {}
EspElements.__index = EspElements

setmetatable(EspElements, { __index = Element })

local function constructor(text: string, config: any): EspElements
	local self = Element.new(text) :: any

	setmetatable(self, EspElements)

	self._config = config

	return self
end

function EspElements.Render(self: EspElements, layoutOrder: number?, _props: Element.RenderOptions?): React.Element<any>
	return e(renderer, {
		EspElements = self,
		LayoutOrder = layoutOrder,
	})
end

function EspElements.RenderInternal(self: EspElements, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		EspElements = self,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type EspElements = typeof(setmetatable(
	{} :: {
		_config: any,
	},
	EspElements
)) & Element.Element

return constructor
