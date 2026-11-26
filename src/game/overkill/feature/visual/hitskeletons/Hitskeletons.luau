local UniversalHitSkeletons = require("@game/universal/feature/visual/hitskeletons/HitSkeletons")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local PlayerController = require("@feature/player/PlayerController")
local botSource = require("@game/overkill/feature/training/botSource")
local gameUi = require("@game/gameUi")

local Hitskeletons = {}

function Hitskeletons.new(link: gameUi.Linker): UniversalHitSkeletons.Hitskeletons
	return UniversalHitSkeletons.new(link, {
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

return Hitskeletons
