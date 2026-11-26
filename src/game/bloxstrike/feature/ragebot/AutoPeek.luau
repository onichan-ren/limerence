local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local UniversalAutoPeek = require("@game/universal/feature/combat/autopeek/AutoPeek")
local clientState = require("@game/bloxstrike/client/clientState")
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
local moveController = require("@game/bloxstrike/client/moveController")

local peek = Charm.peek

local AutoPeek = {}

function AutoPeek.new(link: gameUi.Linker): UniversalAutoPeek.AutoPeek
	return UniversalAutoPeek.new(link, {
		getHrp = function(): BasePart?
			return peek(clientState.parts).HumanoidRootPart :: BasePart?
		end,
		connectShot = function(fire: () -> ()): (() -> ())
			return WeaponController.AddShootTransform(function(data: any): ()
				if type(data) ~= "table" or type(rawget(data, "Bullets")) ~= "table" then
					return
				end
				fire()
			end)
		end,
		teleport = function(savedCFrame: CFrame): ()
			local hrp = peek(clientState.parts).HumanoidRootPart :: BasePart?
			if hrp then
				hrp.CFrame = savedCFrame
			end
		end,
		startMove = function(ctx: UniversalAutoPeek.RetreatContext): (() -> ())
			local touched = false
			local conn = RunService.Stepped:Connect(LPH_NO_VIRTUALIZE(function(): ()
				if not ctx.shouldRun() then
					ctx.arrive()
					return
				end

				local controller = moveController.getActive()
				local delta = ctx.flatDelta()
				if not controller or not delta then
					ctx.arrive()
					return
				end

				if delta.Magnitude <= ctx.stopDistance or ctx.crossedCenter() then
					ctx.arrive()
					return
				end

				touched = true
				controller.moveVector = moveController.worldToMoveVector(delta)
			end))

			return function(): ()
				conn:Disconnect()
				if touched then
					local controller = moveController.getActive()
					if controller then
						controller.moveVector = moveController.realMoveVector(controller)
					end
				end
			end
		end,
	})
end

return AutoPeek
