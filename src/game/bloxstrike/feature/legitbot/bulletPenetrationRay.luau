return LPH_NO_VIRTUALIZE(function()
	local Workspace = game:GetService("Workspace")

	local materialVariantDepth = table.freeze({
		["Sandy Brick"] = 0,
		IndoorWall = 0,
	})

	local materialDepthCap = table.freeze({
		[Enum.Material.Asphalt] = 0,
		[Enum.Material.Basalt] = 0,
		[Enum.Material.Brick] = 0,
		[Enum.Material.Cobblestone] = 0,
		[Enum.Material.Concrete] = 0,
		[Enum.Material.CrackedLava] = 0,
		[Enum.Material.DiamondPlate] = 0,
		[Enum.Material.Foil] = 0,
		[Enum.Material.Glacier] = 0,
		[Enum.Material.Granite] = 0,
		[Enum.Material.Grass] = 0,
		[Enum.Material.Ground] = 0,
		[Enum.Material.Ice] = 0,
		[Enum.Material.LeafyGrass] = 0,
		[Enum.Material.Limestone] = 0,
		[Enum.Material.Marble] = 0,
		[Enum.Material.Metal] = 0,
		[Enum.Material.Mud] = 0,
		[Enum.Material.Pavement] = 0,
		[Enum.Material.Rock] = 0,
		[Enum.Material.Salt] = 0,
		[Enum.Material.Sand] = 0,
		[Enum.Material.Sandstone] = 0,
		[Enum.Material.Slate] = 0,
		[Enum.Material.Snow] = 0,
		[Enum.Material.ForceField] = 0,
		[Enum.Material.Neon] = 0,
		[Enum.Material.CorrodedMetal] = 0,
		[Enum.Material.Pebble] = 0,
		[Enum.Material.CeramicTiles] = 0,
		[Enum.Material.Plaster] = 0,
		[Enum.Material.Plastic] = 10,
		[Enum.Material.SmoothPlastic] = 10,
		[Enum.Material.Wood] = 10,
		[Enum.Material.WoodPlanks] = 10,
		[Enum.Material.Cardboard] = 10,
		[Enum.Material.Glass] = 25,
		[Enum.Material.Fabric] = 25,
	})

	local cachedVizFolder: Folder? = nil

	local modelAncestorCache: { [BasePart]: any } = setmetatable({}, { __mode = "k" }) :: any

	local function getTargetModel(part: BasePart): Model?
		local cached = modelAncestorCache[part]
		if cached ~= nil then
			return cached or nil
		end
		local model = part:FindFirstAncestorWhichIsA("Model")
		modelAncestorCache[part] = model or false
		return model
	end

	local function raycastVizFolder(): Folder?
		local cached = cachedVizFolder
		if cached and cached.Parent then
			return cached
		end
		local debris = Workspace:FindFirstChild("Debris")
		if not debris then
			cachedVizFolder = nil
			return nil
		end
		cachedVizFolder = debris:FindFirstChild("RaycastVisualizers") :: Folder?
		return cachedVizFolder
	end

	local function isPartFiltered(inst: Instance): boolean
		local viz = raycastVizFolder()
		if viz and inst:IsDescendantOf(viz) then
			return true
		end
		if inst:FindFirstAncestorWhichIsA("Accessory") ~= nil then
			return true
		end
		if inst.Name == "CollisionCapsule" then
			return true
		end
		return false
	end

	local function isPartWhitelisted(inst: Instance, whitelist: { Instance }): boolean
		for _, v in next, whitelist do
			if inst == v or inst:IsDescendantOf(v) then
				return true
			end
		end
		return false
	end

	local function getPenetrationMaterial(part: BasePart): Enum.Material
		local parent = part.Parent
		if parent and parent:HasTag("BreakableDoor") then
			return Enum.Material.Metal
		end
		return part.Material
	end

	local depthParams = RaycastParams.new()
	depthParams.FilterType = Enum.RaycastFilterType.Include
	depthParams.CollisionGroup = "Bullet"
	local depthFilter: { Instance } = { nil :: any }

	local function checkMaterialDepth(
		vector3: Vector3,
		vector3_2: Vector3,
		p4: BasePart,
		t2: { any },
		t3: { [Enum.Material]: number },
		t4: { [string]: number },
		n1: number,
		n2: number
	): (number, Vector3, number, boolean)
		depthFilter[1] = p4
		local raycastParams = depthParams
		raycastParams.FilterDescendantsInstances = depthFilter

		local v35 = vector3 + vector3_2 * 1000
		local v36 = vector3 - v35
		local raycastResult = Workspace:Raycast(v35, v36, raycastParams)

		if not raycastResult then
			return 0, vector3, n1, true
		end

		local magnitude = (vector3 - raycastResult.Position).Magnitude
		local raycastResultPosition = raycastResult.Position
		local v40 = n1 + magnitude
		local v41 = false
		local materialVariant = raycastResult.Instance.MaterialVariant

		if materialVariant ~= "" and materialVariantDepth[materialVariant] ~= nil then
			t4[materialVariant] = (t4[materialVariant] or 0) + magnitude
			local v43 = materialVariantDepth[materialVariant] or 0
			if t4[materialVariant] <= v43 + n2 then
				table.insert(t2, {
					instance = raycastResult.Instance,
					position = raycastResult.Position,
					normal = raycastResult.Normal,
					material = getPenetrationMaterial(raycastResult.Instance),
				})
				return magnitude, raycastResultPosition, v40, v41
			end
			return magnitude, raycastResultPosition, v40, true
		end

		local penMaterial = getPenetrationMaterial(raycastResult.Instance)
		t3[penMaterial] = (t3[penMaterial] or 0) + magnitude
		local v45 = materialDepthCap[penMaterial] or 0
		if t3[penMaterial] <= v45 + n2 then
			table.insert(t2, {
				instance = raycastResult.Instance,
				position = raycastResult.Position,
				normal = raycastResult.Normal,
				material = raycastResult.Material,
			})
			return magnitude, raycastResultPosition, v40, v41
		end

		return magnitude, raycastResultPosition, v40, true
	end

	local materialAccumScratch: { [Enum.Material]: number } = {}
	local variantAccumScratch: { [string]: number } = {}

	local function castThroughMaterials(vector3: Vector3, vector3_3: Vector3, n3: number, p5: RaycastParams): { any }
		local unit = vector3_3.Unit
		local t5 = {}
		local materialAccum = materialAccumScratch
		local variantAccum = variantAccumScratch
		local n4 = 0

		for _ = 1, 100 do
			local raycastResult = Workspace:Raycast(vector3, unit * 1000, p5)
			if not raycastResult then
				return t5
			end
			table.clear(materialAccum)
			table.clear(variantAccum)
			p5:AddToFilter(raycastResult.Instance)
			table.insert(t5, {
				instance = raycastResult.Instance,
				position = raycastResult.Position,
				normal = raycastResult.Normal,
				material = getPenetrationMaterial(raycastResult.Instance),
			})
			local _v55, v56
			_v55, vector3, n4, v56 = checkMaterialDepth(
				raycastResult.Position,
				unit,
				raycastResult.Instance :: BasePart,
				t5,
				materialAccum,
				variantAccum,
				n4,
				n3
			)
			if v56 then
				return t5
			end
		end

		return t5
	end

	local castIgnoreScratch: { Instance } = {}

	local function copyIgnoreList(t7: { Instance }?): { Instance }
		local v63 = castIgnoreScratch
		table.clear(v63)
		if not t7 then
			return v63
		end
		for i = 1, #t7 do
			v63[i] = t7[i]
		end
		return v63
	end

	local castDefaultParams = RaycastParams.new()
	castDefaultParams.FilterType = Enum.RaycastFilterType.Exclude
	castDefaultParams.IgnoreWater = false
	castDefaultParams.CollisionGroup = "Bullet"

	local bulletPenetrationRay = {}

	function bulletPenetrationRay.cast(
		vector3: Vector3,
		vector3_4: Vector3,
		p7: RaycastParams?,
		t7: { Instance }?,
		p8: ((Instance) -> boolean)?
	): {
		instance: Instance?,
		position: Vector3,
		normal: Vector3?,
		material: Enum.Material?,
	}
		local v63 = copyIgnoreList(t7)
		local v64: RaycastParams
		if p7 then
			v64 = p7
		else
			v64 = castDefaultParams
		end
		v64.FilterDescendantsInstances = v63

		while true do
			local raycastResult = Workspace:Raycast(vector3, vector3_4, v64)
			if not raycastResult then
				break
			end
			local passFilter: boolean
			if p8 == nil then
				if v64.FilterType ~= Enum.RaycastFilterType.Include then
					passFilter = not isPartFiltered(raycastResult.Instance)
				else
					passFilter = isPartWhitelisted(raycastResult.Instance, v63)
				end
			else
				passFilter = p8(raycastResult.Instance)
			end
			if passFilter then
				return {
					instance = raycastResult.Instance,
					position = raycastResult.Position,
					normal = raycastResult.Normal,
					material = raycastResult.Material,
				}
			end
			table.insert(v63, raycastResult.Instance)
			v64.FilterDescendantsInstances = v63
		end

		return {
			instance = nil,
			position = vector3 + vector3_4,
			normal = nil,
			material = nil,
		}
	end

	local throughParams = RaycastParams.new()
	throughParams.CollisionGroup = "Bullet"
	local throughEmptyFilter: { Instance } = {}

	function bulletPenetrationRay.castThrough(
		vector3: Vector3,
		vector3_5: Vector3,
		n5: number,
		t8: { Instance }?
	): { any }
		throughParams.FilterDescendantsInstances = t8 or throughEmptyFilter
		return castThroughMaterials(vector3, vector3_5, n5, throughParams)
	end

	local probeMatAccum: { [Enum.Material]: number } = {}
	local probeVarAccum: { [string]: number } = {}
	local probeSurfaces: { any } = {}

	local EXIT_CLEARANCE = 5

	function bulletPenetrationRay.probeForward(
		origin: Vector3,
		direction: Vector3,
		penetration: number,
		maxRange: number,
		ignore: { Instance }
	): (Instance?, Vector3, Vector3?, boolean)
		local first = bulletPenetrationRay.cast(origin, direction * maxRange, nil, ignore, nil)
		if not first.instance then
			return nil, first.position, nil, false
		end
		local hitPos = first.position
		local hitNormal = first.normal or -direction
		if penetration <= 0 then
			return first.instance, hitPos, hitNormal, false
		end
		table.clear(probeMatAccum)
		table.clear(probeVarAccum)
		table.clear(probeSurfaces)
		local unit = direction.Unit
		local _, exitPos, _, stopped = checkMaterialDepth(
			hitPos,
			unit,
			first.instance :: BasePart,
			probeSurfaces,
			probeMatAccum,
			probeVarAccum,
			0,
			penetration
		)
		if stopped then
			return first.instance, hitPos, hitNormal, false
		end
		local beyond = bulletPenetrationRay.cast(exitPos + unit * 0.05, unit * EXIT_CLEARANCE, nil, ignore, nil)
		return first.instance, hitPos, hitNormal, beyond.instance == nil
	end

	function bulletPenetrationRay.countWallsToTarget(
		origin: Vector3,
		targetPart: BasePart,
		penetration: number,
		maxRange: number,
		ignoreRoots: { Instance },
		targetPos: Vector3?
	): number
		local targetModel = getTargetModel(targetPart)
		local aim: Vector3 = targetPos or targetPart.Position
		local delta = aim - origin
		local distAlong = delta.Magnitude
		if distAlong <= 0 or distAlong > maxRange then
			return 0
		end
		local dir = delta / distAlong

		local hit = bulletPenetrationRay.cast(origin, dir * maxRange, nil, ignoreRoots, nil)
		if not hit.instance then
			return 0
		end
		if hit.instance == targetPart or (targetModel and hit.instance:IsDescendantOf(targetModel)) then
			return 0
		end
		if (hit.position - origin):Dot(dir) > distAlong + 0.35 then
			return 0
		end

		local entry = hit.position - dir * 0.001
		local budget = penetration
		if budget > distAlong then
			budget = distAlong
		end
		local throughHits = bulletPenetrationRay.castThrough(entry, dir * (budget + 0.001), budget, ignoreRoots)
		local surfaces = 0
		for i = 1, #throughHits do
			local r = throughHits[i]
			if r.instance == targetPart or (targetModel and r.instance:IsDescendantOf(targetModel)) then
				break
			end
			if (r.position - origin):Dot(dir) > distAlong - 0.05 then
				break
			end
			surfaces += 1
		end
		if surfaces == 0 then
			return 1
		end
		return math.ceil(surfaces / 2)
	end

	function bulletPenetrationRay.reachThroughWalls(
		origin: Vector3,
		targetPart: BasePart,
		penetration: number,
		maxRange: number,
		ignoreRoots: { Instance },
		trace: boolean?,
		targetPos: Vector3?
	): boolean
		if penetration <= 0 then
			return false
		end

		local targetModel = getTargetModel(targetPart)
		local aim: Vector3 = targetPos or targetPart.Position
		local delta = aim - origin
		local dir = delta.Unit
		local distAlong = delta.Magnitude
		if distAlong <= 0 then
			return false
		end
		if distAlong > maxRange then
			return false
		end

		local hit = bulletPenetrationRay.cast(origin, dir * maxRange, nil, ignoreRoots, nil)

		local ok: boolean
		local detail: string
		local hitAlong = 0
		local penAlong = 0
		local nThrough = 0

		if not hit.instance then
			local endAlong = (hit.position - origin):Dot(dir)
			ok = endAlong >= distAlong - 0.05
			detail = "noFirstHit"
			hitAlong = endAlong
		elseif hit.instance == targetPart or (targetModel and hit.instance:IsDescendantOf(targetModel)) then
			hitAlong = (hit.position - origin):Dot(dir)
			ok = hitAlong <= distAlong + 0.35
			detail = "firstHitTargetTree"
		elseif (hit.position - origin):Dot(dir) > distAlong + 0.35 then
			ok = true
			hitAlong = (hit.position - origin):Dot(dir)
			detail = "firstHitPastTarget"
		else
			hitAlong = (hit.position - origin):Dot(dir)
			local entry = hit.position - dir * 0.001
			local throughHits =
				bulletPenetrationRay.castThrough(entry, dir * (penetration + 0.001), penetration, ignoreRoots)
			nThrough = #throughHits
			if nThrough == 0 then
				ok = false
				detail = "castThroughEmpty"
			else
				local reachedTarget = false
				for _, r in next, throughHits do
					if r.instance == targetPart or (targetModel and r.instance:IsDescendantOf(targetModel)) then
						reachedTarget = true
						break
					end
				end
				if reachedTarget then
					ok = true
					penAlong = distAlong
					detail = "throughHitTargetTree"
				else
					local last = throughHits[nThrough]
					local penExit = last.position + dir * 0.03
					penAlong = (penExit - origin):Dot(dir)
					ok = penAlong >= distAlong - 0.12
					detail = "oneCastThrough"
				end
			end
		end

		if trace then
			print(
				string.format(
					"[ragebot pen] ok=%s detail=%s distAlong=%.2f hitAlong=%.2f penAlong=%.2f nThrough=%d pen=%.2f target=%s",
					ok and "true" or "false",
					detail,
					distAlong,
					hitAlong,
					penAlong,
					nThrough,
					penetration,
					targetPart:GetFullName()
				)
			)
		end

		return ok
	end

	return bulletPenetrationRay
end)()
