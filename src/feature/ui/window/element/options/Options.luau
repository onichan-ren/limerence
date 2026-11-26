local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local Element = require("@ui/window/element/Element")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local registry = require("@ui/window/element/registry")
local renderer = require("@ui/window/element/options/renderer")

local peek = Charm.peek
local at = Charm.atom
local e = React.createElement

local Options = {}
Options.__index = Options

setmetatable(Options, { __index = Element })

local function constructor(text: string): Options
	local self = Element.new(text) :: any

	setmetatable(self, Options)

	self._elements = at({} :: { [number]: Element.Element })
	self._open = at(false)
	self._sidePaneComponent = nil :: any

	return self
end

function Options.SetSidePane(self: Options, component: any): ()
	self._sidePaneComponent = component
end

function Options.AddElement(self: Options, type: string, ...: any): Element.Element?
	local elementType = registry[type]
	if not elementType then
		return nil
	end

	local element = elementType(...)
	local raw = peek(self._elements)
	self._elements(Sift.Array.insert(raw, #raw + 1, element))

	return element
end

function Options.Open(self: Options, position: UDim2?): ()
	SubwindowController.OpenOptions(self, position)
end

function Options.RenderInternal(self: Options, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		Options = self,
		TextRef = props and props.textRef,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type Options = typeof(setmetatable(
	{} :: {
		_elements: Charm.Atom<{ [number]: Element.Element }>,
		_open: Charm.Atom<boolean>,
		_sidePaneComponent: any,
	},
	Options
)) & Element.Element

return constructor
