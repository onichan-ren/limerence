local BASE_URL = "https://raw.githubusercontent.com/onichan-ren/limerence/main/scripts/build/output/"

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

local target = (type(_G.LIMERENCE_TARGET) == "string" and _G.LIMERENCE_TARGET)
	or PLACE_TARGETS[game.PlaceId]
	or GAME_TARGETS[game.GameId]
	or "universal"

local source = game:HttpGet(BASE_URL .. target .. ".luau")
local fn, err = loadstring(source)
if not fn then
	error(err)
end

return fn()
