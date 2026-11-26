local Charm = require("@pkg/Charm")
local PlayerController = require("@feature/player/PlayerController")
local CommandController = require("@game/overkill/weapon/CommandController")
local ModuleController = require("@game/overkill/module/ModuleController")
local botSource = require("@game/overkill/feature/training/botSource")
local deflectPov = require("@game/overkill/feature/legitbot/deflectPov")
local playerState = require("@feature/record/module/playerState")
local targeting = require("@game/overkill/player/targeting")

local peek = Charm.peek

local CMD_PRIORITY = 110

local BACKSTAB_STEPS = 6
local BACKSTAB_SWEEP = math.rad(55)
local BACKSTAB_PITCHES = { math.rad(50), -math.rad(50), math.rad(78), -math.rad(78) }
local CENTER_PARTS = { "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso" }

local items: any = nil
local reachCache: { [string]: number } = {}

local dirToAngles = LPH_NO_VIRTUALIZE(function(dir: Vector3): (number, number)
	local pitch = math.asin(math.clamp(dir.Y, -1, 1))
	local yaw = math.atan2(-dir.X, -dir.Z)
	return pitch, yaw
end)

local swingLook = LPH_NO_VIRTUALIZE(function(pitch: number, yaw: number): Vector3
	return (CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)).LookVector
end)

local pointInBox = LPH_NO_VIRTUALIZE(function(eye: Vector3, pitch: number, yaw: number, offset: CFrame, half: Vector3, point: Vector3): boolean
	local boxCF = CFrame.new(eye) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0) * offset
	local lp = boxCF:PointToObjectSpace(point)
	return math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z
end)

local coneAndBox = LPH_NO_VIRTUALIZE(function(eye: Vector3, pitch: number, yaw: number, offset: CFrame, half: Vector3, point: Vector3, flatX: number, flatZ: number): boolean
	local look = swingLook(pitch, yaw)
	local lookXZ = math.sqrt(look.X * look.X + look.Z * look.Z)
	if lookXZ < 1e-4 or (look.X * flatX + look.Z * flatZ) / lookXZ <= 0.5 then
		return false
	end
	return pointInBox(eye, pitch, yaw, offset, half, point)
end)

local function centerPart(parts: { [string]: any }): BasePart?
	for i = 1, #CENTER_PARTS do
		local part = parts[CENTER_PARTS[i]]
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local meleeShared = {}

meleeShared.RANGE_MARGIN = 0.5
meleeShared.dirToAngles = dirToAngles

function meleeShared.meleeStats(weaponId: string): any
	if not items then
		items = ModuleController.GetModule("items")
	end
	if not items or type(weaponId) ~= "string" or weaponId == "" then
		return nil
	end
	local item = items.all[weaponId]
	return item and item.stats and item.stats.melee
end

function meleeShared.comboReach(cacheKey: string, combo: any): number
	local cached = reachCache[cacheKey]
	if cached ~= nil then
		return cached
	end
	local reach = 0
	for i = 1, #combo do
		local step = combo[i]
		local size = step.hitboxSize
		local offset = step.hitboxOffset or CFrame.identity
		if size then
			local r = offset.Position.Magnitude + math.max(size.X, size.Y, size.Z) * 0.5
			if r > reach then
				reach = r
			end
		end
	end
	reachCache[cacheKey] = reach
	return reach
end

local considerCandidate = LPH_NO_VIRTUALIZE(function(bp: any, eye: Vector3, maxDist: number, lowestHealth: boolean, bestScore: number): (BasePart?, any?, number?)
	if not targeting.isEnemy(bp) or deflectPov.isPlayerDeflecting(bp) then
		return nil
	end
	local rbxPlayer = bp:GetPlayer()
	local userId = (not bp.isBot and rbxPlayer) and rbxPlayer.UserId or nil
	if userId and playerState.ShouldSkip(userId) then
		return nil
	end
	local parts = peek(bp.parts)
	if next(parts) == nil then
		return nil
	end
	local part = centerPart(parts)
	if not part then
		return nil
	end
	local dist = (part.CFrame.Position - eye).Magnitude
	if dist > maxDist then
		return nil
	end
	local score = lowestHealth and ((bp.health and peek(bp.health)) or 0) or dist
	if score >= bestScore then
		return nil
	end
	return part, bp, score
end)

function meleeShared.pickTarget(eye: Vector3, maxDist: number, lowestHealth: boolean): (BasePart?, any?)
	local best: BasePart? = nil
	local bestOwner: any? = nil
	local bestScore = math.huge

	for _, bp in next, PlayerController.GetAll() do
		local part, owner, score = considerCandidate(bp, eye, maxDist, lowestHealth, bestScore)
		if part then
			best = part
			bestOwner = owner
			bestScore = score :: number
		end
	end
	for _, bot in next, botSource.GetAll() do
		local part, owner, score = considerCandidate(bot, eye, maxDist, lowestHealth, bestScore)
		if part then
			best = part
			bestOwner = owner
			bestScore = score :: number
		end
	end

	return best, bestOwner
end

meleeShared.solveBackstab = LPH_NO_VIRTUALIZE(function(eye: Vector3, targetPos: Vector3, facing: Vector3, size: Vector3, offset: CFrame, basePitch: number): (number?, number?)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 1e-3 then
		return nil, nil
	end
	flat = flat.Unit

	local half = size * 0.5
	local _, yawF = dirToAngles(flat)

	for p = 0, #BACKSTAB_PITCHES do
		local pitch = p == 0 and basePitch or BACKSTAB_PITCHES[p]
		for i = 0, BACKSTAB_STEPS - 1 do
			local off = (i / (BACKSTAB_STEPS - 1)) * BACKSTAB_SWEEP
			for side = 1, i == 0 and 1 or 2 do
				local yaw = side == 1 and yawF + off or yawF - off
				if coneAndBox(eye, pitch, yaw, offset, half, targetPos, flat.X, flat.Z) then
					return pitch, yaw
				end
			end
		end
	end

	return nil, nil
end)

meleeShared.yawStillHits = LPH_NO_VIRTUALIZE(function(eye: Vector3, pitch: number, yaw: number, targetPos: Vector3, facing: Vector3, size: Vector3, offset: CFrame): boolean
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 1e-3 then
		return false
	end
	flat = flat.Unit
	return coneAndBox(eye, pitch, yaw, offset, size * 0.5, targetPos, flat.X, flat.Z)
end)

local RotationSpoof = {}
RotationSpoof.__index = RotationSpoof

function meleeShared.newRotationSpoof(): RotationSpoof
	return setmetatable({
		pending = false,
		delta = 0,
		spoofed = false,
		saved = nil :: Vector3?,
	}, RotationSpoof) :: any
end

function RotationSpoof.apply(self: RotationSpoof, cameraHandler: any, pitch: number, yaw: number): boolean
	local rotation = cameraHandler.currentRotation
	if rotation == nil then
		return false
	end
	self.saved = rotation
	self.delta = rotation.Y - yaw
	cameraHandler.currentRotation = Vector3.new(pitch, yaw, rotation.Z)
	self.spoofed = true
	self.pending = true
	return true
end

function RotationSpoof.restore(self: RotationSpoof, cameraHandler: any): ()
	if not self.spoofed then
		return
	end
	self.spoofed = false
	if cameraHandler and self.saved ~= nil then
		cameraHandler.currentRotation = self.saved
	end
	self.saved = nil
end

function meleeShared.registerYawCorrection(spoof: RotationSpoof): () -> ()
	return CommandController.Register(LPH_JIT_MAX(function(command: any): ()
		if not spoof.pending or type(command) ~= "table" then
			return
		end
		local delta = spoof.delta
		if delta == 0 then
			return
		end
		local x = command.x or 0
		local z = command.z or 0
		if x == 0 and z == 0 then
			return
		end
		local corrected = CFrame.fromEulerAnglesYXZ(0, delta, 0) * Vector3.new(x, 0, z)
		command.x = corrected.X
		command.z = corrected.Z
	end), CMD_PRIORITY)
end

export type RotationSpoof = typeof(setmetatable(
	{} :: {
		pending: boolean,
		delta: number,
		spoofed: boolean,
		saved: Vector3?,
	},
	RotationSpoof
))

export type MeleeShared = typeof(meleeShared)

return meleeShared
