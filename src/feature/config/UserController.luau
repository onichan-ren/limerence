local Charm = require("@pkg/Charm")
local logger = require("@share/logger").new("UserController")
local stateConverter = require("@src/feature/config/module/stateConverter")
local HttpService = cloneref(game:GetService("HttpService")) :: HttpService
local watermarkState = require("@ui/hud/watermark/watermarkState")
local watermarkOrder = require("@ui/hud/watermark/watermarkOrder")
local hudState = require("@ui/hud/hudState")
local dpiState = require("@ui/util/dpiState")

local at = Charm.atom
local peek = Charm.peek

local UserController = {}

local USER_FILE = "limerence.biz/user.json"

UserController.theme = at(nil :: string?) :: Charm.Atom<string?>
UserController.autoloadConfig = at(nil :: string?) :: Charm.Atom<string?>
UserController.developerMode = at(false) :: Charm.Atom<boolean>
UserController.showMenuOnStartup = at(true) :: Charm.Atom<boolean>
UserController.menuToggleKey = at("KeyCode.LeftAlt" :: string?) :: Charm.Atom<string?>
UserController.usernameDisplayMode = at("roblox" :: string) :: Charm.Atom<string>
UserController.usernameCustom = at("") :: Charm.Atom<string>
UserController.dpiScale = at(1) :: Charm.Atom<number>
UserController.autoSaveConfigs = at(false) :: Charm.Atom<boolean>

local themeAtom = UserController.theme
local autoloadConfigAtom = UserController.autoloadConfig
local developerModeAtom = UserController.developerMode
local showMenuOnStartupAtom = UserController.showMenuOnStartup
local menuToggleKeyAtom = UserController.menuToggleKey
local usernameDisplayModeAtom = UserController.usernameDisplayMode
local usernameCustomAtom = UserController.usernameCustom
local dpiScaleAtom = UserController.dpiScale
local autoSaveConfigsAtom = UserController.autoSaveConfigs

local LEGACY_THEME_NAMES: { [string]: string } = {
	Dark = "Default",
	Crimson = "Kanagawa",
	Amethyst = "Catppuccin Mocha",
	Nord = "Everforest",
}

local function resolveLegacyThemeName(name: string): string
	return LEGACY_THEME_NAMES[name] or name
end

local VALID_BIND_SORT: { [string]: boolean } = {
	activated = true,
	longestFrame = true,
	type = true,
}

local prefElements: { [string]: any } = {}
local pendingPrefValues: { [string]: any } = {}
local pendingPrefTransparency: { [string]: number } = {}

local function serializePrefElements(): { values: { [string]: any }, transparency: { [string]: number } }
	local values = table.clone(pendingPrefValues)
	local transparency = table.clone(pendingPrefTransparency)
	for key, element in next, prefElements do
		local state = peek(element._state)
		if state ~= nil then
			values[key] = stateConverter.serializeValue(state)
		end
		if element._transparency then
			local alpha = peek(element._transparency)
			if alpha ~= nil then
				transparency[key] = alpha
			end
		end
	end
	return { values = values, transparency = transparency }
end

local function writeNow(): ()
	local pos = peek(watermarkState.position)
	local bindPos = peek(hudState.position)
	local data = {
		elements = serializePrefElements(),
		theme = peek(themeAtom),
		autoloadConfig = peek(autoloadConfigAtom),
		developerMode = peek(developerModeAtom),
		showMenuOnStartup = peek(showMenuOnStartupAtom),
		menuToggleKey = peek(menuToggleKeyAtom),
		usernameDisplayMode = peek(usernameDisplayModeAtom),
		usernameCustom = peek(usernameCustomAtom),
		dpiScale = peek(dpiScaleAtom),
		autoSaveConfigs = peek(autoSaveConfigsAtom),
		watermark = {
			enabled = peek(watermarkState.enabled),
			showUsername = peek(watermarkState.showUsername),
			showCheat = peek(watermarkState.showCheat),
			showBuild = peek(watermarkState.showBuild),
			showGame = peek(watermarkState.showGame),
			showPing = peek(watermarkState.showPing),
			showFps = peek(watermarkState.showFps),
			showPlaytime = peek(watermarkState.showPlaytime),
			itemOrder = peek(watermarkState.itemOrder),
			position = {
				xScale = pos.X.Scale,
				xOffset = pos.X.Offset,
				yScale = pos.Y.Scale,
				yOffset = pos.Y.Offset,
			},
		},
		bindList = {
			show = peek(hudState.showBindList),
			sortMode = peek(hudState.bindSortMode),
			position = {
				xScale = bindPos.X.Scale,
				xOffset = bindPos.X.Offset,
				yScale = bindPos.Y.Scale,
				yOffset = bindPos.Y.Offset,
			},
		},
	}
	writefile(USER_FILE, HttpService:JSONEncode(data))
end

local persistTask: thread? = nil

local function persist(): ()
	if persistTask then
		return
	end
	persistTask = task.defer(function(): ()
		persistTask = nil
		writeNow()
	end)
end

local prefSaveTask: thread? = nil

local function persistPrefs(): ()
	if prefSaveTask then
		task.cancel(prefSaveTask)
	end
	prefSaveTask = task.delay(1, function(): ()
		prefSaveTask = nil
		writeNow()
	end)
end

function UserController.LinkElement(key: string, element: any): any
	prefElements[key] = element
	local saved = pendingPrefValues[key]
	if saved ~= nil then
		pendingPrefValues[key] = nil
		element._state(stateConverter.deserializeValue(saved))
	end
	if element._transparency then
		local alpha = pendingPrefTransparency[key]
		if alpha ~= nil then
			pendingPrefTransparency[key] = nil
			element._transparency(alpha)
		end
	end
	Charm.subscribe(element._state, persistPrefs)
	if element._transparency then
		Charm.subscribe(element._transparency, persistPrefs)
	end
	return element
end

function UserController.GetTheme(): string?
	return peek(themeAtom)
end

function UserController.SetTheme(name: string?): ()
	if peek(themeAtom) == name then
		return
	end
	themeAtom(name)
	persist()
end

function UserController.GetAutoloadConfig(): string?
	return peek(autoloadConfigAtom)
end

function UserController.SetAutoloadConfig(name: string?): ()
	if peek(autoloadConfigAtom) == name then
		return
	end
	autoloadConfigAtom(name)
	persist()
end

function UserController.GetDeveloperMode(): boolean
	return peek(developerModeAtom)
end

function UserController.SetDeveloperMode(state: boolean): ()
	if peek(developerModeAtom) == state then
		return
	end
	developerModeAtom(state)
	persist()
end

function UserController.GetShowMenuOnStartup(): boolean
	return peek(showMenuOnStartupAtom)
end

function UserController.SetShowMenuOnStartup(state: boolean): ()
	if peek(showMenuOnStartupAtom) == state then
		return
	end
	showMenuOnStartupAtom(state)
	persist()
end

function UserController.GetMenuToggleKey(): string?
	return peek(menuToggleKeyAtom)
end

function UserController.SetMenuToggleKey(serialized: string?): ()
	if peek(menuToggleKeyAtom) == serialized then
		return
	end
	menuToggleKeyAtom(serialized)
	persist()
end

function UserController.GetUsernameDisplayMode(): string
	return peek(usernameDisplayModeAtom)
end

function UserController.SetUsernameDisplayMode(mode: string): ()
	if peek(usernameDisplayModeAtom) == mode then
		return
	end
	usernameDisplayModeAtom(mode)
	persist()
end

function UserController.GetUsernameCustom(): string
	return peek(usernameCustomAtom)
end

function UserController.SetUsernameCustom(name: string): ()
	if peek(usernameCustomAtom) == name then
		return
	end
	usernameCustomAtom(name)
	persist()
end

local function normalizeDpiScale(value: any): number
	if type(value) ~= "number" then
		return 1
	end
	for _, option in next, dpiState.OPTIONS do
		if option == value then
			return option
		end
	end
	return 1
end

function UserController.GetDpiScale(): number
	return peek(dpiScaleAtom)
end

function UserController.SetDpiScale(value: number): ()
	local normalized = normalizeDpiScale(value)
	if peek(dpiScaleAtom) == normalized then
		return
	end
	dpiScaleAtom(normalized)
	dpiState.scale(normalized)
	persist()
end

function UserController.GetAutoSaveConfigs(): boolean
	return peek(autoSaveConfigsAtom)
end

function UserController.SetAutoSaveConfigs(state: boolean): ()
	if peek(autoSaveConfigsAtom) == state then
		return
	end
	autoSaveConfigsAtom(state)
	persist()
end

function UserController.new(): UserController
	if isfile(USER_FILE) then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(readfile(USER_FILE))
		end)

		if ok and type(data) == "table" then
			if type(data.theme) == "string" then
				themeAtom(resolveLegacyThemeName(data.theme))
			end
			if type(data.autoloadConfig) == "string" then
				autoloadConfigAtom(data.autoloadConfig)
			end
			if type(data.developerMode) == "boolean" then
				developerModeAtom(data.developerMode)
			end
			if type(data.showMenuOnStartup) == "boolean" then
				showMenuOnStartupAtom(data.showMenuOnStartup)
			end
			if type(data.menuToggleKey) == "string" then
				menuToggleKeyAtom(data.menuToggleKey)
			end
			if type(data.usernameDisplayMode) == "string" then
				usernameDisplayModeAtom(data.usernameDisplayMode)
			end
			if type(data.usernameCustom) == "string" then
				usernameCustomAtom(data.usernameCustom)
			end
			if type(data.dpiScale) == "number" then
				local normalized = normalizeDpiScale(data.dpiScale)
				dpiScaleAtom(normalized)
				dpiState.scale(normalized)
			end
			if type(data.autoSaveConfigs) == "boolean" then
				autoSaveConfigsAtom(data.autoSaveConfigs)
			end
			if type(data.watermark) == "table" then
				local wm = data.watermark
				if type(wm.enabled) == "boolean" then watermarkState.enabled(wm.enabled) end
				if type(wm.showUsername) == "boolean" then watermarkState.showUsername(wm.showUsername) end
				if type(wm.showCheat) == "boolean" then watermarkState.showCheat(wm.showCheat) end
				if type(wm.showBuild) == "boolean" then watermarkState.showBuild(wm.showBuild) end
				if type(wm.showGame) == "boolean" then watermarkState.showGame(wm.showGame) end
				if type(wm.showPing) == "boolean" then watermarkState.showPing(wm.showPing) end
				if type(wm.showFps) == "boolean" then watermarkState.showFps(wm.showFps) end
				if type(wm.showPlaytime) == "boolean" then watermarkState.showPlaytime(wm.showPlaytime) end
				if type(wm.itemOrder) == "table" then
					watermarkState.itemOrder(watermarkOrder.normalize(wm.itemOrder))
				end
				if type(wm.position) == "table" then
					local p = wm.position
					if type(p.xScale) == "number" and type(p.xOffset) == "number"
						and type(p.yScale) == "number" and type(p.yOffset) == "number"
					then
						watermarkState.position(UDim2.new(p.xScale, p.xOffset, p.yScale, p.yOffset))
					end
				end
			end
			if type(data.elements) == "table" then
				local el = data.elements
				if type(el.values) == "table" then
					pendingPrefValues = el.values
				end
				if type(el.transparency) == "table" then
					pendingPrefTransparency = el.transparency
				end
			end
			if type(data.bindList) == "table" then
				local bl = data.bindList
				if type(bl.show) == "boolean" then hudState.showBindList(bl.show) end
				if type(bl.sortMode) == "string" and VALID_BIND_SORT[bl.sortMode] then
					hudState.bindSortMode(bl.sortMode :: any)
				end
				if type(bl.position) == "table" then
					local p = bl.position
					if type(p.xScale) == "number" and type(p.xOffset) == "number"
						and type(p.yScale) == "number" and type(p.yOffset) == "number"
					then
						hudState.position(UDim2.new(p.xScale, p.xOffset, p.yScale, p.yOffset))
					end
				end
			end
			logger:log("loaded user preferences")
		end
	end

	for _, atom in next, {
		watermarkState.enabled,
		watermarkState.showUsername,
		watermarkState.showCheat,
		watermarkState.showBuild,
		watermarkState.showGame,
		watermarkState.showPing,
		watermarkState.showFps,
		watermarkState.showPlaytime,
		watermarkState.itemOrder,
		hudState.showBindList,
		hudState.bindSortMode,
	} do
		Charm.subscribe(atom, persist)
	end

	local positionSaveTask: thread? = nil
	local function persistPositionDebounced(): ()
		if positionSaveTask then
			task.cancel(positionSaveTask)
		end
		positionSaveTask = task.delay(1, function()
			positionSaveTask = nil
			persist()
		end)
	end
	Charm.subscribe(watermarkState.position, persistPositionDebounced)
	Charm.subscribe(hudState.position, persistPositionDebounced)

	return UserController
end

function UserController.Destroy(): ()
	local dirty = false
	if persistTask then
		task.cancel(persistTask)
		persistTask = nil
		dirty = true
	end
	if prefSaveTask then
		task.cancel(prefSaveTask)
		prefSaveTask = nil
		dirty = true
	end
	if dirty then
		writeNow()
	end
end

export type UserController = typeof(UserController)

return UserController
