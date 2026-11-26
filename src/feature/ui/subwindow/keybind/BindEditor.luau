local Charm = require("@pkg/Charm")
local React = require("@pkg/React")

local Subwindow = require("@ui/subwindow/Subwindow")
local renderer = require("@ui/subwindow/keybind/renderer")

local at = Charm.atom
local peek = Charm.peek
local e = React.createElement

local BindEditor = {}
BindEditor.__index = BindEditor

setmetatable(BindEditor, { __index = Subwindow })

local function constructor(): BindEditor
	local self = Subwindow.new() :: any
	setmetatable(self, BindEditor)
	self._element = at(nil :: any?)
	return self
end

function BindEditor.Open(self: BindEditor, element: any, position: UDim2?): ()
	self._element(element)
	if element and element.AddBind and element._binds and #peek(element._binds) == 0 then
		element:AddBind()
	end
	self:SetPosition(position or UDim2.new(0.5, 0, 0.5, 0))
	self:SetOpen(true)
end

function BindEditor.Close(self: BindEditor): ()
	self:SetOpen(false)
end

function BindEditor.Render(self: BindEditor): React.Element<any>
	return e(renderer, { BindEditor = self })
end

export type Subwindow = Subwindow.Subwindow
export type BindEditor = typeof(setmetatable(
	{} :: {
		_element: Charm.Atom<any?>,
	},
	BindEditor
)) & Subwindow

return constructor
