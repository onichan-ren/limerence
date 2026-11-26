local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Players = cloneref(game:GetService("Players")) :: Players

local ModuleController = require("@game/pf/module/ModuleController")
local localThirdPerson = require("@game/pf/thirdperson/localThirdPerson")

local LocalPlayer = Players.LocalPlayer

local SCAN_STEP = 1 / 30
local DEFAULT_LIFE = 5
local IGNORE_TTL = 0.004
local REFINE_STEPS = 4
local REFINE_MARGIN = 1
local SLIDE_EPS = 0.1
local MAX_SLIDE = 6
local DIAG = 0.7071067811865476

local pfBallistics = {}

local _publicSettings: any = nil

local trajectory = LPH_NO_VIRTUALIZE(
	function(origin: Vector3, accel: Vector3, target: Vector3, speed: number): (Vector3, number)
		local f = -accel
		local ld = target - origin
		local fa = f:Dot(f)
		local b = 4 * ld:Dot(ld)
		local k = (4 * (f:Dot(ld) + speed * speed)) / (2 * fa)
		local v = (k * k - b / fa) ^ 0.5
		local t1, t0 = k - v, k + v
		local tt = (t1 < 0 and t0 or t1) ^ 0.5
		return f * tt / 2 + ld / tt, tt
	end
)

pfBallistics.trajectory = trajectory

local baseFilter: { Instance } = {}
local lastIgnoreRefresh = 0
local IGNORE_NAMES = { "Ignore", "Players" }

local function refreshIgnore(): ()
	local now = os.clock()
	if now - lastIgnoreRefresh < IGNORE_TTL then
		return
	end
	lastIgnoreRefresh = now
	table.clear(baseFilter)
	baseFilter[1] = Workspace.CurrentCamera :: Instance
	baseFilter[2] = Workspace.Terrain :: Instance
	for _, name in next, IGNORE_NAMES do
		local found = Workspace:FindFirstChild(name)
		if found then
			baseFilter[#baseFilter + 1] = found
		end
	end
	local body = localThirdPerson.getCharacterModel()
	if body then
		baseFilter[#baseFilter + 1] = body
	end
	local weapon = localThirdPerson.getWeaponModel()
	if weapon then
		baseFilter[#baseFilter + 1] = weapon
	end
	local character = LocalPlayer.Character
	if character then
		baseFilter[#baseFilter + 1] = character
	end
end

local function bulletLifeTime(): number
	if not _publicSettings then
		_publicSettings = ModuleController.GetModule("PublicSettings")
	end
	local life = _publicSettings and rawget(_publicSettings, "bulletLifeTime")
	return type(life) == "number" and life or DEFAULT_LIFE
end

local workFilter: { Instance } = {}

local exitParams = RaycastParams.new()
exitParams.FilterType = Enum.RaycastFilterType.Include
exitParams.IgnoreWater = true

local scanParams = RaycastParams.new()
scanParams.FilterType = Enum.RaycastFilterType.Exclude
scanParams.IgnoreWater = true

pfBallistics.reach = LPH_NO_VIRTUALIZE(
	function(
		origin: Vector3,
		target: Vector3,
		velocity: Vector3,
		accel: Vector3,
		penBudget: number,
		flightTime: number
	): boolean
		if not flightTime or flightTime ~= flightTime or flightTime <= 0 then
			return false
		end
		if flightTime > bulletLifeTime() then
			return false
		end

		table.clear(workFilter)
		for i = 1, #baseFilter do
			workFilter[i] = baseFilter[i]
		end
		local filter = workFilter
		local params = scanParams
		params.FilterDescendantsInstances = filter

		local pos = origin
		local vel = velocity
		local pen = penBudget
		local elapsed = 0

		while elapsed < flightTime do
			local dt = flightTime - elapsed
			if SCAN_STEP < dt then
				dt = SCAN_STEP
			end
			local disp = dt * vel + (dt * dt / 2) * accel
			if disp.Magnitude < 1e-4 then
				break
			end
			local result = Workspace:Raycast(pos, disp, params)
			while result and (not result.Instance.CanCollide or result.Instance.Transparency == 1) do
				filter[#filter + 1] = result.Instance
				params.FilterDescendantsInstances = filter
				result = Workspace:Raycast(pos, disp, params)
			end
			if not result then
				pos += disp
				vel += dt * accel
				elapsed += dt
			else
				local inst = result.Instance
				if inst.Name == "killbullet" then
					return false
				end
				local hitPos = result.Position
				local unit = disp.Unit
				local probe = unit * inst.Size.Magnitude
				exitParams.FilterDescendantsInstances = { inst }
				local back = Workspace:Raycast(hitPos + probe, -probe, exitParams)
				if back then
					local thickness = unit:Dot(back.Position - hitPos)
					local needed = unit:Dot(target - hitPos)
					if needed < thickness then
						thickness = needed > 0 and needed or 0
					end
					if thickness >= pen then
						return false
					end
					pen -= thickness
				end
				local frac = disp:Dot(hitPos - pos) / disp:Dot(disp) * dt
				pos = hitPos + 0.01 * (pos - hitPos).Unit
				vel += frac * accel
				elapsed += frac
				filter[#filter + 1] = inst
				params.FilterDescendantsInstances = filter
			end
		end

		return true
	end
)

local RING_OUTER: { Vector3 } = table.create(8)
local RING_INNER: { Vector3 } = table.create(4)

for i = 1, 8 do
	local angle = (i - 1) * (math.pi / 4)
	RING_OUTER[i] = Vector3.new(math.cos(angle), math.sin(angle), 0)
end

for i = 1, 4 do
	local angle = math.pi / 4 + (i - 1) * (math.pi / 2)
	RING_INNER[i] = Vector3.new(math.cos(angle) * 0.5, math.sin(angle) * 0.5, 0)
end

local function positionOffsets(point: Vector3, toward: Vector3, offset: number, out: { Vector3 }): ()
	table.clear(out)
	out[1] = point
	if offset <= 0 then
		return
	end
	local dir = toward - point
	if dir.Magnitude < 1e-4 then
		return
	end
	local cf = CFrame.lookAt(point, toward)
	local n = 1
	for i = 1, #RING_INNER do
		n += 1
		out[n] = cf * (RING_INNER[i] * offset)
	end
	n += 1
	out[n] = cf * Vector3.new(0, 0, -offset)
	for i = 1, #RING_OUTER do
		n += 1
		out[n] = cf * (RING_OUTER[i] * offset)
	end
	for i = 1, #RING_OUTER do
		n += 1
		out[n] = cf * (Vector3.new(RING_OUTER[i].X * DIAG, RING_OUTER[i].Y * DIAG, -DIAG) * offset)
	end
end

local originBuf: { Vector3 } = table.create(28)
local targetDirBuf: { Vector3 } = table.create(13)

local function targetDirections(aim: Vector3, origin: Vector3, out: { Vector3 }): number
	local dir = origin - aim
	if dir.Magnitude < 1e-4 then
		return 0
	end
	local cf = CFrame.lookAt(aim, origin)
	out[1] = cf.LookVector
	local n = 1
	for i = 1, #RING_OUTER do
		n += 1
		out[n] = cf:VectorToWorldSpace(RING_OUTER[i])
	end
	for i = 1, 7, 2 do
		n += 1
		out[n] = cf:VectorToWorldSpace(Vector3.new(RING_OUTER[i].X * DIAG, RING_OUTER[i].Y * DIAG, -DIAG))
	end
	return n
end

local slideFilter: { Instance } = {}

local collectSlideOrigins = LPH_NO_VIRTUALIZE(
	function(origin: Vector3, target: Vector3, budget: number, out: { Vector3 }): ()
		if budget <= 0 then
			return
		end
		local delta = target - origin
		local total = delta.Magnitude
		if total < 1 then
			return
		end
		local unit = delta / total
		local limit = total - 0.5
		local reachDist = budget < limit and budget or limit
		table.clear(slideFilter)
		for i = 1, #baseFilter do
			slideFilter[i] = baseFilter[i]
		end
		local params = scanParams
		params.FilterDescendantsInstances = slideFilter
		local pos = origin
		local travelled = 0
		local added = 0
		while travelled < reachDist and added < MAX_SLIDE do
			local result = Workspace:Raycast(pos, unit * (reachDist - travelled), params)
			if not result then
				break
			end
			local inst = result.Instance
			local hitPos = result.Position
			travelled += unit:Dot(hitPos - pos)
			if inst.CanCollide and inst.Transparency < 1 then
				if travelled + SLIDE_EPS <= budget then
					out[#out + 1] = hitPos + unit * SLIDE_EPS
					added += 1
				end
				local probe = unit * inst.Size.Magnitude
				exitParams.FilterDescendantsInstances = { inst }
				local back = Workspace:Raycast(hitPos + probe, -probe, exitParams)
				if back and added < MAX_SLIDE then
					local exitDist = travelled + unit:Dot(back.Position - hitPos) + SLIDE_EPS
					if exitDist > travelled and exitDist <= budget and exitDist <= reachDist then
						out[#out + 1] = back.Position + unit * SLIDE_EPS
						added += 1
					end
				end
			end
			slideFilter[#slideFilter + 1] = inst
			params.FilterDescendantsInstances = slideFilter
			pos = hitPos + unit * 0.01
			travelled += 0.01
		end
	end
)

local solvePoint = LPH_NO_VIRTUALIZE(
	function(o: Vector3, t: Vector3, gravity: Vector3, speed: number, penBudget: number): (Vector3?, number?)
		local v, x = trajectory(o, gravity, t, speed)
		if v and x and x == x and x > 0 and v.X == v.X then
			if pfBallistics.reach(o, t, v, gravity, penBudget, x) then
				return v, x
			end
		end
		return nil, nil
	end
)

local refineDirection = LPH_NO_VIRTUALIZE(
	function(
		o: Vector3,
		aim: Vector3,
		dirVec: Vector3,
		offset: number,
		gravity: Vector3,
		speed: number,
		penBudget: number
	): (Vector3?, number?, Vector3?)
		local t = aim + dirVec * offset
		local v, x = solvePoint(o, t, gravity, speed, penBudget)
		if not (v and x) then
			return nil, nil, nil
		end
		local lo = 0
		local hi = offset
		for _ = 1, REFINE_STEPS do
			local mid = (lo + hi) * 0.5
			local mt = aim + dirVec * mid
			local mv, mx = solvePoint(o, mt, gravity, speed, penBudget)
			if mv and mx then
				hi = mid
				t = mt
				v = mv
				x = mx
			else
				lo = mid
			end
		end
		if hi < offset then
			local padded = hi + REFINE_MARGIN
			if padded > offset then
				padded = offset
			end
			local pt = aim + dirVec * padded
			local pv, px = solvePoint(o, pt, gravity, speed, penBudget)
			if pv and px then
				return pv, px, pt
			end
		end
		return v, x, t
	end
)

local refineOrigin = LPH_NO_VIRTUALIZE(
	function(
		origin: Vector3,
		o: Vector3,
		t: Vector3,
		gravity: Vector3,
		speed: number,
		penBudget: number,
		v: Vector3,
		x: number
	): (Vector3, Vector3, number)
		local off = o - origin
		local radius = off.Magnitude
		if radius < 1e-4 then
			return o, v, x
		end
		local zv, zx = solvePoint(origin, t, gravity, speed, penBudget)
		if zv and zx then
			return origin, zv, zx
		end
		local dirVec = off / radius
		local lo = 0
		local hi = radius
		for _ = 1, REFINE_STEPS do
			local mid = (lo + hi) * 0.5
			local mo = origin + dirVec * mid
			local mv, mx = solvePoint(mo, t, gravity, speed, penBudget)
			if mv and mx then
				hi = mid
				o = mo
				v = mv
				x = mx
			else
				lo = mid
			end
		end
		if hi < radius then
			local padded = hi + REFINE_MARGIN
			if padded > radius then
				padded = radius
			end
			local po = origin + dirVec * padded
			local pv, px = solvePoint(po, t, gravity, speed, penBudget)
			if pv and px then
				return po, pv, px
			end
		end
		return o, v, x
	end
)

local solution: { [string]: any } = {}

local function writeSolution(
	origin: Vector3,
	aim: Vector3,
	o: Vector3,
	t: Vector3,
	v: Vector3,
	x: number,
	oi: number,
	ti: number
): any
	solution.o = o
	solution.dir = v.Unit
	solution.hit = t
	solution.flight = x
	solution.dist = (o - t).Magnitude
	solution.originOffset = (o - origin).Magnitude
	solution.hitOffset = (t - aim).Magnitude
	solution.oi = oi
	solution.ti = ti
	return solution
end

pfBallistics.scan = LPH_NO_VIRTUALIZE(
	function(
		origin: Vector3,
		aim: Vector3,
		gravity: Vector3,
		speed: number,
		penBudget: number,
		fireOffset: number,
		hitOffset: number,
		hintO: number?,
		hintT: number?,
		quick: boolean?
	): any
		refreshIgnore()

		local ev, ex = solvePoint(origin, aim, gravity, speed, penBudget)
		if ev and ex then
			return writeSolution(origin, aim, origin, aim, ev, ex, 1, 1)
		end

		local staticCount = 1
		if quick or fireOffset <= 0 then
			table.clear(originBuf)
			originBuf[1] = origin
		else
			positionOffsets(origin, aim, fireOffset, originBuf)
			staticCount = #originBuf
		end

		local dirCount = 0
		if hitOffset > 0 and not quick then
			dirCount = targetDirections(aim, origin, targetDirBuf)
		end

		if not quick and hintO and hintT and hintO <= staticCount and (hintO > 1 or hintT > 1) then
			local o = originBuf[hintO]
			if o then
				local hv, hx, ht
				if hintT == 1 then
					if hintO > 1 then
						hv, hx = solvePoint(o, aim, gravity, speed, penBudget)
						ht = aim
					end
				elseif hintT - 1 <= dirCount then
					hv, hx, ht = refineDirection(o, aim, targetDirBuf[hintT - 1], hitOffset, gravity, speed, penBudget)
				end
				if hv and hx and ht then
					local ro, rv, rx = refineOrigin(origin, o, ht, gravity, speed, penBudget, hv, hx)
					return writeSolution(origin, aim, ro, ht, rv, rx, hintO, hintT)
				end
			end
		end

		if fireOffset > 0 then
			collectSlideOrigins(origin, aim, fireOffset, originBuf)
		end

		local bestMetric = math.huge
		local bestO, bestT, bestV, bestX
		local bestOi, bestTi = 0, 0
		for oi = 1, #originBuf do
			local o = originBuf[oi]
			local oOff = (o - origin).Magnitude
			if oOff < bestMetric then
				local cv, cx
				if oi > 1 then
					cv, cx = solvePoint(o, aim, gravity, speed, penBudget)
				end
				if cv and cx then
					bestMetric = oOff
					bestO, bestT, bestV, bestX = o, aim, cv, cx
					bestOi, bestTi = oi, 1
				else
					for di = 1, dirCount do
						if bestMetric <= oOff then
							break
						end
						local rv, rx, rt = refineDirection(o, aim, targetDirBuf[di], hitOffset, gravity, speed, penBudget)
						if rv and rx and rt then
							local metric = oOff + (rt - aim).Magnitude
							if metric < bestMetric then
								bestMetric = metric
								bestO, bestT, bestV, bestX = o, rt, rv, rx
								bestOi, bestTi = oi, di + 1
							end
						end
					end
				end
			end
		end
		if not (bestO and bestT and bestV and bestX) then
			return nil
		end
		if bestOi > 1 and bestOi <= staticCount then
			bestO, bestV, bestX = refineOrigin(origin, bestO, bestT, gravity, speed, penBudget, bestV, bestX)
		end
		local outOi = bestOi <= staticCount and bestOi or 0
		return writeSolution(origin, aim, bestO, bestT, bestV, bestX, outOi, bestTi)
	end
)

return pfBallistics
