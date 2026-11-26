local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local NetworkController = require("@game/pf/network/NetworkController")
local localThirdPerson = require("@game/pf/thirdperson/localThirdPerson")

local HALF_PI = math.pi / 2
local TWO_OVER_PI = 2 / math.pi
local PITCH_UP = math.rad(85)
local PITCH_DOWN = -math.rad(85)
local TRAVEL_RANGE = math.rad(85)

local YAW_OPTIONS: { string } = { "Off", "Backward", "Left", "Right", "Spin" }
local PITCH_OPTIONS: { string } = { "Off", "Up", "Down", "Travel" }

local AntiAim = {}
AntiAim.__index = AntiAim

setmetatable(AntiAim, { __index = BaseFeature })

function AntiAim.new(link: gameUi.Linker): AntiAim
	local self = BaseFeature.new() :: any
	setmetatable(self, AntiAim)

	self._enabled = false
	self._unhook = nil :: (() -> ())?
	self._yawMode = "Backward"
	self._pitchMode = "Off"
	self._spinSpeed = 12
	self._travelSpeed = 4
	self._spinYaw = 0
	self._spinLast = 0

	link:Toggle("antiAim", "Anti Aim", false):SetTip({
		title = "Anti Aim",
		body = "Makes your character face a different direction than you are actually looking.",
	})
	link:Dropdown("pitch", "Pitch", PITCH_OPTIONS, "Off"):SetTip({
		title = "Pitch",
		body = "Up/down direction others see. Travel sweeps between up and down.",
	})
	link:Dropdown("yaw", "Yaw", YAW_OPTIONS, "Backward"):SetTip({
		title = "Yaw",
		body = "Left/right direction others see, relative to your aim. Spin rotates you.",
	})
	local antiAimLink = link:OnKey("antiAim")
	antiAimLink:Submenu("opts", "Anti Aim")
	local optsLink = antiAimLink:OnKey("opts")
	optsLink:Slider("spinSpeed", "Spin Speed", 12, 1, 30, 0.5, nil, "x"):SetTip({
		title = "Spin Speed",
		body = "How fast you spin when Yaw is set to Spin.",
	})
	optsLink:Slider("travelSpeed", "Travel Speed", 4, 0.5, 15, 0.5, nil, "x"):SetTip({
		title = "Travel Speed",
		body = "How fast your pitch sweeps when Pitch Travel is on.",
	})

	self._yawMode = link:Get("yaw"):Peek() or "Backward"
	self._pitchMode = link:Get("pitch"):Peek() or "Off"
	self._spinSpeed = link:Peek("antiAim.opts.spinSpeed") or 12
	self._travelSpeed = link:Peek("antiAim.opts.travelSpeed") or 4

	self:Track(link:Get("antiAim"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))
	self:Track(link:Get("yaw"):OnChange(function(value: string): ()
		if value == "Spin" and self._yawMode ~= "Spin" then
			self._spinYaw = 0
			self._spinLast = os.clock()
		end
		self._yawMode = value or "Off"
	end))
	self:Track(link:Get("pitch"):OnChange(function(value: string): ()
		self._pitchMode = value or "Off"
	end))
	self:Track(link:Watch("antiAim.opts.spinSpeed", function(value: number): ()
		self._spinSpeed = type(value) == "number" and value or 12
	end))
	self:Track(link:Watch("antiAim.opts.travelSpeed", function(value: number): ()
		self._travelSpeed = type(value) == "number" and value or 4
	end))

	if link:Peek("antiAim") then
		self:Enable()
	end

	return self
end

AntiAim._resolve = LPH_NO_VIRTUALIZE(function(self: AntiAim, lookAngles: Vector3): Vector3?
	local yawMode = self._yawMode
	local pitchMode = self._pitchMode
	if yawMode == "Off" and pitchMode == "Off" then
		return nil
	end

	local pitch = lookAngles.X
	local yaw = lookAngles.Y

	if yawMode == "Backward" then
		yaw += math.pi
	elseif yawMode == "Left" then
		yaw += HALF_PI
	elseif yawMode == "Right" then
		yaw -= HALF_PI
	elseif yawMode == "Spin" then
		local now = os.clock()
		yaw = self._spinYaw + (now - self._spinLast) * self._spinSpeed
		self._spinYaw = yaw
		self._spinLast = now
	end

	if pitchMode == "Up" then
		pitch = PITCH_UP
	elseif pitchMode == "Down" then
		pitch = PITCH_DOWN
	elseif pitchMode == "Travel" then
		pitch = TWO_OVER_PI * math.asin(math.sin(os.clock() * self._travelSpeed)) * TRAVEL_RANGE
	end

	return Vector3.new(pitch, yaw, 0)
end)

function AntiAim.Enable(self: AntiAim): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._spinYaw = 0
	self._spinLast = os.clock()

	localThirdPerson.setLookOverride(LPH_NO_VIRTUALIZE(function(angles: Vector3): Vector3?
		return self:_resolve(angles)
	end))

	self._unhook = NetworkController.HookOutbound(
		"repupdate",
		LPH_NO_VIRTUALIZE(function(position: any, lookAngles: any, _barrelAngles: any, time: any): (boolean?, { any }?)
			if typeof(lookAngles) ~= "Vector3" then
				return
			end
			local angles = self:_resolve(lookAngles)
			if not angles then
				return
			end
			return false, { position, angles, angles, time }
		end)
	)
end

function AntiAim.Disable(self: AntiAim): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	localThirdPerson.setLookOverride(nil)

	local unhook = self._unhook
	if unhook then
		unhook()
		self._unhook = nil
	end
end

function AntiAim.Destroy(self: AntiAim): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AntiAim =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_unhook: (() -> ())?,
			_yawMode: string,
			_pitchMode: string,
			_spinSpeed: number,
			_travelSpeed: number,
			_spinYaw: number,
			_spinLast: number,
			_resolve: (AntiAim, Vector3) -> Vector3?,
			Enable: (AntiAim) -> (),
			Disable: (AntiAim) -> (),
		},
		AntiAim
	))
	& BaseFeature.BaseFeature

return AntiAim
