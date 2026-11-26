local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local AppController = require("@feature/app/AppController")
local gameUi = require("@game/gameUi")
local hudView = require("@game/universal/feature/visual/hud/hudView")

local at = Charm.atom
local e = React.createElement

local DEFAULT_LOGO = ColorSequence.new(Color3.fromRGB(0, 255, 119))
local DEFAULT_TITLE = ColorSequence.new(Color3.fromRGB(255, 255, 255))
local DEFAULT_INFO = ColorSequence.new(Color3.fromRGB(0, 255, 119))
local DEFAULT_POSITION = UDim2.new(0.5, 0, 0.5, 0)

local Hud = {}
Hud.__index = Hud

setmetatable(Hud, { __index = BaseFeature })

function Hud.new(link: gameUi.Linker): Hud
	local self = BaseFeature.new() :: any
	setmetatable(self, Hud)

	self._mounted = false
	self._open = at(false)

	link:Toggle("hud", "HUD", false):SetTip({
		title = "HUD",
		body = "Shows a logo and title on screen. While the menu is open, drag the HUD to move it and snap it to the screen edges or center. Right-click it to reset its position.",
	})
	local rootLink = link:OnKey("hud")

	rootLink:Submenu("opts", "HUD")
	local optionsLink = rootLink:OnKey("opts")

	optionsLink:Submenu("colors", "Colors")
	local colorsLink = optionsLink:OnKey("colors")

	local logoColor = colorsLink:Colorpicker("logoColor", "Logo Color", DEFAULT_LOGO, 0)
	logoColor:SetTip({
		title = "Logo Color",
		body = "Color of the logo and its particles.",
	})
	local titleColor = colorsLink:Colorpicker("titleColor", "Title Color", DEFAULT_TITLE, 0)
	titleColor:SetTip({
		title = "Title Color",
		body = "Color of the title text.",
	})
	local infoColor = colorsLink:Colorpicker("infoColor", "Info Color", DEFAULT_INFO, 0)
	infoColor:SetTip({
		title = "Info Color",
		body = "Color of the info line.",
	})

	optionsLink:Submenu("info", "Info Line")
	local infoLink = optionsLink:OnKey("info")

	local showInfo = infoLink:Toggle("showInfo", "Info Text", true):SetTip({
		title = "Info Text",
		body = "Shows a line of live details under the title while combat features are active, like your current target and charge progress.",
	})
	local animations = infoLink:Toggle("animations", "Animations", true):SetTip({
		title = "Animations",
		body = "Fades info entries in and out and pulses them when they update.",
	})

	local position = rootLink:Value("position", DEFAULT_POSITION)

	self._logoColor = logoColor
	self._titleColor = titleColor
	self._showInfo = showInfo
	self._animations = animations
	self._infoColor = infoColor
	self._position = position

	self:Track(link:Get("hud"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("hud") then
		self:Enable()
	end

	return self
end

function Hud._ensureMounted(self: Hud): ()
	if self._mounted then
		return
	end
	self._mounted = true
	AppController.Render(e(hudView, {
		open = self._open,
		logoColor = self._logoColor,
		titleColor = self._titleColor,
		showInfo = self._showInfo,
		animations = self._animations,
		infoColor = self._infoColor,
		position = self._position,
	}))
end

function Hud.Enable(self: Hud): ()
	self:_ensureMounted()
	self._open(true)
end

function Hud.Disable(self: Hud): ()
	self._open(false)
end

export type Hud = typeof(setmetatable(
	{} :: {
		_logoColor: any,
		_titleColor: any,
		_showInfo: any,
		_animations: any,
		_infoColor: any,
		_position: any,
		_open: Charm.Atom<boolean>,
		_mounted: boolean,
	},
	Hud
)) & BaseFeature.BaseFeature

return Hud
