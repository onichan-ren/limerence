local ModuleController = require("@game/pf/module/ModuleController")
local hook = require("@share/hook")

local VALID_PARTS = {
	Head = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

local TICKET_TTL = 6
local HEAD_RADIUS = 0.9

export type EnableOpts = {
	getTracks: () -> any,
	folder: Instance,
}

local backtrackHit = {
	_active = false,
	_installed = false,
	_getTracks = nil :: (() -> any)?,
	_folder = nil :: Instance?,
	_hitDetection = nil :: any,
	_ticketCache = {} :: { [any]: number },
}

local function getHitDetection(): any
	if not backtrackHit._hitDetection then
		backtrackHit._hitDetection = ModuleController.GetModule("HitDetectionInterface")
	end
	return backtrackHit._hitDetection
end

local resolveOwner = LPH_NO_VIRTUALIZE(function(part: Instance, position: Vector3): (Player?, string?)
	local getTracks = backtrackHit._getTracks
	if not getTracks then
		return nil, nil
	end
	local tracks = getTracks()
	if not tracks then
		return nil, nil
	end
	for player, track in next, tracks do
		local ghost = track.ghost
		if ghost and track.historyValid and part:IsDescendantOf(ghost) then
			local ghostParts = track.ghostParts
			local headPart = ghostParts and ghostParts["Head"]
			if
				headPart
				and typeof(position) == "Vector3"
				and (position - headPart.Position).Magnitude <= HEAD_RADIUS
			then
				return player, "Head"
			end
			return player, "Torso"
		end
	end
	return nil, nil
end)

local onTouchBacktrack = LPH_NO_VIRTUALIZE(function(bullet: any, part: any, position: any): boolean
	if not backtrackHit._active then
		return false
	end
	local folder = backtrackHit._folder
	if not folder or typeof(part) ~= "Instance" or not part:IsDescendantOf(folder) then
		return false
	end
	local extra = bullet and bullet.extra
	local ticket = extra and extra.bulletTicket
	if ticket == nil or backtrackHit._ticketCache[ticket] then
		return false
	end
	local player, partName = resolveOwner(part, position)
	if not player then
		return false
	end
	if not VALID_PARTS[partName] then
		partName = "Torso"
	end
	local hitDetection = getHitDetection()
	if not hitDetection or type(hitDetection.playerHitDection) ~= "function" then
		return false
	end
	backtrackHit._ticketCache[ticket] = os.clock()
	local id = getthreadidentity()
	setthreadidentity(8)
	hitDetection.playerHitDection(bullet, player, part, partName, position, false)
	setthreadidentity(id)
	return true
end)

local function install(): ()
	if backtrackHit._installed then
		return
	end
	local bullets = ModuleController.GetModule("BulletInterface")
	if not bullets or type(bullets.newBullet) ~= "function" then
		return
	end
	backtrackHit._installed = true

	local origNewBullet
	origNewBullet = hook.add(bullets.newBullet, LPH_NO_VIRTUALIZE(function(bulletData: any): any
		if backtrackHit._active and type(bulletData) == "table" and bulletData.extra then
			local origOnTouch = bulletData.ontouch
			bulletData.ontouch = function(self: any, part: any, position: any, normal: any, exit: any, exitNormal: any): ...any
				if onTouchBacktrack(self, part, position) then
					return
				end
				if origOnTouch then
					return origOnTouch(self, part, position, normal, exit, exitNormal)
				end
				return
			end
		end
		return origNewBullet(bulletData)
	end))
end

function backtrackHit.enable(opts: EnableOpts): ()
	backtrackHit._getTracks = opts.getTracks
	backtrackHit._folder = opts.folder
	install()
	backtrackHit._active = true
end

function backtrackHit.prune(now: number): ()
	local cache = backtrackHit._ticketCache
	for ticket, at in next, cache do
		if now - at > TICKET_TTL then
			cache[ticket] = nil
		end
	end
end

function backtrackHit.disable(): ()
	backtrackHit._active = false
	backtrackHit._getTracks = nil
	backtrackHit._folder = nil
	table.clear(backtrackHit._ticketCache)
end

return backtrackHit
