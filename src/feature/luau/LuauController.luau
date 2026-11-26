local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local Sift = require("@pkg/Sift")

local logger = require("@share/logger")
local fileState = require("@feature/file/fileState")
local FileArchive = require("@feature/file/Archive")
local FileController = require("@feature/file/FileController")
local UIController = require("@ui/UIController")
local NotifyController = require("@ui/hud/notify/NotifyController")
local ToastController = require("@ui/hud/toast/ToastController")
local ConfigController = require("@src/feature/config/ConfigController")
local configState = require("@src/feature/config/configState")
local stateConverter = require("@src/feature/config/module/stateConverter")
local Window = require("@ui/window/Window")
local TabGroup = require("@ui/window/tabgroup/TabGroup")
local Tab = require("@ui/window/tab/Tab")

local gameRegistry = require("@game/gameRegistry")
local luauState = require("@feature/luau/luauState")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")
local luauRunner = require("@feature/luau/luauRunner")
local TarReader = require("@feature/file/formats/Tar")
local ZipReader = require("@feature/file/formats/Zip")

require("@feature/luau/luauBindApi")
require("@feature/luau/luauClientApi")
require("@feature/luau/luauPlayersApi")
require("@feature/luau/luauLegitbotApi")
require("@feature/luau/luauWorldApi")

-- Games that don't provide these (AR2, MVSD) still get a safe empty table so the
-- documented `if api.game.x then` / `if api.ragebot.x then` guards don't index nil.
luauApiRegistry.RegisterDefault("game", {})
luauApiRegistry.RegisterDefault("ragebot", {})
local directoryWatcher = require("@feature/file/modules/directoryWatcher")
local uiState = require("@ui/uiState")

local peek = Charm.peek
local sub = Charm.subscribe

local menuToggleSignal = Signal.new()
sub(uiState.isOpen, function(open: boolean): ()
	menuToggleSignal:Fire(open)
end)

type ElementHandle = {
	id: string?,
	GetValue: (self: ElementHandle) -> any,
	SetValue: (self: ElementHandle, value: any) -> (),
	OnChange: (self: ElementHandle, callback: (value: any) -> ()) -> () -> (),
	GetText: (self: ElementHandle) -> string,
	SetText: (self: ElementHandle, text: string) -> (),
	Get: (self: ElementHandle, field: string) -> any,
	Set: (self: ElementHandle, field: string, value: any) -> (),
	Watch: (self: ElementHandle, field: string, callback: (value: any) -> ()) -> () -> (),
	Has: (self: ElementHandle, field: string) -> boolean,
	SetVisible: (self: ElementHandle, state: boolean) -> ElementHandle,
	IsVisible: (self: ElementHandle) -> boolean,
	OnVisibleChange: (self: ElementHandle, callback: (state: boolean) -> ()) -> () -> (),
	SetTip: (self: ElementHandle, tip: any) -> ElementHandle,
	Destroy: (self: ElementHandle) -> (),
	Exists: (self: ElementHandle) -> boolean,
	[any]: any,
}

type HandleConfig = {
	id: string?,
	element: any?,
	onDestroy: (() -> ())?,
	owner: ScriptHandle?,
}

local fieldKeyCache = setmetatable({}, {
	__index = function(self: { [string]: string }, field: string): string
		local key = "_" .. field
		self[field] = key
		return key
	end,
}) :: { [string]: string }

local function makeElementHandle(config: HandleConfig | string): ElementHandle
	local id: string? = nil
	local owned: any? = nil
	local onDestroy: (() -> ())? = nil
	local owner: ScriptHandle? = nil

	if type(config) == "string" then
		id = config
	else
		id = config.id
		owned = config.element
		onDestroy = config.onDestroy
		owner = config.owner
	end

	local destroyed = false

	local function resolve(): any?
		if destroyed then
			return nil
		end
		if owned then
			return owned
		end
		if id then
			return configState.elements[id]
		end
		return nil
	end

	local function getAtom(field: string): any?
		local element = resolve()
		if not element then
			return nil
		end
		local atom = element[fieldKeyCache[field]]
		if type(atom) ~= "function" then
			return nil
		end
		return atom
	end

	local methods: { [string]: any } = {}

	function methods:GetValue(): any
		local atom = getAtom("state")
		if not atom then
			return nil
		end
		return peek(atom)
	end

	function methods:SetValue(value: any): ()
		local atom = getAtom("state")
		if not atom then
			return
		end
		atom(value)
	end

	function methods:OnChange(callback: (value: any) -> ()): () -> ()
		local atom = getAtom("state")
		if not atom then
			return function() end
		end
		return sub(atom, callback)
	end

	function methods:GetText(): string
		local atom = getAtom("text")
		if not atom then
			return ""
		end
		return peek(atom)
	end

	function methods:SetText(text: string): ()
		local atom = getAtom("text")
		if not atom then
			return
		end
		atom(text)
	end

	function methods:Get(field: string): any
		local atom = getAtom(field)
		if not atom then
			return nil
		end
		return peek(atom)
	end

	function methods:Set(field: string, value: any): ()
		local atom = getAtom(field)
		if not atom then
			return
		end
		atom(value)
	end

	function methods:Watch(field: string, callback: (value: any) -> ()): () -> ()
		local atom = getAtom(field)
		if not atom then
			return function() end
		end
		return sub(atom, callback)
	end

	function methods:Has(field: string): boolean
		return getAtom(field) ~= nil
	end

	function methods:SetVisible(state: boolean): ElementHandle
		local atom = getAtom("visible")
		if atom then
			atom(state)
		end
		return self
	end

	function methods:IsVisible(): boolean
		local atom = getAtom("visible")
		if not atom then
			return true
		end
		return peek(atom)
	end

	function methods:OnVisibleChange(callback: (state: boolean) -> ()): () -> ()
		local atom = getAtom("visible")
		if not atom then
			return function() end
		end
		return sub(atom, callback)
	end

	function methods:SetTip(tip: any): ElementHandle
		local element = resolve()
		if element and type(element.SetTip) == "function" then
			element:SetTip(tip)
		end
		return self
	end

	function methods:Destroy(): ()
		if destroyed then
			return
		end
		destroyed = true
		local element = owned or (id and configState.elements[id]) or nil
		if onDestroy then
			onDestroy()
		end
		if element and type(element.Destroy) == "function" then
			element:Destroy()
		end
	end

	function methods:Exists(): boolean
		return resolve() ~= nil
	end

	function methods:IsOverridden(): boolean
		local element = resolve()
		if not element or type(element.IsOverridden) ~= "function" then
			return false
		end
		return element:IsOverridden()
	end

	function methods:OverrideValue(value: any, priority: number?): any
		local element = resolve()
		if not element or type(element.AddOverride) ~= "function" then
			return nil
		end

		local currentValue = value
		local currentPriority = priority or 0
		local sourceName: string? = owner and owner.name or nil
		local token = element:AddOverride(currentValue, currentPriority, sourceName)

		local released = false
		local releaseHandle = {} :: any

		local function detachFromOwner(): ()
			if not owner then
				return
			end
			for i, rec in next, owner.overrides do
				if rec.token == token and rec.element == element then
					table.remove(owner.overrides, i)
					break
				end
			end
		end

		local function doRelease(): ()
			if released then
				return
			end
			released = true
			if type(element.RemoveOverride) == "function" then
				pcall(element.RemoveOverride, element, token)
			end
			detachFromOwner()
		end

		if owner then
			table.insert(owner.overrides, { element = element, token = token, release = doRelease })
		end

		function releaseHandle.Release(_: any): ()
			doRelease()
		end

		function releaseHandle.IsReleased(_: any): boolean
			return released
		end

		function releaseHandle.GetValue(_: any): any
			return currentValue
		end

		function releaseHandle.GetPriority(_: any): number
			return currentPriority
		end

		function releaseHandle.SetValue(_: any, newValue: any): ()
			if released then
				return
			end
			currentValue = newValue
			if type(element.UpdateOverride) == "function" then
				element:UpdateOverride(token, newValue, currentPriority)
			end
		end

		function releaseHandle.SetPriority(_: any, newPriority: number): ()
			if released then
				return
			end
			currentPriority = newPriority
			if type(element.UpdateOverride) == "function" then
				element:UpdateOverride(token, currentValue, newPriority)
			end
		end

		return releaseHandle
	end

	local handle = { id = id }

	setmetatable(handle, {
		__index = function(_: any, key: any): any
			local m = methods[key]
			if m ~= nil then
				return m
			end
			local element = resolve()
			if not element then
				return nil
			end
			local value = element[key]
			if type(value) == "function" then
				return function(_: any, ...: any): any
					return value(element, ...)
				end
			end
			return value
		end,
	})

	return handle :: any
end

local MOUNT_PATH = "limerence.biz/cache/mounts"
local LUAUS_DIR = "limerence.biz/luaus"
local LUAUS_CONFIG_EXTENSION = "limerence.luaus"
local LUAUS_GROUP_TITLE = "LUAUS"
local LUAUS_GROUP_ORDER = 100
local DEFAULT_TAB_ICON_KEY = "pencil"

type ScriptInfo = luauState.ScriptInfo

type OverrideRecord = {
	element: any,
	token: number,
	release: () -> (),
}

type ScriptHandle = {
	name: string,
	tab: Tab.Tab?,
	configKeys: { string },
	onUnload: Signal.Signal<()>,
	connections: { RBXScriptConnection },
	elements: { any },
	overrides: { OverrideRecord },
	findCache: { [string]: any },
	mounts: { string },
}

local LuauController = {
	_window = nil :: Window.Window?,
	_luausGroup = nil :: TabGroup.TabGroup?,
	_handles = {} :: { [string]: ScriptHandle },
}

local handles = LuauController._handles

local function collectLoadedScriptNames(): { string }
	local names: { string } = {}
	for name in next, handles do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

local function prepareScriptsFromConfig(payload: any): ()
	if type(payload) ~= "table" then
		return
	end
	local wanted = payload.scripts
	if type(wanted) ~= "table" or #wanted == 0 then
		return
	end

	local keep: { [string]: true } = {}
	for _, name in next, wanted do
		if type(name) == "string" and name ~= "" then
			keep[name] = true
		end
	end

	if next(keep) == nil then
		return
	end

	for name in next, handles do
		if not keep[name] then
			LuauController.Unload(name, true)
		end
	end

	for name in next, keep do
		if not handles[name] then
			LuauController.LoadByName(name)
		end
	end
end

local function setScriptInfo(name: string, info: ScriptInfo?): ()
	local current = peek(luauState.scripts)
	if info then
		luauState.scripts(Sift.Dictionary.set(current, name, info))
	else
		luauState.scripts(Sift.Dictionary.removeKey(current, name))
	end
end

local function ensureLuausGroup(): TabGroup.TabGroup?
	local window = LuauController._window
	if not window then
		return nil
	end
	if LuauController._luausGroup then
		return LuauController._luausGroup
	end
	local group = window:AddTabGroup(LUAUS_GROUP_TITLE, LUAUS_GROUP_ORDER)
	group._visible(false)
	LuauController._luausGroup = group
	return group
end

local function refreshGroupVisibility(): ()
	local group = LuauController._luausGroup
	if not group then
		return
	end
	local hasAny = false
	for _, handle in next, handles do
		if handle.tab then
			hasAny = true
			break
		end
	end
	group._visible(hasAny)
end

local function removeTabFromGroup(group: TabGroup.TabGroup, tab: Tab.Tab): ()
	local current = peek(group.tabs)
	local filtered = {}
	for _, existing in next, current do
		if existing ~= tab then
			table.insert(filtered, existing)
		end
	end
	group.tabs(filtered)
end

local makeContainerOps: (host: any, listAtom: any, scriptHandle: ScriptHandle) -> { [string]: any }

local function attachContainerOps(handle: any, element: any, scriptHandle: ScriptHandle): any
	local listAtom = element._elements or element._extras
	if not listAtom then
		return handle
	end
	local ops = makeContainerOps(element, listAtom, scriptHandle)
	for k, v in next, ops do
		handle[k] = v
	end
	return handle
end

makeContainerOps = function(host: any, listAtom: any, scriptHandle: ScriptHandle): { [string]: any }
	local function track(key: string?, element: any): any
		if not element then
			return nil
		end

		table.insert(scriptHandle.elements, element)

		local fullKey: string? = nil
		if key then
			fullKey = `luau.{scriptHandle.name}.{key}`
			ConfigController.Link(fullKey :: string, element)
			table.insert(scriptHandle.configKeys, fullKey :: string)
		end

		local h = makeElementHandle({
			id = fullKey,
			element = element,
			owner = scriptHandle,
			onDestroy = function(): ()
				local current = peek(listAtom)
				local filtered = {}
				for _, e in next, current do
					if e ~= element then
						table.insert(filtered, e)
					end
				end
				listAtom(filtered)

				if fullKey then
					ConfigController.Unlink(fullKey)
					for i, k in next, scriptHandle.configKeys do
						if k == fullKey then
							table.remove(scriptHandle.configKeys, i)
							break
						end
					end
				end

				for i, e in next, scriptHandle.elements do
					if e == element then
						table.remove(scriptHandle.elements, i)
						break
					end
				end
			end,
		})

		return attachContainerOps(h, element, scriptHandle)
	end

	local container: { [string]: any } = {}

	function container.AddToggle(_: any, key: string, label: string, default: boolean?): any
		if type(key) ~= "string" then
			error("AddToggle: key must be a string", 2)
		end
		if type(label) ~= "string" then
			error("AddToggle: label must be a string", 2)
		end
		if type(default) ~= "boolean" and type(default) ~= "nil" then
			error("AddToggle: default must be a boolean or nil", 2)
		end
		return track(key, host:AddElement("Toggle", label, default or false))
	end

	function container.AddSlider(
		_: any,
		key: string,
		label: string,
		default: number,
		min: number,
		max: number,
		step: number,
		prefix: string?,
		suffix: string?
	): any
		return track(key, host:AddElement("Slider", label, default, min, max, step, prefix, suffix))
	end

	function container.AddDropdown(_: any, key: string, label: string, options: { string }, default: any?): any
		return track(key, host:AddElement("Dropdown", label, options, default))
	end

	function container.AddColorpicker(
		_: any,
		key: string,
		label: string,
		default: (Color3 | ColorSequence)?,
		transparency: number?
	): any
		return track(key, host:AddElement("Colorpicker", label, default, transparency))
	end

	function container.AddButton(_: any, label: string, icon: string?): any
		local resolvedIcon: string? = nil
		if icon then
			resolvedIcon = FileController.Get("image", icon)
		end
		return track(nil, host:AddElement("Button", label, resolvedIcon))
	end

	function container.AddKey(_: any, key: string, label: string, default: any?, mode: string?): any
		return track(key, host:AddElement("Key", label, default, mode))
	end

	function container.AddList(_: any, key: string, label: string, items: { any }?, default: string?): any
		if type(key) ~= "string" then
			error("AddList: key must be a string", 2)
		end
		if type(label) ~= "string" then
			error("AddList: label must be a string", 2)
		end
		return track(key, host:AddElement("List", label, items, default))
	end

	function container.AddCurveEditor(_: any, key: string, label: string, min: number, max: number, default: any?): any
		if type(key) ~= "string" then
			error("AddCurveEditor: key must be a string", 2)
		end
		if type(min) ~= "number" or type(max) ~= "number" then
			error("AddCurveEditor: min and max must be numbers", 2)
		end
		return track(key, host:AddElement("CurveEditor", label, min, max, default))
	end

	function container.AddSubmenu(_: any, key: any?, label: string?): any
		local resolvedKey: string? = type(key) == "string" and key or nil
		local resolvedLabel: string = label or resolvedKey or ""
		return track(resolvedKey, host:AddElement("Submenu", resolvedLabel))
	end

	function container.AddOptions(_: any, key: any?, label: string?): any
		local resolvedKey: string? = type(key) == "string" and key or nil
		local resolvedLabel: string = label or resolvedKey or ""
		return track(resolvedKey, host:AddElement("Options", resolvedLabel))
	end

	return container
end

local function buildSection(rawSection: any, handle: ScriptHandle): { [string]: any }
	return makeContainerOps(rawSection, rawSection._elements, handle)
end

local function buildTab(rawTab: any, handle: ScriptHandle): { [string]: any }
	local tab: { [string]: any } = {}
	function tab.AddSection(_: any, title: string, container: number?): { [string]: any }
		local rawSection = rawTab:AddSection(title, container or 1)
		return buildSection(rawSection, handle)
	end
	return tab
end

local function buildApi(handle: ScriptHandle): { [string]: any }
	local api: { [string]: any } = {
		name = handle.name,
	}

	api.onUnload = function(callback: () -> ()): ()
		if type(callback) ~= "function" then
			error("api.onUnload: callback must be a function", 2)
		end
		handle.onUnload:Connect(callback)
	end

	api.getGame = function(): string
		return gameRegistry.name or "unknown"
	end

	api.ui = {
		tab = function(title: string, icon: string?): { [string]: any }
			if type(title) ~= "string" then
				error("api.ui.tab: title must be a string", 2)
			end
			if type(icon) ~= "string" and type(icon) ~= "nil" then
				error("api.ui.tab: icon must be a string or nil", 2)
			end
			if handle.tab then
				error(`api.ui.tab: script "{handle.name}" already has a tab`, 2)
			end
			local group = ensureLuausGroup()
			if not group then
				error("api.ui.tab: window not initialized", 2)
			end
			local iconKey = icon or FileController.Get("image", DEFAULT_TAB_ICON_KEY) :: string
			local rawTab = group:AddTab(title, iconKey, { containers = 2 })
			handle.tab = rawTab

			local current = peek(luauState.scripts)
			local existing = current[handle.name]
			if existing then
				luauState.scripts(
					Sift.Dictionary.set(current, handle.name, Sift.Dictionary.merge(existing, { hasTab = true }))
				)
			end

			group._visible(true)

			return buildTab(rawTab, handle)
		end,
		find = function(id: string): ElementHandle?
			if type(id) ~= "string" then
				error("api.ui.find: id must be a string", 2)
			end
			if not configState.elements[id] then
				return nil
			end
			local cached = handle.findCache[id]
			if cached then
				return cached
			end
			local elementHandle = makeElementHandle({ id = id, owner = handle })
			handle.findCache[id] = elementHandle
			return elementHandle
		end,
		notify = function(spec: { [string]: any }): { [string]: any }
			if type(spec) ~= "table" then
				error("api.ui.notify: spec must be a table", 2)
			end
			if type(spec.title) ~= "string" then
				error("api.ui.notify: spec.title must be a string", 2)
			end
			local id = NotifyController.Push({
				title = spec.title,
				subtext = type(spec.subtext) == "string" and spec.subtext or nil,
				icon = type(spec.icon) == "string" and spec.icon or nil,
				duration = type(spec.duration) == "number" and spec.duration or nil,
				showProgress = spec.showProgress == true,
				timer = spec.timer == true,
				progress = type(spec.progress) == "number" and spec.progress or nil,
			})
			handle.onUnload:Connect(function(): ()
				NotifyController.Dismiss(id)
			end)
			local notifHandle = {}
			function notifHandle.Dismiss(_: any): ()
				NotifyController.Dismiss(id)
			end
			function notifHandle.Update(_: any, patch: { [string]: any }): ()
				if type(patch) ~= "table" then
					error("notify:Update: patch must be a table", 2)
				end
				NotifyController.Update(id, patch)
			end
			function notifHandle.GetId(_: any): string
				return id
			end
			return notifHandle
		end,
		toast = function(spec: any): { [string]: any }
			if type(spec) == "string" then
				spec = { text = spec }
			end
			if type(spec) ~= "table" or type(spec.text) ~= "string" then
				error("api.ui.toast: spec.text must be a string", 2)
			end
			local id = ToastController.Push({
				text = spec.text,
				accent = typeof(spec.accent) == "Color3" and spec.accent or nil,
				duration = type(spec.duration) == "number" and spec.duration or nil,
			})
			handle.onUnload:Connect(function(): ()
				ToastController.Dismiss(id)
			end)
			local toastHandle = {}
			function toastHandle.Dismiss(_: any): ()
				ToastController.Dismiss(id)
			end
			function toastHandle.GetId(_: any): string
				return id
			end
			return toastHandle
		end,
		isOpen = function(): boolean
			return peek(uiState.isOpen)
		end,
		onToggle = luauApiRegistry.WrapSignal(menuToggleSignal, handle.onUnload),
	}

	--[[api.config = {
		Link = function(key: string, element: any): any
			local fullKey = `luau.{handle.name}.{key}`
			ConfigController.Link(fullKey, element)
			table.insert(handle.configKeys, fullKey)
			return element
		end,
	}--]]

	local function splitPath(path)
		local parts = {}
		for part in path:gmatch("[^/]+") do
			table.insert(parts, part)
		end
		return parts
	end

	local function parseTar(archive: buffer): FileArchive.Files
		local reader = TarReader.read(archive)
		local typeFlags = TarReader.typeFlags
		local allFiles: FileArchive.Files = {}

		local function getFolder(paths)
			local current = allFiles

			for _, path in paths do
				local nextFolder = current[path]

				if nextFolder == nil then
					nextFolder = {}
					current[path] = nextFolder
				end

				current = nextFolder
			end

			return current
		end

		while reader:hasNext() do
			local nextRecord = reader:next()
			local typeFlag = nextRecord.typeFlag

			local paths = splitPath(nextRecord.name)

			if typeFlag == typeFlags.REGTYPE or typeFlag == typeFlags.AREGTYPE then
				local newPaths = table.clone(paths)
				local fileName = table.remove(newPaths, #newPaths)

				local parent = getFolder(newPaths)
				parent[fileName] = nextRecord.content
			elseif typeFlag == typeFlags.DIRTYPE then
				getFolder(paths)
			end
		end

		return allFiles
	end

	local function parseZip(archive: buffer): FileArchive.Files
		local reader = ZipReader.read(archive)
		local allFiles: FileArchive.Files = {}

		local function getFolder(paths)
			local current = allFiles

			for _, path in paths do
				local nextFolder = current[path]

				if nextFolder == nil then
					nextFolder = {}
					current[path] = nextFolder
				end

				current = nextFolder
			end

			return current
		end

		while reader:hasNext() do
			local nextRecord = reader:next()
			if nextRecord == nil then
				break
			end

			local paths = splitPath(nextRecord.name)

			if nextRecord.isDirectory then
				getFolder(paths)
			else
				local newPaths = table.clone(paths)
				local fileName = table.remove(newPaths, #newPaths)

				if fileName ~= nil then
					local parent = getFolder(newPaths)
					parent[fileName] = nextRecord.content
				end
			end
		end

		return allFiles
	end

	local function loadFolder(path: string): FileArchive.Files
		local files: FileArchive.Files = {}
		for _, filePath in next, listfiles(path) do
			local name = filePath:match("[^/\\]+$")
			if isfolder(filePath) then
				files[name] = loadFolder(filePath)
			elseif isfile(filePath) then
				files[name] = readfile(filePath)
			end
		end
		return files
	end

	api.utility = {
		connect = function(signal: RBXScriptSignal<...any>, callback: (...any) -> ()): ()
			if typeof(signal) ~= "RBXScriptSignal" or (type(signal) == "table" and not rawget(signal, "Connect")) then
				error("api.utility.connect: signal must be a RBXScriptSignal", 2)
			end
			if type(callback) ~= "function" then
				error("api.utility.connect: callback must be a function", 2)
			end
			local connection = signal:Connect(callback)
			table.insert(handle.connections, connection)
		end,
		loadArchive = function(archive: string | buffer, archiveType: ("Tar" | "Zip")?)
			if type(archive) ~= "string" and typeof(archive) ~= "buffer" then
				error("api.utility.loadArchive: archive must be a string or a buffer")
			end

			local parsed

			if archiveType == "Tar" then
				local archiveBuffer: buffer
				if type(archive) == "string" then
					archiveBuffer = buffer.fromstring(archive)
				else
					archiveBuffer = archive
				end
				parsed = parseTar(archiveBuffer)
			elseif archiveType == "Zip" then
				local archiveBuffer: buffer
				if type(archive) == "string" then
					archiveBuffer = buffer.fromstring(archive)
				else
					archiveBuffer = archive
				end
				parsed = parseZip(archiveBuffer)
			else
				if type(archive) ~= "string" then
					error("api.utility.loadArchive: archive must be a string path when loading a folder")
				end
				if not isfolder(archive) then
					error(`api.utility.loadArchive: folder not found: {archive}`)
				end
				parsed = loadFolder(archive)
			end

			local fileArchive = FileArchive.new(parsed)
			table.insert(handle.mounts, fileArchive.id)
			return fileArchive
		end,

		getAsset = function(type: string, name: string): any
			return FileController.Get(type :: any, name)
		end,
		configLoaded = luauApiRegistry.WrapSignal(ConfigController.onLoaded, handle.onUnload),
		getAssets = function(typeName: string?)
			if typeName and type(typeName) ~= "string" then
				error("api.utility.getAssets: type must be a string or nil", 2)
			end
			if typeName then
				return fileState[typeName :: any]
			end
			return Sift.Dictionary.copyDeep(fileState)
		end,
	}

	luauApiRegistry.BuildInto(api, {
		scriptName = handle.name,
		onUnload = handle.onUnload,
	})

	return api
end

local function tearDownHandle(handle: ScriptHandle): ()
	handle.onUnload:Fire()
	for _, callback in next, handle.connections do
		pcall(callback.Disconnect, callback)
	end

	for _, id in next, handle.mounts do
		local path = MOUNT_PATH .. "/" .. id
		if isfolder(path) and not isfile(path .. "/" .. ".limkeep") then
			pcall(delfolder, MOUNT_PATH .. "/" .. id)
		end
	end

	handle.connections = {}
	handle.onUnload = Signal.new()

	local pending = handle.overrides
	handle.overrides = {}
	for _, record in next, pending do
		pcall(record.release)
	end

	for _, key in next, handle.configKeys do
		ConfigController.Unlink(key)
	end
	handle.configKeys = {}

	for _, element in next, handle.elements do
		if type(element) == "table" and type(element.Destroy) == "function" then
			pcall(element.Destroy, element)
		end
	end
	handle.elements = {}
	handle.findCache = {}

	if handle.tab and LuauController._luausGroup then
		removeTabFromGroup(LuauController._luausGroup, handle.tab)
		handle.tab = nil
	end
end

function LuauController.Unload(name: string, silent: boolean?): ()
	local handle = handles[name]
	if not handle then
		return
	end
	tearDownHandle(handle)
	handles[name] = nil

	local path = `{LUAUS_DIR}/{name}.luau`
	if isfile and isfile(path) then
		setScriptInfo(name, {
			name = name,
			status = "discovered",
			error = nil,
			hasTab = false,
		})
	else
		setScriptInfo(name, nil)
	end

	refreshGroupVisibility()

	if not silent then
		NotifyController.Push({
			title = "Unloaded Luau",
			subtext = name,
			icon = "unload",
			duration = 2,
		})
	end
end

function LuauController.Load(name: string, source: string): ()
	if handles[name] then
		return
	end

	local handle: ScriptHandle = {
		name = name,
		tab = nil,
		configKeys = {},
		connections = {},
		elements = {},
		overrides = {},
		findCache = {},
		mounts = {},
		onUnload = Signal.new(),
	}
	handles[name] = handle

	local api = buildApi(handle)
	local result = luauRunner.Run(source, name, api)

	if not result.ok then
		tearDownHandle(handle)
		handles[name] = nil
		setScriptInfo(name, {
			name = name,
			status = "error",
			error = result.error,
			hasTab = false,
		})
		refreshGroupVisibility()
		NotifyController.Push({
			title = `Failed to load Luau '{name}'`,
			subtext = result.error,
			icon = "trash",
			duration = 2,
		})
		return
	end

	setScriptInfo(name, {
		name = name,
		status = "loaded",
		error = nil,
		hasTab = handle.tab ~= nil,
	})
	refreshGroupVisibility()
	NotifyController.Push({
		title = "Loaded Luau",
		subtext = name,
		icon = "load",
		duration = 2,
	})
end

function LuauController.Reload(name: string): boolean
	local path = `{LUAUS_DIR}/{name}.luau`
	if not isfile or not isfile(path) then
		return false
	end
	local ok, source = pcall(readfile, path)
	if not ok or type(source) ~= "string" then
		return false
	end
	LuauController.Load(name, source)
	return true
end

function LuauController.DiscoverFromDisk(): ()
	if not isfolder(LUAUS_DIR) then
		return
	end

	local found: { [string]: boolean } = {}
	for _, path in next, listfiles(LUAUS_DIR) do
		local name = path:match("([^/\\]+)%.luau$")
		if not name then
			continue
		end
		found[name] = true

		local current = peek(luauState.scripts)
		if not current[name] then
			setScriptInfo(name, {
				name = name,
				status = "discovered",
				error = nil,
				hasTab = false,
			})
		end
	end

	local current = peek(luauState.scripts)
	for name, info in next, current do
		if info.status == "discovered" and not found[name] then
			setScriptInfo(name, nil)
		end
	end
end

function LuauController.LoadByName(name: string): boolean
	local path = `{LUAUS_DIR}/{name}.luau`
	if not isfile(path) then
		setScriptInfo(name, {
			name = name,
			status = "error",
			error = "file not found",
			hasTab = false,
		})
		NotifyController.Push({
			title = `Failed to load Luau '{name}'`,
			subtext = "File not found",
			icon = "trash",
			duration = 2,
		})
		return false
	end
	local ok, source = pcall(readfile, path)
	if not ok or type(source) ~= "string" then
		setScriptInfo(name, {
			name = name,
			status = "error",
			error = "failed to read file",
			hasTab = false,
		})
		NotifyController.Push({
			title = `Failed to load Luau '{name}'`,
			subtext = "Failed to read file",
			icon = "trash",
			duration = 2,
		})
		return false
	end
	LuauController.Load(name, source)
	return true
end

function LuauController.UnloadAll(): ()
	local names = {}
	for name in next, handles do
		table.insert(names, name)
	end
	for _, name in next, names do
		LuauController.Unload(name, true)
	end
end

function LuauController.GetState(): luauState.LuauState
	return luauState
end

function LuauController.new(): LuauController
	if isfolder(MOUNT_PATH) then
		for _, path in next, listfiles(MOUNT_PATH) do
			if isfolder(path) and not isfile(path .. "/.limkeep") then
				delfolder(path)
			end
		end
	end

	LuauController._window = UIController.GetMainWindow()
	ensureLuausGroup()

	local luauUi = require("@feature/luau/module/luauUi")
	luauUi(LuauController)

	LuauController.DiscoverFromDisk()

	stateConverter.RegisterExtension(LUAUS_CONFIG_EXTENSION, function(): { scripts: { string } }?
		local scripts = collectLoadedScriptNames()
		if #scripts == 0 then
			return nil
		end
		return { scripts = scripts }
	end, function(_payload: any): () end, prepareScriptsFromConfig)

	directoryWatcher.create({
		path = LUAUS_DIR,
		extension = "luau",
		interval = 1,
		activeWhile = uiState.isOpen,
		onChange = function(): ()
			LuauController.DiscoverFromDisk()
		end,
	})

	return LuauController
end

function LuauController.Destroy(): ()
	stateConverter.UnregisterExtension(LUAUS_CONFIG_EXTENSION)
	LuauController.UnloadAll()
	LuauController._luausGroup = nil
	LuauController._window = nil
end

export type LuauController = typeof(LuauController)

return LuauController
