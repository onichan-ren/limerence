local bulletPenetrationRay = require("@game/bloxstrike/feature/legitbot/bulletPenetrationRay")

return LPH_NO_VIRTUALIZE(function()
	local CACHE_TTL = 1 / 90
	local CACHE_CAP = 192

	local _cache: { [string]: { result: boolean | number, t: number } } = {}
	local _cacheCount = 0

	local _debugIds: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any

	local function getDebugId(inst: Instance): string
		local id = _debugIds[inst]
		if not id then
			id = inst:GetDebugId()
			_debugIds[inst] = id
		end
		return id
	end

	local function snap8(n: number): number
		return math.floor(n * 8 + 0.5) / 8
	end

	local function ignoreFingerprint(ignoreRoots: { Instance }): string
		local n = #ignoreRoots
		local a = ""
		for i = 1, math.min(n, 6) do
			local inst = ignoreRoots[i]
			if inst then
				a ..= getDebugId(inst)
			else
				a ..= "_"
			end
			a ..= ";"
		end
		return `{n}:{a}`
	end

	local function makeKey(
		origin: Vector3,
		targetPart: BasePart,
		penetration: number,
		maxRange: number,
		ignoreRoots: { Instance },
		targetPos: Vector3?
	): string
		local ox = snap8(origin.X)
		local oy = snap8(origin.Y)
		local oz = snap8(origin.Z)
		local tp = ""
		if targetPos then
			tp = `{snap8(targetPos.X)},{snap8(targetPos.Y)},{snap8(targetPos.Z)}|`
		end
		return `{ox}|{oy}|{oz}|{tp}{getDebugId(targetPart)}|{penetration}|{maxRange}|{ignoreFingerprint(ignoreRoots)}`
	end

	local function pruneIfNeeded(): ()
		if _cacheCount <= CACHE_CAP then
			return
		end
		local now = os.clock()
		for k, v in next, _cache do
			if now - v.t > CACHE_TTL * 4 then
				_cache[k] = nil
				_cacheCount -= 1
			end
		end
	end

	local penetrationQuery = {}

	function penetrationQuery.beginStep(): ()
		table.clear(_cache)
		_cacheCount = 0
	end

	function penetrationQuery.clear(): ()
		table.clear(_cache)
		_cacheCount = 0
	end

	function penetrationQuery.reachThroughWalls(
		origin: Vector3,
		targetPart: BasePart,
		penetration: number,
		maxRange: number,
		ignoreRoots: { Instance },
		trace: boolean?,
		targetPos: Vector3?
	): boolean
		if trace then
			return bulletPenetrationRay.reachThroughWalls(
				origin,
				targetPart,
				penetration,
				maxRange,
				ignoreRoots,
				true,
				targetPos
			)
		end
		local key = makeKey(origin, targetPart, penetration, maxRange, ignoreRoots, targetPos)
		local now = os.clock()
		local slot = _cache[key]
		if slot and (now - slot.t) < CACHE_TTL then
			return slot.result
		end
		local r =
			bulletPenetrationRay.reachThroughWalls(origin, targetPart, penetration, maxRange, ignoreRoots, false, targetPos)
		if slot == nil then
			_cacheCount += 1
		end
		_cache[key] = { result = r, t = now }
		pruneIfNeeded()
		return r
	end

	function penetrationQuery.countWalls(
		origin: Vector3,
		targetPart: BasePart,
		penetration: number,
		maxRange: number,
		ignoreRoots: { Instance },
		targetPos: Vector3?
	): number
		local key = "w|" .. makeKey(origin, targetPart, penetration, maxRange, ignoreRoots, targetPos)
		local now = os.clock()
		local slot = _cache[key]
		if slot and (now - slot.t) < CACHE_TTL then
			return slot.result :: number
		end
		local r =
			bulletPenetrationRay.countWallsToTarget(origin, targetPart, penetration, maxRange, ignoreRoots, targetPos)
		if slot == nil then
			_cacheCount += 1
		end
		_cache[key] = { result = r, t = now }
		pruneIfNeeded()
		return r
	end

	return penetrationQuery
end)() :: any
