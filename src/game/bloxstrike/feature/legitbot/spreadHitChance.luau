local weaponSpreadState = require("@game/bloxstrike/client/weaponSpreadState")

local TINY_SPREAD_DEG = 0.05
local ANG_EPS = 1e-4

local spreadHitChance = {}

local coneHitChance = LPH_NO_VIRTUALIZE(function(
	origin: Vector3,
	aimDirUnit: Vector3,
	targetPos: Vector3,
	spreadDegrees: number,
	targetRadiusStuds: number
): number
	if spreadDegrees <= TINY_SPREAD_DEG then
		return 1
	end

	local spreadClamped = math.min(math.max(0, spreadDegrees), 69)
	local phiMax = math.rad(spreadClamped * 0.5)
	if phiMax <= 0 then
		return 1
	end

	local toT = targetPos - origin
	local dist = toT.Magnitude
	if dist < 1e-4 then
		return 1
	end

	local angAllow = math.atan(targetRadiusStuds / dist) + ANG_EPS
	if angAllow >= phiMax then
		return 1
	end

	local cosAllow = math.cos(angAllow)
	local cosMax = math.cos(phiMax)
	local denom = 1 - cosMax
	if denom < 1e-8 then
		return 1
	end

	return math.clamp((1 - cosAllow) / denom, 0, 1)
end)

spreadHitChance.coneHitChance = coneHitChance

spreadHitChance.estimateForPart = LPH_NO_VIRTUALIZE(
	function(cameraPos: Vector3, part: BasePart, weapon: any, _rng: Random?): number?
		local spreadDeg = weaponSpreadState.getSpreadDegrees(weapon)
		if spreadDeg == nil then
			return nil
		end
		local cam = workspace.CurrentCamera
		local look = (cam and cam.CFrame.LookVector or (part.Position - cameraPos).Unit)
		local sz = part.Size
		local rad = 0.5 * math.max(sz.X, sz.Y, sz.Z)
		return coneHitChance(cameraPos, look, part.Position, spreadDeg, rad)
	end
)

return spreadHitChance
