local loader = require("@loader/loader")
local logger = require("@share/logger").new("hook")

local hook = {}

local hooks: { (...any) -> any } = {}
local instanceHooks: {
	[Instance]: {
		originalMetamethod: any,
		originalIndex: any,
		blockedProperties: { [string]: boolean },
		originalProperties: { [string]: any },
		overriddenProperties: { [string]: (value: any, caller: LocalScript?) -> any },
		spoofedProperties: { [string]: any },
	},
} =
	{}
local othHooks: { (...any) -> any } = {}

function hook.new(): () end

function hook.isFunctionHooked(target: (...any) -> any): boolean
	return isfunctionhooked(target)
end

function hook.add(target: (...any) -> any, replacement: (...any) -> any): (...any) -> any
	if _G.DEBUG then
		local info = debug.getinfo(target :: any)
		logger:debug("adding function hook to:", info.name, "short_src:", info.short_src)
	end

	local original = hookfunction(target, replacement)
	hooks[#hooks + 1] = target
	return original
end

function hook.oth(target: (...any) -> any, replacement: (...any) -> any): (...any) -> any
	if _G.DEBUG then
		local info = debug.getinfo(target :: any)
		logger:debug("adding oth hook to:", info.name, "short_src:", info.short_src)
	end

	local original = oth.hook(target, replacement)
	othHooks[#othHooks + 1] = target
	return original
end

function hook.restore(target: (...any) -> any): ()
	for index = #hooks, 1, -1 do
		if hooks[index] == target then
			pcall(restorefunction, target :: any)
			local last = #hooks
			hooks[index] = hooks[last]
			hooks[last] = nil
			return
		end
	end
end

function hook.restoreOth(target: (...any) -> any): ()
	for index = #othHooks, 1, -1 do
		if othHooks[index] == target then
			pcall(oth.unhook, target :: any)
			local last = #othHooks
			othHooks[index] = othHooks[last]
			othHooks[last] = nil
			return
		end
	end
end

function hook.restoreAll(): ()
	for index = #hooks, 1, -1 do
		local target = hooks[index]
		hooks[index] = nil
		pcall(restorefunction, target :: any)
	end

	for target in next, instanceHooks do
		hook.restoreInstance(target)
	end

	for index = #othHooks, 1, -1 do
		local target = othHooks[index]
		othHooks[index] = nil
		pcall(oth.unhook, target :: any)
	end
end

function hook.restoreInstance(target: any): ()
	local instanceHook = instanceHooks[target]
	if not instanceHook then
		return
	end

	logger:debug("restoring instance:", target)

	setrawmetatable(target, instanceHook.originalMetamethod)
	local originalProperties = instanceHook.originalProperties
	for property, value in next, originalProperties do
		target[property] = value
	end
	instanceHooks[target] = nil
end

hook.addInstance = function(target: Instance)
	if not target or instanceHooks[target] then
		return
	end

	local originalMetamethod = getrawmetatable(target) :: any
	if not originalMetamethod then
		logger:warn("missing metatable for instance:", target)
		return
	end

	logger:debug("hooking instance:", target)
	local originalNamecall = originalMetamethod.__namecall
	local originalNewindex = originalMetamethod.__newindex
	local originalIndex = originalMetamethod.__index

	local overriddenProperties = {}
	local overriddenMethods = {}
	local originalProperties = {}
	local blockedProperties = {}
	local spoofedProperties = {}
	local instanceHook = {
		originalProperties = originalProperties,
		blockedProperties = blockedProperties,
		overriddenProperties = overriddenProperties,
		overriddenMethods = overriddenMethods,
		spoofedProperties = spoofedProperties,
		originalMetamethod = originalMetamethod,
		originalIndex = originalIndex,
	}
	instanceHooks[target] = instanceHook

	local newMetamethod = {
		__index = newcclosure(LPH_NO_VIRTUALIZE(function(self, key)
			if not checkcaller() then
				local spoofed = spoofedProperties[key]
				if spoofed ~= nil then
					return spoofed
				end
				if blockedProperties[key] or overriddenProperties[key] then
					return originalProperties[key]
				end
				local methodCallback = overriddenMethods[key]
				if methodCallback then
					local originalMethod = originalIndex(self, key)
					return newcclosure(LPH_NO_VIRTUALIZE(function(s, ...)
						setthreadidentity(8)
						local results = table.pack(methodCallback(...))
						setthreadidentity(2)
						if results.n == 0 then
							return
						end
						return originalMethod(s, table.unpack(results, 1, results.n))
					end))
				end
			end
			return originalIndex(self, key)
		end)),
		__newindex = newcclosure(LPH_NO_VIRTUALIZE(function(self, key, value)
			if not checkcaller() then
				if blockedProperties[key] then
					originalProperties[key] = value
					return
				end

				local callback = overriddenProperties[key]
				if callback then
					originalProperties[key] = value

					setthreadidentity(8)
					local newValue = callback(value, getcallingscript() :: LocalScript?)
					setthreadidentity(2)
					if newValue == -1 then
						return
					end

					return originalNewindex(self, key, newValue)
				end
			end
			return originalNewindex(self, key, value)
		end)),
		__namecall = newcclosure(LPH_NO_VIRTUALIZE(function(self, ...)
			if next(overriddenMethods) == nil then
				return originalNamecall(self, ...)
			end
			local method = getnamecallmethod()
			local callback = overriddenMethods[method]
			if callback then
				setthreadidentity(8)
				local results = table.pack(callback(...))
				setthreadidentity(2)
				if results.n == 0 then
					return
				end
				setnamecallmethod(method)
				return originalNamecall(self, table.unpack(results, 1, results.n))
			end
			return originalNamecall(self, ...)
		end)),
	}

	for method, closure in next, originalMetamethod do
		if not newMetamethod[method] then
			newMetamethod[method] = closure
		end
	end

	setrawmetatable(target, newMetamethod)
end

function hook.blockProperty(target: Instance, property: string): ()
	local instanceHook = instanceHooks[target]
	if not instanceHook then
		return
	end

	logger:debug("blocking property:", property, "on instance:", target)

	local ok, currentValue = pcall(function()
		return instanceHook.originalIndex(target, property)
	end)
	if ok and currentValue ~= nil then
		instanceHook.originalProperties[property] = currentValue
	end
	instanceHook.blockedProperties[property] = true
end

function hook.overrideMethod(target: Instance, method: string, callback: (...any) -> any): ()
	local instanceHook = instanceHooks[target]
	if not instanceHook then
		return
	end

	logger:debug("override method:", method, "on instance:", target)

	instanceHook.overriddenMethods[method] = callback
end

function hook.restoreMethod(target: Instance, method: string): ()
	local instanceHook = instanceHooks[target]
	if not instanceHook then
		return
	end

	logger:debug("restoring method:", method, "on instance:", target)

	instanceHook.overriddenMethods[method] = nil
end

function hook.unblockProperty(target: any, property: string): ()
	local instanceHook = instanceHooks[target]
	if not instanceHook then
		return
	end

	logger:debug("ublocking property:", property, "on instance:", target)

	instanceHook.blockedProperties[property] = nil

	local originalValue = instanceHook.originalProperties[property]
	if originalValue ~= nil then
		target[property] = originalValue :: any
	end
end

function hook.setProperty(target: Instance, property: string, value: any): ()
	if value == nil then
		return
	end

	logger:debug("setting property:", property, "with value:", value, "on instance:", target)

	local instanceHook = instanceHooks[target]
	if not instanceHook then
		local instance = target :: any
		instance[property] = value
		return
	end

	instanceHook.originalMetamethod.__newindex(target, property, value)
end

function hook.getProperty(target: Instance, property: string): any
	local instanceHook = instanceHooks[target]
	if not instanceHook then
		return (target :: any)[property]
	end
	return instanceHook.originalIndex(target, property)
end

function hook.restoreProperty(target: Instance, property: string): ()
	local instanceHook = instanceHooks[target]
	if not instanceHook then
		return
	end

	logger:debug("restoring property:", property, "on instance:", target)

	instanceHook.overriddenProperties[property] = nil
end

function hook.overrideProperty(
	target: Instance,
	property: string,
	callback: (value: any, caller: LocalScript?) -> any
): ()
	local instanceHook = instanceHooks[target]
	if not instanceHook then
		return
	end

	logger:debug("overriding property:", property, "on instance:", target)

	instanceHook.originalProperties[property] = (target :: any)[property]
	instanceHook.overriddenProperties[property] = callback
end

function hook.spoofProperty(target: Instance, property: string, value: any): ()
	local instanceHook = instanceHooks[target]
	if not instanceHook then
		return
	end

	logger:debug("spoofing property:", property, "with value: ", value, "on instance: ", target)

	instanceHook.spoofedProperties[property] = value
end

function hook.unspoofProperty(target: Instance, property: string): ()
	local instanceHook = instanceHooks[target]
	if not instanceHook then
		return
	end

	logger:debug("unspoofing property:", property, "on instance:", target)

	instanceHook.spoofedProperties[property] = nil
end

function hook.Destroy(): ()
	hook.restoreAll()
end

return hook
