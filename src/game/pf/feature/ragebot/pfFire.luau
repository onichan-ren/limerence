local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local NetworkController = require("@game/pf/network/NetworkController")
local ModuleController = require("@game/pf/module/ModuleController")
local WeaponController = require("@game/pf/weapon/WeaponController")

local DEFAULT_LIFE = 5

local PHYSICS_IGNORE_NAMES = { "Players", "Terrain", "Ignore" }

export type Shot = {
	dir: Vector3,
}

local pfFire = {
	_clock = nil :: any,
	_bullets = nil :: any,
	_hitDetection = nil :: any,
	_effects = nil :: any,
	_publicSettings = nil :: any,
	_fireRound = nil :: any,
	_ticketIndex = nil :: number?,
	_fallback = 0,
}

local function gameClock(): any
	if not pfFire._clock then
		pfFire._clock = ModuleController.GetModule("GameClock")
	end
	return pfFire._clock
end

local function bulletInterface(): any
	if not pfFire._bullets then
		pfFire._bullets = ModuleController.GetModule("BulletInterface")
	end
	return pfFire._bullets
end

local function hitDetection(): any
	if not pfFire._hitDetection then
		pfFire._hitDetection = ModuleController.GetModule("HitDetectionInterface")
	end
	return pfFire._hitDetection
end

local function effectsModule(): any
	if not pfFire._effects then
		pfFire._effects = ModuleController.GetModule("Effects")
	end
	return pfFire._effects
end

local function bulletLife(): number
	if not pfFire._publicSettings then
		pfFire._publicSettings = ModuleController.GetModule("PublicSettings")
	end
	local life = pfFire._publicSettings and rawget(pfFire._publicSettings, "bulletLifeTime")
	return type(life) == "number" and life or DEFAULT_LIFE
end

local function physicsIgnore(): { Instance }
	local ignore = {}
	for i = 1, #PHYSICS_IGNORE_NAMES do
		local found = Workspace:FindFirstChild(PHYSICS_IGNORE_NAMES[i])
		if found then
			ignore[#ignore + 1] = found
		end
	end
	ignore[#ignore + 1] = Workspace.CurrentCamera :: Instance
	return ignore
end

local resolveTicketUpvalue = LPH_NO_VIRTUALIZE(function(): (any, number?)
	if pfFire._fireRound and pfFire._ticketIndex then
		return pfFire._fireRound, pfFire._ticketIndex
	end
	local FirearmObject = ModuleController.GetModule("FirearmObject")
	local fireRound = FirearmObject and rawget(FirearmObject, "fireRound")
	if type(fireRound) ~= "function" then
		return nil, nil
	end
	local ups = debug.getupvalues(fireRound)
	if type(ups) ~= "table" then
		return nil, nil
	end
	for index, value in next, ups do
		if type(value) == "number" then
			pfFire._fireRound = fireRound
			pfFire._ticketIndex = index
			return fireRound, index
		end
	end
	return nil, nil
end)

local function nextTicket(): number
	local fn, index = resolveTicketUpvalue()
	if fn and index then
		local current = debug.getupvalue(fn, index)
		if type(current) == "number" then
			current += 1
			debug.setupvalue(fn, index, current)
			return current
		end
	end
	pfFire._fallback += 1
	return pfFire._fallback
end

local onPlayerHit = LPH_NO_VIRTUALIZE(function(bullet: any, victim: any, part: any, partName: any, position: any, penetration: any): ()
	local hd = pfFire._hitDetection
	if not hd or not hd.playerHitDection then
		return
	end
	local hitList = bullet.extra.playersHit
	if hitList[victim] then
		return
	end
	hitList[victim] = true
	hd.playerHitDection(bullet, victim, part, partName, position, penetration)
end)

pfFire.fire = LPH_NO_VIRTUALIZE(function(firearm: any, cameraPos: Vector3, firePos: Vector3, shots: { Shot }): ()
	if not firearm or #shots == 0 then
		return
	end
	local clock = gameClock()
	local bi = bulletInterface()
	local hd = hitDetection()
	if not clock or not bi then
		return
	end
	local stats = WeaponController.GetLocalFireStats()
	if not stats then
		return
	end
	local gravity = WeaponController.GetGravity()
	local uniqueId = firearm.uniqueId
	local time = clock.getTime()
	local ignore = physicsIgnore()
	local life = bulletLife()

	local bullets = {}
	for i = 1, #shots do
		local dir = shots[i].dir
		local ticket = nextTicket()
		bullets[i] = { dir, ticket }
		bi.newBullet({
			size = 0.2,
			bloom = 0.005,
			position = firePos,
			velocity = stats.speed * dir,
			acceleration = stats.accel * dir + gravity,
			life = life,
			penetrationdepth = stats.penetration,
			visualorigin = firePos,
			physicsignore = ignore,
			onplayerhit = onPlayerHit,
			ontouch = hd and hd.hitDetection,
			extra = {
				playersHit = {},
				bulletTicket = ticket,
				firstHits = {},
				firearmObject = firearm,
				uniqueId = uniqueId,
			},
		})
	end

	NetworkController.Send("newbullets", uniqueId, {
		camerapos = cameraPos,
		firepos = firePos,
		bullets = bullets,
	}, time)
end)

pfFire.fireRage = LPH_NO_VIRTUALIZE(function(
	firearm: any,
	cameraPos: Vector3,
	firePos: Vector3,
	victim: Player,
	hitPart: Instance?,
	hitPos: Vector3,
	dir: Vector3,
	pellets: number,
	shootEffects: boolean
): ()
	if not firearm or pellets < 1 then
		return
	end
	local clock = gameClock()
	if not clock then
		return
	end
	local uniqueId = firearm.uniqueId
	local time = clock.getTime()
	local barrel = firearm._barrelPart

	local bullets = {}
	local tickets = {}
	for i = 1, pellets do
		local ticket = nextTicket()
		bullets[i] = { dir, ticket }
		tickets[i] = ticket
	end

	if shootEffects then
		local fx = effectsModule()
		if fx and fx.muzzleflash and typeof(barrel) == "Instance" then
			fx.muzzleflash(barrel, firearm:getWeaponStat("hideflash"), 0.9)
		end
	end

	NetworkController.SendHooked("newbullets", uniqueId, {
		camerapos = cameraPos,
		firepos = firePos,
		bullets = bullets,
	}, time)

	if typeof(victim) == "Instance" and victim.Parent then
		local id = getthreadidentity()
		setthreadidentity(8)
		for i = 1, #tickets do
			NetworkController.Send("bullethit", uniqueId, victim, hitPos, "Head", tickets[i], time)
		end
		setthreadidentity(id)
	end

	local damage = WeaponController.ComputeDamage(firearm, firePos, "Head", hitPos)
	local id = getthreadidentity()
	setthreadidentity(8)
	for _ = 1, pellets do
		WeaponController.hitPlayer:Fire(victim, hitPart, "Head", hitPos, damage, true)
	end
	setthreadidentity(id)
end)

return pfFire
