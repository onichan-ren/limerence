repeat
	task.wait()
until cloneref(game:GetService("Players")).LocalPlayer

local loader = require("@loader/loader")
local AppController = require("@src/feature/app/AppController")
local ConfigController = require("@src/feature/config/ConfigController")
local ThemeController = require("@src/feature/config/ThemeController")
local UserController = require("@src/feature/config/UserController")
local FileController = require("@src/feature/file/FileController")
local LuauController = require("@src/feature/luau/LuauController")
local SessionController = require("@src/feature/session/SessionController")
local UIController = require("@src/feature/ui/UIController")
local ScopeController = require("@src/feature/ui/scope/ScopeController")
local ProtectionController = require("@src/feature/protection/ProtectionController")
local ServerController = require("@src/feature/server/ServerController")
local RecordController = require("@src/feature/record/RecordController")
local HudController = require("@src/feature/ui/hud/HudController")
local uiRegistry = require("@src/feature/ui/uiRegistry")
local uiState = require("@src/feature/ui/uiState")
local hook = require("@share/hook")

local STARTUP_TAB = "Legitbot"

return function(): () -> ()
	setthreadidentity(8)

	if identifyexecutor() ~= "Potassium" then
		setstackhidden(1, true)
	end
	setstackhidden(oth.hook :: any, true)
	setstackhidden(hookfunction :: any, true)

	loader.add(AppController)
	loader.init()

	HudController.new()
	task.spawn(AppController.Start)

	FileController.new()

	task.spawn(loader.mount, UserController)
	task.spawn(loader.mount, SessionController)
	task.spawn(loader.mount, UIController)
	task.spawn(loader.mount, ScopeController)
	task.spawn(loader.mount, ConfigController)
	task.spawn(loader.mount, ServerController)
	task.spawn(loader.mount, RecordController)
	task.spawn(loader.mount, LuauController)
	task.spawn(loader.mount, hook)
	task.defer(loader.mount, ProtectionController)

	if _G.MCP then
		task.spawn(loader.mount, require("@src/feature/mcp/McpController"))
	end

	local userTheme = UserController.GetTheme()
	if not ThemeController.LoadFromFile(userTheme or ThemeController.DEFAULT_NAME, true) then
		ThemeController.LoadFromFile(ThemeController.DEFAULT_NAME, true)
	end

	return function(): ()
		setthreadidentity(8)

		local userConfig = UserController.GetAutoloadConfig()
		if userConfig then
			task.spawn(ConfigController.LoadFromFile, userConfig)
		end

		if UserController.GetShowMenuOnStartup() then
			UIController.OpenTab(STARTUP_TAB)
			uiState.isOpen(true)
		end
	end
end
