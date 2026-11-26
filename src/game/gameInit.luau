local init = require("@src/init")
local gameRegistry = require("@game/gameRegistry")
local supportedVersions = require("@game/supportedVersions")
local versionGate = require("@game/versionGate")

local LocalPlayer = cloneref(game:GetService("Players")).LocalPlayer

local function preloadFailed(err: string?): ()
	if LPH_OBFUSCATED then
		LocalPlayer:Kick("[limerence.biz]\n\nAn error occurred and the script could not be loaded.")
	end

	if err then
		warn(debug.traceback(err, 2))
	end
end

local function runClosures(closures: { (...any) -> () }): ()
	for i = 1, #closures do
		local ok, err = (pcall :: any)(closures[i])
		if not ok then
			preloadFailed(`{tostring(i)} | ` .. err)
			return
		end
	end
end

return function(closures: { (...any) -> () }, preloadClosures: { (...any) -> () }): ()
	if not versionGate.Check(supportedVersions[gameRegistry.name]) then
		return
	end
	runClosures(preloadClosures)
	local applyAutoload = init()
	runClosures(closures)
	if applyAutoload then
		applyAutoload()
	end
end
