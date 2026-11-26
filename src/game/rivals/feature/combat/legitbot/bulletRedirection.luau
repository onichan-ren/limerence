local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local hook = require("@share/hook")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local mapWhitelist = require("@game/rivals/feature/combat/legitbot/mapWhitelist")
local boxOcclusion = require("@game/universal/feature/combat/ragebot/boxOcclusion")

local peek = Charm.peek

local MAX_DIST = 5000
local CLEAR_TOLERANCE = 3

local EMBED_DEPTH = 0.35
local MAX_EMBED_STEPS = 12
local MAX_SHIFT = 15
local SCAN_STEP = 0.75
local WORLD_DOWN = Vector3.new(0, -1, 0)
local WORLD_UP = Vector3.new(0, 1, 0)

local WORLD_DIRS: { Vector3 } = {
	WORLD_DOWN,
	WORLD_UP,
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
	Vector3.new(1, -1, 0).Unit,
	Vector3.new(-1, -1, 0).Unit,
	Vector3.new(0, -1, 1).Unit,
	Vector3.new(0, -1, -1).Unit,
}

local dirBuffer: { Vector3 } = {}
local RAY_BUDGET = 60
local DIR_TRY_CAP = 5
local FAIL_EPS = 0.5
local FAIL_TTL = 0.3

local segmentBlocked = boxOcclusion.segmentBlocked
local registerBlocker = boxOcclusion.register
local escapeT = boxOcclusion.escapeT

local _orderBuffer = table.create(16)
local _scoreBuffer = table.create(16)
local _tBuffer = table.create(16)
local _memoDirIdx = -1
local _memoDist = 0
local _raysLeft = 0

local _failOrigin: Vector3? = nil
local _failTarget: Vector3? = nil
local _failClock = 0

local _lastWhitelist: { Instance }? = nil

local CF_X, CF_Y, CF_Z = utf8.char(0), utf8.char(1), utf8.char(2)
local CF_RX, CF_RY, CF_RZ = utf8.char(3), utf8.char(4), utf8.char(5)
local CAMERA_DATA_KEY = utf8.char(1)
local CAMERA_START_KEY = utf8.char(0)
local CAMERA_END_KEY = utf8.char(1)
local HIT_PART_KEY = utf8.char(2)
local HIT_OFFSET_KEY = utf8.char(3)

local bulletRedirection = {}

local _active = false
local _target: any? = nil
local _chance = 100
local _installed = false

local _manipActive = false
local _originOffset = Vector3.zero
local _packetHooked = false

local _lastSpoofedOrigin: Vector3? = nil
local _lastSpoofedTime = 0
local SPOOFED_ORIGIN_MAX_AGE = 0.25

local _manipLevelAtom = Charm.atom(nil :: number?)
local _manipBarActive = false
local _manipConnection: RBXScriptConnection? = nil
local _manipClock = 0
local MANIP_INTERVAL = 0.1

local _lastBarOrigin: Vector3? = nil
local _lastBarTarget: Vector3? = nil
local _lastBarLevel: number? = nil
local BAR_RESOLVE_EPS = 0.5

bulletRedirection.manipLevel = _manipLevelAtom

local _hookedCamera: Camera? = nil

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include
raycastParams.IgnoreWater = true
raycastParams.RespectCanCollide = false

local _sourceItemCache: { [string]: boolean } = {}

local isCameraDataCaller = function(): boolean
	for level = 2, 7 do
		local source = debug.info(level, "s")
		if not source then
			break
		end
		local cached = _sourceItemCache[source]
		if cached == nil then
			cached = source:find("Item") ~= nil
			_sourceItemCache[source] = cached
		end
		if cached then
			return true
		end
	end
	return false
end

local makeSpoofedRay = function(origin: Vector3): Ray
	return Ray.new(origin, (_target.position :: Vector3 - origin).Unit)
end

local function install(): ()
	if _installed then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local rayReplacement = LPH_NO_VIRTUALIZE(function(original: (...any) -> ...any, self: any, ...: any): Ray
		if _active and _target and (WeaponController._selfFiring or not checkcaller()) and isCameraDataCaller() then
			if _chance >= 100 or math.random(1, 100) <= _chance then
				local real: Ray = original(self, ...)
				return makeSpoofedRay(real.Origin)
			end
		end
		return original(self, ...)
	end)

	hook.addInstance(camera)
	hook.replaceMethod(camera, "ViewportPointToRay", rayReplacement)
	hook.replaceMethod(camera, "ScreenPointToRay", rayReplacement)
	_hookedCamera = camera
	_installed = true
end

local function uninstall(): ()
	if not _installed then
		return
	end

	if _hookedCamera then
		hook.restoreMethod(_hookedCamera, "ViewportPointToRay")
		hook.restoreMethod(_hookedCamera, "ScreenPointToRay")
		_hookedCamera = nil
	end

	_installed = false
end

local decodeCFrame = LPH_NO_VIRTUALIZE(function(encoded: any): CFrame?
	if type(encoded) ~= "table" then
		return nil
	end
	local x, y, z = encoded[CF_X], encoded[CF_Y], encoded[CF_Z]
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
		return nil
	end
	local cf = CFrame.new(x, y, z)
	local rx, ry, rz = encoded[CF_RX], encoded[CF_RY], encoded[CF_RZ]
	if type(rx) == "number" and type(ry) == "number" and type(rz) == "number" then
		cf = cf * CFrame.fromOrientation(rx, ry, rz)
	end
	return cf
end)

local writeCFrame = LPH_NO_VIRTUALIZE(function(encoded: any, cf: CFrame): ()
	if type(encoded) ~= "table" then
		return
	end
	local rx, ry, rz = cf:ToOrientation()
	encoded[CF_X] = cf.X
	encoded[CF_Y] = cf.Y
	encoded[CF_Z] = cf.Z
	encoded[CF_RX] = rx
	encoded[CF_RY] = ry
	encoded[CF_RZ] = rz
end)

local function cameraCFrame(): CFrame?
	local camera = Workspace.CurrentCamera
	return camera and camera.CFrame
end

local function toCameraWorld(offset: Vector3): Vector3
	if offset == Vector3.zero then
		return Vector3.zero
	end
	local cf = cameraCFrame()
	if not cf then
		return Vector3.zero
	end
	return cf.RightVector * offset.X + cf.UpVector * offset.Y + cf.LookVector * offset.Z
end

local function offsetWorld(): Vector3
	return toCameraWorld(_originOffset)
end

local function clearTo(origin: Vector3, target: Vector3): (boolean, Instance?)
	local direction = target - origin
	local distance = direction.Magnitude
	if distance < 1e-3 then
		return true, nil
	end
	local result = Workspace:Raycast(origin, direction, raycastParams)
	if not result then
		return true, nil
	end
	if (result.Position - origin).Magnitude >= distance - CLEAR_TOLERANCE then
		return true, nil
	end
	return false, result.Instance
end

local culledBlocked = LPH_NO_VIRTUALIZE(function(origin: Vector3, target: Vector3): boolean
	local toTarget = target - origin
	local distance = toTarget.Magnitude
	if distance <= CLEAR_TOLERANCE + 1e-3 then
		return false
	end
	local shortened = origin + toTarget * ((distance - CLEAR_TOLERANCE) / distance)
	return segmentBlocked(origin, shortened) ~= nil
end)

local embedAlong = LPH_NO_VIRTUALIZE(function(origin: Vector3, dir: Vector3, target: Vector3): Vector3?
	local cur = origin
	for _ = 1, MAX_EMBED_STEPS do
		if _raysLeft <= 1 then
			return nil
		end
		local remaining = MAX_SHIFT - (cur - origin).Magnitude
		if remaining <= 1e-3 then
			return nil
		end
		_raysLeft -= 1
		local result = Workspace:Raycast(cur, dir * remaining, raycastParams)
		if not result then
			return nil
		end
		cur = result.Position + dir * EMBED_DEPTH
		if (cur - origin).Magnitude > MAX_SHIFT then
			return nil
		end
		_raysLeft -= 1
		if clearTo(cur, target) then
			return cur
		end
	end
	return nil
end)

local shiftLevel = LPH_NO_VIRTUALIZE(function(shift: number): number
	local level = 1 - math.clamp(shift / MAX_SHIFT, 0, 1) * 0.85
	if level < 0.12 then
		level = 0.12
	end
	return level
end)

local solveOrigin = LPH_NO_VIRTUALIZE(function(origin: Vector3, target: Vector3): (Vector3?, number)
	local whitelist = mapWhitelist.get()
	if whitelist ~= _lastWhitelist then
		_lastWhitelist = whitelist
		raycastParams.FilterDescendantsInstances = whitelist
	end
	boxOcclusion.reset()

	local clear, blocker = clearTo(origin, target)
	if clear then
		_memoDirIdx = -1
		_failOrigin = nil
		return origin, 1
	end
	if blocker then
		registerBlocker(blocker)
	end

	if
		_failOrigin
		and _failTarget
		and os.clock() - _failClock < FAIL_TTL
		and (origin - _failOrigin).Magnitude < FAIL_EPS
		and (target - _failTarget).Magnitude < FAIL_EPS
	then
		return nil, 0
	end

	local cf = cameraCFrame()
	local toTarget = target - origin
	local rayMag = toTarget.Magnitude

	local dirs = dirBuffer
	table.clear(dirs)
	if rayMag > 1e-3 then
		dirs[#dirs + 1] = toTarget / rayMag
	end
	if cf then
		dirs[#dirs + 1] = cf.LookVector
		dirs[#dirs + 1] = -cf.LookVector
		dirs[#dirs + 1] = cf.RightVector
		dirs[#dirs + 1] = -cf.RightVector
		dirs[#dirs + 1] = cf.UpVector
	end
	for i = 1, #WORLD_DIRS do
		dirs[#dirs + 1] = WORLD_DIRS[i]
	end
	local nDirs = #dirs

	_raysLeft = RAY_BUDGET - 1

	if _memoDirIdx >= 1 and _memoDirIdx <= nDirs then
		local memoOrigin = origin + dirs[_memoDirIdx] * _memoDist
		if not culledBlocked(memoOrigin, target) then
			_raysLeft -= 1
			local memoClear, memoBlocker = clearTo(memoOrigin, target)
			if memoClear then
				_failOrigin = nil
				return memoOrigin, shiftLevel(_memoDist)
			end
			if memoBlocker then
				registerBlocker(memoBlocker)
			end
		end
	end

	local shortTarget = target
	if rayMag > CLEAR_TOLERANCE + 1e-3 then
		shortTarget = origin + toTarget * ((rayMag - CLEAR_TOLERANCE) / rayMag)
	end

	local guide: Vector3? = nil
	if blocker and blocker:IsA("BasePart") and rayMag > 1e-3 then
		local axis = toTarget / rayMag
		local fromBlocker = origin - (blocker :: BasePart).Position
		local perp = fromBlocker - axis * fromBlocker:Dot(axis)
		local perpMag = perp.Magnitude
		if perpMag > 1e-3 then
			guide = perp / perpMag
		end
	end

	local tEst = _tBuffer
	local hasBoxes = boxOcclusion.count() > 0
	for i = 1, nDirs do
		if hasBoxes then
			local t = escapeT(origin, dirs[i], shortTarget, 0, MAX_SHIFT, SCAN_STEP)
			if t and t <= 1e-3 then
				t = SCAN_STEP
			end
			tEst[i] = t or math.huge
		else
			tEst[i] = SCAN_STEP
		end
	end

	local scores = _scoreBuffer
	for i = 1, nDirs do
		scores[i] = guide and dirs[i]:Dot(guide) or 0
	end

	local order = _orderBuffer
	for i = 1, nDirs do
		order[i] = i
	end
	for i = 2, nDirs do
		local v = order[i]
		local tv = tEst[v]
		local sv = scores[v]
		local j = i - 1
		while j >= 1 do
			local prev = order[j]
			local tp = tEst[prev]
			if tp > tv or (tp == tv and scores[prev] < sv) then
				order[j + 1] = prev
				j -= 1
			else
				break
			end
		end
		order[j + 1] = v
	end

	for k = 1, nDirs do
		if _raysLeft <= 0 then
			break
		end
		local idx = order[k]
		local t = tEst[idx]
		if t > MAX_SHIFT then
			break
		end
		local dir = dirs[idx]
		local tries = 0
		while t <= MAX_SHIFT and tries < DIR_TRY_CAP and _raysLeft > 0 do
			local candidate = origin + dir * t
			if culledBlocked(candidate, target) then
				local newT = escapeT(origin, dir, shortTarget, t, MAX_SHIFT, SCAN_STEP)
				if not newT or newT > MAX_SHIFT then
					break
				end
				if newT > t + 1e-3 then
					t = newT
				else
					t += SCAN_STEP
				end
			else
				_raysLeft -= 1
				tries += 1
				local candClear, candBlocker = clearTo(candidate, target)
				if candClear then
					_memoDirIdx = idx
					_memoDist = t
					_failOrigin = nil
					return candidate, shiftLevel(t)
				end
				if candBlocker then
					registerBlocker(candBlocker)
				end
				local newT = escapeT(origin, dir, shortTarget, t, MAX_SHIFT, SCAN_STEP)
				if newT and newT > t + 1e-3 then
					t = newT
				else
					t += SCAN_STEP
				end
			end
		end
	end

	for k = 1, nDirs do
		if _raysLeft <= 1 then
			break
		end
		local found = embedAlong(origin, dirs[order[k]], target)
		if found then
			_memoDirIdx = -1
			_failOrigin = nil
			return found, shiftLevel((found - origin).Magnitude)
		end
	end

	_memoDirIdx = -1
	_failOrigin = origin
	_failTarget = target
	_failClock = os.clock()
	return nil, 0
end)

local manipulateCameraData = LPH_NO_VIRTUALIZE(function(cameraData: any): ()
	if type(cameraData) ~= "table" then
		return
	end
	local inner = cameraData[CAMERA_DATA_KEY]
	if type(inner) ~= "table" then
		return
	end

	local startCF = decodeCFrame(inner[CAMERA_START_KEY])
	if not startCF then
		return
	end

	local targetPart = _target and _target.part
	local targetPosition: Vector3? = _target and _target.position
	local hasTarget = targetPart ~= nil and (targetPart :: BasePart).Parent ~= nil and targetPosition ~= nil

	local aimPos: Vector3
	if hasTarget then
		aimPos = targetPosition :: Vector3
	else
		local hitPart = inner[HIT_PART_KEY]
		local hitOffsetCF = decodeCFrame(inner[HIT_OFFSET_KEY])
		if typeof(hitPart) == "Instance" and (hitPart :: Instance):IsA("BasePart") and hitOffsetCF then
			aimPos = ((hitPart :: BasePart).CFrame * hitOffsetCF).Position
		else
			aimPos = startCF.Position + startCF.LookVector * MAX_DIST
		end
	end

	local base = startCF.Position + offsetWorld()
	local solved = solveOrigin(base, aimPos)
	local newOrigin = solved or base

	if (newOrigin - aimPos).Magnitude < 1e-3 then
		return
	end

	if hasTarget then
		inner[HIT_PART_KEY] = targetPart
		if type(inner[HIT_OFFSET_KEY]) ~= "table" then
			inner[HIT_OFFSET_KEY] = {}
		end
		writeCFrame(inner[HIT_OFFSET_KEY], (targetPart :: BasePart).CFrame:ToObjectSpace(CFrame.new(aimPos)))
	end

	_lastSpoofedOrigin = newOrigin
	_lastSpoofedTime = os.clock()

	local newCF = CFrame.lookAt(newOrigin, aimPos)
	writeCFrame(inner[CAMERA_START_KEY], newCF)
	writeCFrame(inner[CAMERA_END_KEY], newCF)
end)

local _packetManipulator = LPH_NO_VIRTUALIZE(function(cameraData: any): ()
	if _manipActive then
		manipulateCameraData(cameraData)
	end
end)

local function installPacketHook(): ()
	if _packetHooked then
		return
	end
	WeaponController.AddShotManipulator(_packetManipulator)
	_packetHooked = true
end

local function uninstallPacketHook(): ()
	if not _packetHooked then
		return
	end
	WeaponController.RemoveShotManipulator(_packetManipulator)
	_packetHooked = false
end

function bulletRedirection.setActive(state: boolean): ()
	if _active == state then
		return
	end
	_active = state
	if state then
		install()
	else
		_target = nil
		if not _manipActive then
			uninstall()
		end
	end
end

function bulletRedirection.setTarget(newTarget: any?): ()
	_target = newTarget
end

function bulletRedirection.setChance(chance: number): ()
	_chance = math.clamp(chance, 0, 100)
end

function bulletRedirection.setManipulationActive(state: boolean): ()
	if _manipActive == state then
		return
	end
	_manipActive = state
	if state then
		installPacketHook()
	else
		uninstallPacketHook()
	end
end

function bulletRedirection.solveShotOrigin(origin: Vector3, target: Vector3): Vector3?
	local solved = solveOrigin(origin, target)
	return solved
end

function bulletRedirection.setOriginOffset(offset: Vector3): ()
	_originOffset = offset
end

function bulletRedirection.getSpoofedOrigin(): Vector3?
	if _lastSpoofedOrigin and os.clock() - _lastSpoofedTime <= SPOOFED_ORIGIN_MAX_AGE then
		return _lastSpoofedOrigin
	end
	return nil
end

local updateManipBar = LPH_NO_VIRTUALIZE(function(): ()
	if not (_manipActive and _target and _target.position) then
		if peek(_manipLevelAtom) ~= nil then
			_manipLevelAtom(nil)
		end
		return
	end

	local now = os.clock()
	if now - _manipClock < MANIP_INTERVAL then
		return
	end
	_manipClock = now

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local origin = camera.CFrame.Position + offsetWorld()
	local targetPos = _target.position :: Vector3

	if
		_lastBarOrigin
		and _lastBarTarget
		and _lastBarLevel
		and (origin - _lastBarOrigin).Magnitude < BAR_RESOLVE_EPS
		and (targetPos - _lastBarTarget).Magnitude < BAR_RESOLVE_EPS
	then
		if peek(_manipLevelAtom) ~= _lastBarLevel then
			_manipLevelAtom(_lastBarLevel)
		end
		return
	end

	local _, level = solveOrigin(origin, targetPos)

	_lastBarOrigin = origin
	_lastBarTarget = targetPos
	_lastBarLevel = level

	if peek(_manipLevelAtom) ~= level then
		_manipLevelAtom(level)
	end
end)

function bulletRedirection.setManipBarActive(state: boolean): ()
	state = state == true
	if _manipBarActive == state then
		return
	end
	_manipBarActive = state

	if state then
		if not _manipConnection then
			_manipConnection = RunService.Heartbeat:Connect(updateManipBar)
		end
	else
		if _manipConnection then
			_manipConnection:Disconnect()
			_manipConnection = nil
		end
		_manipLevelAtom(nil)
	end
end

return bulletRedirection
