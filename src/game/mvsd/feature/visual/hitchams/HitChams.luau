local UniversalHitChams = require("@game/universal/feature/visual/hitchams/HitChams")
local WeaponController = require("@game/mvsd/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local Hitchams = {}

function Hitchams.new(link: gameUi.Linker): UniversalHitChams.Hitchams
	return UniversalHitChams.new(link, {
		connectHit = function(handler: (player: Player) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player): ()
				handler(player)
			end))
		end,
	})
end

return Hitchams
