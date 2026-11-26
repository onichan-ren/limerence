local multipoint = {}

local DEFAULT_SCALE = 0.7
local CORNER_INSET = 0.85

multipoint.samplePointsInto = LPH_NO_VIRTUALIZE(
	function(buffer: { Vector3 }, cf: CFrame, size: Vector3, scale: number?, cornerInset: number?): number
		local center = cf.Position
		local s = scale or DEFAULT_SCALE
		if s <= 0 then
			buffer[1] = center
			return 1
		end

		local right = cf.RightVector
		local up = cf.UpVector
		local look = cf.LookVector

		local rx = right * (size.X * 0.5 * s)
		local uy = up * (size.Y * 0.5 * s)
		local lz = look * (size.Z * 0.5 * s)

		buffer[1] = center
		buffer[2] = center + rx
		buffer[3] = center - rx
		buffer[4] = center + uy
		buffer[5] = center - uy
		buffer[6] = center + lz
		buffer[7] = center - lz

		local inset = cornerInset or CORNER_INSET
		local rxi = rx * inset
		local uyi = uy * inset
		local lzi = lz * inset
		buffer[8] = center + rxi + uyi + lzi
		buffer[9] = center + rxi + uyi - lzi
		buffer[10] = center + rxi - uyi + lzi
		buffer[11] = center + rxi - uyi - lzi
		buffer[12] = center - rxi + uyi + lzi
		buffer[13] = center - rxi + uyi - lzi
		buffer[14] = center - rxi - uyi + lzi
		buffer[15] = center - rxi - uyi - lzi

		return 15
	end
)

return multipoint
