local gameInit = require("@game/gameInit")
local gameRegistry = require("@game/gameRegistry")
local loader = require("@loader/loader")
local ModuleController = require("@game/rivals/module/ModuleController")
local NetworkController = require("@game/rivals/network/NetworkController")
local ClientController = require("@game/rivals/client/ClientController")
local GrenadeController = require("@game/rivals/grenade/GrenadeController")
local PlaceableController = require("@game/rivals/placeable/PlaceableController")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local ViewmodelController = require("@game/rivals/viewmodel/ViewmodelController")
local InventoryChanger = require("@game/rivals/feature/inventory/InventoryChanger")
local clientApi = require("@game/rivals/client/clientApi")
local clientState = require("@game/rivals/client/clientState")
local playerApi = require("@game/rivals/player/playerApi")
local initUi = require("@game/rivals/initUi")
local bypass = require("@game/rivals/bypass")

gameRegistry.name = "rivals"

gameInit({
	function()
		loader.mount(ModuleController)
		loader.mount(NetworkController)
		loader.mount(ClientController)
		loader.mount(GrenadeController)
		loader.mount(PlaceableController)
		loader.mount(WeaponController)
		loader.mount(ViewmodelController)
		loader.mount(InventoryChanger)

		WeaponController.hitPlayer:Connect(function(player: Player, isHead: boolean): ()
			clientApi.signals.onHit:Fire({
				player = player,
				headshot = isHead == true,
			})
		end)
		WeaponController.killedPlayer:Connect(function(victim: Player): ()
			clientApi.signals.onKill:Fire({
				player = victim,
			})
		end)

		gameRegistry.clientApi = clientApi
		gameRegistry.clientState = clientState
		gameRegistry.moduleController = ModuleController
		gameRegistry.networkController = NetworkController
		gameRegistry.playerApi = playerApi

		require("@feature/luau/luauRivalsGameApi")
		require("@feature/luau/luauRagebotApi").Install(require("@game/rivals/feature/combat/ragebot/ragebotApi"))
	end,
	initUi,
}, { bypass })

local rivalsGame = game.GameId
local appendedCode = `if game.GameId ~= ` .. rivalsGame .. [[ then
	return 
end

]]
if LPH_OBFUSCATED then
	appendedCode ..= `lp_key='{lp_key}';`
end
appendedCode ..= `loadstring(game:HttpGet("https://raw.githubusercontent.com/onichan-ren/limerence/main/scripts/build/output/rivals.luau"))()`
clear_teleport_queue()
queue_on_teleport(appendedCode)
