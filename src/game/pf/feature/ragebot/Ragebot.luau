local RunService = cloneref(game:GetService("RunService")) :: RunService

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local ModuleController = require("@game/pf/module/ModuleController")
local NetworkController = require("@game/pf/network/NetworkController")
local repupdateBypass = require("@game/pf/network/repupdateBypass")
local PlayerController = require("@feature/player/PlayerController")
local WeaponController = require("@game/pf/weapon/WeaponController")
local SessionController = require("@feature/session/SessionController")
local pfFire = require("@game/pf/feature/ragebot/pfFire")
local pfBallistics = require("@game/pf/feature/ragebot/pfBallistics")

local pfScan = pfBallistics.scan

local DEFAULT_INTERVAL = 0.03
local NO_TARGET_INTERVAL = 0.02
local BLOCKED_RESCAN_INTERVAL = 0.1

local FIRE_OFFSET = 15.9
local HIT_OFFSET = 10

local function byDist(a: any, b: any): boolean
	return a.dist < b.dist
end

local Ragebot = {}
Ragebot.__index = Ragebot

setmetatable(Ragebot, { __index = BaseFeature })

function Ragebot.new(link: gameUi.Linker): Ragebot
	local self = BaseFeature.new() :: any
	setmetatable(self, Ragebot)

	link:Toggle("enabled", "Enable Ragebot", false):SetTip({
		title = "Enable Ragebot",
		body = "Automatically fires at the closest enemy you can hit.",
	})

	self._running = false
	self._janitor = Janitor.new()
	self._nextShot = 0
	self._origin = nil :: Vector3?
	self._interface = nil :: any
	self._predicted = {} :: { [Player]: number }
	self._blockedUntil = {} :: { [Player]: number }
	self._comboHint = {} :: { [Player]: number }
	self._forced = nil :: Player?
	self._weaponUtils = nil :: any
	self._roundSystem = nil :: any
	self._gameClock = nil :: any

	local cache = {
		enabled = link:Peek("enabled") == true,
	}
	self._cache = cache

	self:Track(link:Get("enabled"):OnChange(function(value: boolean): ()
		cache.enabled = value == true
		self:_setRunning(cache.enabled)
	end))

	if cache.enabled then
		self:_setRunning(true)
	end

	return self
end

function Ragebot._entryHealth(self: Ragebot, entry: any): number
	local getHealth = entry.getHealth
	if type(getHealth) ~= "function" then
		return 0
	end
	local health = getHealth(entry)
	return type(health) == "number" and health or 0
end

function Ragebot._getClosest(self: Ragebot, origin: Vector3, preventOverfire: boolean): { any }
	local iface = self._interface or ModuleController.GetModule("ReplicationInterface")
	self._interface = iface
	local out = {}
	if not iface then
		return out
	end
	local predicted = self._predicted
	for player in next, PlayerController.GetAll() do
		local entry = iface.getEntry(player)
		if
			entry
			and entry._alive
			and entry._isEnemy
			and entry._receivedPosition
			and entry._velspring
			and entry._velspring.t
		then
			local tpo = entry._thirdPersonObject
			local hash = tpo and tpo._characterModelHash
			local head = hash and hash.Head
			if head then
				local health = self:_entryHealth(entry)
				if not (preventOverfire and health > 0 and (predicted[player] or 0) >= health) then
					out[#out + 1] = {
						player = player,
						entry = entry,
						head = head,
						health = health,
						dist = (head.Position - origin).Magnitude,
					}
				end
			end
		end
	end
	table.sort(out, byDist)
	return out
end

function Ragebot._computeDamage(self: Ragebot, firearm: any, distance: number, pellets: number): number
	local utils = self._weaponUtils
	if not utils then
		utils = ModuleController.GetModule("WeaponUtils")
		self._weaponUtils = utils
	end
	if not utils then
		return 0
	end
	local graph = firearm:getWeaponStat("damageGraph")
	if type(graph) ~= "table" then
		return 0
	end
	local base = utils.interpolateDamageGraph(graph, distance)
	if type(base) ~= "number" then
		return 0
	end
	local mult = firearm:getWeaponStat("multhead")
	if type(mult) ~= "number" then
		mult = 1
	end
	return math.floor(base * mult * pellets)
end

function Ragebot._trackDamage(self: Ragebot, firearm: any, candidate: any, best: any, pellets: number): ()
	local damage = self:_computeDamage(firearm, best.dist, pellets)
	if damage <= 0 then
		self._forced = nil
		return
	end
	local key = candidate.player
	local predicted = self._predicted
	local total = (predicted[key] or 0) + damage
	predicted[key] = total

	local life = (SessionController.GetPing() / 1000) + (best.flight or 0)
	task.delay(life, function(): ()
		local current = predicted[key]
		if current then
			current -= damage
			predicted[key] = (current > 0) and current or nil
		end
	end)

	if total < candidate.health then
		self._forced = key
	else
		self._forced = nil
	end
end

function Ragebot._run(self: Ragebot, firearm: any): ()
	local now = os.clock()
	local origin = self._origin
	if typeof(origin) ~= "Vector3" then
		return
	end
	local sent = repupdateBypass.getSentPosition()
	if sent then
		origin = sent
	end

	local speed = firearm:getWeaponStat("bulletspeed")
	if type(speed) ~= "number" or speed <= 0 then
		return
	end
	local penetration = firearm:getWeaponStat("penetrationdepth")
	if type(penetration) ~= "number" then
		return
	end

	local magCount = firearm._magCount
	local spareCount = firearm._spareCount
	if type(magCount) ~= "number" or type(spareCount) ~= "number" then
		return
	end
	if magCount <= 0 and spareCount <= 0 then
		return
	end

	local gameClock = self._gameClock
	if not gameClock then
		gameClock = ModuleController.GetModule("GameClock")
		self._gameClock = gameClock
	end
	if not gameClock then
		return
	end
	local gameTime = gameClock.getTime()
	local weaponNext = firearm._nextShot
	if type(weaponNext) == "number" and gameTime < weaponNext then
		return
	end

	local gravity = WeaponController.GetGravity()
	local fireOffset = FIRE_OFFSET
	local hitOffset = HIT_OFFSET

	local candidates = self:_getClosest(origin, true)
	if #candidates == 0 then
		self._forced = nil
		self._nextShot = now + NO_TARGET_INTERVAL
		return
	end

	if self._forced then
		local found = false
		for i = 1, #candidates do
			if candidates[i].player == self._forced then
				if i > 1 then
					local forced = table.remove(candidates, i)
					table.insert(candidates, 1, forced)
				end
				found = true
				break
			end
		end
		if not found then
			self._forced = nil
		end
	end

	local blocked = self._blockedUntil
	local hints = self._comboHint

	for i = 1, #candidates do
		local candidate = candidates[i]
		local player = candidate.player
		local entry = candidate.entry
		local best
		if (blocked[player] or 0) > now then
			best = pfScan(origin, entry._receivedPosition, gravity, speed, penetration, fireOffset, 0, nil, nil, true)
			if best then
				blocked[player] = nil
			end
		else
			local hint = hints[player]
			local hintO, hintT
			if hint then
				hintO = hint // 256
				hintT = hint % 256
			end
			best = pfScan(
				origin,
				entry._receivedPosition,
				gravity,
				speed,
				penetration,
				fireOffset,
				hitOffset,
				hintO,
				hintT
			)
			if not best then
				blocked[player] = now + BLOCKED_RESCAN_INTERVAL
				hints[player] = nil
			end
		end
		if best then
			hints[player] = best.oi * 256 + best.ti

			if firearm._magCount < 1 then
				local magsize = firearm:getWeaponStat("magsize") or 0
				if firearm._spareCount >= magsize then
					firearm._magCount = magsize
					firearm._spareCount = firearm._spareCount - magsize
				else
					firearm._magCount = firearm._spareCount
					firearm._spareCount = 0
				end
				NetworkController.Send("reload")
			end

			local pellets = firearm:getWeaponStat("pelletcount") or 1
			pfFire.fireRage(
				firearm,
				origin,
				best.o,
				candidate.player,
				candidate.head,
				best.hit,
				best.dir,
				pellets,
				true
			)

			firearm._magCount = math.max(0, firearm._magCount - 1)

			self:_trackDamage(firearm, candidate, best, pellets)

			local data = firearm._weaponData
			local fr: any = data and data.firerate
			if data and data.variablefirerate and type(fr) == "table" then
				fr = fr[firearm._firemodeIndex] or fr[1]
			end
			local interval = ((type(fr) == "number" and fr > 0) and 60 / fr) or DEFAULT_INTERVAL
			firearm._nextShot = (type(weaponNext) == "number" and math.max(weaponNext, gameTime) or gameTime) + interval
			local nextShot = self._nextShot + interval
			if nextShot < now - interval then
				nextShot = now + interval
			end
			self._nextShot = nextShot
			return
		end
	end

	self._nextShot = now + NO_TARGET_INTERVAL
end

Ragebot._tick = LPH_NO_VIRTUALIZE(function(self: Ragebot): ()
	if not self._cache.enabled then
		return
	end
	if os.clock() < self._nextShot then
		return
	end
	if typeof(self._origin) ~= "Vector3" then
		return
	end
	local roundSystem = self._roundSystem
	if not roundSystem then
		roundSystem = ModuleController.GetModule("RoundSystemClientInterface")
		self._roundSystem = roundSystem
	end
	if roundSystem and rawget(roundSystem, "roundLock") then
		return
	end
	if WeaponController.GetWeaponType() ~= "Firearm" then
		return
	end
	local firearm = WeaponController.GetWeapon()
	if not firearm then
		return
	end

	setthreadidentity(8)
	self:_run(firearm)
end)

function Ragebot._setRunning(self: Ragebot, run: boolean): ()
	if run == self._running then
		return
	end
	self._running = run
	if run then
		self._origin = nil
		self._janitor:Add(
			NetworkController.HookOutbound(
				"repupdate",
				LPH_NO_VIRTUALIZE(function(position: any): ()
					if typeof(position) == "Vector3" then
						self._origin = position
					end
				end)
			),
			true
		)
		self._janitor:Add(
			RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
				self:_tick()
			end)),
			"Disconnect"
		)
	else
		self._janitor:Cleanup()
		self._nextShot = 0
		self._origin = nil
		self._forced = nil
		table.clear(self._predicted)
		table.clear(self._blockedUntil)
		table.clear(self._comboHint)
	end
end

function Ragebot.Destroy(self: Ragebot): ()
	self:_setRunning(false)
	self._interface = nil
	self._roundSystem = nil
	self._gameClock = nil
	BaseFeature.Destroy(self)
end

export type Ragebot =
	typeof(setmetatable(
		{} :: {
			_running: boolean,
			_janitor: Janitor.Janitor,
			_nextShot: number,
			_origin: Vector3?,
			_interface: any,
			_cache: any,
			_predicted: { [Player]: number },
			_blockedUntil: { [Player]: number },
			_comboHint: { [Player]: number },
			_forced: Player?,
			_weaponUtils: any,
			_roundSystem: any,
			_gameClock: any,
			_entryHealth: (Ragebot, any) -> number,
			_getClosest: (Ragebot, Vector3, boolean) -> { any },
			_computeDamage: (Ragebot, any, number, number) -> number,
			_trackDamage: (Ragebot, any, any, any, number) -> (),
			_run: (Ragebot, any) -> (),
			_tick: (Ragebot) -> (),
			_setRunning: (Ragebot, boolean) -> (),
		},
		Ragebot
	))
	& BaseFeature.BaseFeature

return Ragebot
