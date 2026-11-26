local UniversalHitmarker = require("@game/universal/feature/visual/hitmarker/Hitmarker")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local Hitmarker = {}

function Hitmarker.new(link: gameUi.Linker): UniversalHitmarker.Hitmarker
	return UniversalHitmarker.new(link, {
		body = "Shows an on-screen X when you hit someone.",
		headshotBody = "Color for critical hits.",
		onActive = function(active: boolean): ()
			WeaponController.SetSuppressGameHit(active)
		end,
		connect = function(emit: (headshot: boolean) -> ())
			return WeaponController.hitDealt:Connect(LPH_NO_VIRTUALIZE(function(headshot: boolean): ()
				emit(headshot)
			end))
		end,
	})
end

return Hitmarker
