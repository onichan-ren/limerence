local Charm = require("@pkg/Charm")
local themeState = require("@ui/theme/themeState")
local themePresets = require("@feature/config/themePresets")
local NotifyController = require("@ui/hud/notify/NotifyController")
local logger = require("@share/logger").new("ThemeController")
local loader = require("@loader/loader")
local directoryWatcher = require("@feature/file/modules/directoryWatcher")
local uiState = require("@ui/uiState")
local HttpService = cloneref(game:GetService("HttpService")) :: HttpService

local peek = Charm.peek
local at = Charm.atom

local ThemeController = {}

local THEME_DIR = "limerence.biz/themes"
local DEFAULT_NAME = "Default"
local WATCH_INTERVAL = 1

ThemeController.revision = at(0)

ThemeController.DEFAULT_NAME = DEFAULT_NAME
ThemeController.BUILTIN_NAMES = themePresets.NAMES

local function pathFor(name: string): string
	return `{THEME_DIR}/{name}.json`
end

local walkColors
walkColors = function(prefix: string, dict: any, callback: (path: string, atom: any) -> ())
	for key, value in next, dict do
		local path = prefix == "" and key or `{prefix}.{key}`
		if type(value) == "function" then
			callback(path, value)
		elseif type(value) == "table" then
			walkColors(path, value, callback)
		end
	end
end

ThemeController.walkColors = walkColors

function ThemeController.Snapshot(): { [string]: any }
	local data: { [string]: any } = {}
	walkColors("", themeState.colors, function(path, atom)
		data[path] = peek(atom)
	end)
	return data
end

function ThemeController.Restore(snapshot: { [string]: any }): ()
	walkColors("", themeState.colors, function(path, atom)
		local saved = snapshot[path]
		if saved ~= nil then
			atom(saved)
		end
	end)
end

function ThemeController.toJson(): string
	local data: { [string]: any } = {}
	walkColors("", themeState.colors, function(path, atom)
		local value = peek(atom)
		if typeof(value) == "Color3" then
			data[path] = { r = value.R, g = value.G, b = value.B }
		elseif type(value) == "table" then
			local color = value[1]
			if typeof(color) == "Color3" then
				data[path] = { r = color.R, g = color.G, b = color.B, a = value[2] }
			end
		end
	end)
	return HttpService:JSONEncode(data)
end

local function migrateLegacyThemePaths(data: { [string]: any })
	local function move(oldPath: string, newPath: string)
		if data[newPath] == nil and data[oldPath] ~= nil then
			data[newPath] = data[oldPath]
		end
	end

	if data["window.searchMuted"] == nil then
		data["window.searchMuted"] = data["window.searchIcon"] or data["window.searchText"]
	end
	move("window.side", "window.sidebar")
	move("window.top", "window.toolbar")
	move("window.tabGroupText", "window.tabHeading")
	move("window.tabButtonBackground", "window.tabSurface")
	move("window.tabButtonStroke", "window.tabStroke")
	move("window.unselectedTabText", "window.tabLabel")
	move("window.selectedTabText", "window.tabLabelSelected")

	local el = "window.element."
	move(el .. "canvas", el .. "panel")
	move(el .. "canvasStroke", el .. "panelStroke")
	move(el .. "secondary", el .. "surface")
	move(el .. "secondaryStroke", el .. "surfaceStroke")
	move(el .. "primary", el .. "accent")
	move(el .. "dimPrimary", el .. "accentSoft")
	move(el .. "activePrimary", el .. "accentStrong")
	move(el .. "knob", el .. "thumb")
	move(el .. "activeKnob", el .. "thumbActive")
	move(el .. "brightKnob", el .. "thumbHighlight")
	move(el .. "knobStroke", el .. "thumbStroke")
	move(el .. "valueBackground", el .. "fieldBackground")
	move(el .. "activeValueBackground", el .. "fieldBackgroundActive")
	move(el .. "valueStroke", el .. "fieldStroke")
	move(el .. "activeValueStroke", el .. "fieldStrokeActive")
	move(el .. "mutedText", el .. "caption")
	move(el .. "activeMutedText", el .. "captionActive")
	move(el .. "activeText", el .. "textActive")
	move(el .. "activeIcon", el .. "iconActive")
	move("hud.mutedText", "hud.textMuted")
	move("hud.secondaryBackground", "hud.backgroundSecondary")
end

function ThemeController.fromJson(json: string): ()
	local data = HttpService:JSONDecode(json)
	migrateLegacyThemePaths(data)
	walkColors(
		"",
		themeState.colors,
		LPH_NO_VIRTUALIZE(function(path, atom)
			local saved = data[path]
			if not saved then
				return
			end
			local current = peek(atom)
			if typeof(current) == "Color3" then
				atom(Color3.new(saved.r, saved.g, saved.b))
			elseif type(current) == "table" then
				atom({ Color3.new(saved.r, saved.g, saved.b), saved.a or current[2] })
			end
		end)
	)
end

function ThemeController.IsBuiltin(name: string): boolean
	return themePresets.IsBuiltin(name)
end

function ThemeController.IsDefault(name: string): boolean
	return ThemeController.IsBuiltin(name)
end

local LEGACY_NAMES: { [string]: string } = {
	Dark = "Default",
	Bloom = "Default",
	Ember = "Default",
	Dracula = "Default",
	Neverlose = "Default",
	Crimson = "Kanagawa",
	Amethyst = "Catppuccin Mocha",
	Nord = "Everforest",
}

local function resolveLegacyName(name: string): string
	return LEGACY_NAMES[name] or name
end

function ThemeController.SaveToFile(name: string): ()
	if ThemeController.IsBuiltin(name) then
		return
	end
	writefile(pathFor(name), ThemeController.toJson())
end

function ThemeController.LoadFromFile(name: string, silent: boolean?): boolean
	name = resolveLegacyName(name)

	local builtin = themePresets.GetSnapshot(name)
	if builtin then
		ThemeController.Restore(builtin)
		if not silent then
			NotifyController.Push({
				title = "Loaded theme",
				subtext = name,
				icon = "paintbrush",
				duration = 2,
			})
		end
		return true
	end

	local path = pathFor(name)
	if not isfile(path) then
		if not silent then
			NotifyController.Push({
				title = `Theme error: {name}`,
				subtext = "file not found",
				icon = "trash",
				duration = 2,
			})
		end
		return false
	end
	ThemeController.fromJson(readfile(path))
	if not silent then
		NotifyController.Push({
			title = "Loaded theme",
			subtext = name,
			icon = "paintbrush",
			duration = 2,
		})
	end
	return true
end

function ThemeController.CreateTheme(name: string): boolean
	if ThemeController.IsBuiltin(name) then
		return false
	end

	local path = pathFor(name)
	if isfile(path) then
		return false
	end
	writefile(path, "{}")
	return true
end

function ThemeController.RenameTheme(oldName: string, newName: string): boolean
	if oldName == newName then
		return false
	end

	if ThemeController.IsBuiltin(oldName) or ThemeController.IsBuiltin(newName) then
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
	return true
end

function ThemeController.HasTheme(name: string): boolean
	if ThemeController.IsBuiltin(name) then
		return true
	end
	return isfile(pathFor(name))
end

function ThemeController.DeleteTheme(name: string): boolean
	if ThemeController.IsBuiltin(name) then
		return false
	end

	local path = pathFor(name)
	if not isfile(path) then
		return false
	end

	delfile(path)
	return true
end

function ThemeController.ListThemes(): { string }
	local names: { string } = {}
	local seen: { [string]: true } = {}

	for _, builtin in next, themePresets.NAMES do
		table.insert(names, builtin)
		seen[builtin] = true
	end

	if not isfolder(THEME_DIR) then
		return names
	end

	local userNames: { string } = {}
	for _, path in next, listfiles(THEME_DIR) do
		local name = path:match("([^/\\]+)%.json$")
		if name and not seen[name] then
			table.insert(userNames, name)
		end
	end
	table.sort(userNames)

	for _, name in next, userNames do
		table.insert(names, name)
	end

	return names
end

local watcher = directoryWatcher.create({
	path = THEME_DIR,
	extension = "json",
	interval = WATCH_INTERVAL,
	activeWhile = uiState.isOpen,
	onChange = function(): ()
		ThemeController.revision(peek(ThemeController.revision) + 1)
	end,
})
loader.addDestroyer(function(): ()
	watcher:Stop()
end)

logger:log(`registered {#themePresets.NAMES} built-in themes`)

return ThemeController
