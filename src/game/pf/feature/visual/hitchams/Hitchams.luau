local UniversalHitChams = require("@game/universal/feature/visual/hitchams/HitChams")
local WeaponController = require("@game/pf/weapon/WeaponController")
local PlayerController = require("@feature/player/PlayerController")
local gameUi = require("@game/gameUi")

local Hitchams = {}

function Hitchams.new(link: gameUi.Linker): UniversalHitChams.Hitchams
	return UniversalHitChams.new(link, {
		connectHit = function(handler: (player: Player) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player): ()
				handler(player)
			end))
		end,
		getSizes = function(player: Player): { [string]: Vector3 }?
			local playerData = PlayerController.Get(player) :: any
			return playerData and playerData:GetPartSizes()
		end,
	})
end

return Hitchams
