local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local DamageLog = require("@game/universal/feature/visual/damagelog/DamageLog")
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
local PlayerController = require("@feature/player/PlayerController")
local clientApi = require("@game/bloxstrike/client/clientApi")
local predictDamage = require("@game/bloxstrike/feature/legitbot/predictDamage")
local gameUi = require("@game/gameUi")

local HIT_DEDUPE = 0.05
local REJECT_WINDOW = 0.5

local function hitboxLabel(part: BasePart): string
	if string.find(part.Name, "Head") then
		return "head"
	end
	return "body"
end

local function nameOf(player: Player): string
	return player.DisplayName ~= "" and player.DisplayName or player.Name
end

local function damageFor(player: Player, part: BasePart): number?
	local weapon = clientApi.GetWeapon()
	local camera = Workspace.CurrentCamera
	if not weapon or not camera then
		return nil
	end
	local damage = predictDamage(camera.CFrame.Position, part, weapon, false, PlayerController.Get(player))
	if type(damage) ~= "number" or damage <= 0 then
		return nil
	end
	return math.floor(damage + 0.5)
end

local HitLog = {}

function HitLog.new(link: gameUi.Linker): DamageLog.DamageLog
	local optsLink: gameUi.Linker
	local log = DamageLog.new(link, {
		key = "hitLogs",
		label = "Shot Logs",
		tip = {
			title = "Shot Logs",
			body = "Shows a notification for your shots, including the target, hitbox, and estimated damage on hits.",
		},
		connect = function(emit: (text: string) -> ())
			local lastHit: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
			local pendingShots: { { target: Player, thread: thread } } = {}

			local resolvePending = LPH_NO_VIRTUALIZE(function(victim: Player?): ()
				for i = 1, #pendingShots do
					local entry = pendingShots[i]
					if victim == nil or entry.target == victim then
						task.cancel(entry.thread)
						table.remove(pendingShots, i)
						return
					end
				end
			end)

			local shotConnection = WeaponController.shotFired:Connect(
				LPH_NO_VIRTUALIZE(function(_, hitPlayer: Player?, ragebotTarget: Player?): ()
					if not ragebotTarget or not optsLink:Peek("logMisses") then
						return
					end
					if not hitPlayer then
						emit("Missed <hl>" .. nameOf(ragebotTarget) .. "</hl> due to <hl>spread</hl>")
						return
					end
					local entry = {} :: { target: Player, thread: thread }
					entry.target = hitPlayer
					entry.thread = task.delay(REJECT_WINDOW, function(): ()
						for i = 1, #pendingShots do
							if pendingShots[i] == entry then
								table.remove(pendingShots, i)
								break
							end
						end
						emit("Missed <hl>" .. nameOf(entry.target) .. "</hl> due to <hl>server rejection</hl>")
					end)
					pendingShots[#pendingShots + 1] = entry
				end)
			)

			local confirmConnection = WeaponController.serverHitConfirmed:Connect(
				LPH_NO_VIRTUALIZE(function(victim: Player?, part: BasePart?): ()
					resolvePending(victim)
					if not victim or not optsLink:Peek("logHits") then
						return
					end
					local now = os.clock()
					local last = lastHit[victim]
					if last and now - last < HIT_DEDUPE then
						return
					end
					lastHit[victim] = now
					local label = part and hitboxLabel(part) or "body"
					local damage = part and damageFor(victim, part)
					if damage then
						emit(
							"Hit <hl>"
								.. nameOf(victim)
								.. "</hl> in the <hl>"
								.. label
								.. "</hl> for <hl>"
								.. damage
								.. "</hl>"
						)
					else
						emit("Hit <hl>" .. nameOf(victim) .. "</hl> in the <hl>" .. label .. "</hl>")
					end
				end)
			)

			local killConnection = WeaponController.killedPlayer:Connect(LPH_NO_VIRTUALIZE(function(victim: Player): ()
				resolvePending(victim)
			end))

			return function()
				shotConnection:Disconnect()
				confirmConnection:Disconnect()
				killConnection:Disconnect()
				for i = #pendingShots, 1, -1 do
					task.cancel(pendingShots[i].thread)
					pendingShots[i] = nil
				end
			end
		end,
	})

	local toggle = link:Get("hitLogs")
	link:Extra(toggle, "shotLogOpts", "Submenu", "Shot Log Options")
	optsLink = link:OnKey("shotLogOpts")
	optsLink:Toggle("logMisses", "Log Misses", true):SetTip({
		title = "Log Misses",
		body = "Shows a notification when a ragebot shot misses, including the target and reason. Covers spread misses and shots the server did not register.",
	})
	optsLink:Toggle("logHits", "Log Hits", true):SetTip({
		title = "Log Hits",
		body = "Shows a notification when a shot hits an enemy, including the target, hitbox, and estimated damage.",
	})

	return log
end

return HitLog
