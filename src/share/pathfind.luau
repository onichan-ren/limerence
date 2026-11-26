local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local instances = require("@share/instances")

local pathfind = {}

local OFFSET = 2048
local STRIDE = 4096
local ZERO = Vector3.zero

local NEIGHBORS_STRAIGHT = {
	Vector2.new(1, 0),
	Vector2.new(-1, 0),
	Vector2.new(0, 1),
	Vector2.new(0, -1),
}

local NEIGHBORS_ALL = {
	Vector2.new(1, 0),
	Vector2.new(-1, 0),
	Vector2.new(0, 1),
	Vector2.new(0, -1),
	Vector2.new(1, 1),
	Vector2.new(1, -1),
	Vector2.new(-1, 1),
	Vector2.new(-1, -1),
}

local FLY_AXIAL = {
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
}

local FLY_ALL: { Vector3 } = table.create(26)
for x = -1, 1 do
	for y = -1, 1 do
		for z = -1, 1 do
			if x ~= 0 or y ~= 0 or z ~= 0 then
				FLY_ALL[#FLY_ALL + 1] = Vector3.new(x, y, z)
			end
		end
	end
end

export type Waypoint = {
	position: Vector3,
	jump: boolean,
}

export type Config = {
	mode: ("walk" | "fly")?,
	gridSize: number?,
	maxRadius: number?,
	maxNodes: number?,
	stepHeight: number?,
	jumpHeight: number?,
	dropHeight: number?,
	agentHeight: number?,
	agentWidth: number?,
	lift: number?,
	goalRadius: number?,
	yieldEvery: number?,
	heuristicWeight: number?,
	jumpCost: number?,
	maxSlope: number?,
	diagonals: boolean?,
	simplify: boolean?,
	partial: boolean?,
	ignoreWater: boolean?,
	respectCanCollide: boolean?,
	ignore: { Instance }?,
	costModifier: ((from: Vector3, to: Vector3, cost: number) -> number?)?,
	nodeValidator: ((position: Vector3) -> boolean)?,
}

type Resolved = {
	mode: "walk" | "fly",
	gridSize: number,
	maxRadius: number,
	maxNodes: number,
	stepHeight: number,
	jumpHeight: number,
	dropHeight: number,
	agentHeight: number,
	agentWidth: number,
	lift: number,
	goalRadius: number,
	yieldEvery: number,
	heuristicWeight: number,
	jumpCost: number,
	minNormalY: number?,
	diagonals: boolean,
	simplify: boolean,
	partial: boolean,
	ignoreWater: boolean,
	respectCanCollide: boolean,
	costModifier: ((from: Vector3, to: Vector3, cost: number) -> number?)?,
	nodeValidator: ((position: Vector3) -> boolean)?,
}

local function resolve(config: Config): Resolved
	local gridSize = config.gridSize or 4
	local stepHeight = config.stepHeight or 4
	return {
		mode = config.mode == "fly" and "fly" or "walk",
		gridSize = gridSize,
		maxRadius = math.min(config.maxRadius or 100, gridSize * (OFFSET - 1)),
		maxNodes = config.maxNodes or 2500,
		stepHeight = stepHeight,
		jumpHeight = config.jumpHeight or stepHeight,
		dropHeight = config.dropHeight or stepHeight,
		agentHeight = config.agentHeight or 5,
		agentWidth = config.agentWidth or 3,
		lift = config.lift or 3,
		goalRadius = config.goalRadius or gridSize,
		yieldEvery = config.yieldEvery or 50,
		heuristicWeight = config.heuristicWeight or 1,
		jumpCost = config.jumpCost or 2,
		minNormalY = config.maxSlope and math.cos(math.rad(config.maxSlope)) or nil,
		diagonals = config.diagonals ~= false,
		simplify = config.simplify ~= false,
		partial = config.partial ~= false,
		ignoreWater = config.ignoreWater ~= false,
		respectCanCollide = config.respectCanCollide ~= false,
		costModifier = config.costModifier,
		nodeValidator = config.nodeValidator,
	}
end

local function newHeap(
	closed: { [number]: boolean },
	fScore: { [number]: number }
): ((number, number) -> (), () -> number?)
	local heapKeys: { number } = {}
	local heapF: { number } = {}
	local heapSize = 0

	local function push(key: number, f: number): ()
		fScore[key] = f
		heapSize += 1
		heapKeys[heapSize] = key
		heapF[heapSize] = f
		local i = heapSize
		while i > 1 do
			local parent = i // 2
			if heapF[parent] <= heapF[i] then
				break
			end
			heapF[i], heapF[parent] = heapF[parent], heapF[i]
			heapKeys[i], heapKeys[parent] = heapKeys[parent], heapKeys[i]
			i = parent
		end
	end

	local function pop(): number?
		while heapSize > 0 do
			local key = heapKeys[1]
			local f = heapF[1]
			heapKeys[1] = heapKeys[heapSize]
			heapF[1] = heapF[heapSize]
			heapKeys[heapSize] = nil
			heapF[heapSize] = nil
			heapSize -= 1
			local i = 1
			while true do
				local left = i * 2
				if left > heapSize then
					break
				end
				local smallest = left
				local right = left + 1
				if right <= heapSize and heapF[right] < heapF[left] then
					smallest = right
				end
				if heapF[i] <= heapF[smallest] then
					break
				end
				heapF[i], heapF[smallest] = heapF[smallest], heapF[i]
				heapKeys[i], heapKeys[smallest] = heapKeys[smallest], heapKeys[i]
				i = smallest
			end
			if not closed[key] and f <= (fScore[key] or math.huge) then
				return key
			end
		end
		return nil
	end

	return push, pop
end

local function simplifySegment(
	pts: { Waypoint },
	s: number,
	e: number,
	out: { Waypoint },
	fits: (Vector3, Vector3) -> boolean,
	liftVec: Vector3
): ()
	local i = s
	while i < e do
		local j = e
		while j > i + 1 do
			if fits(pts[i].position - liftVec, pts[j].position - liftVec) then
				break
			end
			j -= 1
		end
		out[#out + 1] = pts[j]
		i = j
	end
end

local function simplifyPath(pts: { Waypoint }, fits: (Vector3, Vector3) -> boolean, liftVec: Vector3): { Waypoint }
	local count = #pts
	if count <= 2 then
		return pts
	end
	local out: { Waypoint } = { pts[1] }
	local segStart = 1
	for i = 2, count do
		if pts[i].jump then
			simplifySegment(pts, segStart, i - 1, out, fits, liftVec)
			out[#out + 1] = pts[i]
			segStart = i
		end
	end
	simplifySegment(pts, segStart, count, out, fits, liftVec)
	return out
end

local Pather = {}
Pather.__index = Pather

function pathfind.new(config: Config?): Pather
	local self = setmetatable({}, Pather)
	local raw: Config = {}
	if config then
		for key, value in next, config do
			(raw :: any)[key] = value
		end
	end
	self._raw = raw
	local resolved = resolve(raw)
	self._config = resolved
	self._ignore = {} :: { Instance }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = resolved.ignoreWater
	params.RespectCanCollide = resolved.respectCanCollide
	self._params = params
	self:SetIgnore(raw.ignore)
	return self :: Pather
end

function Pather.Configure(self: Pather, config: Config): ()
	local raw = self._raw
	for key, value in next, config do
		(raw :: any)[key] = value
	end
	local resolved = resolve(raw)
	self._config = resolved
	self._params.IgnoreWater = resolved.ignoreWater
	self._params.RespectCanCollide = resolved.respectCanCollide
	if config.ignore then
		self:SetIgnore(config.ignore)
	end
end

function Pather.SetIgnore(self: Pather, list: { Instance }?): ()
	local count = list and #list or 0
	local ignore = table.create(count + 1)
	ignore[1] = instances.ignore
	if list then
		for i = 1, count do
			ignore[i + 1] = list[i]
		end
	end
	self._ignore = ignore
	self._params.FilterDescendantsInstances = ignore
end

function Pather.AddIgnore(self: Pather, instance: Instance): ()
	local ignore = self._ignore
	for i = 1, #ignore do
		if ignore[i] == instance then
			return
		end
	end
	ignore[#ignore + 1] = instance
	self._params.FilterDescendantsInstances = ignore
end

function Pather.RemoveIgnore(self: Pather, instance: Instance): ()
	local ignore = self._ignore
	for i = 2, #ignore do
		if ignore[i] == instance then
			ignore[i] = ignore[#ignore]
			ignore[#ignore] = nil
			self._params.FilterDescendantsInstances = ignore
			return
		end
	end
end

local computeWalk = LPH_NO_VIRTUALIZE(function(self: Pather, start: Vector3, goal: Vector3): { Waypoint }?
	local cfg = self._config
	local params = self._params

	local size = cfg.gridSize
	local maxRadius = cfg.maxRadius
	local maxNodes = cfg.maxNodes
	local stepHeight = cfg.stepHeight
	local jumpHeight = cfg.jumpHeight
	local dropHeight = cfg.dropHeight
	local agentHeight = cfg.agentHeight
	local agentWidth = cfg.agentWidth
	local lift = cfg.lift
	local goalRadius = cfg.goalRadius
	local yieldEvery = cfg.yieldEvery
	local heuristicWeight = cfg.heuristicWeight
	local jumpCost = cfg.jumpCost
	local minNormalY = cfg.minNormalY
	local costModifier = cfg.costModifier
	local nodeValidator = cfg.nodeValidator
	local neighbors = if cfg.diagonals then NEIGHBORS_ALL else NEIGHBORS_STRAIGHT

	local sx, sy, sz = start.X, start.Y, start.Z
	local probeUp = math.max(stepHeight, jumpHeight) + 0.5
	local probeVec = Vector3.new(0, -(probeUp + math.max(stepHeight, dropHeight) * 2 + 8), 0)
	local liftVec = Vector3.new(0, lift, 0)

	local floors: { [number]: Vector3 | false } = {}

	local function floorAt(ix: number, iz: number, refY: number?): Vector3?
		local key = (ix + OFFSET) * STRIDE + iz + OFFSET
		local cached = floors[key]
		if cached ~= nil then
			return cached or nil
		end
		local origin = Vector3.new(sx + ix * size, (refY or sy) + probeUp, sz + iz * size)
		local result = Workspace:Raycast(origin, probeVec, params)
		local position: Vector3 | false = false
		if result then
			if minNormalY and result.Normal.Y < minNormalY then
				position = false
			elseif nodeValidator and not nodeValidator(result.Position) then
				position = false
			else
				position = result.Position
			end
		end
		floors[key] = position
		return position or nil
	end

	local boxHeight = math.max(agentHeight - stepHeight, 0.5)
	local boxSize = Vector3.new(agentWidth, boxHeight, agentWidth)
	local boxCenterY = (stepHeight + agentHeight) / 2

	local function fits(a: Vector3, b: Vector3): boolean
		local dir = b - a
		if dir.Magnitude < 1e-3 then
			return true
		end
		local origin = Vector3.new(a.X, a.Y + boxCenterY, a.Z)
		local hit = Workspace:Blockcast(CFrame.new(origin), boxSize, dir, params)
		if not hit then
			return true
		end
		if hit.Distance < 0.75 then
			return Workspace:Raycast(origin, dir, params) == nil
		end
		return false
	end

	if not floorAt(0, 0, sy) then
		return nil
	end

	local gix = math.floor((goal.X - sx) / size + 0.5)
	local giz = math.floor((goal.Z - sz) / size + 0.5)
	local goalFlat = Vector3.new(goal.X, 0, goal.Z)

	local function heuristic(ix: number, iz: number): number
		local dx = gix - ix
		local dz = giz - iz
		return math.sqrt(dx * dx + dz * dz) * size
	end

	local startKey = OFFSET * STRIDE + OFFSET
	local gScore: { [number]: number } = { [startKey] = 0 }
	local fScore: { [number]: number } = {}
	local cameFrom: { [number]: number } = {}
	local jumpEdge: { [number]: boolean } = {}
	local closed: { [number]: boolean } = {}
	local push, pop = newHeap(closed, fScore)

	local function reconstruct(endKey: number): { Waypoint }
		local keys: { number } = {}
		local node: number? = endKey
		while node do
			keys[#keys + 1] = node
			node = cameFrom[node]
		end
		local out: { Waypoint } = table.create(#keys)
		for i = #keys, 1, -1 do
			local key = keys[i]
			out[#out + 1] = {
				position = (floors[key] :: Vector3) + liftVec,
				jump = jumpEdge[key] == true,
			}
		end
		if cfg.simplify then
			return simplifyPath(out, fits, liftVec)
		end
		return out
	end

	local startH = heuristic(0, 0)
	push(startKey, startH * heuristicWeight)
	local bestNode = startKey
	local bestH = startH
	local expansions = 0
	local exhausted = false

	while true do
		local current = pop()
		if not current then
			exhausted = true
			break
		end
		closed[current] = true

		local cix = current // STRIDE - OFFSET
		local ciz = current % STRIDE - OFFSET
		local cFloor = floors[current] :: Vector3

		if (Vector3.new(cFloor.X, 0, cFloor.Z) - goalFlat).Magnitude <= goalRadius then
			return reconstruct(current)
		end

		expansions += 1
		if expansions > maxNodes then
			break
		end
		if yieldEvery > 0 and expansions % yieldEvery == 0 then
			task.wait()
		end

		local baseG = gScore[current]
		for n = 1, #neighbors do
			local offset = neighbors[n]
			local nix = cix + offset.X
			local niz = ciz + offset.Y
			if math.abs(nix) * size <= maxRadius and math.abs(niz) * size <= maxRadius then
				local nk = (nix + OFFSET) * STRIDE + niz + OFFSET
				if not closed[nk] then
					local nFloor = floorAt(nix, niz, cFloor.Y)
					if nFloor then
						local dy = nFloor.Y - cFloor.Y
						local passable = false
						local isJump = false
						if dy > stepHeight then
							if dy <= jumpHeight and fits(Vector3.new(cFloor.X, nFloor.Y, cFloor.Z), nFloor) then
								passable = true
								isJump = true
							end
						elseif dy < -stepHeight then
							if -dy <= dropHeight and fits(cFloor, Vector3.new(nFloor.X, cFloor.Y, nFloor.Z)) then
								passable = true
							end
						elseif fits(cFloor, nFloor) then
							passable = true
						end
						if passable then
							local cost = (nFloor - cFloor).Magnitude
							if isJump then
								cost *= jumpCost
							end
							if costModifier then
								local modified = costModifier(cFloor, nFloor, cost)
								if modified then
									cost = modified
								else
									passable = false
								end
							end
							if passable then
								local tentative = baseG + cost
								if tentative < (gScore[nk] or math.huge) then
									cameFrom[nk] = current
									jumpEdge[nk] = isJump or nil
									gScore[nk] = tentative
									local h = heuristic(nix, niz)
									push(nk, tentative + h * heuristicWeight)
									if h < bestH then
										bestH = h
										bestNode = nk
									end
								end
							end
						end
					end
				end
			end
		end
	end

	if cfg.partial then
		if exhausted and bestNode == startKey then
			return nil
		end
		return reconstruct(bestNode)
	end
	return nil
end)

local computeFly = LPH_NO_VIRTUALIZE(function(self: Pather, start: Vector3, goal: Vector3): { Waypoint }?
	local cfg = self._config
	local params = self._params

	local size = cfg.gridSize
	local maxRadius = cfg.maxRadius
	local maxNodes = cfg.maxNodes
	local agentHeight = cfg.agentHeight
	local agentWidth = cfg.agentWidth
	local goalRadius = cfg.goalRadius
	local yieldEvery = cfg.yieldEvery
	local heuristicWeight = cfg.heuristicWeight
	local costModifier = cfg.costModifier
	local nodeValidator = cfg.nodeValidator
	local neighbors = if cfg.diagonals then FLY_ALL else FLY_AXIAL

	local sx, sy, sz = start.X, start.Y, start.Z
	local boxSize = Vector3.new(agentWidth, agentHeight, agentWidth)

	local function fits(a: Vector3, b: Vector3): boolean
		local dir = b - a
		if dir.Magnitude < 1e-3 then
			return true
		end
		local hit = Workspace:Blockcast(CFrame.new(a), boxSize, dir, params)
		if not hit then
			return true
		end
		if hit.Distance < 0.75 then
			return Workspace:Raycast(a, dir, params) == nil
		end
		return false
	end

	if fits(start, goal) then
		return {
			{ position = start, jump = false },
			{ position = goal, jump = false },
		}
	end

	local gix = math.floor((goal.X - sx) / size + 0.5)
	local giy = math.floor((goal.Y - sy) / size + 0.5)
	local giz = math.floor((goal.Z - sz) / size + 0.5)

	local function heuristic(ix: number, iy: number, iz: number): number
		local dx = gix - ix
		local dy = giy - iy
		local dz = giz - iz
		return math.sqrt(dx * dx + dy * dy + dz * dz) * size
	end

	local startKey = (OFFSET * STRIDE + OFFSET) * STRIDE + OFFSET
	local gScore: { [number]: number } = { [startKey] = 0 }
	local fScore: { [number]: number } = {}
	local cameFrom: { [number]: number } = {}
	local closed: { [number]: boolean } = {}
	local push, pop = newHeap(closed, fScore)

	local function posOf(key: number): Vector3
		local iy = key % STRIDE - OFFSET
		local rest = key // STRIDE
		local iz = rest % STRIDE - OFFSET
		local ix = rest // STRIDE - OFFSET
		return Vector3.new(sx + ix * size, sy + iy * size, sz + iz * size)
	end

	local function reconstruct(endKey: number, reached: boolean): { Waypoint }
		local keys: { number } = {}
		local node: number? = endKey
		while node do
			keys[#keys + 1] = node
			node = cameFrom[node]
		end
		local out: { Waypoint } = table.create(#keys + 1)
		for i = #keys, 1, -1 do
			out[#out + 1] = {
				position = posOf(keys[i]),
				jump = false,
			}
		end
		if reached and (out[#out].position - goal).Magnitude > 1e-3 then
			out[#out + 1] = { position = goal, jump = false }
		end
		if cfg.simplify then
			return simplifyPath(out, fits, ZERO)
		end
		return out
	end

	local startH = heuristic(0, 0, 0)
	push(startKey, startH * heuristicWeight)
	local bestNode = startKey
	local bestH = startH
	local expansions = 0
	local exhausted = false

	while true do
		local current = pop()
		if not current then
			exhausted = true
			break
		end
		closed[current] = true

		local cPos = posOf(current)
		if (cPos - goal).Magnitude <= goalRadius then
			return reconstruct(current, true)
		end

		expansions += 1
		if expansions > maxNodes then
			break
		end
		if yieldEvery > 0 and expansions % yieldEvery == 0 then
			task.wait()
		end

		local ciy = current % STRIDE - OFFSET
		local rest = current // STRIDE
		local ciz = rest % STRIDE - OFFSET
		local cix = rest // STRIDE - OFFSET

		local baseG = gScore[current]
		for n = 1, #neighbors do
			local offset = neighbors[n]
			local nix = cix + offset.X
			local niy = ciy + offset.Y
			local niz = ciz + offset.Z
			if
				math.abs(nix) * size <= maxRadius
				and math.abs(niy) * size <= maxRadius
				and math.abs(niz) * size <= maxRadius
			then
				local nk = ((nix + OFFSET) * STRIDE + niz + OFFSET) * STRIDE + niy + OFFSET
				if not closed[nk] then
					local nPos = Vector3.new(sx + nix * size, sy + niy * size, sz + niz * size)
					if (not nodeValidator or nodeValidator(nPos)) and fits(cPos, nPos) then
						local cost = (nPos - cPos).Magnitude
						local passable = true
						if costModifier then
							local modified = costModifier(cPos, nPos, cost)
							if modified then
								cost = modified
							else
								passable = false
							end
						end
						if passable then
							local tentative = baseG + cost
							if tentative < (gScore[nk] or math.huge) then
								cameFrom[nk] = current
								gScore[nk] = tentative
								local h = heuristic(nix, niy, niz)
								push(nk, tentative + h * heuristicWeight)
								if h < bestH then
									bestH = h
									bestNode = nk
								end
							end
						end
					end
				end
			end
		end
	end

	if cfg.partial then
		if exhausted and bestNode == startKey then
			return nil
		end
		return reconstruct(bestNode, false)
	end
	return nil
end)

function Pather.Compute(self: Pather, start: Vector3, goal: Vector3, extraIgnore: { Instance }?): { Waypoint }?
	local params = self._params
	if extraIgnore then
		local base = self._ignore
		local baseCount = #base
		local merged = table.create(baseCount + #extraIgnore)
		for i = 1, baseCount do
			merged[i] = base[i]
		end
		for i = 1, #extraIgnore do
			merged[baseCount + i] = extraIgnore[i]
		end
		params.FilterDescendantsInstances = merged
	else
		params.FilterDescendantsInstances = self._ignore
	end
	if self._config.mode == "fly" then
		return computeFly(self, start, goal)
	end
	return computeWalk(self, start, goal)
end

pathfind.compute = function(start: Vector3, goal: Vector3, config: Config?): { Waypoint }?
	return pathfind.new(config):Compute(start, goal)
end

export type Pather = typeof(setmetatable(
	{} :: {
		_raw: Config,
		_config: Resolved,
		_ignore: { Instance },
		_params: RaycastParams,
	},
	Pather
))

return pathfind
