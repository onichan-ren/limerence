local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local Charm = require("@pkg/Charm")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local binTracker = require("@game/ar2/feature/visuals/world/binTracker")
local worldEspState = require("@game/ar2/feature/visuals/world/worldEspState")
local worldIndicatorRenderer = require("@game/ar2/feature/visuals/world/worldIndicatorRenderer")
local clientState = require("@game/ar2/client/clientState")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local subscribeToBinding = (React :: any).__subscribeToBinding

local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement

local BIN_NAME = "Vehicles"
local DISTANCE_STEP = 0.25

local DEFAULT_COLOR = Color3.fromRGB(145, 190, 215)
local DEFAULT_FILL_COLOR = Color3.fromRGB(145, 190, 215)
local DEFAULT_OUTLINE_COLOR = Color3.fromRGB(225, 225, 225)

local DISPLAY_ORDER = 15

local VehicleEsp = {}
VehicleEsp.__index = VehicleEsp

setmetatable(VehicleEsp, { __index = BaseFeature })

function VehicleEsp.new(link: gameUi.Linker): VehicleEsp
	local self = BaseFeature.new() :: any
	setmetatable(self, VehicleEsp)

	local toggle = link:Toggle("vehicleEsp", "Vehicle ESP", false):SetTip({
		title = "Vehicle ESP",
		body = "On-screen markers over vehicles with their name and distance.",
	})
	local vehicleLink = link:OnKey("vehicleEsp")
	vehicleLink:Extra(toggle, "color", "Colorpicker", "Color", DEFAULT_COLOR)
	vehicleLink:Extra(toggle, "opts", "Submenu", "Vehicle ESP Options")
	local optsLink = vehicleLink:OnKey("opts")
	optsLink:Slider("maxDistance", "Max Distance", 1000, 100, 3000, 50, nil, "st"):SetTip({
		title = "Max Distance",
		body = "Hides markers past this distance.",
	})
	optsLink:Toggle("showDistance", "Show Distance", true):SetTip({
		title = "Show Distance",
		body = "Shows how far away each vehicle is.",
	})

	local highlightToggle = optsLink:Toggle("highlight", "Highlight Vehicles", false):SetTip({
		title = "Highlight",
		body = "Outline each vehicle through walls.",
	})
	optsLink:Extra(highlightToggle, "highlightOpts", "Submenu", "Highlight Options")
	local highlightOptsLink = optsLink:OnKey("highlightOpts")
	highlightOptsLink:Colorpicker("fillColor", "Fill Color", DEFAULT_FILL_COLOR, 0.5)
	highlightOptsLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE_COLOR, 0)

	self._enabledLink = link:Get("vehicleEsp")
	self._maxDistanceLink = optsLink:Get("maxDistance")
	self._highlightToggleLink = optsLink:Get("highlight")
	self._fillColorLink = highlightOptsLink:Get("fillColor")
	self._outlineColorLink = highlightOptsLink:Get("outlineColor")

	self._highlights = {} :: { [Model]: Highlight }
	self._distanceConn = nil :: RBXScriptConnection?

	self._trackerJanitor = binTracker.track(BIN_NAME, worldEspState.vehicles, function(model: Model): string
		return string.upper(model.Name)
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
		colorLink = vehicleLink:Get("color"),
		maxDistanceLink = optsLink:Get("maxDistance"),
		showDistanceLink = optsLink:Get("showDistance"),
		entries = worldEspState.vehicles,
		excludeAtom = clientState.vehicle,
	}))

	self:Track(sub(worldEspState.vehicles, function(): ()
		self:_refreshHighlights()
	end))
	self:Track(sub(clientState.vehicle, function(): ()
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

function VehicleEsp._applyHighlightColors(self: VehicleEsp): ()
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

function VehicleEsp._stepHighlightDistance(self: VehicleEsp): ()
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

function VehicleEsp._syncDistanceLoop(self: VehicleEsp): ()
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

function VehicleEsp._refreshHighlights(self: VehicleEsp): ()
	local enabled = peek(self._enabledLink._state) == true
	local highlightOn = peek(self._highlightToggleLink._state) == true
	local entries = peek(worldEspState.vehicles)
	local ownVehicle = peek(clientState.vehicle)

	for model, hl in next, self._highlights do
		if not entries[model] or model == ownVehicle or not enabled or not highlightOn then
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
		if model ~= ownVehicle and not self._highlights[model] then
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

function VehicleEsp.Destroy(self: VehicleEsp): ()
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

export type VehicleEsp =
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
		VehicleEsp
	))
	& BaseFeature.BaseFeature

return VehicleEsp
