local gameInit = require("@game/gameInit")
local gameRegistry = require("@game/gameRegistry")
local loader = require("@loader/loader")
local initUi = require("@game/mvsd/initUi")
local clientState = require("@game/mvsd/client/clientState")
local ModuleController = require("@game/mvsd/module/ModuleController")
local ClientController = require("@game/mvsd/client/ClientController")
local WeaponController = require("@game/mvsd/weapon/WeaponController")

gameRegistry.name = "murderers vs sheriffs duels"

gameInit({
	function()
		loader.mount(ModuleController)
		loader.mount(ClientController)
		loader.mount(WeaponController)

		gameRegistry.clientState = clientState
		gameRegistry.moduleController = ModuleController

		require("@game/mvsd/mvsdGameApi")
	end,
	initUi,
}, {})

local mvsdGame = game.GameId
local appendedCode = `if game.GameId ~= ` .. mvsdGame .. [[ then
	return
end
]]
if LPH_OBFUSCATED then
	appendedCode ..= `lp_key='{lp_key}';`
	appendedCode ..= `loadstring(game:HttpGet("https://raw.githubusercontent.com/onichan-ren/limerence/main/scripts/build/output/mvsd.luau"))()`
end
if not LPH_OBFUSCATED then
	appendedCode ..= `loadfile("mvsd.luau")()`
end
clear_teleport_queue()
queue_on_teleport(appendedCode)
