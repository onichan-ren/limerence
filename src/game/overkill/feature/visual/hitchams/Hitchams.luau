local UniversalHitChams = require("@game/universal/feature/visual/hitchams/HitChams")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local PlayerController = require("@feature/player/PlayerController")
local botSource = require("@game/overkill/feature/training/botSource")
local gameUi = require("@game/gameUi")

local Hitchams = {}

function Hitchams.new(link: gameUi.Linker): UniversalHitChams.Hitchams
	return UniversalHitChams.new(link, {
		connectHit = function(handler: (player: Player) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player): ()
				handler(player)
			end))
		end,
		resolve = function(player: any): any
			return PlayerController.Get(player) or botSource.GetByPlayer(player)
		end,
	})
end

return Hitchams
