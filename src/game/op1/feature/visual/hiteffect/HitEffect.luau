local UniversalHitEffect = require("@game/universal/feature/visual/hiteffect/HitEffect")
local WeaponController = require("@game/op1/weapon/WeaponController")
local PlayerController = require("@feature/player/PlayerController")
local gameUi = require("@game/gameUi")

local HEAD_PART = "head"

local HitEffect = {}

function HitEffect.new(link: gameUi.Linker): UniversalHitEffect.HitEffect
	return UniversalHitEffect.new(link, {
		connect = function(play: (kind: string, position: Vector3) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player, part: Instance, position: Vector3): ()
				local kind: string
				if part.Name == HEAD_PART then
					kind = "headshot"
				else
					local playerData = PlayerController.Get(player)
					if playerData and not playerData:IsAlive() then
						kind = "lethal"
					else
						kind = "hit"
					end
				end
				play(kind, position)
			end))
		end,
	})
end

return HitEffect
