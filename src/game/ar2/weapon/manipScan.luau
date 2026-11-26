local worldRaycast = require("@game/ar2/weapon/worldRaycast")
local boxOcclusion = require("@game/universal/feature/combat/ragebot/boxOcclusion")

local manipScan = {}

local FIRE_OFFSET = 6.9
local HIT_OFFSET = 6.4
local DIAG = 0.7071067811865476

local WORLD_UP = Vector3.new(0, 1, 0)
local AXIS_FALLBACK = Vector3.new(1, 0, 0)

local losBlocker = worldRaycast.losBlocker
local segmentBlocked = boxOcclusion.segmentBlocked
local registerBlocker = boxOcclusion.register

local _dirs = table.create(8)
local _order = table.create(8)
local _scores = table.create(8)

local _memoODir = -1
local _memoHDir = -1

local tryRay = LPH_NO_VIRTUALIZE(function(o: Vector3, h: Vector3, ignore: { Instance }): boolean
	if segmentBlocked(o, h) then
		return false
	end
	local clear, blocker = losBlocker(o, h, ignore)
	if clear then
		return true
	end
	if blocker then
		registerBlocker(blocker)
	end
	return false
end)

manipScan.solve = LPH_NO_VIRTUALIZE(
	function(
		origin: Vector3,
		aim: Vector3,
		ignore: { Instance },
		fireOffset: number?,
		hitOffset: number?
	): (Vector3?, Vector3?)
		local fire = fireOffset or FIRE_OFFSET
		local hit = hitOffset or HIT_OFFSET

		local dir = aim - origin
		local mag = dir.Magnitude
		if mag < 1e-4 then
			return nil, nil
		end
		local axis = dir / mag

		if tryRay(origin, aim, ignore) then
			return origin, aim
		end

		local right = axis:Cross(WORLD_UP)
		local rmag = right.Magnitude
		if rmag < 1e-3 then
			right = AXIS_FALLBACK
		else
			right /= rmag
		end
		local up = right:Cross(axis)

		local dirs = _dirs
		dirs[1] = right
		dirs[2] = -right
		dirs[3] = up
		dirs[4] = -up
		dirs[5] = (right + up) * DIAG
		dirs[6] = (right - up) * DIAG
		dirs[7] = (-right + up) * DIAG
		dirs[8] = (-right - up) * DIAG

		if _memoODir >= 0 then
			local o = origin
			if _memoODir >= 1 and _memoODir <= 8 then
				o = origin + dirs[_memoODir] * fire
			elseif _memoODir == 9 then
				o = origin + axis * fire
			end
			local h = aim
			if _memoHDir >= 1 and _memoHDir <= 8 then
				h = aim + dirs[_memoHDir] * hit
			elseif _memoHDir == 9 then
				h = aim - axis * hit
			end
			if tryRay(o, h, ignore) then
				return o, h
			end
		end

		local order = _order
		for i = 1, 8 do
			order[i] = i
		end
		local guidePos = boxOcclusion.lastPosition()
		if guidePos then
			local toAim = aim - guidePos
			local perp = toAim - axis * toAim:Dot(axis)
			local pmag = perp.Magnitude
			if pmag > 1e-3 then
				perp /= pmag
				local scores = _scores
				for i = 1, 8 do
					scores[i] = dirs[i]:Dot(perp)
				end
				for i = 2, 8 do
					local v = order[i]
					local sv = scores[v]
					local j = i - 1
					while j >= 1 and scores[order[j]] < sv do
						order[j + 1] = order[j]
						j -= 1
					end
					order[j + 1] = v
				end
			end
		end

		for k = 1, 8 do
			local d = order[k]
			local h = aim + dirs[d] * hit
			if tryRay(origin, h, ignore) then
				_memoODir = 0
				_memoHDir = d
				return origin, h
			end
		end
		local hAxis = aim - axis * hit
		if tryRay(origin, hAxis, ignore) then
			_memoODir = 0
			_memoHDir = 9
			return origin, hAxis
		end

		for k = 1, 8 do
			local d = order[k]
			local o = origin + dirs[d] * fire
			if tryRay(o, aim, ignore) then
				_memoODir = d
				_memoHDir = 0
				return o, aim
			end
		end
		local oAxis = origin + axis * fire
		if tryRay(oAxis, aim, ignore) then
			_memoODir = 9
			_memoHDir = 0
			return oAxis, aim
		end

		for k = 1, 8 do
			local d = order[k]
			local shift = dirs[d]
			local o = origin + shift * fire
			local h = aim + shift * hit
			if tryRay(o, h, ignore) then
				_memoODir = d
				_memoHDir = d
				return o, h
			end
		end

		for a = 1, 3 do
			for b = 1, 3 do
				if a ~= b then
					local od = order[a]
					local hd = order[b]
					local o = origin + dirs[od] * fire
					local h = aim + dirs[hd] * hit
					if tryRay(o, h, ignore) then
						_memoODir = od
						_memoHDir = hd
						return o, h
					end
				end
			end
		end

		_memoODir = -1
		_memoHDir = -1
		return nil, nil
	end
)

return manipScan
