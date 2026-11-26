local boxOcclusion = {}

local MAX_BLOCKERS = 6

local _blockers = table.create(MAX_BLOCKERS)
local _count = 0
local _lastPosition: Vector3? = nil

local segmentHitsBox = LPH_NO_VIRTUALIZE(
	function(cf: CFrame, hx: number, hy: number, hz: number, a: Vector3, b: Vector3): boolean
		local la = cf:PointToObjectSpace(a)
		local lb = cf:PointToObjectSpace(b)
		local ax, ay, az = la.X, la.Y, la.Z
		local dx, dy, dz = lb.X - ax, lb.Y - ay, lb.Z - az
		local tmin = 0
		local tmax = 1

		if dx < 1e-9 and dx > -1e-9 then
			if ax < -hx or ax > hx then
				return false
			end
		else
			local inv = 1 / dx
			local t1 = (-hx - ax) * inv
			local t2 = (hx - ax) * inv
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			if t1 > tmin then
				tmin = t1
			end
			if t2 < tmax then
				tmax = t2
			end
			if tmin > tmax then
				return false
			end
		end

		if dy < 1e-9 and dy > -1e-9 then
			if ay < -hy or ay > hy then
				return false
			end
		else
			local inv = 1 / dy
			local t1 = (-hy - ay) * inv
			local t2 = (hy - ay) * inv
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			if t1 > tmin then
				tmin = t1
			end
			if t2 < tmax then
				tmax = t2
			end
			if tmin > tmax then
				return false
			end
		end

		if dz < 1e-9 and dz > -1e-9 then
			if az < -hz or az > hz then
				return false
			end
		else
			local inv = 1 / dz
			local t1 = (-hz - az) * inv
			local t2 = (hz - az) * inv
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			if t1 > tmin then
				tmin = t1
			end
			if t2 < tmax then
				tmax = t2
			end
			if tmin > tmax then
				return false
			end
		end

		return true
	end
)

boxOcclusion.segmentHitsBox = segmentHitsBox

boxOcclusion.reset = function(): ()
	_count = 0
	_lastPosition = nil
end

boxOcclusion.register = LPH_NO_VIRTUALIZE(function(instance: Instance): ()
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	_lastPosition = part.Position
	if instance.ClassName ~= "Part" or (instance :: Part).Shape ~= Enum.PartType.Block then
		return
	end
	for i = 1, _count do
		if _blockers[i].instance == instance then
			return
		end
	end
	if _count >= MAX_BLOCKERS then
		return
	end
	_count += 1
	local entry = _blockers[_count]
	if not entry then
		entry = {} :: any
		_blockers[_count] = entry
	end
	local size = part.Size
	entry.instance = instance
	entry.cf = part.CFrame
	entry.hx = size.X * 0.5
	entry.hy = size.Y * 0.5
	entry.hz = size.Z * 0.5
end)

boxOcclusion.segmentBlocked = LPH_NO_VIRTUALIZE(function(a: Vector3, b: Vector3): number?
	for i = 1, _count do
		local entry = _blockers[i]
		if segmentHitsBox(entry.cf, entry.hx, entry.hy, entry.hz, a, b) then
			return i
		end
	end
	return nil
end)

local ESCAPE_EPS = 0.05
local ESCAPE_REFINE_ITERS = 5

boxOcclusion.count = function(): number
	return _count
end

boxOcclusion.escapeT = LPH_NO_VIRTUALIZE(
	function(origin: Vector3, dir: Vector3, target: Vector3, minT: number, maxT: number, step: number): number?
		if _count == 0 then
			return nil
		end
		local blockedT = -1
		local clearT = -1
		local t = minT
		while t <= maxT do
			local blocked = false
			local a = origin + dir * t
			for i = 1, _count do
				local entry = _blockers[i]
				if segmentHitsBox(entry.cf, entry.hx, entry.hy, entry.hz, a, target) then
					blocked = true
					break
				end
			end
			if blocked then
				blockedT = t
			else
				clearT = t
				break
			end
			t += step
		end
		if clearT < 0 then
			return nil
		end
		if blockedT >= 0 then
			local lo = blockedT
			local hi = clearT
			for _ = 1, ESCAPE_REFINE_ITERS do
				local mid = (lo + hi) * 0.5
				local a = origin + dir * mid
				local blocked = false
				for i = 1, _count do
					local entry = _blockers[i]
					if segmentHitsBox(entry.cf, entry.hx, entry.hy, entry.hz, a, target) then
						blocked = true
						break
					end
				end
				if blocked then
					lo = mid
				else
					hi = mid
				end
			end
			clearT = hi + ESCAPE_EPS
		end
		return clearT
	end
)

boxOcclusion.position = function(index: number): Vector3?
	local entry = _blockers[index]
	return entry and entry.cf.Position or nil
end

boxOcclusion.lastPosition = function(): Vector3?
	return _lastPosition
end

return boxOcclusion
