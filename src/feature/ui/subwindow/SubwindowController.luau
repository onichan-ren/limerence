local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local subwindows = require("@ui/subwindow/subwindows")
local Options = require("@ui/subwindow/options/Options")
local Colorpicker = require("@ui/subwindow/colorpicker/Colorpicker")
local Context = require("@ui/subwindow/context/Context")
local Dropdown = require("@ui/subwindow/dropdown/Dropdown")
local ThemeEditor = require("@ui/subwindow/themeEditor/ThemeEditor")
local BindEditor = require("@ui/subwindow/keybind/BindEditor")
local AssetPicker = require("@ui/subwindow/assetPicker/AssetPicker")
local ScopeMenu = require("@ui/subwindow/scopemenu/ScopeMenu")
local RecordEditor = require("@ui/subwindow/recordEditor/RecordEditor")
local SkinConfig = require("@ui/subwindow/skinConfig/SkinConfig")
local VisualImport = require("@ui/subwindow/visualImport/VisualImport")
local CharacterEditor = require("@ui/subwindow/characterEditor/CharacterEditor")
local floatingController = require("@ui/floating/floatingController")
local contextApi = require("@ui/subwindow/context/contextApi")
local dropdownApi = require("@ui/subwindow/dropdown/dropdownApi")
local elementApi = require("@ui/window/element/elementApi")

local peek = Charm.peek
local at = Charm.atom
local sub = Charm.subscribe

local SubwindowController = {
	subwindows = at({} :: { [string]: Subwindow }),
	anyOpen = at(false),
}

local function recomputeAnyOpen(): ()
	for _, subwindow in next, peek(SubwindowController.subwindows) do
		if peek(subwindow._isOpen) then
			SubwindowController.anyOpen(true)
			return
		end
	end
	SubwindowController.anyOpen(false)
end

function SubwindowController.Add(name: string, subwindow: Subwindow): Subwindow
	local raw = peek(SubwindowController.subwindows)
	SubwindowController.subwindows(Sift.Dictionary.set(raw, name, subwindow))

	sub(subwindow._isOpen, recomputeAnyOpen)
	recomputeAnyOpen()

	return subwindow
end

function SubwindowController.Get(name: string): Subwindow?
	return peek(SubwindowController.subwindows)[name]
end

local OPTIONS_SLOTS = { "Options", "Submenu", "Submenu2", "Submenu3", "Submenu4" }
local SUBMENU_SLOTS = { "Submenu", "Submenu2", "Submenu3", "Submenu4" }

local function openFromSlots(slots: { string }, source: any, position: UDim2?): Options?
	if not floatingController.IsSubwindowOpenAllowed() then
		return nil
	end

	local subwindowsMap = peek(SubwindowController.subwindows)

	for _, name in next, slots do
		local sw: any = subwindowsMap[name]
		if sw and peek(sw._source) == source then
			sw:Open(source, position)
			return sw
		end
	end

	for _, name in next, slots do
		local sw: any = subwindowsMap[name]
		if sw and not peek(sw._isOpen) then
			sw:Open(source, position)
			return sw
		end
	end

	local fallback: any = subwindowsMap[slots[1]]
	if not fallback then
		return nil
	end
	fallback:Open(source, position)
	return fallback
end

function SubwindowController.OpenOptions(source: any, position: UDim2?): Options?
	return openFromSlots(OPTIONS_SLOTS, source, position)
end

function SubwindowController.OpenSubmenu(source: any, position: UDim2?): Options?
	return openFromSlots(SUBMENU_SLOTS, source, position)
end

function SubwindowController.CloseAllSubmenus(): ()
	local subwindowsMap = peek(SubwindowController.subwindows)
	for _, name in next, SUBMENU_SLOTS do
		local sw: any = subwindowsMap[name]
		if sw then
			sw:Close()
		end
	end
end

function SubwindowController.OpenColorpicker(source: any, position: UDim2?): ColorpickerSub?
	if not floatingController.IsSubwindowOpenAllowed() then
		return nil
	end
	local colorpickerSubwindow: any = SubwindowController.Get("Colorpicker")
	if not colorpickerSubwindow then
		return nil
	end

	colorpickerSubwindow:Open(source, position)

	return colorpickerSubwindow
end

function SubwindowController.OpenDropdown(source: any, position: UDim2?): DropdownSub?
	if not floatingController.IsSubwindowOpenAllowed() then
		return nil
	end
	local dropdownSubwindow: any = SubwindowController.Get("Dropdown")
	if not dropdownSubwindow then
		return nil
	end

	dropdownSubwindow:Open(source, position)

	return dropdownSubwindow
end

function SubwindowController.CloseDropdown(source: any?): ()
	local dropdownSubwindow: any = SubwindowController.Get("Dropdown")
	if not dropdownSubwindow then
		return
	end

	if source and peek(dropdownSubwindow._source) ~= source then
		return
	end

	dropdownSubwindow:Close()
end

function SubwindowController.WasDropdownJustClosedFor(source: any): boolean
	local dropdownSubwindow: any = SubwindowController.Get("Dropdown")
	if not dropdownSubwindow then
		return false
	end
	return dropdownSubwindow:WasJustClosedFor(source)
end

function SubwindowController.OpenThemeEditor(opts: ThemeEditor.OpenOptions): ThemeEditorSub?
	if not floatingController.IsSubwindowOpenAllowed() then
		return nil
	end
	local editor: any = SubwindowController.Get("ThemeEditor")
	if not editor then
		return nil
	end

	editor:Open(opts)

	return editor
end

function SubwindowController.OpenContext(items: { Context.ContextItem }, position: UDim2?): ContextSub?
	if not floatingController.IsSubwindowOpenAllowed() then
		return nil
	end
	local contextSubwindow: any = SubwindowController.Get("Context")
	if not contextSubwindow then
		return nil
	end

	contextSubwindow:Open(items, position)

	return contextSubwindow
end

function SubwindowController.CloseContext(): ()
	local contextSubwindow: any = SubwindowController.Get("Context")
	if not contextSubwindow then
		return
	end

	contextSubwindow:Close()
end

function SubwindowController.OpenAssetPicker(source: any, position: UDim2?): AssetPickerSub?
	if not floatingController.IsSubwindowOpenAllowed() then
		return nil
	end
	local assetPickerSubwindow: any = SubwindowController.Get("AssetPicker")
	if not assetPickerSubwindow then
		return nil
	end

	assetPickerSubwindow:Open(source, position)

	return assetPickerSubwindow
end

function SubwindowController.OpenScopeMenu(position: UDim2?, anchorRef: { current: GuiObject? }?): ScopeMenuSub?
	if not floatingController.IsSubwindowOpenAllowed() then
		return nil
	end
	local scopeMenu: any = SubwindowController.Get("ScopeMenu")
	if not scopeMenu then
		return nil
	end
	scopeMenu:Open(position, anchorRef)
	return scopeMenu
end

function SubwindowController.CloseScopeMenu(): ()
	local scopeMenu: any = SubwindowController.Get("ScopeMenu")
	if not scopeMenu then
		return
	end
	scopeMenu:Close()
end

function SubwindowController.WasScopeMenuJustClosed(): boolean
	local scopeMenu: any = SubwindowController.Get("ScopeMenu")
	if not scopeMenu then
		return false
	end
	return scopeMenu:WasJustClosed()
end

function SubwindowController.OpenRecordEditor(opts: RecordEditor.OpenOptions): RecordEditorSub?
	if not floatingController.IsSubwindowOpenAllowed() then
		return nil
	end
	local editor: any = SubwindowController.Get("RecordEditor")
	if not editor then
		return nil
	end

	editor:Open(opts)

	return editor
end

function SubwindowController.OpenSkinConfig(opts: SkinConfig.OpenOptions): SkinConfigSub?
	if not floatingController.IsSubwindowOpenAllowed() then
		return nil
	end
	local skinConfigSubwindow: any = SubwindowController.Get("SkinConfig")
	if not skinConfigSubwindow then
		return nil
	end

	skinConfigSubwindow:Open(opts)

	return skinConfigSubwindow
end

function SubwindowController.CloseSkinConfig(): ()
	local skinConfigSubwindow: any = SubwindowController.Get("SkinConfig")
	if not skinConfigSubwindow then
		return
	end
	skinConfigSubwindow:Close()
end

function SubwindowController.OpenVisualImport(opts: VisualImport.OpenOptions): VisualImportSub?
	if not floatingController.IsSubwindowOpenAllowed() then
		return nil
	end
	local visualImportSubwindow: any = SubwindowController.Get("VisualImport")
	if not visualImportSubwindow then
		return nil
	end

	visualImportSubwindow:Open(opts)

	return visualImportSubwindow
end

function SubwindowController.OpenBindEditor(element: any, position: UDim2?): BindEditorSub?
	if not floatingController.IsSubwindowOpenAllowed() then
		return nil
	end
	local bindEditorSubwindow: any = SubwindowController.Get("BindEditor")
	if not bindEditorSubwindow then
		return nil
	end

	bindEditorSubwindow:Open(element, position)

	return bindEditorSubwindow
end

function SubwindowController.OpenCharacterEditor(opts: CharacterEditor.OpenOptions): CharacterEditorSub?
	if not floatingController.IsSubwindowOpenAllowed() then
		return nil
	end
	local editor: any = SubwindowController.Get("CharacterEditor")
	if not editor then
		return nil
	end

	editor:Open(opts)

	return editor
end

function SubwindowController.CloseAll(): ()
	for _, subwindow in next, peek(SubwindowController.subwindows) do
		subwindow:SetOpen(false)
	end
end

function SubwindowController.init(): ()
	SubwindowController.Add("Options", Options())
	SubwindowController.Add("Submenu", Options())
	SubwindowController.Add("Submenu2", Options())
	SubwindowController.Add("Submenu3", Options())
	SubwindowController.Add("Submenu4", Options())
	SubwindowController.Add("Colorpicker", Colorpicker())
	SubwindowController.Add("Dropdown", Dropdown())
	SubwindowController.Add("ThemeEditor", ThemeEditor())
	SubwindowController.Add("BindEditor", BindEditor())
	SubwindowController.Add("AssetPicker", AssetPicker())
	SubwindowController.Add("ScopeMenu", ScopeMenu())
	SubwindowController.Add("RecordEditor", RecordEditor())
	SubwindowController.Add("SkinConfig", SkinConfig())
	SubwindowController.Add("VisualImport", VisualImport())
	SubwindowController.Add("CharacterEditor", CharacterEditor())

	local contextSubwindow = Context()
	SubwindowController.Add("Context", contextSubwindow)

	contextApi.SetHandlers(function(items, position)
		if not floatingController.IsSubwindowOpenAllowed() then
			return
		end
		contextSubwindow:Open(items, position)
	end, function()
		contextSubwindow:Close()
	end)

	dropdownApi.SetHandlers(function(source, position)
		SubwindowController.OpenDropdown(source, position)
	end, function(source)
		if source then
			SubwindowController.CloseDropdown(source)
		else
			SubwindowController.CloseDropdown()
		end
	end, function(source)
		return SubwindowController.WasDropdownJustClosedFor(source)
	end)

	elementApi.SetHandlers(function(element, position)
		SubwindowController.OpenBindEditor(element, position)
	end, function(items, position)
		SubwindowController.OpenContext(items, position)
	end)
end

export type SubwindowController = typeof(SubwindowController)
export type Subwindow = subwindows.Subwindow
export type ContextItem = Context.ContextItem
type Options = Options.Options
type ColorpickerSub = Colorpicker.Colorpicker
type ContextSub = Context.Context
type DropdownSub = Dropdown.Dropdown
type ThemeEditorSub = ThemeEditor.ThemeEditor
type BindEditorSub = BindEditor.BindEditor
type AssetPickerSub = AssetPicker.AssetPicker
type ScopeMenuSub = ScopeMenu.ScopeMenu
type RecordEditorSub = RecordEditor.RecordEditor
type SkinConfigSub = SkinConfig.SkinConfig
type VisualImportSub = VisualImport.VisualImport
type CharacterEditorSub = CharacterEditor.CharacterEditor

return SubwindowController
