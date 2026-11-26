local Janitor = require("@pkg/Janitor")
local CoreGui = cloneref(gethui())
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Charm = require("@pkg/Charm")
local clientState = require("@game/overkill/client/clientState")
local customCharacterOpts = require("@game/overkill/feature/visual/self/customCharacterOpts")

local peek = Charm.peek
local sub = Charm.subscribe

local SelfEsp = {}
SelfEsp.__index = SelfEsp

setmetatable(SelfEsp, { __index = BaseFeature })

function SelfEsp.new(link: gameUi.Linker): SelfEsp
	local self = BaseFeature.new() :: any
	setmetatable(self, SelfEsp)

	link:Toggle("selfHighlight", "Highlight", false):SetTip({
		title = "Highlight",
		body = "Draws a Highlight on your own character so you can see your body in third person or when the camera clips.",
	})
	local highlightLink = link:OnKey("selfHighlight")
	highlightLink:Colorpicker("selfFillColor", "Fill Color", Color3.fromRGB(145, 190, 215), 0.7):SetTip({
		title = "Fill Color",
		body = "Inner color of the self highlight.",
	})
	highlightLink:Submenu("opts", "Self Highlight Options")
	local optsLink = highlightLink:OnKey("opts")
	optsLink:Colorpicker("selfOutlineColor", "Outline Color", Color3.fromRGB(225, 225, 225), 0):SetTip({
		title = "Outline Color",
		body = "Outline color of the self highlight.",
	})

	self._fillPicker = highlightLink:Get("selfFillColor")
	self._outlinePicker = optsLink:Get("selfOutlineColor")
	self._highlightEnabled = false
	self._highlightJanitor = nil :: Janitor.Janitor?

	self:Track(link:Get("selfHighlight"):OnChange(function(enabled: boolean): ()
		if enabled then
			self:EnableHighlight()
		else
			self:DisableHighlight()
		end
	end))

	if link:Get("selfHighlight"):Peek() then
		self:EnableHighlight()
	end

	return self
end

function SelfEsp.EnableHighlight(self: SelfEsp): ()
	if self._highlightEnabled then
		return
	end
	self._highlightEnabled = true

	local highlight = Instance.new("Highlight")
	highlight.Parent = CoreGui
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

	local highlightJanitor = Janitor.new()
	self._highlightJanitor = highlightJanitor
	highlightJanitor:Add(function(): ()
		highlight.Enabled = false
		highlight.Adornee = nil
		highlight:Destroy()
	end, true)

	local fillPicker = self._fillPicker
	local outlinePicker = self._outlinePicker

	local function applyFill(snapshot: any): ()
		highlight.FillColor = snapshot.color
		highlight.FillTransparency = snapshot.transparency
	end

	local function applyOutline(snapshot: any): ()
		highlight.OutlineColor = snapshot.color
		highlight.OutlineTransparency = snapshot.transparency
	end

	applyFill(fillPicker:GetSnapshot())
	applyOutline(outlinePicker:GetSnapshot())

	highlightJanitor:Add(fillPicker:OnUpdate(applyFill))
	highlightJanitor:Add(outlinePicker:OnUpdate(applyOutline))

	local function updateAdornee(): ()
		highlight.Adornee = peek(customCharacterOpts.visibleModelAtom) or peek(clientState.character)
	end

	highlightJanitor:Add(sub(clientState.character, updateAdornee))
	highlightJanitor:Add(sub(customCharacterOpts.visibleModelAtom, updateAdornee))

	updateAdornee()
end

function SelfEsp.DisableHighlight(self: SelfEsp): ()
	if not self._highlightEnabled then
		return
	end
	self._highlightEnabled = false
	if self._highlightJanitor then
		self._highlightJanitor:Destroy()
		self._highlightJanitor = nil
	end
end

function SelfEsp.Destroy(self: SelfEsp): ()
	self:DisableHighlight()
	BaseFeature.Destroy(self)
end

export type SelfEsp =
	typeof(setmetatable(
		{} :: {
			_fillPicker: any,
			_outlinePicker: any,
			_highlightEnabled: boolean,
			_highlightJanitor: Janitor.Janitor?,
		},
		SelfEsp
	))
	& BaseFeature.BaseFeature

return SelfEsp
