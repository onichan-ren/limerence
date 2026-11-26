local UniversalHitOverlay = require("@game/universal/feature/visual/hitoverlay/HitOverlay")
local WeaponController = require("@game/pf/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local HitOverlay = {}

function HitOverlay.new(link: gameUi.Linker): UniversalHitOverlay.HitOverlay
	return UniversalHitOverlay.new(link, {
		connect = function(emit: (headshot: boolean) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(_player: Player, _part: Instance, _partName: string, _position: Vector3, _damage: number, headshot: boolean): ()
				emit(headshot)
			end))
		end,
	})
end

return HitOverlay
