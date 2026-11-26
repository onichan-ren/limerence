local spreadMath = {}

local CF_ANGLES = CFrame.Angles
local CF_LOOK = CFrame.new
local ZERO = Vector3.zero

local applySpread = LPH_NO_VIRTUALIZE(function(dir: Vector3, polar: number, az: number): Vector3
	return (CF_LOOK(ZERO, dir) * CF_ANGLES(0, 0, az) * CF_ANGLES(polar, 0, 0)).LookVector
end)

spreadMath.applySpread = applySpread

spreadMath.inverseSpread = LPH_NO_VIRTUALIZE(function(desired: Vector3, polar: number, az: number): Vector3
	local base = desired
	for _ = 1, 5 do
		local got = applySpread(base, polar, az)
		local axis = got:Cross(desired)
		local sinMag = axis.Magnitude
		if sinMag < 1e-7 then
			break
		end
		local cosA = math.clamp(got:Dot(desired), -1, 1)
		local rot = CFrame.fromAxisAngle(axis / sinMag, math.atan2(sinMag, cosA))
		base = rot:VectorToWorldSpace(base)
	end
	return base
end)

return spreadMath
