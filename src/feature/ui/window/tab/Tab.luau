local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")
local renderer = require("@ui/window/tab/renderer")
local Section = require("@ui/window/section/Section")
local windowState = require("@ui/window/windowState")

local peek = Charm.peek
local sub = Charm.subscribe
local at = Charm.atom
local e = React.createElement

local Tab = {}
Tab.__index = Tab

local function constructor(title: string, icon: string, properties: TabProperties): Tab
	local self = setmetatable({}, Tab) :: Tab

	self.title = title
	self.icon = icon
	self.layoutOrder = nil :: number?

	self._isOpen = at(false)
	self._subtabs = at({}) :: Charm.Atom<{ [number]: Tab }>
	self._parent = nil :: Tab?
	self._activeSubtab = at(nil :: Tab?)

	local containerCount = properties.containers or 1
	local containers = {}

	for i = 1, containerCount do
		containers[i] = {
			_sections = at({}),
		}
	end

	self._containers = at(containers)
	self._customRenderer = at(nil :: { render: (Tab) -> React.Element<any> }?)
	self._headerAccessory = at(nil :: { render: (Tab) -> React.Element<any> }?)
	self._useScope = at(false)

	sub(windowState.openTab, function(tab)
		if tab == self then
			self._isOpen(true)
			if self._parent then
				self._parent._activeSubtab(self)
			end
		else
			self._isOpen(false)
		end
	end)

	return self
end

function Tab.AddSection(self: Tab, title: string, container: number): Section.Section
	local containers = peek(self._containers)
	local containerData = containers[container]

	local sections = peek(containerData._sections)
	local newSection = Section(title)
	;(newSection :: any)._tab = self
	containerData._sections(Sift.Array.insert(sections, #sections + 1, newSection))

	return newSection
end

function Tab.AddSubtab(self: Tab, title: string, icon: string, properties: TabProperties?): Tab
	local rawSubtabs = peek(self._subtabs)
	local newTab = constructor(title, icon, properties or {})
	newTab._parent = self
	newTab.layoutOrder = #rawSubtabs + 1

	self._subtabs(Sift.Array.insert(rawSubtabs, #rawSubtabs + 1, newTab))

	return newTab
end

function Tab.GetSubtab(self: Tab, title: string): Tab?
	for _, subtab in next, peek(self._subtabs) do
		if subtab.title == title then
			return subtab
		end
	end
	return nil
end

function Tab.GetSection(self: Tab, title: string): Section.Section?
	local containers = peek(self._containers)
	for _, containerData in next, containers do
		local sections = peek(containerData._sections)
		for _, section in next, sections do
			if section._title == title then
				return section
			end
		end
	end
	return nil
end

function Tab.Render(self: Tab): React.Element<any>
	return e(renderer, {
		Tab = self,
	})
end

function Tab.UseScope(self: Tab, enabled: boolean?): Tab
	self._useScope(enabled ~= false)
	return self
end

function Tab.SetHeaderAccessory(self: Tab, fn: ((Tab) -> React.Element<any>)?): Tab
	if fn then
		self._headerAccessory({ render = fn })
	else
		self._headerAccessory(nil)
	end
	return self
end

function Tab.SetRenderer(self: Tab, fn: ((Tab) -> React.Element<any>)?): Tab
	if fn then
		self._customRenderer({ render = fn })
	else
		self._customRenderer(nil)
	end
	return self
end

function Tab.IsOpen(self: Tab): boolean
	return peek(self._isOpen)
end

export type Tab = typeof(setmetatable(
	{} :: {
		_containers: Charm.Atom<{ [number]: { _sections: Charm.Atom<{ [number]: Section.Section }> } }>,
		_customRenderer: Charm.Atom<{ render: (Tab) -> React.Element<any> }?>,
		_headerAccessory: Charm.Atom<{ render: (Tab) -> React.Element<any> }?>,
		_useScope: Charm.Atom<boolean>,
		title: string,
		icon: string,
		layoutOrder: number?,
		_isOpen: Charm.Atom<boolean>,
		_subtabs: Charm.Atom<{ [number]: Tab }>,
		_parent: Tab?,
		_activeSubtab: Charm.Atom<Tab?>,
	},
	Tab
))
export type TabProperties = {
	containers: number?,
}

return constructor
