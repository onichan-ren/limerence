local UniversalHitOverlay = require("@game/universal/feature/visual/hitoverlay/HitOverlay")
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local HitOverlay = {}

function HitOverlay.new(link: gameUi.Linker): UniversalHitOverlay.HitOverlay
	return UniversalHitOverlay.new(link, {
		connect = function(emit: (headshot: boolean) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(_player: Player, part: Instance): ()
				emit(part.Name == "Head")
			end))
		end,
	})
end

return HitOverlay
