local UniversalHitEffect = require("@game/universal/feature/visual/hiteffect/HitEffect")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local isLethal = require("@game/overkill/feature/visual/lethal")
local gameUi = require("@game/gameUi")

local HitEffect = {}

function HitEffect.new(link: gameUi.Linker): UniversalHitEffect.HitEffect
	return UniversalHitEffect.new(link, {
		connect = function(play: (kind: string, position: Vector3) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player, _part: Instance, _partName: string, position: Vector3, _damage: number, headshot: boolean): ()
				local kind: string
				if headshot then
					kind = "headshot"
				elseif isLethal(player) then
					kind = "lethal"
				else
					kind = "hit"
				end
				play(kind, position)
			end))
		end,
	})
end

return HitEffect
