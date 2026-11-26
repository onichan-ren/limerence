local NetworkController = require("@game/bloxstrike/network/NetworkController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")

local PACKET_TYPE = "Player"
local PACKET_NAME = "ReportPlayerConnect"

local PingSpoofer = {}
PingSpoofer.__index = PingSpoofer

setmetatable(PingSpoofer, { __index = BaseFeature })

function PingSpoofer.new(link: gameUi.Linker): PingSpoofer
	local self = BaseFeature.new() :: any
	setmetatable(self, PingSpoofer)

	link:Toggle("pingSpoofer", "Ping Spoofer", false):SetTip({
		title = "Ping Spoofer",
		body = "Raises your reported ping by a set amount.",
	})
	local pingLink = link:OnKey("pingSpoofer")
	pingLink:Submenu("opts", "Ping Spoofer")
	local optionsLink = pingLink:OnKey("opts")
	optionsLink:Slider("delay", "Added Delay", 200, 0, 1000, 5, nil, "ms"):SetTip({
		title = "Added Delay",
		body = "Milliseconds added on top of your real ping.",
	})

	self._delay = 200

	self:Track(link:Get("pingSpoofer"):OnChange(function(value: boolean): ()
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("pingSpoofer.opts.delay", function(value: number): ()
		self._delay = value
	end))

	if link:Peek("pingSpoofer") then
		self:_setEnabled(true)
	end

	return self
end

function PingSpoofer._setEnabled(self: PingSpoofer, enabled: boolean): ()
	if enabled then
		if self._enabled then
			return
		end
		self._enabled = true

		NetworkController.HookPacket(PACKET_TYPE, PACKET_NAME, function(value: string): (boolean, string)
			local real = tonumber(value) or 0
			return false, tostring(math.floor(real + self._delay))
		end)
	else
		if not self._enabled then
			return
		end
		self._enabled = false

		NetworkController.UnhookPacket(PACKET_TYPE, PACKET_NAME)
	end
end

function PingSpoofer.Destroy(self: PingSpoofer): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type PingSpoofer =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_delay: number,
		},
		PingSpoofer
	))
	& BaseFeature.BaseFeature

return PingSpoofer
