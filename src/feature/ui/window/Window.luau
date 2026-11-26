local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local renderer = require("@ui/window/renderer")
local Tab = require("@ui/window/tab/Tab")
local TabGroup = require("@ui/window/tabgroup/TabGroup")

local peek = Charm.peek
local at = Charm.atom
local e = React.createElement

local Window = {}
Window.__index = Window

local function constructor(name: string): Window
	local self = setmetatable({}, Window) :: Window

	self._name = name
	self._isOpen = at(false)
	self._size = at(UDim2.fromOffset(680, 560))
	self._position = at(UDim2.fromScale(0.5, 0.5))
	self._tabGroups = at({}) :: Charm.Atom<{ [number]: TabGroup.TabGroup }>

	return self
end

function Window.AddTabGroup(self: Window, title: string, layoutOrder: number?): TabGroup.TabGroup
	local rawTabGroups = peek(self._tabGroups)
	local newTabGroup = TabGroup(title, layoutOrder or (#rawTabGroups + 1))

	self._tabGroups(Sift.Array.insert(rawTabGroups, #rawTabGroups + 1, newTabGroup))

	return newTabGroup
end

function Window.GetTabGroup(self: Window, title: string): TabGroup.TabGroup?
	for _, group in peek(self._tabGroups) do
		if group.title == title then
			return group
		end
	end
	return nil
end

function Window.RemoveTabGroup(self: Window, title: string): ()
	local raw = peek(self._tabGroups)
	local filtered = {}
	for _, group in next, raw do
		if group.title ~= title then
			table.insert(filtered, group)
		end
	end
	self._tabGroups(filtered)
end

function Window.AddTabToGroup(
	self: Window,
	groupTitle: string,
	tabTitle: string,
	icon: string,
	properties: Tab.TabProperties?
): Tab.Tab?
	local group = self:GetTabGroup(groupTitle)
	if not group then
		return nil
	end
	return group:AddTab(tabTitle, icon, properties or {})
end

function Window.IsOpen(self: Window): boolean
	return peek(self._isOpen)
end

function Window.SetOpen(self: Window, open: boolean): ()
	self._isOpen(open)
end

function Window.ToggleOpen(self: Window): ()
	self._isOpen(not peek(self._isOpen))
end

function Window.SetSize(self: Window, size: UDim2): ()
	self._size(size)
end

function Window.SetPosition(self: Window, position: UDim2): ()
	self._position(position)
end

function Window.Render(self: Window): React.Element<any>
	return e(renderer, {
		Window = self,
	})
end

export type Window = typeof(setmetatable(
	{} :: {
		_name: string,
		_isOpen: Charm.Atom<boolean>,
		_size: Charm.Atom<UDim2>,
		_position: Charm.Atom<UDim2>,
		_openTab: Charm.Atom<any>,
		_tabGroups: Charm.Atom<{ [number]: TabGroup.TabGroup }>,
	},
	Window
))
return constructor
