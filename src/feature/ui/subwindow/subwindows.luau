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

local subwindows = {
	Options = Options,
	Colorpicker = Colorpicker,
	Context = Context,
	Dropdown = Dropdown,
	ThemeEditor = ThemeEditor,
	BindEditor = BindEditor,
	AssetPicker = AssetPicker,
	ScopeMenu = ScopeMenu,
	RecordEditor = RecordEditor,
	SkinConfig = SkinConfig,
	VisualImport = VisualImport,
	CharacterEditor = CharacterEditor,
}

export type Subwindow = Options.Subwindow

return subwindows
