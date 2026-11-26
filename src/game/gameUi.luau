local Charm = require("@pkg/Charm")
local UIController = require("@src/feature/ui/UIController")
local FileController = require("@src/feature/file/FileController")
local ConfigController = require("@src/feature/config/ConfigController")
local UserController = require("@src/feature/config/UserController")
local ScopeController = require("@src/feature/ui/scope/ScopeController")
local uiRegistry = require("@src/feature/ui/uiRegistry")
local loader = require("@loader/loader")

local sub = Charm.subscribe
local peek = Charm.peek

local gameUi = {}

function gameUi.Group(title: string): any
	return UIController.EnsureTabGroup(title)
end

function gameUi.Tab(group: any, name: string, icon: string, containers: number?): any
	if not group then
		return nil
	end
	return uiRegistry.add(
		group:AddTab(name, FileController.Get("image", icon) :: string, {
			containers = containers or 2,
		}),
		{ kind = "tab" }
	)
end

function gameUi.Subtab(tab: any, name: string, icon: string, containers: number?): any
	if not tab then
		return nil
	end
	return uiRegistry.add(
		tab:AddSubtab(name, FileController.Get("image", icon) :: string, {
			containers = containers or 2,
		}),
		{ kind = "tab" }
	)
end

local Linker = {}
Linker.__index = Linker

local function joinKey(prefix: string, key: string): string
	if prefix == "" then
		return key
	end
	return `{prefix}.{key}`
end

local function makeLinker(host: any, prefix: string, scoped: boolean?, globalOnly: boolean?, prefs: boolean?): Linker
	return setmetatable({
		_host = host,
		_prefix = prefix,
		_scoped = scoped or false,
		_globalOnly = globalOnly or false,
		_prefs = prefs or false,
		_elements = {} :: { [string]: any },
	}, Linker) :: any
end

local function add(self: Linker, key: string?, element: any): any
	if key then
		local fullKey = joinKey(self._prefix, key)
		if self._prefs then
			UserController.LinkElement(fullKey, element)
		else
			ConfigController.Link(fullKey, element)
		end
		self._elements[key] = element
		if self._scoped then
			ScopeController.BindElement(element, fullKey, { globalOnly = self._globalOnly })
		end
	end
	return element
end

function gameUi.Section(tab: any, name: string, container: number?, prefix: string?): Linker
	return makeLinker(tab:AddSection(name, container or 1), prefix or "")
end

function gameUi.ScopedSection(tab: any, name: string, container: number?, prefix: string?): Linker
	return makeLinker(tab:AddSection(name, container or 1), prefix or "", true)
end

function Linker.Raw(self: Linker): any
	return self._host
end

function Linker.Self(self: Linker): any
	return self._host
end

function Linker.SortByTextLength(self: Linker, descending: boolean?): Linker
	local host = self._host
	if host and type(host.SortByTextLength) == "function" then
		host:SortByTextLength(descending)
	end
	return self
end

local function resolveKey(self: Linker, key: string): any
	local first = string.find(key, ".", 1, true)
	if not first then
		return self._elements[key]
	end
	local head = string.sub(key, 1, first - 1)
	local rest = string.sub(key, first + 1)
	local element = self._elements[head]
	if not element then
		return nil
	end
	if not element._linkerChild then
		return nil
	end
	return resolveKey(element._linkerChild, rest)
end

function Linker.Get(self: Linker, key: string): any
	return resolveKey(self, key)
end

function Linker.Watch(self: Linker, key: string, callback: (value: any) -> ()): () -> ()
	local element = resolveKey(self, key)
	if not element then
		return function() end
	end
	if type(element.OnChange) == "function" then
		return element:OnChange(callback)
	end
	return sub(element._state, callback)
end

function Linker.Tip(self: Linker, key: string, tip: (string | { title: string?, body: string })?): Linker
	local element = resolveKey(self, key)
	if element and element.SetTip then
		element:SetTip(tip)
	end
	return self
end

function Linker.Peek(self: Linker, key: string): any
	local element = resolveKey(self, key)
	if not element then
		return nil
	end
	if type(element.Peek) == "function" then
		return element:Peek()
	end
	return peek(element._state)
end

function Linker.PeekTransparency(self: Linker, key: string): number?
	local element = resolveKey(self, key)
	if not element or not element._transparency then
		return nil
	end
	return peek(element._transparency)
end

function Linker.On(self: Linker, host: any, subPrefix: string?): Linker
	local prefix = self._prefix
	if subPrefix and subPrefix ~= "" then
		prefix = joinKey(prefix, subPrefix)
	end
	local sublinker = makeLinker(host, prefix, self._scoped, self._globalOnly, self._prefs)
	host._linkerChild = sublinker
	return sublinker
end

function Linker.WithPrefix(self: Linker, prefix: string): Linker
	return makeLinker(self._host, prefix, self._scoped, self._globalOnly, self._prefs)
end

function Linker.Scoped(self: Linker, enabled: boolean?): Linker
	self._scoped = enabled ~= false
	return self
end

function Linker.Global(self: Linker): Linker
	return setmetatable({
		_host = self._host,
		_prefix = self._prefix,
		_scoped = self._scoped,
		_globalOnly = self._scoped,
		_prefs = self._prefs,
		_elements = self._elements,
	}, Linker) :: any
end

function Linker.OnKey(self: Linker, key: string): Linker
	local element = self._elements[key]
	if not element then
		return self
	end
	if element._linkerChild then
		return element._linkerChild
	end
	return self:On(element, key)
end

function Linker.Toggle(self: Linker, key: string, label: string, default: boolean?): any
	return add(self, key, self._host:AddElement("Toggle", label, default or false))
end

function Linker.Slider(
	self: Linker,
	key: string,
	label: string,
	default: number,
	min: number,
	max: number,
	step: number,
	prefix: string?,
	suffix: string?
): any
	return add(self, key, self._host:AddElement("Slider", label, default, min, max, step, prefix, suffix))
end

function Linker.RangeSlider(
	self: Linker,
	key: string,
	label: string,
	defaultLow: number,
	defaultHigh: number,
	min: number,
	max: number,
	step: number,
	prefix: string?,
	suffix: string?
): any
	return add(
		self,
		key,
		self._host:AddElement("RangeSlider", label, defaultLow, defaultHigh, min, max, step, prefix, suffix)
	)
end

function Linker.Dropdown(self: Linker, key: string, label: string, options: { string }, default: any?): any
	return add(self, key, self._host:AddElement("Dropdown", label, options, default))
end

function Linker.Textbox(
	self: Linker,
	key: string,
	label: string,
	default: string?,
	placeholder: string?,
	numeric: boolean?
): any
	return add(self, key, self._host:AddElement("Textbox", label, default, placeholder, numeric))
end

function Linker.Colorpicker(
	self: Linker,
	key: string,
	label: string,
	default: Color3 | ColorSequence?,
	transparency: number?
): any
	return add(self, key, self._host:AddElement("Colorpicker", label, default, transparency))
end

function Linker.CurveEditor(self: Linker, key: string, label: string, min: number, max: number, default: any?): any
	return add(self, key, self._host:AddElement("CurveEditor", label, min, max, default))
end

function Linker.List(self: Linker, key: string, label: string, items: { any }?, default: string?): any
	return add(self, key, self._host:AddElement("List", label, items, default))
end

function Linker.PriorityList(self: Linker, key: string, label: string, options: { string }?, default: { string }?): any
	return add(self, key, self._host:AddElement("PriorityList", label, options, default))
end

function Linker.Button(self: Linker, label: string, icon: string?): any
	return self._host:AddElement("Button", label, icon)
end

function Linker.Key(
	self: Linker,
	key: string,
	label: string,
	default: (Enum.KeyCode | Enum.UserInputType)?,
	mode: string?
): any
	local element = self._host:AddElement("Key", label, default, mode)
	if key then
		local fullKey = joinKey(self._prefix, key)
		if self._prefs then
			UserController.LinkElement(fullKey, element)
		else
			ConfigController.Link(fullKey, element)
		end
		self._elements[key] = element
		if self._scoped then
			ScopeController.BindElement(element, fullKey, { globalOnly = true })
		end
	end
	return element
end

function Linker.Value(self: Linker, key: string, default: any): any
	return add(self, key, { _state = Charm.atom(default) })
end

function Linker.Submenu(self: Linker, key: string?, label: string?): any
	local resolvedLabel = label or key or ""
	local element = self._host:AddElement("Submenu", resolvedLabel)
	if key then
		self._elements[key] = element
	end
	return element
end

function Linker.AssetPicker(self: Linker, key: string, label: string, config: any): any
	local element = self._host:AddElement("AssetPicker", label, config)
	return add(self, key, element)
end

function Linker.Extra(self: Linker, parent: any, key: string, type: string, ...: any): any
	local element = parent:AddElement(type, ...)
	if not element then
		return nil
	end
	return add(self, key, element)
end

function Linker.StateColors(self: Linker, label: string, config: any): any
	return self._host:AddElement("StateColors", label, config)
end

function Linker.Guide(self: Linker, label: string, config: any): any
	return self._host:AddElement("Guide", label, config)
end

function Linker.EspPreview(self: Linker, label: string, config: any): any
	return self._host:AddElement("EspPreview", label, config)
end

function Linker.EspElements(self: Linker, label: string, config: any): any
	return self._host:AddElement("EspElements", label, config)
end

function Linker.Options(self: Linker, key: string?, label: string?): any
	local resolvedLabel = label or key or ""
	local element = self._host:AddElement("Options", resolvedLabel)
	if key then
		self._elements[key] = element
	end
	return element
end

function gameUi.SettingsHudSection(prefix: string?): Linker
	return makeLinker(ConfigController.GetSettingsHudSection(), prefix or "", false, false, true)
end

function gameUi.Mount(FeatureClass: any, link: Linker?, opts: any?): any
	local instance = FeatureClass.new(link, opts)
	if instance.Destroy then
		loader.addDestroyer(function()
			instance:Destroy()
		end)
	end
	return instance
end

export type Linker = typeof(setmetatable(
	{} :: {
		_host: any,
		_prefix: string,
		_scoped: boolean,
		_globalOnly: boolean,
		_prefs: boolean,
		_elements: { [string]: any },
	},
	Linker
))

return gameUi
