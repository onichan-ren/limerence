local registry = getreg()

local LogService = cloneref(game:GetService("LogService"))
local ScriptContext = cloneref(game:GetService("ScriptContext"))

local function getReplacements(): { [number]: (...any) -> () }
	local closures = {}

	for _, data in next, getconnections(LogService.MessageOut) do
		local closure = data.Function
		if not closure then
			continue
		end

		closures[#closures + 1] = closure
	end

	for _, data in next, getconnections(ScriptContext.Error) do
		local closure = data.Function
		if closure then
			closures[#closures + 1] = closure
		end

		data:Disconnect()
	end

	if not LPH_OBFUSCATED then
		if getgenv().bypassed then
			return closures
		end

		getgenv().bypassed = true
	end

	return closures
end

return LPH_JIT_MAX(function(): ()
	local registryReplacements = getReplacements()
	local replacementSet: { [(...any) -> ()]: true } = {}
	for i = 1, #registryReplacements do
		replacementSet[registryReplacements[i]] = true
	end

	for idx, closure in next, registry do
		if replacementSet[closure] then
			registry[idx] = function() end
		end
	end
end)
