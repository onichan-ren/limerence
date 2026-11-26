local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/guide/renderer")

local e = React.createElement

local Guide = {}
Guide.__index = Guide

setmetatable(Guide, { __index = Element })

export type GuideAction = {
	label: string,
	icon: string?,
	onClick: () -> (),
}

export type GuideStep = {
	title: string,
	body: string,
	doneAt: number,
	action: GuideAction?,
}

export type GuideConfig = {
	stage: Charm.Atom<number>,
	badge: { doneText: string, pendingText: string, doneAt: number }?,
	steps: { GuideStep },
}

local function constructor(text: string, config: GuideConfig): Guide
	local self = Element.new(text) :: any

	setmetatable(self, Guide)

	self._config = config

	return self
end

function Guide.Render(self: Guide, layoutOrder: number?, _props: Element.RenderOptions?): React.Element<any>
	return e(renderer, {
		Guide = self,
		LayoutOrder = layoutOrder,
	})
end

function Guide.RenderInternal(self: Guide, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		Guide = self,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type Guide = typeof(setmetatable(
	{} :: {
		_config: GuideConfig,
	},
	Guide
)) & Element.Element

return constructor
