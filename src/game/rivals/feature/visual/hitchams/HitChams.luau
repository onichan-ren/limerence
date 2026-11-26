local UniversalHitChams = require("@game/universal/feature/visual/hitchams/HitChams")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local Hitchams = {}

function Hitchams.new(link: gameUi.Linker): UniversalHitChams.Hitchams
	return UniversalHitChams.new(link, {
		body = "Briefly highlights the body parts you hit.",
		lastShotBody = "Only keeps the highlight from your latest hit instead of stacking them.",
		colorBody = "Color of the hit highlight boxes.",
		connectHit = function(handler: (player: Player) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player, _crit: boolean): ()
				handler(player)
			end))
		end,
	})
end

return Hitchams
