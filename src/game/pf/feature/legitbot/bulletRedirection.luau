local ModuleController = require("@game/pf/module/ModuleController")
local NetworkController = require("@game/pf/network/NetworkController")
local WeaponController = require("@game/pf/weapon/WeaponController")
local hook = require("@share/hook")

local RunService = cloneref(game:GetService("RunService")) :: RunService

local ENTRY_TTL = 2
local VEL_SMOOTH_RATE = 18
local VEL_DT_MAX = 0.2
local VEL_TELEPORT_SPEED = 400
local SOLVE_ITERATIONS = 4

local bulletRedirection = {
	_active = false,
	_target = nil :: { position: Vector3, player: any?, part: any? }?,
	_chance = 100,
	_tickets = {} :: { [any]: { dir: Vector3, time: number } },
	_hooked = false,
	_packetUnhook = nil :: (() -> ())?,
	_velConn = nil :: RBXScriptConnection?,
	_trackedPart = nil :: any,
	_prevPos = nil :: Vector3?,
	_prevClock = 0,
	_velocity = Vector3.zero,
}

local roll = LPH_NO_VIRTUALIZE(function(chance: number): boolean
	if chance >= 100 then
		return true
	end
	if chance <= 0 then
		return false
	end
	return math.random(1, 100) <= chance
end)

local prune = LPH_NO_VIRTUALIZE(function(now: number): ()
	local tickets = bulletRedirection._tickets
	for id, entry in next, tickets do
		if now - entry.time > ENTRY_TTL then
			tickets[id] = nil
		end
	end
end)

local function liveTargetPos(): Vector3?
	local target = bulletRedirection._target
	if not target then
		return nil
	end
	local part = target.part
	if part and part.Parent then
		return part.Position
	end
	if typeof(target.position) == "Vector3" then
		return target.position
	end
	return nil
end

local trackVelocity = LPH_NO_VIRTUALIZE(function(): ()
	local target = bulletRedirection._target
	local part = target and target.part
	if part ~= bulletRedirection._trackedPart then
		bulletRedirection._trackedPart = part
		bulletRedirection._prevPos = nil
		bulletRedirection._velocity = Vector3.zero
	end

	local pos = liveTargetPos()
	if not pos then
		return
	end

	local now = os.clock()
	local prev = bulletRedirection._prevPos
	if prev then
		local dt = now - bulletRedirection._prevClock
		if dt > 1e-4 then
			if dt > VEL_DT_MAX then
				bulletRedirection._velocity = Vector3.zero
			else
				local instant = (pos - prev) / dt
				if instant.Magnitude > VEL_TELEPORT_SPEED then
					bulletRedirection._velocity = Vector3.zero
				else
					local alpha = 1 - math.exp(-dt * VEL_SMOOTH_RATE)
					bulletRedirection._velocity = bulletRedirection._velocity
						+ (instant - bulletRedirection._velocity) * alpha
				end
			end
		end
	end
	bulletRedirection._prevPos = pos
	bulletRedirection._prevClock = now
end)

local solveAim = LPH_NO_VIRTUALIZE(
	function(origin: Vector3, targetPos: Vector3, vel: Vector3, grav: Vector3, speed: number): Vector3
		local t = (targetPos - origin).Magnitude / speed
		for _ = 1, SOLVE_ITERATIONS do
			local future = targetPos + vel * t
			local desired = future - origin - 0.5 * grav * t * t
			t = desired.Magnitude / speed
		end
		return targetPos + vel * t - 0.5 * grav * t * t
	end
)

local redirectBullet = LPH_NO_VIRTUALIZE(function(params: any): ()
	if not bulletRedirection._active or not bulletRedirection._target then
		return
	end

	local extra = params.extra
	if not extra or extra.firearmObject ~= WeaponController.GetWeapon() then
		return
	end

	local origin = params.position
	local velocity = params.velocity
	if typeof(origin) ~= "Vector3" or typeof(velocity) ~= "Vector3" then
		return
	end

	local speed = velocity.Magnitude
	if speed < 1e-3 then
		return
	end

	if not roll(bulletRedirection._chance) then
		return
	end

	local targetPos = liveTargetPos()
	if not targetPos then
		return
	end
	local aimVel = bulletRedirection._velocity

	local oldUnit = velocity.Unit
	local accel = params.acceleration
	local forward = 0
	local grav = Vector3.zero
	if typeof(accel) == "Vector3" then
		forward = accel:Dot(oldUnit)
		grav = accel - oldUnit * forward
	end

	local aim = solveAim(origin, targetPos, aimVel, grav, speed)
	local toAim = aim - origin
	if toAim.Magnitude < 1e-3 then
		return
	end
	local newUnit = toAim.Unit

	params.velocity = speed * newUnit
	if typeof(accel) == "Vector3" then
		params.acceleration = newUnit * forward + grav
	end

	local ticket = extra.bulletTicket
	if ticket ~= nil then
		local now = os.clock()
		prune(now)
		bulletRedirection._tickets[ticket] = { dir = newUnit, time = now }
	end
end)

local onNewBullets = LPH_NO_VIRTUALIZE(function(_uniqueId: any, payload: any, _sendTime: any): (boolean?, { any }?)
	if type(payload) ~= "table" then
		return true
	end
	local bullets = payload.bullets
	if type(bullets) ~= "table" then
		return true
	end
	local tickets = bulletRedirection._tickets
	for _, bullet in next, bullets do
		if type(bullet) == "table" then
			local entry = tickets[bullet[2]]
			if entry then
				bullet[1] = entry.dir
			end
		end
	end
	return true
end)

local function ensureHooks(): ()
	if not bulletRedirection._hooked then
		local bulletInterface = ModuleController.GetModule("BulletInterface")
		if not bulletInterface then
			return
		end
		bulletRedirection._hooked = true

		local original
		original = hook.add(
			bulletInterface.newBullet,
			LPH_NO_VIRTUALIZE(function(params: any): any
				redirectBullet(params)
				return original(params)
			end)
		)
	end

	bulletRedirection._packetUnhook = NetworkController.HookOutbound("newbullets", onNewBullets, true)
	bulletRedirection._velConn = RunService.Heartbeat:Connect(trackVelocity)
end

local function restoreHooks(): ()
	if bulletRedirection._packetUnhook then
		bulletRedirection._packetUnhook()
		bulletRedirection._packetUnhook = nil
	end
	if bulletRedirection._velConn then
		bulletRedirection._velConn:Disconnect()
		bulletRedirection._velConn = nil
	end
end

function bulletRedirection.setActive(active: boolean): ()
	if bulletRedirection._active == active then
		return
	end
	bulletRedirection._active = active
	if active then
		ensureHooks()
	else
		bulletRedirection._target = nil
		bulletRedirection._trackedPart = nil
		bulletRedirection._prevPos = nil
		bulletRedirection._velocity = Vector3.zero
		table.clear(bulletRedirection._tickets)
		restoreHooks()
	end
end

function bulletRedirection.setTarget(target: { position: Vector3, player: any?, part: any? }?): ()
	bulletRedirection._target = target
end

function bulletRedirection.setChance(chance: number): ()
	bulletRedirection._chance = chance
end

return bulletRedirection
