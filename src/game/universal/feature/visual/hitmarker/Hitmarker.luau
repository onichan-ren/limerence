local BaseFeature = require("@game/BaseFeature")
local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local hitmarkerView = require("@game/universal/feature/visual/hitmarker/hitmarkerView")

local e = React.createElement

local DEFAULT_HIT = Color3.fromRGB(225, 225, 225)
local DEFAULT_HEADSHOT = Color3.fromRGB(220, 95, 95)
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)

export type Pulse = { seq: number, headshot: boolean }

export type HitmarkerOpts = {
	connect: (emit: (headshot: boolean) -> ()) -> Signal.Connection,
	onActive: ((active: boolean) -> ())?,
	body: string?,
	headshotBody: string?,
}

local Hitmarker = {}
Hitmarker.__index = Hitmarker

setmetatable(Hitmarker, { __index = BaseFeature })

function Hitmarker.new(link: gameUi.Linker, opts: HitmarkerOpts): Hitmarker
	local self = BaseFeature.new() :: any
	setmetatable(self, Hitmarker)

	self._connect = opts.connect
	self._onActive = opts.onActive

	link:Toggle("hitmarker", "Hit Marker", false):SetTip({
		title = "Hit Marker",
		body = opts.body or "Shows an on-screen X when your shots register on a player.",
	})
	local rootLink = link:OnKey("hitmarker")
	rootLink:Submenu("opts", "Hit Marker")
	local optsLink = rootLink:OnKey("opts")
	optsLink:Colorpicker("hitColor", "Hit", DEFAULT_HIT, 0):SetTip({
		title = "Hit",
		body = "Color for body hits.",
	})
	optsLink:Colorpicker("headshotColor", "Headshot", DEFAULT_HEADSHOT, 0):SetTip({
		title = "Headshot",
		body = opts.headshotBody or "Color when the hit part is the head.",
	})
	optsLink:Colorpicker("outlineColor", "Outline", DEFAULT_OUTLINE, 0):SetTip({
		title = "Outline",
		body = "Color and transparency of the marker outline.",
	})
	optsLink:Slider("thickness", "Thickness", 2, 1, 6, 1):SetTip({
		title = "Thickness",
		body = "Width of the hit marker arms.",
	})

	self._weaponConn = nil :: RBXScriptConnection?
	self._pulse = Charm.atom({ seq = 0, headshot = false } :: Pulse)
	self._enabledLink = link:Get("hitmarker")
	self._hitColorLink = link:Get("hitmarker.opts.hitColor")
	self._headshotColorLink = link:Get("hitmarker.opts.headshotColor")
	self._outlineColorLink = link:Get("hitmarker.opts.outlineColor")
	self._thicknessLink = link:Get("hitmarker.opts.thickness")

	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = 20,
	}, cloneref(gethui()))
	self._screenGui = screenGui

	self._root = ReactRoblox.createRoot(screenGui)
	self._root:render(e(hitmarkerView, {
		pulseAtom = self._pulse,
		enabledLink = self._enabledLink,
		hitColorLink = self._hitColorLink,
		headshotColorLink = self._headshotColorLink,
		outlineColorLink = self._outlineColorLink,
		thicknessLink = self._thicknessLink,
	}))

	self:Track(self._enabledLink:OnChange(function(on: boolean): ()
		self:_setListening(on)
	end))

	if link:Peek("hitmarker") then
		self:_setListening(true)
	end

	return self
end

function Hitmarker._setListening(self: Hitmarker, on: boolean): ()
	if self._weaponConn then
		self._weaponConn:Disconnect()
		self._weaponConn = nil
	end
	if self._onActive then
		self._onActive(on)
	end
	if not on then
		return
	end
	self._weaponConn = self._connect(function(headshot: boolean): ()
		self._pulse(function(s: Pulse): Pulse
			return { seq = s.seq + 1, headshot = headshot }
		end)
	end)
end

function Hitmarker.Destroy(self: Hitmarker): ()
	self:_setListening(false)
	self._root:unmount()
	self._screenGui:Destroy()
	BaseFeature.Destroy(self)
end

export type Hitmarker =
	typeof(setmetatable(
		{} :: {
			_connect: (emit: (headshot: boolean) -> ()) -> Signal.Connection,
			_onActive: ((active: boolean) -> ())?,
			_weaponConn: Signal.Connection?,
			_pulse: Charm.Atom<Pulse>,
			_enabledLink: any,
			_hitColorLink: any,
			_headshotColorLink: any,
			_outlineColorLink: any,
			_thicknessLink: any,
			_root: ReactRoblox.RootType,
			_screenGui: Instance,
		},
		Hitmarker
	))
	& BaseFeature.BaseFeature

return Hitmarker
