local Players = cloneref(game:GetService("Players")) :: Players

local UniversalHitEffect = require("@game/universal/feature/visual/hiteffect/HitEffect")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local PlayerController = require("@feature/player/PlayerController")
local gameUi = require("@game/gameUi")

local HitEffect = {}

function HitEffect.new(link: gameUi.Linker): UniversalHitEffect.HitEffect
	return UniversalHitEffect.new(link, {
		connect = function(play: (kind: string, position: Vector3) -> ())
			return WeaponController.hitTarget:Connect(LPH_NO_VIRTUALIZE(function(model: Model, part: BasePart): ()
				if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
					return
				end
				local kind: string
				if string.find(part.Name, "Head") then
					kind = "headshot"
				else
					local player = Players:GetPlayerFromCharacter(model)
					local playerData = player and PlayerController.Get(player)
					if playerData and not playerData:IsAlive() then
						kind = "lethal"
					else
						kind = "hit"
					end
				end
				play(kind, part.Position)
			end))
		end,
	})
end

return HitEffect
