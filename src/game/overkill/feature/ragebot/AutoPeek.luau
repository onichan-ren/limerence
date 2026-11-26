local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local UniversalAutoPeek = require("@game/universal/feature/combat/autopeek/AutoPeek")
local clientState = require("@game/overkill/client/clientState")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local CommandController = require("@game/overkill/weapon/CommandController")

local peek = Charm.peek

local AutoPeek = {}

function AutoPeek.new(link: gameUi.Linker): UniversalAutoPeek.AutoPeek
	return UniversalAutoPeek.new(link, {
		getHrp = function(): BasePart?
			return peek(clientState.hrp)
		end,
		connectShot = function(fire: () -> ()): (() -> ())
			local conn = WeaponController.weaponFiredLocal:Connect(fire)
			return function(): ()
				conn:Disconnect()
			end
		end,
		startMove = function(ctx: UniversalAutoPeek.RetreatContext): (() -> ())
			local unregister = CommandController.Register(LPH_NO_VIRTUALIZE(function(command: any): ()
				if not ctx.shouldRun() then
					ctx.arrive()
					return
				end

				local delta = ctx.flatDelta()
				if not delta then
					ctx.arrive()
					return
				end

				if delta.Magnitude <= ctx.stopDistance or ctx.crossedCenter() then
					command.x = 0
					command.z = 0
					ctx.arrive()
					return
				end

				local dir = delta.Unit
				command.x = dir.X
				command.z = dir.Z
			end), 50)

			return function(): ()
				task.defer(unregister)
			end
		end,
	})
end

return AutoPeek
