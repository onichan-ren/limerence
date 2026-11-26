local UniversalHitmarker3d = require("@game/universal/feature/visual/hitmarker3d/Hitmarker3d")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local Hitmarker3d = {}

function Hitmarker3d.new(link: gameUi.Linker): UniversalHitmarker3d.Hitmarker3d
	return UniversalHitmarker3d.new(link, {
		headshotBody = "Color for critical hits.",
		connect = function(emit: (position: Vector3, headshot: boolean) -> ())
			return WeaponController.hitTarget:Connect(LPH_NO_VIRTUALIZE(function(_model: Model, part: BasePart): ()
				emit(part.Position, string.find(part.Name, "Head") ~= nil)
			end))
		end,
	})
end

return Hitmarker3d
