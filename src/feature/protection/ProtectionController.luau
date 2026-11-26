local protectionFlags = require("@feature/protection/ProtectionFlags")

local getRawMetatable = getrawmetatable
local setRawMetatable = setrawmetatable
local coroutineResume = coroutine.resume
local coroutineCreate = coroutine.create
local coroutineStatus = coroutine.status
local coroutineClose = coroutine.close
local coroutineWrap = coroutine.wrap
local taskSpawn = task.spawn
local taskDelay = task.delay
local delFolder = delfolder
local taskWait = task.wait
local osClock = os.clock
local pcall = pcall

local ProtectionController = {
	_detectionFunctions = {},
}
local detectionFunctions = ProtectionController._detectionFunctions

local detectionCount = 0
local isEnabled = nil :: any

function ProtectionController.new()
	isEnabled = 1

	local addDetection = ProtectionController.addDetection
	local flag = ProtectionController.Flag
	for _, detectionData in next, protectionFlags do
		local isThread = detectionData.thread
		local detection = detectionData.detection

		if not isThread then
			taskSpawn(detection, flag)
		else
			addDetection(detection)
		end
	end

	addDetection(function()
		while true do
			for i = 1, detectionCount do
				local thread = detectionFunctions[i]
				if not thread then
					flag("coroutine fail " .. i)
					break
				end
			end
			taskWait(1)
		end
	end)

	return ProtectionController
end

function ProtectionController.Destroy(): ()
	isEnabled = nil
	for i = 1, detectionCount do
		local thread = detectionFunctions[i]
		pcall(coroutineClose, thread)
		detectionFunctions[i] = nil
	end
end

function ProtectionController.Flag(flagData: string): ()
	if not isEnabled then
		return
	end

	if LPH_OBFUSCATED then
		LP_BLACKLIST("tampering")
	else
		warn(`protection flagged: {flagData}`)
	end
end

function ProtectionController.addDetection(detectionFunction: (flag: (flagData: string) -> ()) -> ()): ()
	local thread = coroutineCreate(function()
		detectionFunction(ProtectionController.Flag)
	end)

	coroutineResume(thread)
	detectionFunctions[#detectionFunctions + 1] = thread
	detectionCount += 1
end

return ProtectionController
