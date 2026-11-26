local React = require("@pkg/React")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")

local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local subscribeToBinding = (React :: any).__subscribeToBinding

local function findHighlight(): Highlight?
	local interfaceFolder = ReplicatedStorage:FindFirstChild("Interface")
	local interactFolder = interfaceFolder and interfaceFolder:FindFirstChild("Interact")
	local highlight = interactFolder and interactFolder:FindFirstChild("Highlight")
	if highlight then
		return highlight :: Highlight
	end

	local interact = ModuleController.FrameworkRequire("Interface", "Interact")
	local gui = interact and interact.Gui
	local parent = gui and gui.Parent
	return parent and parent:FindFirstChild("Highlight") :: Highlight?
end

local DEFAULT_FILL = Color3.fromRGB(120, 180, 255)
local DEFAULT_OUTLINE = Color3.fromRGB(160, 200, 255)

local InteractHighlight = {}
InteractHighlight.__index = InteractHighlight

setmetatable(InteractHighlight, { __index = BaseFeature })

local apply = LPH_NO_VIRTUALIZE(function(self: InteractHighlight): ()
	local highlight = self._highlight
	if not highlight then
		return
	end

	highlight.FillColor = (self._fillLink._currentColor :: any):getValue() :: Color3
	highlight.OutlineColor = (self._outlineLink._currentColor :: any):getValue() :: Color3
	highlight.FillTransparency = self._fillLink:GetTransparency()
	highlight.OutlineTransparency = self._outlineLink:GetTransparency()
end)

function InteractHighlight.new(link: gameUi.Linker): InteractHighlight
	local self = BaseFeature.new() :: any
	setmetatable(self, InteractHighlight)

	self._enabled = false
	self._highlight = nil :: Highlight?
	self._conns = {} :: { RBXScriptConnection }
	self._origFill = nil :: Color3?
	self._origOutline = nil :: Color3?

	local toggle = link:Toggle("interactHighlight", "Interaction Highlight", false):SetTip({
		title = "Interaction Highlight",
		body = "Recolors the outline shown on interactable objects.",
	})
	local highlightLink = link:OnKey("interactHighlight")
	highlightLink:Extra(toggle, "colors", "Submenu", "Highlight Colors")
	local colorsLink = highlightLink:OnKey("colors")
	colorsLink:Colorpicker("fillColor", "Fill Color", DEFAULT_FILL, 0.7)
	colorsLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)

	self._fillLink = colorsLink:Get("fillColor")
	self._outlineLink = colorsLink:Get("outlineColor")

	self:Track(subscribeToBinding(self._fillLink._currentColor, function(): ()
		apply(self)
	end))
	self:Track(subscribeToBinding(self._outlineLink._currentColor, function(): ()
		apply(self)
	end))

	self:Track(link:Get("interactHighlight"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("interactHighlight") then
		self:Enable()
	end

	return self
end

function InteractHighlight.Enable(self: InteractHighlight): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local highlight = findHighlight()
	if not highlight then
		return
	end

	self._highlight = highlight
	self._origFill = highlight.FillColor
	self._origOutline = highlight.OutlineColor

	local conns = self._conns
	conns[1] = highlight:GetPropertyChangedSignal("FillColor"):Connect(LPH_NO_VIRTUALIZE(function(): ()
		apply(self)
	end))
	conns[2] = highlight:GetPropertyChangedSignal("OutlineColor"):Connect(LPH_NO_VIRTUALIZE(function(): ()
		apply(self)
	end))
	conns[3] = highlight:GetPropertyChangedSignal("FillTransparency"):Connect(LPH_NO_VIRTUALIZE(function(): ()
		apply(self)
	end))

	apply(self)
end

function InteractHighlight.Disable(self: InteractHighlight): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	local conns = self._conns :: { RBXScriptConnection }
	for i = 1, #conns do
		conns[i]:Disconnect()
		conns[i] = nil
	end

	local highlight = self._highlight
	if highlight then
		if self._origFill then
			highlight.FillColor = self._origFill
		end
		if self._origOutline then
			highlight.OutlineColor = self._origOutline
		end
		self._highlight = nil
	end
end

function InteractHighlight.Destroy(self: InteractHighlight): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type InteractHighlight =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_highlight: Highlight?,
			_conns: { RBXScriptConnection },
			_origFill: Color3?,
			_origOutline: Color3?,
			_fillLink: any,
			_outlineLink: any,
		},
		InteractHighlight
	))
	& BaseFeature.BaseFeature

return InteractHighlight
