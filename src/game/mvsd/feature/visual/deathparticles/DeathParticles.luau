local UniversalDeathParticles = require("@game/universal/feature/visual/deathparticles/DeathParticles")
local WeaponController = require("@game/mvsd/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local DeathParticles = {}

function DeathParticles.new(link: gameUi.Linker): UniversalDeathParticles.DeathParticles
	return UniversalDeathParticles.new(link, {
		connect = function(onKill: (player: Player, position: Vector3?) -> ())
			return WeaponController.killedPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player): ()
				onKill(player)
			end))
		end,
	})
end

return DeathParticles
