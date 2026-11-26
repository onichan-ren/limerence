local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/esppreview/renderer")

local e = React.createElement

local EspPreview = {}
EspPreview.__index = EspPreview

setmetatable(EspPreview, { __index = Element })

local function constructor(text: string, config: any): EspPreview
	local self = Element.new(text) :: any

	setmetatable(self, EspPreview)

	self._config = config
	self._searchHidden = true

	return self
end

function EspPreview.Render(self: EspPreview, layoutOrder: number?, _props: Element.RenderOptions?): React.Element<any>
	return e(renderer, {
		EspPreview = self,
		LayoutOrder = layoutOrder,
	})
end

function EspPreview.RenderInternal(self: EspPreview, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		EspPreview = self,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type EspPreview = typeof(setmetatable(
	{} :: {
		_config: any,
	},
	EspPreview
)) & Element.Element

return constructor
