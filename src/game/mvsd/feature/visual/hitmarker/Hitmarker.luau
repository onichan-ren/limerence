local UniversalHitmarker = require("@game/universal/feature/visual/hitmarker/Hitmarker")
local WeaponController = require("@game/mvsd/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local Hitmarker = {}

function Hitmarker.new(link: gameUi.Linker): UniversalHitmarker.Hitmarker
	return UniversalHitmarker.new(link, {
		connect = function(emit: (headshot: boolean) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(_player: Player, part: Instance): ()
				emit(part.Name:find("Head") and true or false)
			end))
		end,
	})
end

return Hitmarker
