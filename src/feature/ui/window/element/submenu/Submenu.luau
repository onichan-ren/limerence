local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local Element = require("@ui/window/element/Element")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local registry = require("@ui/window/element/registry")
local renderer = require("@ui/window/element/submenu/renderer")

local peek = Charm.peek
local at = Charm.atom
local e = React.createElement

local Submenu = {}
Submenu.__index = Submenu

setmetatable(Submenu, { __index = Element })

local function constructor(text: string): Submenu
	local self = Element.new(text) :: any

	setmetatable(self, Submenu)

	self._elements = at({} :: { [number]: Element.Element })
	self._open = at(false)
	self._showTitle = at(false)

	return self
end

function Submenu.AddElement(self: Submenu, type: string, ...: any): Element.Element?
	local elementType = registry[type]
	if not elementType then
		return nil
	end

	local element = elementType(...)
	local raw = peek(self._elements)
	self._elements(Sift.Array.insert(raw, #raw + 1, element))

	return element
end

function Submenu.Open(self: Submenu, position: UDim2?): ()
	SubwindowController.OpenSubmenu(self, position)
end

function Submenu.RenderInternal(self: Submenu, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		Submenu = self,
		TextRef = props and props.textRef,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type Submenu = typeof(setmetatable(
	{} :: {
		_elements: Charm.Atom<{ [number]: Element.Element }>,
		_open: Charm.Atom<boolean>,
		_showTitle: Charm.Atom<boolean>,
	},
	Submenu
)) & Element.Element

return constructor
