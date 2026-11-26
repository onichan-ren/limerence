local gameInit = require("@game/gameInit")
local gameRegistry = require("@game/gameRegistry")
local loader = require("@loader/loader")
local instances = require("@share/instances")
local initUi = require("@game/ar2/initUi")
local clientApi = require("@game/ar2/client/clientApi")
local clientState = require("@game/ar2/client/clientState")
local ModuleController = require("@game/ar2/module/ModuleController")
local ClientController = require("@game/ar2/client/ClientController")
local NetworkController = require("@game/ar2/network/NetworkController")
local InteractionController = require("@game/ar2/interaction/InteractionController")
local SquadController = require("@game/ar2/client/SquadController")
local WeaponController = require("@game/ar2/weapon/WeaponController")
local ZombieController = require("@game/ar2/zombie/ZombieController")
local InventoryChanger = require("@game/ar2/feature/inventory/InventoryChanger")
local playerApi = require("@game/ar2/player/playerApi")
local bypass = require("@game/ar2/bypass")

gameRegistry.name = "apocalypse rising 2"

gameInit({
	function()
		instances.setIgnore("Effects")
		loader.mount(ModuleController)
		loader.mount(NetworkController)
		loader.mount(InteractionController)
		loader.mount(SquadController)
		loader.mount(ClientController)
		loader.mount(WeaponController)
		loader.mount(ZombieController)
		loader.mount(InventoryChanger)

		WeaponController.hitPlayer:Connect(function(player: Player, part: BasePart?, position: Vector3?, damage: number?): ()
			local partName = part and part.Name or nil
			clientApi.signals.onHit:Fire({
				player = player,
				part = part,
				partName = partName,
				position = position,
				damage = damage,
				headshot = partName == "Head",
			})
		end)

		gameRegistry.clientApi = clientApi
		gameRegistry.clientState = clientState
		gameRegistry.moduleController = ModuleController
		gameRegistry.networkController = NetworkController
		gameRegistry.playerApi = playerApi

		require("@feature/luau/luauRagebotApi").Install(require("@game/ar2/feature/ragebot/ragebotApi"))
		require("@game/ar2/feature/misc/autoLootApi")
		require("@game/ar2/ar2GameApi")
	end,
	initUi,
}, { bypass })
