local Charm = require("@pkg/Charm")
local viewmodelState = require("@game/rivals/viewmodel/viewmodelState")

local peek = Charm.peek

local chargeReader = {}

local function readCharge(vm: any): number?
	local item = rawget(vm, "ClientItem")
	local info = item and item.Info
	local timestamps = info and info.ChargeLevelTimestamps
	if type(timestamps) ~= "table" then
		return nil
	end
	local full = timestamps[#timestamps]
	if type(full) ~= "number" or full <= 0 then
		return nil
	end
	local itemInterface = rawget(item, "ItemInterface")
	local charge = itemInterface and rawget(itemInterface, "Charge")
	local startTime = charge and rawget(charge, "_start_time")
	if type(startTime) ~= "number" then
		return 0
	end
	return math.clamp((tick() - startTime) / full, 0, 1) * 100
end

chargeReader.sample = LPH_NO_VIRTUALIZE(function(): number?
	local vm = peek(viewmodelState._viewmodel)
	if type(vm) ~= "table" then
		return nil
	end
	return readCharge(vm)
end)

return chargeReader
