local UniversalHitmarker = require("@game/universal/feature/visual/hitmarker/Hitmarker")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local hudSuppressor = require("@game/overkill/feature/visual/removals/hudSuppressor")
local gameUi = require("@game/gameUi")

local Hitmarker = {}

function Hitmarker.new(link: gameUi.Linker): UniversalHitmarker.Hitmarker
	local held = false
	return UniversalHitmarker.new(link, {
		body = "Shows an on-screen X when your shots register on a player. Replaces the game's hitmarker.",
		onActive = function(active: boolean): ()
			if active == held then
				return
			end
			held = active
			if active then
				hudSuppressor.Acquire("HitMarker")
			else
				hudSuppressor.Release("HitMarker")
			end
		end,
		connect = function(emit: (headshot: boolean) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(_player: Player, _part: Instance, _partName: string, _position: Vector3, _damage: number, headshot: boolean): ()
				emit(headshot)
			end))
		end,
	})
end

return Hitmarker
