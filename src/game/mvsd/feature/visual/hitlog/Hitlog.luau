local DamageLog = require("@game/universal/feature/visual/damagelog/DamageLog")
local WeaponController = require("@game/mvsd/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local HIT_DEDUPE = 0.05

local function hitboxLabel(part: BasePart): string
	if string.find(part.Name, "Head") then
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
			body = "Shows a notification each time you hit an enemy, including the target, hitbox",
		},
		connect = function(emit: (text: string) -> ())
			local lastHit: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
			local connection = WeaponController.hitPlayer:Connect(
				function(player: Player, hitPart: BasePart, hitPosition: Vector3)
					if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") then
						return
					end

					if not player then
						return
					end

					local now = os.clock()
					local last = lastHit[player]
					if last and now - last < HIT_DEDUPE then
						return
					end
					lastHit[player] = now
					local label = hitboxLabel(hitPart)

					emit("Hit <hl>" .. nameOf(player) .. "</hl> in the <hl>" .. label .. "</hl>")
				end
			)
			return function()
				connection:Disconnect()
			end
		end,
	})
end

return HitLog
