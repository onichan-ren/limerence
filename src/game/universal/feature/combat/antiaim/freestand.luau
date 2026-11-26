local freestand = {}

local RECOMPUTE_INTERVAL = 0.05
local MIN_INTERVAL = 1 / 30
local EYE_MOVE_EPS = 1
local SIDE_OFFSET = 1.8
local LOWER_DROP = 1.4
local MAX_ENEMY_DIST = 350
local MIN_WEIGHT_DIST = 8
local ENTER_MARGIN = 0.12
local SWITCH_MARGIN = 0.25
local EXIT_MARGIN = 0.05
local MIN_HOLD = 0.45
local ENTER_HOLD = 0.15
local NEUTRAL_HOLD = 0.5
local SMOOTH_TAU = 0.15
local MAX_SMOOTH_DT = 0.5

export type Side = "Left" | "Right"
export type CastClear = (origin: Vector3, target: Vector3, context: any?) -> boolean

local Freestand = {}
Freestand.__index = Freestand

function freestand.new(castClear: CastClear): Freestand
	local self = setmetatable({}, Freestand) :: any

	self._castClear = castClear
	self._side = nil :: Side?
	self._lastComputeAt = 0
	self._lastSwitchAt = 0
	self._neutralSince = nil :: number?
	self._lastEye = nil :: Vector3?
	self._emaLeft = 0
	self._emaRight = 0
	self._emaPrimed = false

	return self
end

Freestand.ShouldRecompute = LPH_NO_VIRTUALIZE(function(self: Freestand, now: number, eye: Vector3): boolean
	local elapsed = now - self._lastComputeAt
	if elapsed >= RECOMPUTE_INTERVAL then
		return true
	end
	if elapsed < MIN_INTERVAL then
		return false
	end
	local lastEye = self._lastEye
	return lastEye ~= nil and (eye - lastEye).Magnitude > EYE_MOVE_EPS
end)

Freestand.Compute = LPH_NO_VIRTUALIZE(
	function(
		self: Freestand,
		now: number,
		eye: Vector3,
		rightVec: Vector3,
		positions: { Vector3 },
		contexts: { any }?,
		count: number
	): ()
		local computeDt = now - self._lastComputeAt
		self._lastComputeAt = now
		self._lastEye = eye

		if count <= 0 then
			self._side = nil
			self._neutralSince = nil
			self._emaPrimed = false
			return
		end

		local castClear = self._castClear
		local leftUpper = eye - rightVec * SIDE_OFFSET
		local rightUpper = eye + rightVec * SIDE_OFFSET
		local drop = Vector3.new(0, LOWER_DROP, 0)
		local leftLower = leftUpper - drop
		local rightLower = rightUpper - drop

		local expLeft = 0
		local expRight = 0
		local totalWeight = 0

		for i = 1, count do
			local enemyEye = positions[i]
			local dist = (enemyEye - eye).Magnitude
			if dist > MAX_ENEMY_DIST then
				continue
			end
			local context = contexts and contexts[i] or nil
			local weight = 1 / math.max(dist, MIN_WEIGHT_DIST)
			totalWeight += weight

			local left = 0
			if castClear(enemyEye, leftUpper, context) then
				left += 0.5
			end
			if castClear(enemyEye, leftLower, context) then
				left += 0.5
			end
			local right = 0
			if castClear(enemyEye, rightUpper, context) then
				right += 0.5
			end
			if castClear(enemyEye, rightLower, context) then
				right += 0.5
			end

			expLeft += weight * left
			expRight += weight * right
		end

		if totalWeight <= 0 then
			self._side = nil
			self._neutralSince = nil
			self._emaPrimed = false
			return
		end

		expLeft /= totalWeight
		expRight /= totalWeight

		if self._emaPrimed then
			if computeDt > MAX_SMOOTH_DT then
				computeDt = MAX_SMOOTH_DT
			end
			local alpha = 1 - math.exp(-computeDt / SMOOTH_TAU)
			self._emaLeft += (expLeft - self._emaLeft) * alpha
			self._emaRight += (expRight - self._emaRight) * alpha
		else
			self._emaLeft = expLeft
			self._emaRight = expRight
			self._emaPrimed = true
		end
		expLeft = self._emaLeft
		expRight = self._emaRight

		local diff = expLeft - expRight
		local side = self._side

		if side == nil then
			if now - self._lastSwitchAt < ENTER_HOLD then
				return
			end
			if diff <= -ENTER_MARGIN then
				self._side = "Left"
				self._lastSwitchAt = now
			elseif diff >= ENTER_MARGIN then
				self._side = "Right"
				self._lastSwitchAt = now
			end
			self._neutralSince = nil
			return
		end

		local magnitude = diff < 0 and -diff or diff
		if magnitude < EXIT_MARGIN then
			local since = self._neutralSince
			if since == nil then
				self._neutralSince = now
			elseif now - since >= NEUTRAL_HOLD then
				self._side = nil
				self._neutralSince = nil
				self._lastSwitchAt = now
			end
			return
		end
		self._neutralSince = nil

		local currentExposure = side == "Left" and expLeft or expRight
		local otherExposure = side == "Left" and expRight or expLeft
		if otherExposure + SWITCH_MARGIN <= currentExposure and now - self._lastSwitchAt >= MIN_HOLD then
			self._side = side == "Left" and "Right" or "Left"
			self._lastSwitchAt = now
		end
	end
)

function Freestand.GetSide(self: Freestand): Side?
	return self._side
end

function Freestand.Reset(self: Freestand): ()
	self._side = nil
	self._neutralSince = nil
	self._lastEye = nil
	self._lastComputeAt = 0
	self._emaPrimed = false
end

export type Freestand = typeof(setmetatable(
	{} :: {
		_castClear: CastClear,
		_side: Side?,
		_lastComputeAt: number,
		_lastSwitchAt: number,
		_neutralSince: number?,
		_lastEye: Vector3?,
		_emaLeft: number,
		_emaRight: number,
		_emaPrimed: boolean,
		ShouldRecompute: (Freestand, number, Vector3) -> boolean,
		Compute: (Freestand, number, Vector3, Vector3, { Vector3 }, { any }?, number) -> (),
	},
	Freestand
))

return freestand
