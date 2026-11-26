local NetworkController = require("@game/ar2/network/NetworkController")

local STATE_REPORT = "Character State Report"
local STATE_SYNC = "Character State Sync"

local StateReport = {}

StateReport.Field = {
	ServerTime = 1,
	RunningInput = 2,
	CrouchingInput = 3,
	FirstPerson = 4,
	AtEase = 5,
	ShoulderSwapped = 6,
	Zooming = 7,
	Staggered = 8,
	Shoving = 9,
	LookDirection = 10,
	Position = 11,
	Velocity = 12,
	MoveVector = 13,
	LadderId = 14,
}

local _spoofers = {}
local _installed = false

local _syncOut: any = nil
local _n4Index: number? = nil
local _receiverRef: any = nil

local _currentPerm: { number } = {}
local _currentArgs: { any } = {}
local _overridesScratch: { [number]: any } = {}
local _outScratch: { any } = {}
local _orderScratch: { number } = {}

local resolve = LPH_NO_VIRTUALIZE(function(): boolean
	local receiver = NetworkController.getReceiver(STATE_SYNC)
	if not receiver then
		return false
	end
	if receiver == _receiverRef and _syncOut then
		return true
	end

	local ups = debug.getupvalues(receiver)
	if not ups then
		return false
	end

	for _, value in ups do
		if type(value) == "function" then
			local inner = debug.getupvalues(value)
			if inner then
				for index, innerValue in inner do
					if type(innerValue) == "number" then
						_syncOut = value
						_n4Index = index
						_receiverRef = receiver
						return true
					end
				end
			end
		end
	end

	return false
end)

local buildPerm = LPH_NO_VIRTUALIZE(function(seed: number, count: number): ()
	local slots = _currentPerm
	table.clear(slots)

	local order = _orderScratch
	table.clear(order)
	for i = 1, count do
		order[i] = i
	end

	local random = Random.new(seed)
	local remaining = count
	for position = 1, count do
		local pick = random:NextInteger(1, remaining)
		slots[order[pick]] = position
		table.remove(order, pick)
		remaining -= 1
	end
end)

function StateReport.get(field: number): any
	return _currentArgs[_currentPerm[field]]
end

local managerHook = LPH_NO_VIRTUALIZE(function(...): ...any
	if not resolve() then
		return
	end

	local seed = debug.getupvalue(_syncOut, _n4Index)
	if type(seed) ~= "number" then
		return
	end

	local count = select("#", ...)
	buildPerm(seed, count)

	local args = _currentArgs
	for i = 1, count do
		args[i] = select(i, ...)
	end

	local overrides = _overridesScratch
	table.clear(overrides)
	for i = 1, #_spoofers do
		_spoofers[i](overrides)
	end

	local field = next(overrides)
	if field == nil then
		return
	end

	local out = _outScratch
	table.clear(out)
	local maxPos = 0
	while field ~= nil do
		local pos = _currentPerm[field]
		out[pos] = overrides[field]
		if pos > maxPos then
			maxPos = pos
		end
		field = next(overrides, field)
	end

	return table.unpack(out, 1, maxPos)
end)

function StateReport.register(spoofer: (overrides: { [number]: any }) -> ()): ()
	for i = 1, #_spoofers do
		if _spoofers[i] == spoofer then
			return
		end
	end
	table.insert(_spoofers, spoofer)

	if not _installed then
		NetworkController.hookSend(STATE_REPORT, managerHook)
		_installed = true
	end
end

function StateReport.unregister(spoofer: (overrides: { [number]: any }) -> ()): ()
	for i = #_spoofers, 1, -1 do
		if _spoofers[i] == spoofer then
			table.remove(_spoofers, i)
		end
	end

	if #_spoofers == 0 and _installed then
		NetworkController.restoreSend(STATE_REPORT, managerHook)
		_installed = false
	end
end

return StateReport
