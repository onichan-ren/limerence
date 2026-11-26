local v3 = Vector3.new
local tan = math.tan
local rad = math.rad

export type Projector = (pos: Vector3) -> Vector3

local make = LPH_NO_VIRTUALIZE(function(camera: Camera, viewport: Vector2): (Projector, number)
	local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = camera.CFrame:GetComponents()
	local y = viewport.Y
	local f = (y * 0.5) / tan(rad(camera.FieldOfView) * 0.5)
	local cxCenter = viewport.X * 0.5
	local cyCenter = y * 0.5

	local project = function(pos: Vector3): Vector3
		local rx = pos.X - px
		local ry = pos.Y - py
		local rz = pos.Z - pz
		local depth = -(rx * r02 + ry * r12 + rz * r22)
		local inv = f / depth
		return v3(
			cxCenter + (rx * r00 + ry * r10 + rz * r20) * inv,
			cyCenter - (rx * r01 + ry * r11 + rz * r21) * inv,
			depth
		)
	end

	return project, f
end)

local project = LPH_NO_VIRTUALIZE(function(camera: Camera, viewport: Vector2, pos: Vector3): Vector3
	local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = camera.CFrame:GetComponents()
	local y = viewport.Y
	local f = (y * 0.5) / tan(rad(camera.FieldOfView) * 0.5)
	local rx = pos.X - px
	local ry = pos.Y - py
	local rz = pos.Z - pz
	local depth = -(rx * r02 + ry * r12 + rz * r22)
	local inv = f / depth
	return v3(
		viewport.X * 0.5 + (rx * r00 + ry * r10 + rz * r20) * inv,
		y * 0.5 - (rx * r01 + ry * r11 + rz * r21) * inv,
		depth
	)
end)

return {
	make = make,
	project = project,
}
