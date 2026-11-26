local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local Charm = require("@pkg/Charm")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local binTracker = require("@game/ar2/feature/visuals/world/binTracker")
local worldEspState = require("@game/ar2/feature/visuals/world/worldEspState")
local worldIndicatorRenderer = require("@game/ar2/feature/visuals/world/worldIndicatorRenderer")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local subscribeToBinding = (React :: any).__subscribeToBinding

local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement

local BIN_NAME = "Corpses"
local LABEL = "CORPSE"
local DISTANCE_STEP = 0.25

local DEFAULT_COLOR = Color3.fromRGB(200, 186, 160)
local DEFAULT_FILL_COLOR = Color3.fromRGB(200, 186, 160)
local DEFAULT_OUTLINE_COLOR = Color3.fromRGB(225, 225, 225)

local DISPLAY_ORDER = 15

local CorpseEsp = {}
CorpseEsp.__index = CorpseEsp

setmetatable(CorpseEsp, { __index = BaseFeature })

function CorpseEsp.new(link: gameUi.Linker): CorpseEsp
	local self = BaseFeature.new() :: any
	setmetatable(self, CorpseEsp)

	local toggle = link:Toggle("corpseEsp", "Corpse ESP", false):SetTip({
		title = "Corpse ESP",
		body = "On-screen markers over corpses so you can find loot.",
	})
	local corpseLink = link:OnKey("corpseEsp")
	corpseLink:Extra(toggle, "color", "Colorpicker", "Color", DEFAULT_COLOR)
	corpseLink:Extra(toggle, "opts", "Submenu", "Corpse ESP Options")
	local optsLink = corpseLink:OnKey("opts")
	optsLink:Slider("maxDistance", "Max Distance", 500, 50, 2000, 25, nil, "st"):SetTip({
		title = "Max Distance",
		body = "Hides markers past this distance.",
	})
	optsLink:Toggle("showDistance", "Show Distance", true):SetTip({
		title = "Show Distance",
		body = "Shows how far away each corpse is.",
	})

	local highlightToggle = optsLink:Toggle("highlight", "Highlight Corpses", true):SetTip({
		title = "Highlight",
		body = "Outline each corpse through walls.",
	})
	optsLink:Extra(highlightToggle, "highlightOpts", "Submenu", "Highlight Options")
	local highlightOptsLink = optsLink:OnKey("highlightOpts")
	highlightOptsLink:Colorpicker("fillColor", "Fill Color", DEFAULT_FILL_COLOR, 0.5)
	highlightOptsLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE_COLOR, 0)

	self._enabledLink = link:Get("corpseEsp")
	self._maxDistanceLink = optsLink:Get("maxDistance")
	self._highlightToggleLink = optsLink:Get("highlight")
	self._fillColorLink = highlightOptsLink:Get("fillColor")
	self._outlineColorLink = highlightOptsLink:Get("outlineColor")

	self._highlights = {} :: { [Model]: Highlight }
	self._distanceConn = nil :: RBXScriptConnection?

	self._trackerJanitor = binTracker.track(BIN_NAME, worldEspState.corpses, function(): string
		return LABEL
	end, function(model: Model): boolean
		return model:GetAttribute("InteractId") ~= nil
	end)

	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = DISPLAY_ORDER,
	}, cloneref(gethui()))
	self._screenGui = screenGui

	self._root = ReactRoblox.createRoot(screenGui)
	self._root:render(e(worldIndicatorRenderer, {
		enabledLink = self._enabledLink,
		colorLink = corpseLink:Get("color"),
		maxDistanceLink = optsLink:Get("maxDistance"),
		showDistanceLink = optsLink:Get("showDistance"),
		entries = worldEspState.corpses,
	}))

	self:Track(sub(worldEspState.corpses, function(): ()
		self:_refreshHighlights()
	end))
	self:Track(self._highlightToggleLink:OnChange(function(): ()
		self:_refreshHighlights()
	end))
	self:Track(self._enabledLink:OnChange(function(): ()
		self:_refreshHighlights()
	end))

	self:Track(subscribeToBinding(self._fillColorLink._currentColor, function(): ()
		self:_applyHighlightColors()
	end))
	self:Track(subscribeToBinding(self._outlineColorLink._currentColor, function(): ()
		self:_applyHighlightColors()
	end))

	self:_refreshHighlights()

	return self
end

function CorpseEsp._applyHighlightColors(self: CorpseEsp): ()
	local fill = (self._fillColorLink._currentColor :: any):getValue() :: Color3
	local outline = (self._outlineColorLink._currentColor :: any):getValue() :: Color3
	local fillTransparency = self._fillColorLink:GetTransparency()
	local outlineTransparency = self._outlineColorLink:GetTransparency()
	for _, hl in next, self._highlights do
		hl.FillColor = fill
		hl.OutlineColor = outline
		hl.FillTransparency = fillTransparency
		hl.OutlineTransparency = outlineTransparency
	end
end

function CorpseEsp._stepHighlightDistance(self: CorpseEsp): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local maxDistance = peek(self._maxDistanceLink._state) :: number
	local camPos = camera.CFrame.Position

	for model, hl in next, self._highlights do
		local primary = model.PrimaryPart
		local pos = primary and primary.Position or model:GetPivot().Position
		hl.Enabled = (pos - camPos).Magnitude <= maxDistance
	end
end

function CorpseEsp._syncDistanceLoop(self: CorpseEsp): ()
	if next(self._highlights) then
		if not self._distanceConn then
			local accumulator = DISTANCE_STEP
			self._distanceConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
				accumulator += dt
				if accumulator < DISTANCE_STEP then
					return
				end
				accumulator = 0
				self:_stepHighlightDistance()
			end))
		end
	elseif self._distanceConn then
		self._distanceConn:Disconnect()
		self._distanceConn = nil
	end
end

function CorpseEsp._refreshHighlights(self: CorpseEsp): ()
	local enabled = peek(self._enabledLink._state) == true
	local highlightOn = peek(self._highlightToggleLink._state) == true
	local entries = peek(worldEspState.corpses)

	for model, hl in next, self._highlights do
		if not entries[model] or not enabled or not highlightOn then
			hl.Enabled = false
			hl.Adornee = nil
			hl:Destroy()
			self._highlights[model] = nil
		end
	end

	if not enabled or not highlightOn then
		self:_syncDistanceLoop()
		return
	end

	for model in next, entries do
		if not self._highlights[model] then
			local hl = Instance.new("Highlight")
			hl.Adornee = model
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Parent = model
			self._highlights[model] = hl
		end
	end

	self:_applyHighlightColors()
	self:_stepHighlightDistance()
	self:_syncDistanceLoop()
end

function CorpseEsp.Destroy(self: CorpseEsp): ()
	if self._distanceConn then
		self._distanceConn:Disconnect()
		self._distanceConn = nil
	end
	for _, hl in next, self._highlights do
		hl.Enabled = false
		hl.Adornee = nil
		hl:Destroy()
	end
	table.clear(self._highlights)
	if self._trackerJanitor then
		self._trackerJanitor:Destroy()
	end
	if self._root then
		self._root:unmount()
	end
	if self._screenGui then
		self._screenGui:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type CorpseEsp =
	typeof(setmetatable(
		{} :: {
			_enabledLink: any,
			_maxDistanceLink: any,
			_highlightToggleLink: any,
			_fillColorLink: any,
			_outlineColorLink: any,
			_highlights: { [Model]: Highlight },
			_distanceConn: RBXScriptConnection?,
			_trackerJanitor: any,
			_screenGui: Instance,
			_root: ReactRoblox.RootType,
		},
		CorpseEsp
	))
	& BaseFeature.BaseFeature

return CorpseEsp
