local UniversalHitSkeletons = require("@game/universal/feature/visual/hitskeletons/HitSkeletons")
local WeaponController = require("@game/op1/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local Hitskeletons = {}

function Hitskeletons.new(link: gameUi.Linker): UniversalHitSkeletons.Hitskeletons
	return UniversalHitSkeletons.new(link, {
		connectHit = function(handler: (player: Player) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player): ()
				handler(player)
			end))
		end,
	})
end

return Hitskeletons
