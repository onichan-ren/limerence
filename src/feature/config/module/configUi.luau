local Charm = require("@pkg/Charm")
local UIController = require("@src/feature/ui/UIController")
local FileController = require("@src/feature/file/FileController")
local UserController = require("@src/feature/config/UserController")
local uiRegistry = require("@src/feature/ui/uiRegistry")
local themeUi = require("@src/feature/config/module/themeUi")
local hudState = require("@src/feature/ui/hud/hudState")
local watermarkState = require("@src/feature/ui/hud/watermark/watermarkState")
local spectatorsState = require("@ui/hud/spectators/spectatorsState")
local toastState = require("@ui/hud/toast/toastState")
local displayUsername = require("@feature/session/displayUsername")
local watermarkOrder = require("@ui/hud/watermark/watermarkOrder")
local uiState = require("@src/feature/ui/uiState")
local dpiState = require("@ui/util/dpiState")
local directoryWatcher = require("@src/feature/file/modules/directoryWatcher")
local visualImport = require("@src/feature/config/module/visualImport")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local Tab = require("@ui/window/tab/Tab")

local at = Charm.atom
local sub = Charm.subscribe
local peek = Charm.peek

local udim2Same = LPH_NO_VIRTUALIZE(function(a: UDim2, b: UDim2): boolean
	return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset
end)

type ConfigController = {
	ListConfigs: () -> { string },
	CreateConfig: (name: string) -> boolean,
	SaveToFile: (name: string) -> (),
	LoadFromFile: (name: string) -> boolean,
	DeleteConfig: (name: string) -> boolean,
	RenameConfig: (oldName: string, newName: string) -> boolean,
	GetConfigDir: () -> string,
	Link: (key: string, element: any) -> any,
	ListConfigGames: () -> { string },
	ListConfigsForGame: (gameName: string) -> { string },
	ImportVisuals: (gameName: string, configName: string, selected: { [string]: boolean }) -> boolean,
	ListCloudConfigs: () -> { string },
	CreateCloudConfig: (name: string) -> boolean,
	SaveToCloud: (name: string) -> boolean,
	LoadFromCloud: (name: string) -> boolean,
	DeleteCloudConfig: (name: string) -> boolean,
	RenameCloudConfig: (oldName: string, newName: string) -> boolean,
	RegisterSettingsHudSection: (section: any) -> (),
}

local DEFAULT_NAME = "Unnamed"

local uniqueName = LPH_NO_VIRTUALIZE(function(existing: { string }, base: string): string
	local taken: { [string]: true } = {}
	for _, name in next, existing do
		taken[name] = true
	end

	if not taken[base] then
		return base
	end

	local index = 2
	while taken[`{base} {index}`] do
		index += 1
	end
	return `{base} {index}`
end)

local function toItems(names: { string }, autoload: string?): { { id: string, name: string, icon: string? } }
	local curved_right_arrow = FileController.Get("image", "curved_right_arrow")
	local items = {}
	for index, name in next, names do
		items[index] = {
			id = name,
			name = name,
			icon = name == autoload and curved_right_arrow or nil,
		}
	end
	return items
end

return function(ConfigController: ConfigController): Tab.Tab?
	local window = UIController.GetMainWindow()
	local group = window:GetTabGroup("COMMON")

	if not group then
		return nil
	end

	local tab = uiRegistry.add(
		group:AddTab("Settings", FileController.Get("image", "cog") :: string, {
			containers = 2,
		}),
		{ kind = "tab" }
	)

	local configsTab = uiRegistry.add(
		tab:AddSubtab("Configs", FileController.Get("image", "file") :: string, {
			containers = 1,
		}),
		{ kind = "tab" }
	)

	local displayTab = uiRegistry.add(
		tab:AddSubtab("Display", FileController.Get("image", "computer") :: string, {
			containers = 2,
		}),
		{ kind = "tab" }
	)

	local section = configsTab:AddSection("CONFIGS", 1)
	local autoSaveToggle = section:AddElement("Toggle", "Auto Save", peek(UserController.autoSaveConfigs)) :: any
	autoSaveToggle:SetBindable(false)
	autoSaveToggle:SetTip({
		title = "Auto Save",
		body = "Save changes to the loaded config automatically.",
	})

	sub(autoSaveToggle._state, function(state: boolean): ()
		UserController.SetAutoSaveConfigs(state)
	end)

	sub(UserController.autoSaveConfigs, function(state: boolean): ()
		if peek(autoSaveToggle._state) ~= state then
			autoSaveToggle._state(state)
		end
	end)
	local list = section:AddElement("List", "Config") :: any
	ConfigController.Link("settings.configList", list)
	list:SetRenamable(true)
	list:SetEmptyText("No configs")
	list:SetMaxHeight(180)

	local function refresh(): ()
		list:SetItems(toItems(ConfigController.ListConfigs(), UserController.GetAutoloadConfig()))
	end

	sub(UserController.autoloadConfig, refresh)

	list:OnRename(function(oldName: string, newName: string): ()
		if not ConfigController.RenameConfig(oldName, newName) then
			refresh()
			return
		end
		if UserController.GetAutoloadConfig() == oldName then
			UserController.SetAutoloadConfig(newName)
		end
	end)

	directoryWatcher.create({
		path = ConfigController.GetConfigDir(),
		extension = "json",
		interval = 1,
		activeWhile = uiState.isOpen,
		onChange = refresh,
	})

	local createButton = section:AddElement("Button", "Create", FileController.Get("image", "write")) :: any
	createButton:OnClick(function(): ()
		local name = uniqueName(ConfigController.ListConfigs(), DEFAULT_NAME)
		ConfigController.CreateConfig(name)
		refresh()
		list:SetSelected(name)
	end)

	local deleteButton = createButton:Combine("Delete")
	deleteButton:SetIcon(FileController.Get("image", "delete"))
	deleteButton:RequireConfirm()
	deleteButton:OnClick(function(): ()
		local selected = list:GetSelected()
		if not selected then
			return
		end
		ConfigController.DeleteConfig(selected)
		if UserController.GetAutoloadConfig() == selected then
			UserController.SetAutoloadConfig(nil)
		end
		refresh()
	end)

	local saveButton = section:AddElement("Button", "Save", FileController.Get("image", "disk")) :: any
	saveButton:RequireConfirm()
	saveButton:OnClick(function(): ()
		local selected = list:GetSelected()
		if not selected then
			return
		end
		ConfigController.SaveToFile(selected)
	end)

	local loadButton = saveButton:Combine("Load")
	loadButton:SetIcon(FileController.Get("image", "load"))
	loadButton:OnClick(function(): ()
		local selected = list:GetSelected()
		if not selected then
			return
		end
		ConfigController.LoadFromFile(selected)
	end)

	local autoloadButton =
		section:AddElement("Button", "Autoload", FileController.Get("image", "curved_right_arrow")) :: any
	autoloadButton:SetIcon(FileController.Get("image", "curved_right_arrow"))
	autoloadButton:OnClick(function(): ()
		local selected = list:GetSelected()
		if not selected then
			return
		end
		if UserController.GetAutoloadConfig() == selected then
			UserController.SetAutoloadConfig(nil)
		else
			UserController.SetAutoloadConfig(selected)
		end
	end)

	refresh()

	local cloudSection = configsTab:AddSection("CLOUD", 1)

	local cloudList = cloudSection:AddElement("List", "Cloud Config") :: any
	cloudList:SetRenamable(true)
	cloudList:SetEmptyText("No cloud configs")
	cloudList:SetMaxHeight(180)

	local cloudNames: { string } = {}
	local cloudBusy = false

	local function refreshCloud(): ()
		cloudNames = ConfigController.ListCloudConfigs()
		cloudList:SetItems(toItems(cloudNames, nil))
	end

	local function runCloud(action: () -> ()): ()
		if cloudBusy then
			return
		end
		cloudBusy = true
		task.spawn(function(): ()
			pcall(action)
			cloudBusy = false
		end)
	end

	cloudList:OnRename(function(oldName: string, newName: string): ()
		runCloud(function(): ()
			ConfigController.RenameCloudConfig(oldName, newName)
			refreshCloud()
		end)
	end)

	local cloudCreateButton = cloudSection:AddElement("Button", "Create", FileController.Get("image", "write")) :: any
	cloudCreateButton:OnClick(function(): ()
		runCloud(function(): ()
			local name = uniqueName(cloudNames, DEFAULT_NAME)
			if ConfigController.CreateCloudConfig(name) then
				refreshCloud()
				cloudList:SetSelected(name)
			end
		end)
	end)

	local cloudDeleteButton = cloudCreateButton:Combine("Delete")
	cloudDeleteButton:SetIcon(FileController.Get("image", "delete"))
	cloudDeleteButton:RequireConfirm()
	cloudDeleteButton:OnClick(function(): ()
		local selected = cloudList:GetSelected()
		if not selected then
			return
		end
		runCloud(function(): ()
			ConfigController.DeleteCloudConfig(selected)
			refreshCloud()
		end)
	end)

	local cloudSaveButton = cloudSection:AddElement("Button", "Save", FileController.Get("image", "disk")) :: any
	cloudSaveButton:RequireConfirm()
	cloudSaveButton:OnClick(function(): ()
		local selected = cloudList:GetSelected()
		if not selected then
			return
		end
		runCloud(function(): ()
			ConfigController.SaveToCloud(selected)
		end)
	end)

	local cloudLoadButton = cloudSaveButton:Combine("Load")
	cloudLoadButton:SetIcon(FileController.Get("image", "load"))
	cloudLoadButton:OnClick(function(): ()
		local selected = cloudList:GetSelected()
		if not selected then
			return
		end
		runCloud(function(): ()
			ConfigController.LoadFromCloud(selected)
		end)
	end)

	local cloudRefreshButton =
		cloudSection:AddElement("Button", "Refresh", FileController.Get("image", "refresh")) :: any
	cloudRefreshButton:OnClick(function(): ()
		runCloud(refreshCloud)
	end)

	runCloud(refreshCloud)

	local function displayGameName(name: string): string
		return (name:gsub("%f[%w]%a", string.upper))
	end

	local importCategories: { { id: string, label: string } } = {}
	for index, category in next, visualImport.CATEGORIES do
		importCategories[index] = { id = category.id, label = category.label }
	end

	local copyVisualsButton =
		section:AddElement("Button", "Import Visuals", FileController.Get("image", "paintbrush")) :: any
	copyVisualsButton:SetTip({
		title = "Import Visuals",
		body = "Import visual settings from another game's config.",
	})
	copyVisualsButton:OnClick(function(): ()
		local games: { { id: string, label: string, configs: { string } } } = {}
		for index, name in next, ConfigController.ListConfigGames() do
			games[index] = {
				id = name,
				label = displayGameName(name),
				configs = ConfigController.ListConfigsForGame(name),
			}
		end

		SubwindowController.OpenVisualImport({
			games = games,
			categories = importCategories,
			onImport = function(gameId: string, configName: string, selected: { [string]: boolean }): ()
				ConfigController.ImportVisuals(gameId, configName, selected)
			end,
		})
	end)

	local displaySection = displayTab:AddSection("DISPLAY", 1)

	local dpiDropdown = displaySection:AddElement(
		"Dropdown",
		"DPI Scale",
		dpiState.LABELS,
		dpiState.labelFor(UserController.GetDpiScale())
	) :: any
	dpiDropdown:SetBindable(false)
	dpiDropdown:SetTip({
		title = "DPI Scale",
		body = "Scales the entire menu, HUD, and subwindows. 100% matches the default size.",
	})

	sub(dpiDropdown._state, function(label: string): ()
		UserController.SetDpiScale(dpiState.scaleFor(label))
	end)

	sub(UserController.dpiScale, function(value: number): ()
		local label = dpiState.labelFor(value)
		if peek(dpiDropdown._state) ~= label then
			dpiDropdown._state(label)
		end
	end)

	local startupSection = displayTab:AddSection("STARTUP", 1)

	local showMenuToggle =
		startupSection:AddElement("Toggle", "Show Menu on Load", peek(UserController.showMenuOnStartup)) :: any
	showMenuToggle:SetBindable(false)
	showMenuToggle:SetTip({
		title = "Show Menu on Load",
		body = "Show the menu automatically when the script runs.",
	})

	sub(showMenuToggle._state, function(state: boolean): ()
		UserController.SetShowMenuOnStartup(state)
	end)

	sub(UserController.showMenuOnStartup, function(state: boolean): ()
		if peek(showMenuToggle._state) ~= state then
			showMenuToggle._state(state)
		end
	end)

	local menuToggleKey = startupSection:AddElement(
		"Key",
		"Menu Toggle",
		UIController.GetMenuToggleInput(),
		"onPress",
		UIController.GetMenuToggleBindName()
	) :: any
	menuToggleKey:SetBindable(false)
	menuToggleKey:SetTip({
		title = "Menu Toggle",
		body = "Key used to open and close the menu. Saved in user preferences.",
	})

	local hudSection = displayTab:AddSection("HUD", 2)
	ConfigController.RegisterSettingsHudSection(hudSection)

	local function applyUsernameDisplay(): ()
		displayUsername.apply(
			displayUsername.normalizeMode(UserController.GetUsernameDisplayMode()),
			UserController.GetUsernameCustom()
		)
	end

	local usernameDisplayDropdown = hudSection:AddElement(
		"Dropdown",
		"Username Display",
		displayUsername.DROPDOWN_OPTIONS,
		displayUsername.modeToLabel(displayUsername.normalizeMode(UserController.GetUsernameDisplayMode()))
	) :: any
	usernameDisplayDropdown:SetBindable(false)
	usernameDisplayDropdown:SetTip({
		title = "Username Display",
		body = "How your name appears in the HUD watermark.",
	})

	sub(usernameDisplayDropdown._state, function(label: string): ()
		UserController.SetUsernameDisplayMode(displayUsername.labelToMode(label))
		applyUsernameDisplay()
	end)

	sub(UserController.usernameDisplayMode, function(mode: string): ()
		local label = displayUsername.modeToLabel(displayUsername.normalizeMode(mode))
		if peek(usernameDisplayDropdown._state) ~= label then
			usernameDisplayDropdown._state(label)
		end
	end)

	local customUsernameBox =
		hudSection:AddElement("Textbox", "Custom Username", UserController.GetUsernameCustom(), "Username") :: any
	customUsernameBox:SetBindable(false)
	customUsernameBox:SetTip({
		title = "Custom Username",
		body = "Shown in the watermark when Username Display is set to Custom.",
	})

	local function syncCustomUsernameVisible(): ()
		local isCustom = UserController.GetUsernameDisplayMode() == "custom"
		customUsernameBox:SetVisible(isCustom)
	end

	syncCustomUsernameVisible()

	sub(customUsernameBox._state, function(value: string): ()
		UserController.SetUsernameCustom(value)
		if UserController.GetUsernameDisplayMode() == "custom" then
			applyUsernameDisplay()
		end
	end)

	sub(UserController.usernameDisplayMode, function(_mode: string): ()
		syncCustomUsernameVisible()
	end)

	local showWatermarkToggle = hudSection:AddElement("Toggle", "Show Watermark", peek(watermarkState.enabled)) :: any
	showWatermarkToggle:SetBindable(false)
	showWatermarkToggle:SetTip({
		title = "Show Watermark",
		body = "Overlay with your session info. Right-click it to choose what shows.",
	})
	ConfigController.Link("hud.showWatermark", showWatermarkToggle)

	sub(showWatermarkToggle._state, function(state: boolean)
		watermarkState.enabled(state)
	end)

	sub(watermarkState.enabled, function(state: boolean)
		showWatermarkToggle._state(state)
	end)

	local watermarkPositionHolder = {
		_state = at(peek(watermarkState.position)),
	}
	ConfigController.Link("hud.watermarkPosition", watermarkPositionHolder)

	sub(watermarkPositionHolder._state, function(p: UDim2)
		if not udim2Same(peek(watermarkState.position), p) then
			watermarkState.position(p)
		end
	end)

	sub(watermarkState.position, function(p: UDim2)
		if not udim2Same(peek(watermarkPositionHolder._state), p) then
			watermarkPositionHolder._state(p)
		end
	end)

	local spectatorsPositionHolder = {
		_state = at(peek(spectatorsState.position)),
	}
	ConfigController.Link("hud.spectatorsPosition", spectatorsPositionHolder)

	sub(spectatorsPositionHolder._state, function(p: UDim2)
		if not udim2Same(peek(spectatorsState.position), p) then
			spectatorsState.position(p)
		end
	end)

	sub(spectatorsState.position, function(p: UDim2)
		if not udim2Same(peek(spectatorsPositionHolder._state), p) then
			spectatorsPositionHolder._state(p)
		end
	end)

	local watermarkOrderHolder = {
		_state = at(peek(watermarkState.itemOrder)),
	}
	ConfigController.Link("hud.watermarkItemOrder", watermarkOrderHolder)

	sub(watermarkOrderHolder._state, function(order: { string })
		local normalized = watermarkOrder.normalize(order)
		local current = peek(watermarkState.itemOrder)
		if #normalized ~= #current then
			watermarkState.itemOrder(normalized :: any)
			return
		end
		for i, id in next, normalized do
			if current[i] ~= id then
				watermarkState.itemOrder(normalized :: any)
				return
			end
		end
	end)

	sub(watermarkState.itemOrder, function(order: { string })
		local normalized = watermarkOrder.normalize(order) :: any
		local holder = peek(watermarkOrderHolder._state)
		if #normalized ~= #holder then
			watermarkOrderHolder._state(normalized)
			return
		end
		for i, id in next, normalized do
			if holder[i] ~= id then
				watermarkOrderHolder._state(normalized)
				return
			end
		end
	end)

	local showBindListToggle = hudSection:AddElement("Toggle", "Show Bind List", peek(hudState.showBindList)) :: any
	showBindListToggle:SetBindable(false)
	showBindListToggle:SetTip({
		title = "Show Bind List",
		body = "Lists your active keybinds. Right-click it to sort the list.",
	})
	ConfigController.Link("hud.showBindList", showBindListToggle)

	sub(showBindListToggle._state, function(state: boolean)
		hudState.showBindList(state)
	end)

	sub(hudState.showBindList, function(state: boolean)
		showBindListToggle._state(state)
	end)

	local bindSortHolder = {
		_state = at(peek(hudState.bindSortMode)),
	}
	ConfigController.Link("hud.bindSortMode", bindSortHolder)

	sub(bindSortHolder._state, function(mode: string)
		if peek(hudState.bindSortMode) ~= mode then
			hudState.bindSortMode(mode :: any)
		end
	end)

	sub(hudState.bindSortMode, function(mode: string)
		if peek(bindSortHolder._state) ~= mode then
			bindSortHolder._state(mode)
		end
	end)

	local toastPositionDropdown = hudSection:AddElement(
		"Dropdown",
		"Toast Position",
		toastState.POSITION_LABELS,
		toastState.labelFor(peek(toastState.position))
	) :: any
	toastPositionDropdown:SetBindable(false)
	toastPositionDropdown:SetTip({
		title = "Toast Position",
		body = "Where toast messages appear on screen.",
	})

	local toastPositionHolder = {
		_state = at(peek(toastState.position) :: string),
	}
	ConfigController.Link("hud.toastPosition", toastPositionHolder)

	sub(toastPositionDropdown._state, function(label: string)
		local position = toastState.positionFor(label)
		if peek(toastState.position) ~= position then
			toastState.position(position)
		end
	end)

	sub(toastPositionHolder._state, function(position: string)
		if peek(toastState.position) ~= position then
			toastState.position(toastState.positionFor(toastState.labelFor(position)))
		end
	end)

	sub(toastState.position, function(position: string)
		if peek(toastPositionHolder._state) ~= position then
			toastPositionHolder._state(position)
		end
		local label = toastState.labelFor(position)
		if peek(toastPositionDropdown._state) ~= label then
			toastPositionDropdown._state(label)
		end
	end)

	themeUi(displayTab)

	return tab
end
