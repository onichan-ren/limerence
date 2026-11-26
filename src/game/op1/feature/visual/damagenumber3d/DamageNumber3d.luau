local UniversalDamageNumber3d = require("@game/universal/feature/visual/damagenumber3d/DamageNumber3d")
local WeaponController = require("@game/op1/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local DamageNumber3d = {}

function DamageNumber3d.new(link: gameUi.Linker): UniversalDamageNumber3d.DamageNumber3d
	return UniversalDamageNumber3d.new(link, {
		connect = function(emit: (position: Vector3, amount: number, headshot: boolean) -> ())
			local connection = WeaponController.damageDealt:Connect(
				LPH_NO_VIRTUALIZE(function(_player: Player, _part: Instance, position: Vector3, damage: number, headshot: boolean, isEnemy: boolean): ()
					if not isEnemy or damage <= 0 then
						return
					end
					emit(position, math.floor(damage + 0.5), headshot)
				end)
			)
			return function(): ()
				connection:Disconnect()
			end
		end,
	})
end

return DamageNumber3d
