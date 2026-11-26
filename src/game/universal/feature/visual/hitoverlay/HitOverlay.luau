local RunService = cloneref(game:GetService("RunService")) :: RunService
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Signal = require("@pkg/Signal")
local instances = require("@share/instances")
local FileController = require("@feature/file/FileController")
local Ripple = require("@pkg/Ripple")

local DEFAULT_HIT = Color3.fromRGB(225, 225, 225)
local DEFAULT_HEADSHOT = Color3.fromRGB(220, 95, 95)
local FADE_DURATION = 0.12

export type HitOverlayOpts = {
	connect: (emit: (headshot: boolean) -> ()) -> Signal.Connection,
	onActive: ((active: boolean) -> ())?,
}

local HitOverlay = {}
HitOverlay.__index = HitOverlay

setmetatable(HitOverlay, { __index = BaseFeature })

function HitOverlay.new(link: gameUi.Linker, opts: HitOverlayOpts): HitOverlay
	local self = BaseFeature.new() :: any
	setmetatable(self, HitOverlay)

	self._connect = opts.connect
	self._onActive = opts.onActive

	local toggle = link:Toggle("hitOverlay", "Hit Overlay", false):SetTip({
		title = "Hit Overlay",
		body = "Shows an on-screen overlay when you hit someone.",
	})
	link:Extra(toggle, "options", "Submenu", "Hit Overlay Options")
	local optionsLink = link:OnKey("options")
	optionsLink:Colorpicker("headshotColor", "Headshot Color", DEFAULT_HEADSHOT, 0):SetTip({
		title = "Headshot Color",
		body = "Color for headshot hits.",
	})
	optionsLink:Colorpicker("hitColor", "Hit Color", DEFAULT_HIT, 0):SetTip({
		title = "Hit Color",
		body = "Color for body hits.",
	})

	self._janitor = Janitor.new()

	self:Track(toggle:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optionsLink:Get("headshotColor"):OnColorChange(function(color: Color3): ()
		self._headshotColor = color
	end))
	self:Track(optionsLink:Get("hitColor"):OnColorChange(function(color: Color3): ()
		self._hitColor = color
	end))
	self:Track(optionsLink:Get("headshotColor"):OnTransparencyChange(function(transparency: number): ()
		self._headshotTransparency = transparency
	end))
	self:Track(optionsLink:Get("hitColor"):OnTransparencyChange(function(transparency: number): ()
		self._hitTransparency = transparency
	end))

	self._headshotColor = optionsLink:Get("headshotColor"):PeekColor()
	self._hitColor = optionsLink:Get("hitColor"):PeekColor()
	self._headshotTransparency = optionsLink:Get("headshotColor"):PeekTransparency()
	self._hitTransparency = optionsLink:Get("hitColor"):PeekTransparency()

	if toggle:Peek() then
		self:Enable()
	end

	return self
end

function HitOverlay._createOverlay(self: HitOverlay, headshot: boolean): ()
	local color = headshot and self._headshotColor or self._hitColor
	local transparency = headshot and self._headshotTransparency or self._hitTransparency

	local overlay = instances.newSimple("ImageLabel", {
		Parent = self._screenGui,
		Image = FileController.Get("image", "screen_overlay"),
		ImageColor3 = color,
		ImageTransparency = transparency,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Stretch,
		Visible = true,
	})

	local spring = Ripple.createSpring(0, {
		tension = 550,
		friction = 45,
		start = true,
		precision = 0.01,
	})

	local overlayIndex = {}
	local springIndex = {}
	self._janitor:Add(overlay, "Destroy", overlayIndex)
	self._janitor:Add(function()
		spring:destroy()
	end, true, springIndex)

	spring:onChange(LPH_NO_VIRTUALIZE(function(value: number, _dt: number): ()
		local newTransparency = 1 - (1 - transparency) * value
		overlay.ImageTransparency = newTransparency
	end))
	spring:onComplete(function(): ()
		local fadeStart = os.clock()
		local fadeConn: RBXScriptConnection?
		fadeConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
			local t = math.min((os.clock() - fadeStart) / FADE_DURATION, 1)
			local eased = t * t * (3 - 2 * t)
			overlay.ImageTransparency = transparency + (1 - transparency) * eased
			if t >= 1 then
				if fadeConn then
					fadeConn:Disconnect()
					fadeConn = nil
				end
				self._janitor:Remove(springIndex)
				self._janitor:Remove(overlayIndex)
			end
		end))
	end)
	spring:setGoal(1)
end

function HitOverlay.Enable(self: HitOverlay): ()
	if self._enabled then
		return
	end
	self._enabled = true

	if self._onActive then
		self._onActive(true)
	end

	local screenGui = instances.newSimple("ScreenGui", {
		Parent = cloneref(gethui()),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		DisplayOrder = 1000,
		IgnoreGuiInset = true,
		Enabled = true,
	})
	self._screenGui = screenGui

	self._janitor:Add(
		self._connect(LPH_NO_VIRTUALIZE(function(headshot: boolean): ()
			self:_createOverlay(headshot)
		end)),
		"Disconnect"
	)

	self._janitor:Add(screenGui, "Destroy")
end

function HitOverlay.Disable(self: HitOverlay): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	if self._onActive then
		self._onActive(false)
	end
	self._janitor:Cleanup()
end

function HitOverlay.Destroy(self: HitOverlay): ()
	self:Disable()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type HitOverlay =
	typeof(setmetatable(
		{} :: {
			_connect: (emit: (headshot: boolean) -> ()) -> Signal.Connection,
			_onActive: ((active: boolean) -> ())?,
			_janitor: Janitor.Janitor,
			_screenGui: Instance,
			_enabled: boolean,
			_headshotColor: Color3,
			_hitColor: Color3,
			_headshotTransparency: number,
			_hitTransparency: number,
		},
		HitOverlay
	))
	& BaseFeature.BaseFeature

return HitOverlay
