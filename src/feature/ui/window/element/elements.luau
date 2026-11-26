local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local Element = require("@ui/window/element/Element")
local Options = require("@ui/window/element/options/Options")
local Toggle = require("@ui/window/element/toggle/Toggle")
local Slider = require("@ui/window/element/slider/Slider")
local RangeSlider = require("@ui/window/element/rangeslider/RangeSlider")
local Colorpicker = require("@ui/window/element/colorpicker/Colorpicker")
local CurveEditor = require("@ui/window/element/curveeditor/CurveEditor")
local Dropdown = require("@ui/window/element/dropdown/Dropdown")
local Submenu = require("@ui/window/element/submenu/Submenu")
local List = require("@ui/window/element/list/List")
local PriorityList = require("@ui/window/element/prioritylist/PriorityList")
local Button = require("@ui/window/element/button/Button")
local Key = require("@ui/window/element/key/Key")
local AssetPicker = require("@ui/window/element/assetpicker/AssetPicker")
local Table = require("@ui/window/element/table/Table")
local Textbox = require("@ui/window/element/textbox/Textbox")
local Guide = require("@ui/window/element/guide/Guide")
local StateColors = require("@ui/window/element/statecolors/StateColors")
local EspPreview = require("@ui/window/element/esppreview/EspPreview")
local EspElements = require("@ui/window/element/espelements/EspElements")
local registry = require("@ui/window/element/registry")

local peek = Charm.peek

registry.Options = Options
registry.Toggle = Toggle
registry.Slider = Slider
registry.RangeSlider = RangeSlider
registry.Colorpicker = Colorpicker
registry.CurveEditor = CurveEditor
registry.Dropdown = Dropdown
registry.Submenu = Submenu
registry.List = List.__call
registry.PriorityList = PriorityList.__call
registry.Button = Button
registry.Key = Key
registry.AssetPicker = AssetPicker
registry.Table = Table
registry.Textbox = Textbox
registry.Guide = Guide
registry.StateColors = StateColors
registry.EspPreview = EspPreview
registry.EspElements = EspElements

local elementClass: any = Element
function elementClass.AddElement(self: any, type: string, ...: any): any?
	local elementType = registry[type]
	if not elementType then
		return nil
	end

	local element = elementType(...)
	local raw = peek(self._extras)
	self._extras(Sift.Array.insert(raw, #raw + 1, element))

	return element
end

export type Element = Element.Element

return registry
