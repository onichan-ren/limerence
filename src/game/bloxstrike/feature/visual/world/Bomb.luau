local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local Charm = require("@pkg/Charm")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local bombState = require("@game/bloxstrike/bomb/bombState")
local bombRenderer = require("@game/bloxstrike/feature/visual/world/bombRenderer")

local subscribeToBinding = (React :: any).__subscribeToBinding

local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement

local DEFAULT_BOMB_COLOR = Color3.fromRGB(220, 190, 110)
local DEFAULT_DEFUSING_COLOR = Color3.fromRGB(200, 186, 160)
local DEFAULT_DEFUSED_COLOR = Color3.fromRGB(120, 200, 130)
local DEFAULT_BAR_COLOR = Color3.fromRGB(42, 42, 42)
local DEFAULT_FILL_COLOR = Color3.fromRGB(195, 95, 95)
local DEFAULT_OUTLINE_COLOR = Color3.fromRGB(225, 225, 225)

local INDICATOR_DISPLAY_ORDER = 15

local Bomb = {}
Bomb.__index = Bomb

setmetatable(Bomb, { __index = BaseFeature })

function Bomb.new(link: gameUi.Linker): Bomb
	local self = BaseFeature.new() :: any
	setmetatable(self, Bomb)

	local toggle = link:Toggle("bombIndicator", "Bomb Indicator", false):SetTip({
		title = "Bomb Indicator",
		body = "On-screen marker with countdown and outline for a planted bomb.",
	})
	link:Extra(toggle, "opts", "Submenu", "Bomb Indicator Options")
	local optsLink = link:OnKey("opts")
	optsLink:Colorpicker("bombColor", "Bomb Color", DEFAULT_BOMB_COLOR)
	optsLink:Colorpicker("defusingColor", "Defusing Color", DEFAULT_DEFUSING_COLOR)
	optsLink:Colorpicker("defusedColor", "Defused Color", DEFAULT_DEFUSED_COLOR)
	optsLink:Colorpicker("barColor", "Bar Color", DEFAULT_BAR_COLOR)

	local highlightToggle = optsLink:Toggle("highlight", "Highlight Bomb", true):SetTip({
		title = "Highlight",
		body = "Outline the planted bomb through walls.",
	})
	optsLink:Extra(highlightToggle, "highlightOpts", "Submenu", "Highlight Options")
	local highlightOptsLink = optsLink:OnKey("highlightOpts")
	highlightOptsLink:Colorpicker("fillColor", "Fill Color", DEFAULT_FILL_COLOR, 0.5)
	highlightOptsLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE_COLOR, 0)

	self._enabledLink = link:Get("bombIndicator")
	self._highlightToggleLink = optsLink:Get("highlight")
	self._fillColorLink = highlightOptsLink:Get("fillColor")
	self._outlineColorLink = highlightOptsLink:Get("outlineColor")

	self._highlight = nil :: Highlight?

	local parent = cloneref(gethui())

	local indicatorGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Enabled = true,
		DisplayOrder = INDICATOR_DISPLAY_ORDER,
	}, parent)
	self._indicatorGui = indicatorGui

	self._indicatorRoot = ReactRoblox.createRoot(indicatorGui)
	self._indicatorRoot:render(e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		Indicator = e(bombRenderer, {
			enabledLink = self._enabledLink,
			bombColorLink = optsLink:Get("bombColor"),
			defusingColorLink = optsLink:Get("defusingColor"),
			defusedColorLink = optsLink:Get("defusedColor"),
			barColorLink = optsLink:Get("barColor"),
		}),
	}))

	self:Track(sub(bombState.bomb, function(): ()
		self:_refreshHighlight()
	end))
	self:Track(self._highlightToggleLink:OnChange(function(): ()
		self:_refreshHighlight()
	end))
	self:Track(self._enabledLink:OnChange(function(): ()
		self:_refreshHighlight()
	end))

	local fillColorBinding = self._fillColorLink._currentColor
	local outlineColorBinding = self._outlineColorLink._currentColor
	self:Track(subscribeToBinding(fillColorBinding, function(): ()
		self:_applyHighlightColors()
	end))
	self:Track(subscribeToBinding(outlineColorBinding, function(): ()
		self:_applyHighlightColors()
	end))

	self:_refreshHighlight()

	return self
end

function Bomb._destroyHighlight(self: Bomb): ()
	if self._highlight then
		local hl = self._highlight :: Highlight
		hl.Enabled = false
		hl.Adornee = nil
		hl:Destroy()
		self._highlight = nil
	end
end

function Bomb._applyHighlightColors(self: Bomb): ()
	if not self._highlight then
		return
	end
	local fill = (self._fillColorLink._currentColor :: any):getValue() :: Color3
	local outline = (self._outlineColorLink._currentColor :: any):getValue() :: Color3
	;(self._highlight :: Highlight).FillColor = fill
	;(self._highlight :: Highlight).OutlineColor = outline
end

function Bomb._refreshHighlight(self: Bomb): ()
	local enabled = peek(self._enabledLink._state) == true
	local highlightOn = peek(self._highlightToggleLink._state) == true
	local bomb = peek(bombState.bomb)

	if not enabled or not highlightOn or not bomb then
		self:_destroyHighlight()
		return
	end

	if not self._highlight then
		local hl = Instance.new("Highlight")
		hl.Adornee = bomb.model
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillTransparency = 0.5
		hl.OutlineTransparency = 0
		hl.Parent = bomb.model
		self._highlight = hl
	else
		(self._highlight :: Highlight).Adornee = bomb.model
	end
	self:_applyHighlightColors()
end

function Bomb.Destroy(self: Bomb): ()
	self:_destroyHighlight()
	if self._indicatorRoot then
		self._indicatorRoot:unmount()
	end
	if self._indicatorGui then
		self._indicatorGui:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type Bomb =
	typeof(setmetatable(
		{} :: {
			_enabledLink: any,
			_highlightToggleLink: any,
			_fillColorLink: any,
			_outlineColorLink: any,
			_highlight: Highlight?,
			_indicatorGui: Instance,
			_indicatorRoot: ReactRoblox.RootType,
		},
		Bomb
	))
	& BaseFeature.BaseFeature

return Bomb
