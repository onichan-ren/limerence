local NetworkController = require("@game/bloxstrike/network/NetworkController")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local ClientController = require("@game/bloxstrike/client/ClientController")
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
local ViewmodelController = require("@game/bloxstrike/viewmodel/ViewmodelController")
local LoadoutController = require("@game/bloxstrike/loadout/LoadoutController")
local MotionTracker = require("@game/bloxstrike/player/MotionTracker")
local GrenadeController = require("@game/bloxstrike/grenade/GrenadeController")
local DroppedItemController = require("@game/bloxstrike/dropped/DroppedItemController")
local BombController = require("@game/bloxstrike/bomb/BombController")
local PurchaseController = require("@game/bloxstrike/purchase/PurchaseController")
local HostageController = require("@game/bloxstrike/hostage/HostageController")
local InventoryChanger = require("@game/bloxstrike/feature/inventory/InventoryChanger")
local MenuMouseController = require("@game/bloxstrike/MenuMouseController")
local clientApi = require("@game/bloxstrike/client/clientApi")
local clientState = require("@game/bloxstrike/client/clientState")
local playerApi = require("@game/bloxstrike/player/playerApi")
local Backtrack = require("@game/bloxstrike/feature/ragebot/Backtrack")
local gameInit = require("@game/gameInit")
local gameRegistry = require("@game/gameRegistry")
local loader = require("@loader/loader")
local instances = require("@share/instances")
local initUi = require("@game/bloxstrike/initUi")
local bypass = require("@game/bloxstrike/bypass")

gameRegistry.name = "bloxstrike"

gameInit({
	function()
		instances.setIgnore("Debris")
		loader.mount(NetworkController)
		loader.mount(ModuleController)
		loader.mount(ClientController)
		loader.mount(WeaponController)
		loader.mount(ViewmodelController)
		loader.mount(GrenadeController)
		loader.mount(DroppedItemController)
		loader.mount(BombController)
		loader.mount(PurchaseController)
		loader.mount(HostageController)
		loader.mount(LoadoutController)
		loader.mount(InventoryChanger)
		loader.mount(MenuMouseController)
		loader.mount(MotionTracker)

		WeaponController.hitPlayer:Connect(function(player: Player, part: Instance?): ()
			local partName = part and part.Name or nil
			clientApi.signals.onHit:Fire({
				player = player,
				part = part,
				partName = partName,
				headshot = partName == "Head",
			})
		end)
		WeaponController.killedPlayer:Connect(function(victim: Player, position: Vector3?): ()
			clientApi.signals.onKill:Fire({
				player = victim,
				position = position,
			})
		end)

		gameRegistry.clientApi = clientApi
		gameRegistry.clientState = clientState
		gameRegistry.networkController = NetworkController
		gameRegistry.moduleController = ModuleController
		gameRegistry.playerApi = playerApi
		gameRegistry.augmentPlayerHandle = function(baseHandle: any): any
			local handle = setmetatable({}, { __index = baseHandle }) :: any
			function handle.getBacktrackPosition(partName: string): Vector3?
				if type(partName) ~= "string" then
					error("PlayerHandle.getBacktrackPosition: partName must be a string", 2)
				end
				return Backtrack.GetHistoricalPosition(baseHandle.getPlayer(), partName)
			end
			return handle
		end

		require("@feature/luau/luauGameApi")
		require("@feature/luau/luauRagebotApi").Install(require("@game/bloxstrike/feature/ragebot/ragebotApi"))
	end,
	initUi,
}, { bypass })
