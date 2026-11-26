local DamageLog = require("@game/universal/feature/visual/damagelog/DamageLog")
local WeaponController = require("@game/pf/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local HIT_DEDUPE = 0.05

local function hitboxLabel(partName: string): string
	if string.find(partName, "Head") then
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
			body = "Shows a notification each time you hit an enemy, including the target, hitbox, and estimated damage.",
		},
		connect = function(emit: (text: string) -> ())
			local lastHit: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
			local connection = WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player, _part: Instance, partName: string, _position: Vector3, damage: number, _headshot: boolean): ()
				local now = os.clock()
				local last = lastHit[player]
				if last and now - last < HIT_DEDUPE then
					return
				end
				lastHit[player] = now
				local label = hitboxLabel(partName)
				if damage > 0 then
					emit("Hit <hl>" .. nameOf(player) .. "</hl> in the <hl>" .. label .. "</hl> for <hl>" .. math.floor(damage + 0.5) .. "</hl>")
				else
					emit("Hit <hl>" .. nameOf(player) .. "</hl> in the <hl>" .. label .. "</hl>")
				end
			end))
			return function()
				connection:Disconnect()
			end
		end,
	})
end

return HitLog
