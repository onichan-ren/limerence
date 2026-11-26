local Signal = require("@pkg/Signal")
local gameInit = require("@game/gameInit")
local gameRegistry = require("@game/gameRegistry")
local loader = require("@loader/loader")
local instances = require("@share/instances")
local initUi = require("@game/pf/initUi")
local clientState = require("@game/pf/client/clientState")
local ClientController = require("@game/pf/client/ClientController")
local ModuleController = require("@game/pf/module/ModuleController")
local NetworkController = require("@game/pf/network/NetworkController")
local AntiFlag = require("@game/pf/protection/AntiFlag")
local WeaponController = require("@game/pf/weapon/WeaponController")
local GrenadeController = require("@game/pf/grenade/GrenadeController")
local SkinChanger = require("@game/pf/feature/inventory/SkinChanger")

gameRegistry.name = "phantom forces"

gameInit({
	function()
		instances.setIgnore("Ignore")
		loader.mount(ModuleController)
		loader.mount(NetworkController)
		loader.mount(AntiFlag)
		loader.mount(ClientController)
		loader.mount(WeaponController)
		loader.mount(GrenadeController)
		loader.mount(SkinChanger)

		local combatSignals = {
			onHit = Signal.new(),
			onKill = Signal.new(),
		}
		WeaponController.hitPlayer:Connect(
			function(player: Player, part: Instance?, partName: string?, position: Vector3?, damage: number?, headshot: boolean?): ()
				combatSignals.onHit:Fire({
					player = player,
					part = part,
					partName = partName,
					position = position,
					damage = damage,
					headshot = headshot == true,
				})
			end
		)
		WeaponController.killedPlayer:Connect(function(victim: Player, position: Vector3?): ()
			combatSignals.onKill:Fire({
				player = victim,
				position = position,
			})
		end)
		gameRegistry.clientApi = { signals = combatSignals }

		gameRegistry.clientState = clientState

		require("@game/pf/pfGameApi")
	end,
	initUi,
}, {})
