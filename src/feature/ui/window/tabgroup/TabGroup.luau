local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")
local Tab = require("@ui/window/tab/Tab")
local Renderer = require("@ui/window/tabgroup/renderer")

local peek = Charm.peek
local e = React.createElement
local at = Charm.atom

local TabGroup = {}
TabGroup.__index = TabGroup

local function constructor(title: string, layoutOrder: number?): TabGroup
	local self = setmetatable({}, TabGroup) :: TabGroup

	self.title = title
	self.layoutOrder = layoutOrder
	self.tabs = at({})
	self._visible = at(true) :: Charm.Atom<boolean>

	return self
end

function TabGroup.AddTab(self: TabGroup, title: string, icon: string, properties: Tab.TabProperties): Tab.Tab
	local rawTabs = peek(self.tabs)
	local newTab = Tab(title, icon, properties)
	newTab.layoutOrder = #rawTabs + 1

	self.tabs(Sift.Array.insert(rawTabs, #rawTabs + 1, newTab))

	return newTab
end

function TabGroup.Render(self: TabGroup): React.Element<any>
	return e(Renderer, {
		TabGroup = self,
	})
end

export type TabGroup = typeof(setmetatable(
	{} :: {
		title: string,
		tabs: Charm.Atom<{ [number]: Tab.Tab }>,
		layoutOrder: number?,
		_visible: Charm.Atom<boolean>,
	},
	TabGroup
))
export type Tab = Tab.Tab

return constructor
