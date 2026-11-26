if not game:IsLoaded() then
	game.Loaded:Wait()
end

local cloneref = cloneref or function(instance)
	return instance
end

local Players = cloneref(game:GetService("Players"))
while not Players.LocalPlayer do
	task.wait()
end

local BASE_URL = "https://raw.githubusercontent.com/onichan-ren/limerence/main/scripts/build/output/"

local VALID_TARGETS = {
	ar2 = true,
	bedwars = true,
	bloxstrike = true,
	dahood = true,
	mvsd = true,
	op1 = true,
	overkill = true,
	pf = true,
	rivals = true,
	universal = true,
}

local DEBUG_TARGETS = {
	ar2 = true,
	bloxstrike = true,
	mvsd = true,
	op1 = true,
	overkill = true,
	pf = true,
	rivals = true,
	universal = true,
}

local ACTOR_TARGETS = {
	pf = true,
}

local PLACE_TARGETS = {
	[863266079] = "ar2",
	[6872265039] = "bedwars",
	[8444591321] = "bedwars",
	[8560631822] = "bedwars",
	[114234929420007] = "bloxstrike",
	[2788229376] = "dahood",
	[12355337193] = "mvsd",
	[17392399335] = "op1",
	[124842176624983] = "overkill",
	[292439477] = "pf",
	[17625359962] = "rivals",
}

local GAME_TARGETS = {
	[2619619496] = "bedwars",
	[113491250] = "pf",
	[6035872082] = "rivals",
}

local function getGlobal(key)
	local env = if type(getgenv) == "function" then getgenv() else _G
	return env[key]
end

local function resolveTarget()
	local override = getGlobal("LIMERENCE_TARGET")
	if type(override) == "string" and VALID_TARGETS[override] then
		return override
	end
	return PLACE_TARGETS[game.PlaceId] or GAME_TARGETS[game.GameId] or "universal"
end

local function fetch(url)
	local ok, body = pcall(game.HttpGet, game, url)
	if not ok or type(body) ~= "string" or #body == 0 or body == "404: Not Found" then
		error("[limerence] failed to fetch: " .. url .. " (" .. tostring(body) .. ")")
	end
	return body
end

local function setGlobal(key, value)
	local env = if type(getgenv) == "function" then getgenv() else _G
	env[key] = value
end

local function loadPf(source)
	local env = if type(getgenv) == "function" then getgenv() else _G
	local executor = string.lower(if type(identifyexecutor) == "function" then identifyexecutor() else "")
	local threadSource = [[
		for _, func in getgc(false) do
			if type(func) == "function" and islclosure(func) and debug.getinfo(func).name == "require" and string.find(debug.getinfo(func).source, "ClientLoader") then
				loadstring(]] .. string.format("%q", source) .. [[, "@limerence/pf")()
				break
			end
		end
	]]

	local function runSource(runner, getAll)
		if type(runner) ~= "function" or type(getAll) ~= "function" then
			return false
		end
		for _, actor in getAll() do
			runner(actor, threadSource)
		end
		return true
	end

	local ran = false
	if not env.executed then
		if string.find(executor, "choco") then
			ran = runSource(run_on_actor, get_deleted_actors)
		elseif string.find(executor, "nexomia") or string.find(executor, "volt") then
			ran = runSource(run_on_actor, getactors)
		elseif string.find(executor, "potassium") then
			ran = runSource(run_on_thread, getactorthreads)
		elseif string.find(executor, "nihon") or string.find(executor, "synapse z") or string.find(executor, "yubx") or string.find(executor, "cosmic") then
			ran = runSource(run_on_actor, getdeletedactors)
		elseif type(getfflag) == "function" and string.lower(tostring(getfflag("DebugRunParallelLuaOnMainThread"))) == "true" then
			local fn, err = loadstring(source, "@limerence/pf")
			if not fn then
				error("[limerence] failed to compile pf: " .. tostring(err))
			end
			setGlobal("executed", true)
			return fn()
		elseif type(setfflag) == "function" then
			setfflag("DebugRunParallelLuaOnMainThread", "True")
			if type(queue_on_teleport) == "function" then
				queue_on_teleport('loadstring(game:HttpGet("https://raw.githubusercontent.com/onichan-ren/limerence/main/loader.lua?t=" .. tostring(os.time())))()')
			end
			cloneref(game:GetService("TeleportService")):Teleport(game.PlaceId)
			setGlobal("executed", true)
			return
		end
	end

	setGlobal("executed", true)
	if ran then
		return
	end
end

local target = resolveTarget()
local useDebug = getGlobal("LIMERENCE_DEBUG") == true and DEBUG_TARGETS[target]
local fileName = target .. (if useDebug then ".debug.luau" else ".luau")

local source = fetch(BASE_URL .. fileName .. "?t=" .. tostring(os.time()))

if ACTOR_TARGETS[target] then
	return loadPf(source)
end

local fn, err = loadstring(source, "@limerence/" .. target)
if not fn then
	error("[limerence] failed to compile " .. fileName .. ": " .. tostring(err))
end

return fn()
