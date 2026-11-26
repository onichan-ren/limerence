local UniversalHitSkeletons = require("@game/universal/feature/visual/hitskeletons/HitSkeletons")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local Hitskeletons = {}

function Hitskeletons.new(link: gameUi.Linker): UniversalHitSkeletons.Hitskeletons
	return UniversalHitSkeletons.new(link, {
		body = "Briefly draws the skeleton of a player where you hit them.",
		lastShotBody = "Only keeps the skeleton from your latest hit instead of stacking them.",
		colorBody = "Color of the hit skeleton lines.",
		connectHit = function(handler: (player: Player) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player, _crit: boolean): ()
				handler(player)
			end))
		end,
	})
end

return Hitskeletons
