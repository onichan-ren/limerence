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

local target = resolveTarget()
local useDebug = getGlobal("LIMERENCE_DEBUG") == true and DEBUG_TARGETS[target]
local fileName = target .. (if useDebug then ".debug.luau" else ".luau")

local source = fetch(BASE_URL .. fileName .. "?t=" .. tostring(os.time()))

if ACTOR_TARGETS[target] and type(getactors) == "function" and type(run_on_actor) == "function" then
	local alreadyInActor = type(isactor) == "function" and isactor()
	if not alreadyInActor then
		local actors = getactors()
		local actor = actors and actors[1]
		if actor then
			return run_on_actor(actor, source)
		end
	end
end

local fn, err = loadstring(source, "@limerence/" .. target)
if not fn then
	error("[limerence] failed to compile " .. fileName .. ": " .. tostring(err))
end

return fn()
