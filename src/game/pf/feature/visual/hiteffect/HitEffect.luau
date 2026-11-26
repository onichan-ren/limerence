local UniversalHitEffect = require("@game/universal/feature/visual/hiteffect/HitEffect")
local WeaponController = require("@game/pf/weapon/WeaponController")
local PlayerController = require("@feature/player/PlayerController")
local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")

local peek = Charm.peek

local function isLethal(player: Player): boolean
	local playerData = PlayerController.Get(player)
	if not playerData then
		return false
	end
	return peek((playerData :: any).alive) == false
end

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
