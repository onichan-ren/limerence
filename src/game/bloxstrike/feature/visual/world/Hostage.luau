local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local Charm = require("@pkg/Charm")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local hostageState = require("@game/bloxstrike/hostage/hostageState")
local hostageRenderer = require("@game/bloxstrike/feature/visual/world/hostageRenderer")

local subscribeToBinding = (React :: any).__subscribeToBinding

local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement

local DEFAULT_IDLE_COLOR = Color3.fromRGB(200, 186, 160)
local DEFAULT_RESCUING_COLOR = Color3.fromRGB(220, 190, 110)
local DEFAULT_CARRIED_COLOR = Color3.fromRGB(120, 200, 130)
local DEFAULT_BAR_COLOR = Color3.fromRGB(42, 42, 42)
local DEFAULT_FILL_COLOR = Color3.fromRGB(120, 200, 130)
local DEFAULT_OUTLINE_COLOR = Color3.fromRGB(225, 225, 225)

local DISPLAY_ORDER = 15

local Hostage = {}
Hostage.__index = Hostage

setmetatable(Hostage, { __index = BaseFeature })

function Hostage.new(link: gameUi.Linker): Hostage
	local self = BaseFeature.new() :: any
	setmetatable(self, Hostage)

	local toggle = link:Toggle("hostageIndicator", "Hostage Indicator", false):SetTip({
		title = "Hostage Indicator",
		body = "On-screen marker and outline for each hostage, with rescue progress.",
	})
	link:Extra(toggle, "opts", "Submenu", "Hostage Indicator Options")
	local optsLink = link:OnKey("opts")
	optsLink:Colorpicker("idleColor", "Idle Color", DEFAULT_IDLE_COLOR)
	optsLink:Colorpicker("rescuingColor", "Rescuing Color", DEFAULT_RESCUING_COLOR)
	optsLink:Colorpicker("carriedColor", "Carried Color", DEFAULT_CARRIED_COLOR)
	optsLink:Colorpicker("barColor", "Bar Color", DEFAULT_BAR_COLOR)

	local highlightToggle = optsLink:Toggle("highlight", "Highlight Hostages", true):SetTip({
		title = "Highlight",
		body = "Outline each hostage through walls.",
	})
	optsLink:Extra(highlightToggle, "highlightOpts", "Submenu", "Highlight Options")
	local highlightOptsLink = optsLink:OnKey("highlightOpts")
	highlightOptsLink:Colorpicker("fillColor", "Fill Color", DEFAULT_FILL_COLOR, 0.5)
	highlightOptsLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE_COLOR, 0)

	self._enabledLink = link:Get("hostageIndicator")
	self._highlightToggleLink = optsLink:Get("highlight")
	self._fillColorLink = highlightOptsLink:Get("fillColor")
	self._outlineColorLink = highlightOptsLink:Get("outlineColor")

	self._highlights = {} :: { [string]: Highlight }

	local parent = cloneref(gethui())

	local indicatorGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Enabled = true,
		DisplayOrder = DISPLAY_ORDER,
	}, parent)
	self._indicatorGui = indicatorGui

	self._indicatorRoot = ReactRoblox.createRoot(indicatorGui)
	self._indicatorRoot:render(e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		Indicators = e(hostageRenderer, {
			enabledLink = self._enabledLink,
			idleColorLink = optsLink:Get("idleColor"),
			rescuingColorLink = optsLink:Get("rescuingColor"),
			carriedColorLink = optsLink:Get("carriedColor"),
			barColorLink = optsLink:Get("barColor"),
		}),
	}))

	self:Track(sub(hostageState.hostages, function(): ()
		self:_refreshHighlights()
	end))
	self:Track(self._highlightToggleLink:OnChange(function(): ()
		self:_refreshHighlights()
	end))
	self:Track(self._enabledLink:OnChange(function(): ()
		self:_refreshHighlights()
	end))

	local fillColorBinding = self._fillColorLink._currentColor
	local outlineColorBinding = self._outlineColorLink._currentColor
	self:Track(subscribeToBinding(fillColorBinding, function(): ()
		self:_applyHighlightColors()
	end))
	self:Track(subscribeToBinding(outlineColorBinding, function(): ()
		self:_applyHighlightColors()
	end))

	self:_refreshHighlights()

	return self
end

function Hostage._applyHighlightColors(self: Hostage): ()
	local fill = (self._fillColorLink._currentColor :: any):getValue() :: Color3
	local outline = (self._outlineColorLink._currentColor :: any):getValue() :: Color3
	for _, hl in next, self._highlights do
		hl.FillColor = fill
		hl.OutlineColor = outline
	end
end

function Hostage._refreshHighlights(self: Hostage): ()
	local enabled = peek(self._enabledLink._state) == true
	local highlightOn = peek(self._highlightToggleLink._state) == true
	local hostages = peek(hostageState.hostages)

	for key, hl in next, self._highlights do
		if not hostages[key] then
			hl.Enabled = false
			hl.Adornee = nil
			hl:Destroy()
			self._highlights[key] = nil
		end
	end

	if not enabled or not highlightOn then
		for _, hl in next, self._highlights do
			hl.Enabled = false
			hl.Adornee = nil
			hl:Destroy()
		end
		table.clear(self._highlights)
		return
	end

	for key, entry in next, hostages do
		if not self._highlights[key] then
			local hl = Instance.new("Highlight")
			hl.Adornee = entry.model
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.FillTransparency = 0.5
			hl.OutlineTransparency = 0
			hl.Parent = entry.model
			self._highlights[key] = hl
		end
	end

	self:_applyHighlightColors()
end

function Hostage.Destroy(self: Hostage): ()
	for _, hl in next, self._highlights do
		hl.Enabled = false
		hl.Adornee = nil
		hl:Destroy()
	end
	table.clear(self._highlights)
	if self._indicatorRoot then
		self._indicatorRoot:unmount()
	end
	if self._indicatorGui then
		self._indicatorGui:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type Hostage =
	typeof(setmetatable(
		{} :: {
			_enabledLink: any,
			_highlightToggleLink: any,
			_fillColorLink: any,
			_outlineColorLink: any,
			_highlights: { [string]: Highlight },
			_indicatorGui: Instance,
			_indicatorRoot: ReactRoblox.RootType,
		},
		Hostage
	))
	& BaseFeature.BaseFeature

return Hostage
