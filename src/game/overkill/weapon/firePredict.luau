local ModuleController = require("@game/overkill/module/ModuleController")
local slotKeys = require("@game/overkill/weapon/slotKeys")

local firePredict = {}
firePredict.__index = firePredict

local _f32 = buffer.create(4)

local FIRE_LOOKAHEAD = 0.03

local clientModule: any = nil
local inputHandler: any = nil
local items: any = nil

function firePredict.estimateServerTime(): number
	if not clientModule then
		clientModule = ModuleController.GetModule("clientModule")
	end
	if not clientModule then
		return 0
	end
	local est = clientModule.estimatedServerTime or 0
	if type(clientModule.LocalTick) == "function" then
		est = clientModule:LocalTick() - (clientModule.estimatedServerTimeOffset or 0)
	end
	local worldState = clientModule.worldState
	local hz = worldState and (worldState.clientReplicationHz or worldState.serverHz)
	local pad = 0
	if type(clientModule.getInterpSearchPad) == "function" then
		pad = clientModule:getInterpSearchPad() or 0
	end
	local st = est
	if type(hz) == "number" and hz > 0 then
		st = est - (1 / hz + pad)
	end
	buffer.writef32(_f32, 0, st)
	return buffer.readf32(_f32, 0)
end

function firePredict.serverTimeNow(): number
	if not clientModule then
		clientModule = ModuleController.GetModule("clientModule")
	end
	if not clientModule then
		return 0
	end
	local est = clientModule.estimatedServerTime or 0
	if type(clientModule.LocalTick) == "function" then
		est = clientModule:LocalTick() - (clientModule.estimatedServerTimeOffset or 0)
	end
	return est
end

local function isFiring(): boolean
	if not inputHandler then
		inputHandler = ModuleController.GetModule("inputHandler")
	end
	if not inputHandler or type(inputHandler.IsPressed) ~= "function" then
		return false
	end
	return inputHandler:IsPressed("Shoot") == true
end

function firePredict.new(): FirePredict
	local self = setmetatable({
		_heldLast = false,
		_firePending = false,
		_lastFireSeen = -1,
	}, firePredict)
	return self :: any
end

function firePredict.reset(self: FirePredict): ()
	self._heldLast = false
	self._firePending = false
end

function firePredict.willFire(self: FirePredict, state: any): boolean
	if not isFiring() then
		self._heldLast = false
		self._firePending = false
		return false
	end
	local slot = state.equippedSlot or 1
	local keys = slotKeys[slot] or slotKeys[1]
	if not items then
		items = ModuleController.GetModule("items")
	end
	local weaponID = state[keys.weaponID]
	local firing = nil
	if items and items.all and weaponID ~= nil and weaponID ~= "" then
		local itemData = items.all[weaponID]
		firing = itemData and itemData.stats and itemData.stats.firing
	end
	local rate = (firing and firing.rate) or 0.1
	local lastFire = state[keys.lastFireServerTime] or 0
	if lastFire ~= self._lastFireSeen then
		self._lastFireSeen = lastFire
		self._firePending = false
	end
	local rateReady = (firePredict.serverTimeNow() - lastFire) >= rate - FIRE_LOOKAHEAD
	local mode = state[keys.mode] or "single"
	local canStart
	if mode == "single" then
		canStart = rateReady and not self._heldLast
	else
		canStart = rateReady
	end
	self._heldLast = true
	if canStart then
		local magCount = state[keys.magCount] or 0
		local reloading = (state[keys.reloadStartServerTime] or 0) ~= 0
		if magCount > 0 and not reloading then
			self._firePending = true
		end
	end
	return self._firePending
end


export type FirePredict = typeof(setmetatable(
	{} :: {
		_heldLast: boolean,
		_firePending: boolean,
		_lastFireSeen: number,
	},
	firePredict
))

return firePredict
