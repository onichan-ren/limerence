local UniversalHitOverlay = require("@game/universal/feature/visual/hitoverlay/HitOverlay")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local HitOverlay = {}

function HitOverlay.new(link: gameUi.Linker): UniversalHitOverlay.HitOverlay
	return UniversalHitOverlay.new(link, {
		connect = function(emit: (headshot: boolean) -> ())
			return WeaponController.hitDealt:Connect(LPH_NO_VIRTUALIZE(function(headshot: boolean): ()
				emit(headshot)
			end))
		end,
	})
end

return HitOverlay
