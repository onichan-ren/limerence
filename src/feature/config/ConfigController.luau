local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local configUi = require("@src/feature/config/module/configUi")
local stateConverter = require("@src/feature/config/module/stateConverter")
local visualImport = require("@src/feature/config/module/visualImport")
local configState = require("@src/feature/config/configState")
local UserController = require("@src/feature/config/UserController")
local gameRegistry = require("@game/gameRegistry")
local NotifyController = require("@ui/hud/notify/NotifyController")
local scopeState = require("@ui/scope/scopeState")
local logger = require("@share/logger")

local HttpService = cloneref(game:GetService("HttpService")) :: HttpService

local sub = Charm.subscribe

local ConfigController = {}

ConfigController.onLoaded = Signal.new() :: Signal.Signal<string>

local CONFIG_ROOT = "limerence.biz/configs"
local AUTOSAVE_DELAY = 0.75

local activeConfig: string? = nil
local autoSaveTask: thread? = nil
local autoSaveSuppressed = false
local autoSaveUnsubs: { [string]: { () -> () } } = {}

local function gameKey(): string
	local name = gameRegistry.name
	if type(name) == "string" and name ~= "" then
		return name
	end
	return "shared"
end

local function configDir(): string
	return `{CONFIG_ROOT}/{gameKey()}`
end

local function ensureDir(): string
	if not isfolder(CONFIG_ROOT) then
		makefolder(CONFIG_ROOT)
	end
	local dir = configDir()
	if not isfolder(dir) then
		makefolder(dir)
	end
	return dir
end

local function pathFor(name: string): string
	return `{configDir()}/{name}.json`
end

function ConfigController.GetConfigDir(): string
	return ensureDir()
end

local function flushAutoSave(): ()
	autoSaveTask = nil
	if autoSaveSuppressed then
		return
	end
	if not UserController.GetAutoSaveConfigs() then
		return
	end
	local name = activeConfig
	if not name then
		return
	end
	ensureDir()
	writefile(pathFor(name), stateConverter.toJson())
end

function ConfigController.QueueAutoSave(): ()
	if autoSaveSuppressed or autoSaveTask then
		return
	end
	if not UserController.GetAutoSaveConfigs() or not activeConfig then
		return
	end
	autoSaveTask = task.delay(AUTOSAVE_DELAY, flushAutoSave)
end

function ConfigController.new(): ConfigController
	ensureDir()

	configUi(ConfigController)

	sub(scopeState.values, ConfigController.QueueAutoSave)
	sub(scopeState.enabled, ConfigController.QueueAutoSave)

	return ConfigController
end

local function watchAutoSave(key: string, element: any): ()
	local unsubs: { () -> () } = {}
	local onChange = ConfigController.QueueAutoSave
	for _, atomKey in next, { "_state", "_transparency", "_rotation", "_animation", "_speed" } do
		local atom = element[atomKey]
		if atom then
			table.insert(unsubs, sub(atom, onChange))
		end
	end
	if #unsubs > 0 then
		autoSaveUnsubs[key] = unsubs
	end
end

local function unwatchAutoSave(key: string): ()
	local unsubs = autoSaveUnsubs[key]
	if not unsubs then
		return
	end
	autoSaveUnsubs[key] = nil
	for _, unsub in next, unsubs do
		unsub()
	end
end

function ConfigController.Link(key: string, element: any): any
	configState.elements[key] = element
	watchAutoSave(key, element)
	local extraByKey = element._extraByKey
	if type(extraByKey) == "table" then
		for assignKey, lookup in next, extraByKey do
			for extraKey, nested in next, lookup do
				ConfigController.Link(`{key}.extras.{assignKey}.{extraKey}`, nested)
			end
		end
	end
	return element
end

function ConfigController.Unlink(key: string): ()
	local element = configState.elements[key]
	unwatchAutoSave(key)
	local extraByKey = element and element._extraByKey
	if type(extraByKey) == "table" then
		for assignKey, lookup in next, extraByKey do
			for extraKey in next, lookup do
				ConfigController.Unlink(`{key}.extras.{assignKey}.{extraKey}`)
			end
		end
	end
	configState.elements[key] = nil
end

function ConfigController.GetElement(key: string): any?
	return configState.elements[key]
end

local settingsHudSection: any = nil

function ConfigController.RegisterSettingsHudSection(section: any): ()
	settingsHudSection = section
end

function ConfigController.GetSettingsHudSection(): any
	return settingsHudSection
end

function ConfigController.SaveToFile(name: string): ()
	ensureDir()
	writefile(pathFor(name), stateConverter.toJson())
	activeConfig = name
	NotifyController.Push({
		title = "Saved config",
		subtext = name,
		icon = "saved_config",
		duration = 2,
	})
end

function ConfigController.CreateConfig(name: string): boolean
	ensureDir()
	local path = pathFor(name)
	if isfile(path) then
		return false
	end

	writefile(path, '{"values":{},"transparency":{}}')
	return true
end

function ConfigController.LoadFromFile(name: string): boolean
	local path = pathFor(name)
	if not isfile(path) then
		return false
	end

	autoSaveSuppressed = true
	stateConverter.fromJson(readfile(path))
	autoSaveSuppressed = false
	activeConfig = name
	ConfigController.onLoaded:Fire(name)
	NotifyController.Push({
		title = "Loaded config",
		subtext = name,
		icon = "loaded_config",
		duration = 2,
	})
	return true
end

function ConfigController.RenameConfig(oldName: string, newName: string): boolean
	if oldName == newName then
		return false
	end

	local oldPath = pathFor(oldName)
	local newPath = pathFor(newName)

	if not isfile(oldPath) then
		return false
	end

	if isfile(newPath) then
		return false
	end

	writefile(newPath, readfile(oldPath))
	delfile(oldPath)
	if activeConfig == oldName then
		activeConfig = newName
	end
	return true
end

function ConfigController.HasConfig(name: string): boolean
	return isfile(pathFor(name))
end

function ConfigController.DeleteConfig(name: string): boolean
	local path = pathFor(name)
	if not isfile(path) then
		return false
	end

	delfile(path)
	if activeConfig == name then
		activeConfig = nil
		if autoSaveTask then
			task.cancel(autoSaveTask)
			autoSaveTask = nil
		end
	end
	NotifyController.Push({
		title = "Deleted config",
		subtext = name,
		icon = "trash",
		duration = 2,
	})
	return true
end

function ConfigController.ListConfigs(): { string }
	local names: { string } = {}

	local dir = configDir()
	if not isfolder(dir) then
		return names
	end

	for _, path in next, listfiles(dir) do
		local name = path:match("([^/\\]+)%.json$")
		if name then
			table.insert(names, name)
		end
	end

	return names
end

function ConfigController.ListConfigGames(): { string }
	local games: { string } = {}
	if not isfolder(CONFIG_ROOT) then
		return games
	end

	local current = gameKey()
	for _, path in next, listfiles(CONFIG_ROOT) do
		if not isfolder(path) then
			continue
		end
		local name = path:match("([^/\\]+)$")
		if not name or name == current then
			continue
		end
		for _, filePath in next, listfiles(path) do
			if filePath:match("%.json$") then
				table.insert(games, name)
				break
			end
		end
	end

	return games
end

function ConfigController.ListConfigsForGame(gameName: string): { string }
	local names: { string } = {}
	local dir = `{CONFIG_ROOT}/{gameName}`
	if not isfolder(dir) then
		return names
	end

	for _, path in next, listfiles(dir) do
		local name = path:match("([^/\\]+)%.json$")
		if name then
			table.insert(names, name)
		end
	end

	return names
end

function ConfigController.ImportVisuals(gameName: string, configName: string, selected: { [string]: boolean }): boolean
	local path = `{CONFIG_ROOT}/{gameName}/{configName}.json`
	if not isfile(path) then
		return false
	end

	local applied = visualImport.Apply(readfile(path), selected)
	NotifyController.Push({
		title = "Imported visuals",
		subtext = `{applied} settings from {configName}`,
		icon = "loaded_config",
		duration = 2,
	})
	return true
end

local function cloudIndexId(): string
	return `cloudConfigs-{gameKey()}`
end

local function cloudIdFor(name: string): string
	return `cloudConfig-{gameKey()}-{name}`
end

local cloudIndexCache: { string }?

local function readCloudIndex(): { string }
	if cloudIndexCache then
		return cloudIndexCache
	end

	local names: { string } = {}
	local success, response = LP_GET_VALUE(cloudIndexId())
	if success and type(response) == "string" then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(response)
		end)
		if ok and type(decoded) == "table" then
			names = decoded
		end
	end

	cloudIndexCache = names
	return names
end

local function writeCloudIndex(names: { string }): boolean
	cloudIndexCache = names
	return LP_SAVE_VALUE(cloudIndexId(), HttpService:JSONEncode(names), true) == true
end

local function addToCloudIndex(name: string): ()
	local names = readCloudIndex()
	for _, existing in next, names do
		if existing == name then
			return
		end
	end
	table.insert(names, name)
	writeCloudIndex(names)
end

local function removeFromCloudIndex(name: string): ()
	local names = readCloudIndex()
	for index, existing in next, names do
		if existing == name then
			table.remove(names, index)
			writeCloudIndex(names)
			return
		end
	end
end

function ConfigController.ListCloudConfigs(): { string }
	return readCloudIndex()
end

function ConfigController.CreateCloudConfig(name: string): boolean
	if LP_SAVE_VALUE(cloudIdFor(name), '{"values":{},"transparency":{}}', false) ~= true then
		return false
	end
	addToCloudIndex(name)
	return true
end

function ConfigController.SaveToCloud(name: string): boolean
	if LP_SAVE_VALUE(cloudIdFor(name), stateConverter.toJson(), true) ~= true then
		NotifyController.Push({
			title = "Failed to save cloud config",
			subtext = name,
			icon = "trash",
			duration = 2,
		})
		return false
	end

	addToCloudIndex(name)
	NotifyController.Push({
		title = "Saved cloud config",
		subtext = name,
		icon = "saved_config",
		duration = 2,
	})
	return true
end

function ConfigController.LoadFromCloud(name: string): boolean
	local success, response = LP_GET_VALUE(cloudIdFor(name))
	if not success or type(response) ~= "string" then
		NotifyController.Push({
			title = "Failed to load cloud config",
			subtext = name,
			icon = "trash",
			duration = 2,
		})
		return false
	end

	stateConverter.fromJson(response)
	ConfigController.onLoaded:Fire(name)
	NotifyController.Push({
		title = "Loaded cloud config",
		subtext = name,
		icon = "loaded_config",
		duration = 2,
	})
	return true
end

function ConfigController.DeleteCloudConfig(name: string): boolean
	LP_DELETE_VALUE(cloudIdFor(name))
	removeFromCloudIndex(name)
	NotifyController.Push({
		title = "Deleted cloud config",
		subtext = name,
		icon = "trash",
		duration = 2,
	})
	return true
end

function ConfigController.RenameCloudConfig(oldName: string, newName: string): boolean
	if oldName == newName then
		return false
	end

	local names = readCloudIndex()
	local oldIndex: number?
	for index, existing in next, names do
		if existing == newName then
			return false
		end
		if existing == oldName then
			oldIndex = index
		end
	end
	if not oldIndex then
		return false
	end

	local success, response = LP_GET_VALUE(cloudIdFor(oldName))
	if not success or type(response) ~= "string" then
		return false
	end

	if LP_SAVE_VALUE(cloudIdFor(newName), response, true) ~= true then
		return false
	end

	LP_DELETE_VALUE(cloudIdFor(oldName))
	names[oldIndex] = newName
	writeCloudIndex(names)
	return true
end

function ConfigController.Destroy(): ()
	if autoSaveTask then
		task.cancel(autoSaveTask)
		autoSaveTask = nil
	end
	for key in next, autoSaveUnsubs do
		unwatchAutoSave(key)
	end
end

export type ConfigController = typeof(ConfigController)

return ConfigController
