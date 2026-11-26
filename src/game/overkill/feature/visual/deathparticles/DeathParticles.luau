local UniversalDeathParticles = require("@game/universal/feature/visual/deathparticles/DeathParticles")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local botSource = require("@game/overkill/feature/training/botSource")
local gameUi = require("@game/gameUi")

local DeathParticles = {}

function DeathParticles.new(link: gameUi.Linker): UniversalDeathParticles.DeathParticles
	return UniversalDeathParticles.new(link, {
		connect = function(onKill: (player: Player, position: Vector3?) -> ())
			return WeaponController.killedPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player): ()
				onKill(player)
			end))
		end,
		resolveParts = function(player: any): { Vector3 }?
			local bot = botSource.GetByPlayer(player)
			if not bot then
				return nil
			end
			local positions: { Vector3 } = {}
			for _, part in next, bot:GetParts() do
				if part:IsA("BasePart") then
					positions[#positions + 1] = part.Position
				end
			end
			return positions
		end,
	})
end

return DeathParticles
