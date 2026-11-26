local UserInputService = game:GetService("UserInputService") :: UserInputService

local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local hook = require("@share/hook")
local instances = require("@share/instances")

local AppController = require("@src/feature/app/AppController")
local BindController = require("@ui/bind/BindController")
local UserController = require("@feature/config/UserController")
local elementBindController = require("@ui/bind/elementBindController")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local WindowController = require("@ui/window/WindowController")
local Window = require("@ui/window/Window")
local HudController = require("@ui/hud/HudController")
local uiCanvas = require("@ui/uiCanvas")
local subwindowCanvas = require("@ui/subwindowCanvas")
local tooltipCanvas = require("@ui/tooltip/tooltipCanvas")
local uiState = require("@ui/uiState")
local windowState = require("@ui/window/windowState")
local subwindowPosition = require("@ui/util/subwindowPosition")

local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement

local MENU_TOGGLE_BIND_NAME = "Toggle Menu"

local UIController = {
	_toggleBind = nil :: BindController.Bind?,
	_mainWindow = nil :: Window.Window?,
	_savedMouse = nil :: { behavior: Enum.MouseBehavior, icon: boolean }?,
}

local function menuToggleInputFromUser(): (Enum.KeyCode | Enum.UserInputType)?
	local serialized = UserController.GetMenuToggleKey()
	if not serialized then
		return nil
	end
	return elementBindController.DeserializeInput(serialized)
end

local function applyMenuToggleInputsFromUser(): ()
	local bind = UIController._toggleBind
	if not bind then
		return
	end
	local input = menuToggleInputFromUser()
	bind:SetInputs(input and { input } or {})
end

local function persistMenuToggleKeyFromBind(): ()
	local bind = UIController._toggleBind
	if not bind then
		return
	end
	local inputs = peek(bind.inputs)
	local input = inputs[1]
	local serialized = input and elementBindController.SerializeInput(input) or nil
	UserController.SetMenuToggleKey(serialized)
end

function UIController.new(): UIController
	BindController.new()
	SubwindowController.init()
	HudController.new()

	AppController.Render(e(uiCanvas, {
		Windows = WindowController.windows,
		SubwindowOpen = SubwindowController.anyOpen,
	}))

	AppController.Render(e(subwindowCanvas, {
		Subwindows = SubwindowController.subwindows,
	}))

	AppController.Render(e(tooltipCanvas))

	UIController._toggleBind = BindController.AddBind(MENU_TOGGLE_BIND_NAME, function()
		uiState.isOpen(not peek(uiState.isOpen))
	end):SetMode("onPress")

	applyMenuToggleInputsFromUser()

	sub(UserController.menuToggleKey, function(): ()
		applyMenuToggleInputsFromUser()
	end)

	sub((UIController._toggleBind :: any).inputs, function(): ()
		persistMenuToggleKeyFromBind()
	end)

	local inputBlocker = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = false,
		DisplayOrder = 99, -- approot is 100
	}, cloneref(gethui()))

	-- this is here to block scrolling
	local scrollingHolder = instances.new("ScrollingFrame", {
		Active = false,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		ElasticBehavior = Enum.ElasticBehavior.Never,
		ScrollBarThickness = 0,
		ScrollingEnabled = true,
		Selectable = false,
	}, inputBlocker)

	-- this is here to block the hovered effect in uis
	instances.new("UIDragDetector", {
		ActivatedCursorIcon = nil,
		ActivatedCursorIconContent = nil,
		CursorIcon = nil,
		CursorIconContent = nil,
		BoundingUI = nil,
	}, scrollingHolder)

	-- and this is here to block button inputs
	instances.new("TextButton", {
		BackgroundTransparency = 1,
		TextTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
	}, scrollingHolder)

	sub(uiState.isOpen, function(open: boolean)
		setthreadidentity(8)
		WindowController.SetAllOpen(open)

		inputBlocker.Enabled = open

		if not open then
			SubwindowController.CloseAll()
			local saved = UIController._savedMouse
			if saved then
				hook.restoreProperty(UserInputService, "MouseBehavior")
				hook.restoreProperty(UserInputService, "MouseIconEnabled")
				hook.restoreProperty(UserInputService, "MouseIcon")
				UserInputService.MouseBehavior = saved.behavior
				UserInputService.MouseIconEnabled = saved.icon
				UserInputService.MouseIcon = saved.mouseIcon
				UIController._savedMouse = nil
			end
		elseif not UIController._savedMouse then
			local saved = {
				behavior = UserInputService.MouseBehavior,
				icon = UserInputService.MouseIconEnabled,
				mouseIcon = UserInputService.MouseIcon,
			}
			UIController._savedMouse = saved

			hook.addInstance(UserInputService)
			hook.overrideProperty(
				UserInputService,
				"MouseBehavior",
				LPH_NO_VIRTUALIZE(function(value: Enum.MouseBehavior): Enum.MouseBehavior
					saved.behavior = value
					return Enum.MouseBehavior.Default
				end)
			)
			hook.overrideProperty(
				UserInputService,
				"MouseIconEnabled",
				LPH_NO_VIRTUALIZE(function(value: boolean): boolean
					saved.icon = value
					return true
				end)
			)
			hook.overrideProperty(
				UserInputService,
				"MouseIcon",
				LPH_NO_VIRTUALIZE(function(value: string): string
					saved.mouseIcon = value
					return ""
				end)
			)

			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			UserInputService.MouseIcon = ""
		end
		setthreadidentity(8)
	end)

	local window = Window("Limerence")
	UIController.AddWindow(window)

	UIController._mainWindow = window

	sub(window._position, subwindowPosition.syncMenuPosition)
	subwindowPosition.syncMenuPosition(peek(window._position))

	window:AddTabGroup("COMMON", 99)

	return UIController
end

function UIController.AddWindow(window: WindowController.Window): WindowController.Window
	return WindowController.Add(window)
end

function UIController.EnsureTabGroup(title: string): any
	local window = UIController._mainWindow
	if not window then
		return nil
	end

	local existing = window:GetTabGroup(title)
	if existing then
		return existing
	end

	return window:AddTabGroup(title)
end

function UIController.OpenOptions(source: any): SubwindowController.Subwindow?
	return SubwindowController.OpenOptions(source)
end

function UIController.GetMainWindow(): Window.Window
	return UIController._mainWindow :: Window.Window
end

function UIController.GetTab(title: string): any?
	local window = UIController._mainWindow
	if not window then
		return nil
	end

	for _, group in next, peek(window._tabGroups) do
		for _, tab in next, peek(group.tabs) do
			if tab.title == title then
				return tab
			end
			for _, subtab in next, peek(tab._subtabs) do
				if subtab.title == title then
					return subtab
				end
			end
		end
	end
	return nil
end

function UIController.OpenTab(title: string): boolean
	local tab = UIController.GetTab(title)
	if not tab then
		return false
	end
	local subtabs = peek(tab._subtabs)
	if #subtabs > 0 then
		tab = peek(tab._activeSubtab) or subtabs[1]
	end
	windowState.openTab(tab)
	return true
end

function UIController.GetMenuToggleBindName(): string
	return MENU_TOGGLE_BIND_NAME
end

function UIController.GetMenuToggleInput(): (Enum.KeyCode | Enum.UserInputType)?
	return menuToggleInputFromUser()
end

function UIController.Destroy(): ()
	BindController.Destroy()
	local saved = UIController._savedMouse
	if saved then
		hook.restoreProperty(UserInputService, "MouseBehavior")
		hook.restoreProperty(UserInputService, "MouseIconEnabled")
		UserInputService.MouseBehavior = saved.behavior
		UserInputService.MouseIconEnabled = saved.icon
		UIController._savedMouse = nil
	end
end

export type UIController = typeof(UIController)

return UIController
