local DamageLog = require("@game/universal/feature/visual/damagelog/DamageLog")
local WeaponController = require("@game/op1/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local HEAD_PART = "head"

local function hitboxLabel(part: Instance): string
	if part.Name == HEAD_PART then
		return "head"
	end
	return "body"
end

local function nameOf(player: Player): string
	return player.DisplayName ~= "" and player.DisplayName or player.Name
end

local HitLog = {}

function HitLog.new(link: gameUi.Linker): DamageLog.DamageLog
	return DamageLog.new(link, {
		key = "hitLogs",
		label = "Hit Logs",
		tip = {
			title = "Hit Logs",
			body = "Shows a notification each time you hit an enemy, including the target and hitbox.",
		},
		connect = function(emit: (text: string) -> ())
			local connection = WeaponController.damageDealt:Connect(
				LPH_NO_VIRTUALIZE(function(player: Player, part: Instance, _position: Vector3, damage: number, _headshot: boolean, isEnemy: boolean): ()
					if not isEnemy then
						return
					end
					emit(
						"Hit <hl>"
							.. nameOf(player)
							.. "</hl> in the <hl>"
							.. hitboxLabel(part)
							.. "</hl> for <hl>"
							.. tostring(math.floor(damage + 0.5))
							.. "</hl>"
					)
				end)
			)
			return function(): ()
				connection:Disconnect()
			end
		end,
	})
end

return HitLog
