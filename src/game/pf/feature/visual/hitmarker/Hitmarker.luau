local UniversalHitmarker = require("@game/universal/feature/visual/hitmarker/Hitmarker")
local WeaponController = require("@game/pf/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local Hitmarker = {}

function Hitmarker.new(link: gameUi.Linker): UniversalHitmarker.Hitmarker
	return UniversalHitmarker.new(link, {
		connect = function(emit: (headshot: boolean) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(_player: Player, _part: Instance, _partName: string, _position: Vector3, _damage: number, headshot: boolean): ()
				emit(headshot)
			end))
		end,
	})
end

return Hitmarker
