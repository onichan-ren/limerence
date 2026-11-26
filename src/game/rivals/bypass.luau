local hook = require("@share/hook")

local registry = getreg()

local LogService = cloneref(game:GetService("LogService"))
local ScriptContext = cloneref(game:GetService("ScriptContext"))

local rawInfo = clonefunction(debug.info)

local acNames = { "LocalScript3", "MiscellaneousController", "AnalyticsPipeline", "CameraSecurity" }

local function isAcCalling(): boolean
	for level = 2, 16 do
		local ok, source = pcall(rawInfo, level, "s")
		if ok and type(source) == "string" then
			for _, name in next, acNames do
				if string.find(source, name, 1, true) then
					return true
				end
			end
		end
	end
	return false
end

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
		if not closure then
			continue
		end

		closures[#closures + 1] = closure
	end

	if getgenv().bypassed then
		return closures
	end

	getgenv().bypassed = true

	local renv = getrenv()

	--[[local oldInfo
	oldInfo = oth.hook(renv.debug.info, function(a, b, ...)
		if not checkcaller() and type(a) == "function" and type(b) == "string" and isexecutorclosure(a) then
			local sIndex = string.find(b, "s", 1, true)
			if sIndex then
				local res = table.pack(oldInfo(a, b, ...))
				res[sIndex] = "MiscellaneousController"
				return table.unpack(res, 1, res.n)
			end
		end
		return oldInfo(a, b, ...)
	end)--]]

	LPH_NO_VIRTUALIZE(function()
		local oldSetmetatable
		oldSetmetatable = hook.oth(renv.setmetatable, function(target, metatable)
			if not checkcaller() and type(metatable) == "table" then
				local mode = rawget(metatable, "__mode")
				if (mode == "k" or mode == "v" or mode == "kv") and isAcCalling() then
					return oldSetmetatable({ 1, 2, 3 }, {})
				end
			end
			return oldSetmetatable(target, metatable)
		end)
	end)()

	return closures
end

return function(): ()
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
end
