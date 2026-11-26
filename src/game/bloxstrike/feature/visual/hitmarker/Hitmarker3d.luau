local UniversalHitmarker3d = require("@game/universal/feature/visual/hitmarker3d/Hitmarker3d")
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local Hitmarker3d = {}

function Hitmarker3d.new(link: gameUi.Linker): UniversalHitmarker3d.Hitmarker3d
	return UniversalHitmarker3d.new(link, {
		connect = function(emit: (position: Vector3, headshot: boolean) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(_player: Player, part: Instance): ()
				if part:IsA("BasePart") then
					emit(part.Position, part.Name == "Head")
				end
			end))
		end,
	})
end

return Hitmarker3d
