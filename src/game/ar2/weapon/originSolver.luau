local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local worldRaycast = require("@game/ar2/weapon/worldRaycast")

local originSolver = {}

local SCAN_STEP = 0.75
local SCAN_COARSE = 1.5
local SCAN_BINARY_ITERS = 4
local MAX_SHIFT = 7
local EMBED_DEPTH = 0.35
local MAX_EMBED_STEPS = 12

local WORLD_UP = Vector3.new(0, 1, 0)
local WORLD_DOWN = Vector3.new(0, -1, 0)
local AXIS_PX = Vector3.new(1, 0, 0)
local AXIS_NX = Vector3.new(-1, 0, 0)
local AXIS_PZ = Vector3.new(0, 0, 1)
local AXIS_NZ = Vector3.new(0, 0, -1)
local DIAG_PXNY = Vector3.new(1, -1, 0).Unit
local DIAG_NXNY = Vector3.new(-1, -1, 0).Unit
local DIAG_NYPZ = Vector3.new(0, -1, 1).Unit
local DIAG_NYNZ = Vector3.new(0, -1, -1).Unit

local _dirs: { Vector3 } = {}

local clearTo = worldRaycast.clearLineOfSight

local _params = RaycastParams.new()
_params.FilterType = Enum.RaycastFilterType.Exclude
_params.IgnoreWater = true
_params.RespectCanCollide = false

local embedAlong = LPH_NO_VIRTUALIZE(
	function(origin: Vector3, dir: Vector3, target: Vector3, ignore: { Instance }): Vector3?
		local cur = origin
		for _ = 1, MAX_EMBED_STEPS do
			local remaining = MAX_SHIFT - (cur - origin).Magnitude
			if remaining <= 1e-3 then
				return nil
			end
			_params.FilterDescendantsInstances = ignore
			local result = Workspace:Raycast(cur, dir * remaining, _params)
			if not result then
				return nil
			end
			cur = result.Position + dir * EMBED_DEPTH
			if (cur - origin).Magnitude > MAX_SHIFT then
				return nil
			end
			if clearTo(cur, target, ignore) then
				return cur
			end
		end
		return nil
	end
)

local scanClear = LPH_NO_VIRTUALIZE(
	function(origin: Vector3, dir: Vector3, target: Vector3, ignore: { Instance }): Vector3?
		local prev = 0
		local firstClear = -1
		local dist = SCAN_COARSE
		while true do
			local s = dist < MAX_SHIFT and dist or MAX_SHIFT
			if clearTo(origin + dir * s, target, ignore) then
				firstClear = s
				break
			end
			prev = s
			if s >= MAX_SHIFT then
				break
			end
			dist += SCAN_COARSE
		end

		if firstClear < 0 then
			return nil
		end

		local lo = prev
		local hi = firstClear
		for _ = 1, SCAN_BINARY_ITERS do
			local mid = (lo + hi) * 0.5
			if clearTo(origin + dir * mid, target, ignore) then
				hi = mid
			else
				lo = mid
			end
		end

		return origin + dir * hi
	end
)

originSolver.solveOrigin = LPH_NO_VIRTUALIZE(
	function(origin: Vector3, target: Vector3, ignore: { Instance }): (Vector3?, number)
		if clearTo(origin, target, ignore) then
			return origin, 1
		end

		local camera = Workspace.CurrentCamera
		local cf = camera and camera.CFrame
		local toTarget = target - origin

		local dirs = _dirs
		table.clear(dirs)
		if toTarget.Magnitude > 1e-3 then
			dirs[#dirs + 1] = toTarget.Unit
		end
		if cf then
			dirs[#dirs + 1] = cf.LookVector
			dirs[#dirs + 1] = -cf.LookVector
			dirs[#dirs + 1] = cf.RightVector
			dirs[#dirs + 1] = -cf.RightVector
			dirs[#dirs + 1] = cf.UpVector
		end
		dirs[#dirs + 1] = WORLD_DOWN
		dirs[#dirs + 1] = WORLD_UP
		dirs[#dirs + 1] = AXIS_PX
		dirs[#dirs + 1] = AXIS_NX
		dirs[#dirs + 1] = AXIS_PZ
		dirs[#dirs + 1] = AXIS_NZ
		dirs[#dirs + 1] = DIAG_PXNY
		dirs[#dirs + 1] = DIAG_NXNY
		dirs[#dirs + 1] = DIAG_NYPZ
		dirs[#dirs + 1] = DIAG_NYNZ

		local best: Vector3? = nil
		local bestShift = math.huge

		for _, dir in next, dirs do
			local clear = scanClear(origin, dir, target, ignore)
			if clear then
				local shift = (clear - origin).Magnitude
				if shift < bestShift then
					best = clear
					bestShift = shift
					if bestShift <= SCAN_STEP then
						break
					end
				end
			end
		end

		if not best then
			for _, dir in next, dirs do
				local found = embedAlong(origin, dir, target, ignore)
				if found then
					local shift = (found - origin).Magnitude
					if shift < bestShift then
						best = found
						bestShift = shift
						if bestShift <= EMBED_DEPTH then
							break
						end
					end
				end
			end
		end

		if best then
			local level = 1 - math.clamp(bestShift / MAX_SHIFT, 0, 1) * 0.85
			if level < 0.12 then
				level = 0.12
			end
			return best, level
		end
		return nil, 0
	end
)

return originSolver
