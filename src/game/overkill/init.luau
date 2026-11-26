local Signal = require("@pkg/Signal")
local gameInit = require("@game/gameInit")
local gameRegistry = require("@game/gameRegistry")
local loader = require("@loader/loader")
local instances = require("@share/instances")
local initUi = require("@game/overkill/initUi")
local clientState = require("@game/overkill/client/clientState")
local ModuleController = require("@game/overkill/module/ModuleController")
local NetworkController = require("@game/overkill/network/NetworkController")
local ClientController = require("@game/overkill/client/ClientController")
local LocalWeaponController = require("@game/overkill/client/LocalWeaponController")
local StateController = require("@game/overkill/state/StateController")
local TeamController = require("@game/overkill/team/TeamController")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local WeaponStateController = require("@game/overkill/weapon/WeaponStateController")
local CommandController = require("@game/overkill/weapon/CommandController")
local CommandBaseController = require("@game/overkill/weapon/CommandBaseController")
local GrenadeController = require("@game/overkill/grenade/GrenadeController")
local InventoryChanger = require("@game/overkill/feature/inventory/InventoryChanger")

gameRegistry.name = "overkill"

gameInit({
	function()
		instances.setIgnore("Debris")
		loader.mount(ModuleController)
		loader.mount(NetworkController)
		loader.mount(ClientController)
		loader.mount(LocalWeaponController)
		loader.mount(StateController)
		loader.mount(TeamController)
		loader.mount(WeaponController)
		loader.mount(WeaponStateController)
		loader.mount(CommandController)
		loader.mount(CommandBaseController)
		loader.mount(GrenadeController)
		loader.mount(InventoryChanger)

		local combatSignals = {
			onHit = Signal.new(),
			onKill = Signal.new(),
		}
		WeaponController.hitPlayer:Connect(
			function(
				player: Player,
				_model: Instance?,
				partName: string?,
				position: Vector3?,
				damage: number?,
				headshot: boolean?
			): ()
				combatSignals.onHit:Fire({
					player = player,
					partName = partName,
					position = position,
					damage = damage,
					headshot = headshot == true,
				})
			end
		)
		WeaponController.killedPlayer:Connect(function(victim: Player, headshot: boolean?): ()
			combatSignals.onKill:Fire({
				player = victim,
				headshot = headshot == true,
			})
		end)
		gameRegistry.clientApi = { signals = combatSignals }

		gameRegistry.clientState = clientState
		gameRegistry.moduleController = ModuleController
		gameRegistry.networkController = NetworkController

		require("@game/overkill/overkillGameApi")
	end,
	initUi,
}, {})

local overkillGame = game.GameId
local appendedCode = `if game.GameId ~= ` .. overkillGame .. [[ then
	return
end
]]
if LPH_OBFUSCATED then
	appendedCode ..= `lp_key='{lp_key}';`
	appendedCode ..= `loadstring(game:HttpGet("https://limerence.biz/loader/{script_id or "?"}.luau"))()`
end
if not LPH_OBFUSCATED then
	appendedCode ..= `loadfile("overkill.luau")()`
end
clear_teleport_queue()
queue_on_teleport(appendedCode)
