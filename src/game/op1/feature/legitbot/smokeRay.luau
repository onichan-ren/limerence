local EPSILON = 1e-4

local smokeRay = {}

local rayBoxEnterExit = LPH_NO_VIRTUALIZE(
	function(
		rayOrigin: Vector3,
		rayDirectionUnit: Vector3,
		maxDistance: number,
		boxMin: Vector3,
		boxMax: Vector3
	): (number?, number?)
		local tEnter = 0
		local tExit = maxDistance

		local oX, oY, oZ = rayOrigin.X, rayOrigin.Y, rayOrigin.Z
		local dX, dY, dZ = rayDirectionUnit.X, rayDirectionUnit.Y, rayDirectionUnit.Z
		local minX, minY, minZ = boxMin.X, boxMin.Y, boxMin.Z
		local maxX, maxY, maxZ = boxMax.X, boxMax.Y, boxMax.Z

		if math.abs(dX) < EPSILON then
			if oX < minX or oX > maxX then
				return nil
			end
		else
			local invD = 1 / dX
			local t1 = (minX - oX) * invD
			local t2 = (maxX - oX) * invD
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			if t1 > tEnter then
				tEnter = t1
			end
			if t2 < tExit then
				tExit = t2
			end
			if tEnter > tExit then
				return nil
			end
		end

		if math.abs(dY) < EPSILON then
			if oY < minY or oY > maxY then
				return nil
			end
		else
			local invD = 1 / dY
			local t1 = (minY - oY) * invD
			local t2 = (maxY - oY) * invD
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			if t1 > tEnter then
				tEnter = t1
			end
			if t2 < tExit then
				tExit = t2
			end
			if tEnter > tExit then
				return nil
			end
		end

		if math.abs(dZ) < EPSILON then
			if oZ < minZ or oZ > maxZ then
				return nil
			end
		else
			local invD = 1 / dZ
			local t1 = (minZ - oZ) * invD
			local t2 = (maxZ - oZ) * invD
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			if t1 > tEnter then
				tEnter = t1
			end
			if t2 < tExit then
				tExit = t2
			end
			if tEnter > tExit then
				return nil
			end
		end

		if tExit < 0 or tEnter > maxDistance then
			return nil
		end
		if tEnter < 0 then
			tEnter = 0
		end
		if tExit > maxDistance then
			tExit = maxDistance
		end
		return tEnter, tExit
	end
)

smokeRay.lengthThroughSmoke = LPH_NO_VIRTUALIZE(
	function(rayOrigin: Vector3, rayDirectionUnit: Vector3, maxDistance: number, voxels: { [Part]: any }): number
		local total = 0
		for voxel in next, voxels do
			if not voxel.Parent then
				continue
			end
			local center = voxel.Position
			local size = voxel.Size
			local hX, hY, hZ = size.X * 0.5, size.Y * 0.5, size.Z * 0.5
			local boxMin = Vector3.new(center.X - hX, center.Y - hY, center.Z - hZ)
			local boxMax = Vector3.new(center.X + hX, center.Y + hY, center.Z + hZ)
			local tEnter, tExit = rayBoxEnterExit(rayOrigin, rayDirectionUnit, maxDistance, boxMin, boxMax)
			if tEnter and tExit then
				total += tExit - tEnter
			end
		end
		return total
	end
)

return smokeRay
