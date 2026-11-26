local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local NetworkController = require("@game/ar2/network/NetworkController")

local SWING_PACKET = "Melee Swing"
local HIT_PACKET = "Melee Hit Register"
local MAX_SHIFT = 0.2
local SPACING = 1 / 30

local BurstMelee = {}
BurstMelee.__index = BurstMelee

setmetatable(BurstMelee, { __index = BaseFeature })

function BurstMelee.new(link: gameUi.Linker): BurstMelee
	local self = BaseFeature.new() :: any
	setmetatable(self, BurstMelee)

	self._enabled = false
	self._queue = {} :: { any }
	self._flushScheduled = false
	self._shiftBudget = 0
	self._shiftClock = nil :: number?
	self._lastSwing = nil :: any

	self._onSwing = function(serverTime, itemId, combo): ()
		if not self._enabled then
			return
		end
		self._lastSwing = { serverTime = serverTime, itemId = itemId, combo = combo }
	end

	self._onHit = function(itemId, serverTime, ray, part, encoded): ()
		if not self._enabled or typeof(encoded) ~= "Vector3" or type(serverTime) ~= "number" then
			return
		end
		local queue = self._queue
		queue[#queue + 1] = {
			itemId = itemId,
			serverTime = serverTime,
			ray = ray,
			part = part,
			encoded = encoded,
		}
		self:_schedule()
	end

	link:Toggle("burstMelee", "Burst Melee", false):SetTip({
		title = "Burst Melee",
		body = "Lands several melee hits at once each time you swing.",
	})

	self:Track(link:Get("burstMelee"):OnChange(function(value: boolean): ()
		self:_setActive(value == true)
	end))

	if link:Peek("burstMelee") == true then
		self:_setActive(true)
	end

	return self
end

function BurstMelee._setActive(self: BurstMelee, active: boolean): ()
	if self._enabled == active then
		return
	end
	self._enabled = active
	if active then
		self._shiftBudget = MAX_SHIFT
		self._shiftClock = os.clock()
		NetworkController.hookSend(SWING_PACKET, self._onSwing)
		NetworkController.hookSend(HIT_PACKET, self._onHit)
	else
		NetworkController.restoreSend(SWING_PACKET, self._onSwing)
		NetworkController.restoreSend(HIT_PACKET, self._onHit)
		table.clear(self._queue)
		self._lastSwing = nil
	end
end

function BurstMelee._schedule(self: BurstMelee): ()
	if self._flushScheduled then
		return
	end
	self._flushScheduled = true
	task.defer(function(): ()
		self:_flush()
	end)
end

BurstMelee._flush = LPH_NO_VIRTUALIZE(function(self: BurstMelee): ()
	self._flushScheduled = false
	local queue = self._queue
	self._queue = {}

	if not self._enabled then
		return
	end

	local count = #queue
	if count == 0 then
		return
	end

	local nowClock = os.clock()
	local lastClock = self._shiftClock or nowClock
	self._shiftBudget = math.min(MAX_SHIFT, self._shiftBudget + (nowClock - lastClock))
	self._shiftClock = nowClock

	local extra = math.floor(self._shiftBudget / SPACING)
	if extra <= 0 then
		return
	end
	self._shiftBudget -= extra * SPACING

	local swing = self._lastSwing
	local baseTime = swing and swing.serverTime or queue[1].serverTime

	setthreadidentity(2)
	for k = extra, 1, -1 do
		local newTime = baseTime - k * SPACING

		if swing then
			NetworkController.sendRaw(SWING_PACKET, newTime, swing.itemId, swing.combo)
		end

		for i = 1, count do
			local hit = queue[i]
			local scale = newTime / hit.serverTime
			local encoded = hit.encoded
			NetworkController.sendRaw(
				HIT_PACKET,
				hit.itemId,
				newTime,
				hit.ray,
				hit.part,
				Vector3.new(encoded.X * scale, encoded.Y * scale, encoded.Z * scale)
			)
		end
	end
	setthreadidentity(8)
end)

function BurstMelee.Destroy(self: BurstMelee): ()
	self:_setActive(false)
	BaseFeature.Destroy(self)
end

export type BurstMelee =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_queue: { any },
			_flushScheduled: boolean,
			_shiftBudget: number,
			_shiftClock: number?,
			_lastSwing: any,
			_onSwing: (...any) -> (),
			_onHit: (...any) -> (),
			_setActive: (BurstMelee, boolean) -> (),
			_schedule: (BurstMelee) -> (),
			_flush: (BurstMelee) -> (),
		},
		BurstMelee
	))
	& BaseFeature.BaseFeature

return BurstMelee
