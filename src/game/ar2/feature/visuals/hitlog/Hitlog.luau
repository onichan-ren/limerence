local DamageLog = require("@game/universal/feature/visual/damagelog/DamageLog")
local WeaponController = require("@game/ar2/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local HIT_DEDUPE = 0.05
local CONFIRM_WINDOW = 0.75
local INVALID_ACCENT = Color3.fromRGB(235, 80, 80)

local function hitboxLabel(part: BasePart): string
	if string.find(part.Name, "Head") then
		return "head"
	end
	return "body"
end

local function nameOf(player: Player): string
	return player.DisplayName ~= "" and player.DisplayName or player.Name
end

type PendingClaim = {
	player: Player,
	shotId: number,
	label: string,
	confirmed: boolean,
	thread: thread,
}

local HitLog = {}

function HitLog.new(link: gameUi.Linker): DamageLog.DamageLog
	local optsLink: gameUi.Linker
	local log = DamageLog.new(link, {
		key = "hitLogs",
		label = "Shot Logs",
		tip = {
			title = "Shot Logs",
			body = "Shows a notification for your shots, including the target, hitbox, and damage on hits.",
		},
		connect = function(emit: (text: string, accent: Color3?) -> ())
			local lastHit: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
			local pending: { PendingClaim } = {}

			local claimConn = WeaponController.shotClaimed:Connect(
				function(player: Player, hitPart: BasePart, shotId: number)
					for i = 1, #pending do
						local existing = pending[i]
						if existing.shotId == shotId and existing.player == player then
							return
						end
					end

					local entry = {} :: PendingClaim
					entry.player = player
					entry.shotId = shotId
					entry.label = hitboxLabel(hitPart)
					entry.confirmed = false
					entry.thread = task.delay(CONFIRM_WINDOW, function(): ()
						local idx = table.find(pending, entry)
						if idx then
							table.remove(pending, idx)
						end
						if not entry.confirmed and optsLink:Peek("logInvalid") then
							emit("Shot on <hl>" .. nameOf(player) .. "</hl> did not register", INVALID_ACCENT)
						end
					end)
					pending[#pending + 1] = entry
				end
			)

			local damageConn = WeaponController.gameDamaged:Connect(function(victim: Player, damage: number): ()
				for i = 1, #pending do
					local entry = pending[i]
					if entry.player == victim and not entry.confirmed then
						entry.confirmed = true
						task.cancel(entry.thread)
						table.remove(pending, i)

						if not optsLink:Peek("logHits") then
							return
						end
						local now = os.clock()
						local last = lastHit[victim]
						if last and now - last < HIT_DEDUPE then
							return
						end
						lastHit[victim] = now

						emit(
							"Hit <hl>"
								.. nameOf(victim)
								.. "</hl> in the <hl>"
								.. entry.label
								.. "</hl> for <hl>"
								.. math.floor(damage + 0.5)
								.. "</hl>"
						)
						return
					end
				end
			end)

			return function()
				claimConn:Disconnect()
				damageConn:Disconnect()
				for i = #pending, 1, -1 do
					task.cancel(pending[i].thread)
					pending[i] = nil
				end
			end
		end,
	})

	local toggle = link:Get("hitLogs")
	link:Extra(toggle, "shotLogOpts", "Submenu", "Shot Log Options")
	optsLink = link:OnKey("shotLogOpts")
	optsLink:Toggle("logInvalid", "Log Invalid", false):SetTip({
		title = "Log Invalid",
		body = "Shows a notification when a shot lands on your screen but the server does not register it.",
	})
	optsLink:Toggle("logHits", "Log Hits", true):SetTip({
		title = "Log Hits",
		body = "Shows a notification when the server registers your shot on an enemy, including the target, hitbox, and damage.",
	})

	return log
end

return HitLog
