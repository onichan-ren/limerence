local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local UniversalAutoPeek = require("@game/universal/feature/combat/autopeek/AutoPeek")
local clientState = require("@game/rivals/client/clientState")
local WeaponController = require("@game/rivals/weapon/WeaponController")

local peek = Charm.peek

local AutoPeek = {}

function AutoPeek.new(link: gameUi.Linker): UniversalAutoPeek.AutoPeek
	return UniversalAutoPeek.new(link, {
		getHrp = function(): BasePart?
			return peek(clientState.hrp)
		end,
		connectShot = function(fire: () -> ()): (() -> ())
			local conn = WeaponController.shotFired:Connect(fire)
			return function(): ()
				conn:Disconnect()
			end
		end,
		startMove = function(ctx: UniversalAutoPeek.RetreatContext): (() -> ())
			local conn = RunService.Stepped:Connect(LPH_NO_VIRTUALIZE(function(): ()
				if not ctx.shouldRun() then
					ctx.arrive()
					return
				end

				local delta = ctx.flatDelta()
				local humanoid = peek(clientState.humanoid)
				if not delta or not humanoid then
					ctx.arrive()
					return
				end

				if delta.Magnitude <= ctx.stopDistance or ctx.crossedCenter() then
					humanoid:Move(Vector3.zero, false)
					ctx.arrive()
					return
				end

				humanoid:Move(delta.Unit, false)
			end))

			return function(): ()
				conn:Disconnect()
			end
		end,
	})
end

return AutoPeek
