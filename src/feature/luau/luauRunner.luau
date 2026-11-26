local luauRunner = {}

local getGenv = getgenv
local getRenv = getrenv
local typeOf = typeof
local stringSub = string.sub
local rawSet = rawset
local setMetatable = setmetatable
local realLoadstring = loadstring
local realPcall = pcall

local realHookMetamethod = hookmetamethod
local realGetRawMetatable = getrawmetatable
local realSetRawMetatable = setrawmetatable
local realSetReadonly = setreadonly
local realGetfenv = getfenv
local realSetfenv = setfenv
local realGetGc = getgc
local realGetReg = getreg

-- real C functions we wrap; must never leak back to the script
local protectedOriginals: { [any]: boolean } = {}
local function protect(fn: any): ()
	if fn then
		protectedOriginals[fn] = true
	end
end
protect(realHookMetamethod)
protect(realGetRawMetatable)
protect(realSetRawMetatable)
protect(realSetReadonly)
protect(realGetfenv)
protect(realSetfenv)
protect(realGetGc)
protect(realGetReg)
protect(getGenv)
protect(getRenv)

export type RunResult = {
	ok: boolean,
	error: string?,
}

local function isBlockedGlobal(key: any): boolean
	if type(key) ~= "string" then
		return false
	end
	return stringSub(key, 1, 3) == "LP_" or stringSub(key, 1, 4) == "LPH_"
end

local function deny(what: string): ()
	warn(`[limerence] {what} is not allowed`)
	error(`{what} is not allowed`, 3)
end

local function buildSandbox(api: { [string]: any }): { [string]: any }
	local genv = getGenv()
	local renv = getRenv()

	local sandbox
	local genvProxy
	local renvProxy

	-- the real game-instance metatable, used to catch setreadonly bypasses
	local instanceMeta = realGetRawMetatable(game)

	local guarded: { [string]: any } = {}

	guarded.hookmetamethod = function(object: any, method: any, hook: any): any
		if typeOf(object) == "Instance" then
			deny("hooking instance metamethods")
		end
		return realHookMetamethod(object, method, hook)
	end

	guarded.getrawmetatable = function(object: any): any
		if typeOf(object) == "Instance" then
			deny("reading the instance metatable")
		end
		return realGetRawMetatable(object)
	end

	guarded.setrawmetatable = function(object: any, mt: any): any
		if typeOf(object) == "Instance" then
			deny("setting the instance metatable")
		end
		return realSetRawMetatable(object, mt)
	end

	if realSetReadonly then
		guarded.setreadonly = function(tbl: any, value: any): any
			if tbl == instanceMeta then
				deny("unlocking the instance metatable")
			end
			return realSetReadonly(tbl, value)
		end
	end

	-- never let the script reach a real environment to escape the sandbox
	guarded.getfenv = function(_: any): any
		return sandbox
	end
	guarded.setfenv = function(target: any, env: any): any
		-- numeric levels target the live thread (our env); only allow on their own functions
		if type(target) ~= "function" then
			deny("setfenv on the running thread")
		end
		return realSetfenv(target, env)
	end

	-- nested chunks stay sandboxed
	guarded.loadstring = function(src: any, chunkName: any): (any, any?)
		local chunk, parseErr = realLoadstring(src, chunkName)
		if not chunk then
			return chunk, parseErr
		end
		realSetfenv(chunk, sandbox)
		return chunk
	end

	guarded.getgenv = function(): any
		return genvProxy
	end
	guarded.getrenv = function(): any
		return renvProxy
	end

	-- strip our wrapped originals out of gc / registry scrapes
	if realGetGc then
		guarded.getgc = function(...): any
			local raw = realGetGc(...)
			if type(raw) ~= "table" then
				return raw
			end
			local out = {}
			for _, value in next, raw do
				if not protectedOriginals[value] then
					out[#out + 1] = value
				end
			end
			return out
		end
	end
	if realGetReg then
		guarded.getreg = function(...): any
			local raw = realGetReg(...)
			if type(raw) ~= "table" then
				return raw
			end
			local out = {}
			for key, value in next, raw do
				if not protectedOriginals[value] then
					out[key] = value
				end
			end
			return out
		end
	end

	local function resolve(key: any): any
		if isBlockedGlobal(key) then
			return nil
		end
		local override = guarded[key]
		if override ~= nil then
			return override
		end
		local value = genv[key]
		if value ~= nil then
			if protectedOriginals[value] then
				return nil
			end
			return value
		end
		value = renv[key]
		if protectedOriginals[value] then
			return nil
		end
		return value
	end

	genvProxy = setMetatable({}, {
		__index = function(_, key: any): any
			return resolve(key)
		end,
		__newindex = function(): ()
			deny("writing to the global environment")
		end,
		__metatable = false,
	})
	renvProxy = genvProxy

	sandbox = setMetatable({}, {
		__index = function(_, key: any): any
			return resolve(key)
		end,
	})

	rawSet(sandbox, "api", api)
	rawSet(sandbox, "_G", sandbox)
	rawSet(sandbox, "shared", sandbox)

	return sandbox
end

function luauRunner.Run(source: string, scriptName: string, api: { [string]: any }): RunResult
	local chunk, parseErr = realLoadstring(source, `@luau:{scriptName}`)
	if not chunk then
		return { ok = false, error = `parse error: {tostring(parseErr)}` }
	end

	realSetfenv(chunk, buildSandbox(api))

	local ok, err = realPcall(chunk)
	if not ok then
		return { ok = false, error = `runtime error: {tostring(err)}` }
	end

	return { ok = true }
end

return luauRunner
