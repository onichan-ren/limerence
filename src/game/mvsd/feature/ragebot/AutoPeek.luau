local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local UniversalAutoPeek = require("@game/universal/feature/combat/autopeek/AutoPeek")
local clientState = require("@game/mvsd/client/clientState")
local WeaponController = require("@game/mvsd/weapon/WeaponController")

local peek = Charm.peek

local MOVE_BIND_NAME = "LimerenceAutoPeekMove"
local MOVE_BIND_PRIORITY = Enum.RenderPriority.Input.Value + 1

local AutoPeek = {}

function AutoPeek.new(link: gameUi.Linker): UniversalAutoPeek.AutoPeek
	return UniversalAutoPeek.new(link, {
		getHrp = function(): BasePart?
			return peek(clientState.hrp)
		end,
		connectShot = function(fire: () -> ()): (() -> ())
			local conn = WeaponController.weaponUsed:Connect(fire)
			return function(): ()
				conn:Disconnect()
			end
		end,
		teleport = function(savedCFrame: CFrame): ()
			local hrp = peek(clientState.hrp)
			if hrp then
				hrp.CFrame = savedCFrame
			end
		end,
		startMove = function(ctx: UniversalAutoPeek.RetreatContext): (() -> ())
			RunService:BindToRenderStep(MOVE_BIND_NAME, MOVE_BIND_PRIORITY, LPH_NO_VIRTUALIZE(function(): ()
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
				RunService:UnbindFromRenderStep(MOVE_BIND_NAME)
			end
		end,
	})
end

return AutoPeek
