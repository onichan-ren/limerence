local bulletRedirection = {}

local clientApi = require("@game/bloxstrike/client/clientApi")
local weaponSpreadState = require("@game/bloxstrike/client/weaponSpreadState")
local bulletPenetrationRay = require("@game/bloxstrike/feature/legitbot/bulletPenetrationRay")
local hook = require("@share/hook")

local _lastProcessed
local _target
local _active = false
local _chance = 100
local _restoreInsertHook: (() -> ())? = nil
local ZERO_VECTOR = Vector3.new(0, 0, 0)

export type RaycastHit = {
	Position: Vector3,
	Instance: Instance,
	Material: string,
	Normal: Vector3,
	Exit: boolean,
}

export type PerformRaycastResult = {
	Distance: number,
	Origin: Vector3,
	Direction: Vector3,
	Hits: { RaycastHit },
}

local function getNewHits(
	origin: Vector3,
	direction: Vector3,
	performRaycastResult: PerformRaycastResult
): { RaycastHit }
	local hits = {}

	local weaponProperties = clientApi.GetWeaponProperties()
	local penetration = weaponProperties and weaponProperties.Penetration or 0

	local rays = bulletPenetrationRay.castThrough(
		origin + direction * 0.01,
		direction * (performRaycastResult.Distance + penetration),
		penetration,
		nil
	)

	for i = 1, #rays do
		local hit = rays[i]

		if hit.instance and hit.material then
			hits[#hits + 1] = {
				Position = hit.position,
				Instance = hit.instance,
				Material = hit.material.Name,
				Normal = hit.normal or ZERO_VECTOR,
				Exit = i % 2 == 0,
			}
		end
	end

	return hits
end

local function ensureInsertHook(): ()
	if _restoreInsertHook then
		return
	end

	local old
	old = hook.oth(
		table.insert,
		LPH_NO_VIRTUALIZE(function(target, t)
			if
				_active
				and not checkcaller()
				and _target
				and _lastProcessed ~= t
				and type(t) == "table"
				and t["Distance"]
				and t["Origin"]
				and t["Direction"]
				and t["Hits"]
			then
				_lastProcessed = t
				if _chance >= 100 or math.random(1, 100) <= _chance then
					local origin = t.Origin
					local currentWeapon = clientApi.GetWeapon()
					local spreadDegrees = (
						currentWeapon and weaponSpreadState.getFiredSpreadDegrees(currentWeapon) or 0
					)
					local newDirection = weaponSpreadState.applyBulletSpread(
						(_target.position - origin).Unit,
						spreadDegrees
					)
					t.Direction = newDirection
					t.Hits = getNewHits(origin, newDirection * t.Distance, t)
				end
			end

			return old(target, t)
		end)
	)

	_restoreInsertHook = function(): ()
		hook.restoreOth(table.insert :: any)
		_restoreInsertHook = nil
	end
end

function bulletRedirection.setActive(state: boolean)
	if _active == state then
		return
	end

	_active = state
	if state then
		ensureInsertHook()
	else
		_target = nil
		_lastProcessed = nil
		if _restoreInsertHook then
			_restoreInsertHook()
		end
	end
end

function bulletRedirection.setTarget(newTarget: any?)
	_target = newTarget
end

function bulletRedirection.setChance(chance: number)
	_chance = math.clamp(chance, 0, 100)
end

return bulletRedirection
