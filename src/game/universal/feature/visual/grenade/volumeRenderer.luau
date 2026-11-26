local instances = require("@share/instances")

local ANGLES = 10
local MAX_RINGS = 4
local RING_SPACING = 4
local LEVEL_GAP = 3
local CONNECTORS = 4
local MAX_SAMPLES = 320
local MAX_POINTS = MAX_RINGS * ANGLES

local BOUNDS_INTERVAL = 0.1
local SHAPE_RATE = 14
local ALPHA_RATE = 13
local LEAVE_RATE = 11
local SCALE_RATE = 9
local SCALE_START = 0.8
local SCALE_LEAVE = 0.86
local MAX_DISTANCE = 100
local FADE_START = 70
local NEAR_PLANE = 0.5
local DEPTH_FADE = 0.5
local CONNECTOR_DIM = 0.72
local THICK_NEAR = 2
local THICK_FAR = 1
local GLOW_EXTRA = 9
local GLOW_STRENGTH = 0.6
local FADE_RANGE = math.max(MAX_DISTANCE - FADE_START, 1)
local PULSE_THRESHOLD = 0.22
local PULSE_SPEED = 7
local PULSE_DEPTH = 0.45
local MIN_RADIUS = 0.6
local MIN_VISIBILITY = 0.02
local SCREEN_MARGIN = 24
local POOL_LIMIT = 256

local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local CORNER_FULL = UDim.new(1, 0)

local GLOW_FALLOFF = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.25, 0.62),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.75, 0.62),
	NumberSequenceKeypoint.new(1, 1),
})

local DIR_X: { number } = table.create(ANGLES)
local DIR_Z: { number } = table.create(ANGLES)
for i = 1, ANGLES do
	local angle = (i - 1) / ANGLES * math.pi * 2
	DIR_X[i] = math.cos(angle)
	DIR_Z[i] = math.sin(angle)
end

local POSITIONS: { Vector3 } = table.create(MAX_SAMPLES)
local EXTENTS: { Vector3 } = table.create(MAX_SAMPLES)
local LOW: { number } = table.create(MAX_SAMPLES)
local HIGH: { number } = table.create(MAX_SAMPLES)
local ORDER: { number } = table.create(MAX_SAMPLES)
local RADII: { number } = table.create(ANGLES)
local SMOOTHED: { number } = table.create(ANGLES)
local SCREEN_X: { number } = table.create(MAX_POINTS)
local SCREEN_Y: { number } = table.create(MAX_POINTS)
local SCREEN_Z: { number } = table.create(MAX_POINTS)

local CAM_X, CAM_Y, CAM_Z = 0, 0, 0
local R00, R01, R02 = 1, 0, 0
local R10, R11, R12 = 0, 1, 0
local R20, R21, R22 = 0, 0, 1
local FOCAL = 1
local HALF_WIDTH, HALF_HEIGHT = 0, 0
local VIEW_WIDTH, VIEW_HEIGHT = 0, 0
local INV_X, INV_Y = 0, 0
local SHAPE_BLEND, ALPHA_BLEND, LEAVE_BLEND, SCALE_BLEND = 0, 0, 0, 0
local FRAME_TIME = 0

local function compareLow(first: number, second: number): boolean
	return LOW[first] < LOW[second]
end

export type Adapter = {
	id: string,
	key: string,
	label: string,
	tip: string?,
	entries: any,
	defaultColor: Color3,
	defaultGlow: Color3?,
	resolveSamples: (entry: any, positions: { Vector3 }, extents: { Vector3 }, limit: number) -> number,
	resolveTiming: ((entry: any) -> (number?, number?))?,
}

export type Settings = {
	enabled: boolean,
	color: Color3,
	transparency: number,
	glowColor: Color3,
	glowTransparency: number,
}

type Segment = {
	glow: Frame,
	core: Frame,
}

export type View = {
	segments: { Segment },
	segmentCount: number,
	parent: Instance,
	entry: any,
	leaving: boolean,
	expired: boolean,
	hidden: boolean,
	alpha: number,
	scale: number,
	nextBuild: number,
	color: Color3,
	glowColor: Color3,
	ringCount: number,
	points: { number },
	targets: { number },
	centers: { number },
	targetCenters: { number },
	originX: number,
	originY: number,
	originZ: number,
}

local POOL: { Segment } = {}
local POOL_SIZE = 0

local beginFrame = LPH_NO_VIRTUALIZE(function(camera: Camera, viewport: Vector2, deltaTime: number, now: number): ()
	local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = camera.CFrame:GetComponents()
	CAM_X, CAM_Y, CAM_Z = px, py, pz
	R00, R01, R02 = r00, r01, r02
	R10, R11, R12 = r10, r11, r12
	R20, R21, R22 = r20, r21, r22

	local width = viewport.X
	local height = viewport.Y
	VIEW_WIDTH, VIEW_HEIGHT = width, height
	HALF_WIDTH, HALF_HEIGHT = width * 0.5, height * 0.5
	INV_X, INV_Y = 1 / width, 1 / height
	FOCAL = HALF_HEIGHT / math.tan(math.rad(camera.FieldOfView) * 0.5)

	SHAPE_BLEND = 1 - math.exp(-SHAPE_RATE * deltaTime)
	ALPHA_BLEND = 1 - math.exp(-ALPHA_RATE * deltaTime)
	LEAVE_BLEND = 1 - math.exp(-LEAVE_RATE * deltaTime)
	SCALE_BLEND = 1 - math.exp(-SCALE_RATE * deltaTime)
	FRAME_TIME = now
end)

local buildShape = LPH_JIT_MAX(function(view: View, adapter: Adapter): ()
	local count = adapter.resolveSamples(view.entry, POSITIONS, EXTENTS, MAX_SAMPLES)
	if count < 1 then
		if view.ringCount > 0 then
			view.expired = true
		end
		return
	end

	for i = 1, count do
		local position = POSITIONS[i]
		local extent = EXTENTS[i]
		LOW[i] = position.Y - extent.Y
		HIGH[i] = position.Y + extent.Y
		ORDER[i] = i
	end
	for i = count + 1, #ORDER do
		ORDER[i] = nil
	end

	table.sort(ORDER, compareLow)

	local targets = view.targets
	local targetCenters = view.targetCenters
	local ringIndex = 0
	local clusterStart = 1

	while clusterStart <= count and ringIndex < MAX_RINGS do
		local clusterLow = LOW[ORDER[clusterStart]]
		local clusterHigh = HIGH[ORDER[clusterStart]]
		local clusterEnd = clusterStart

		while clusterEnd < count do
			local candidate = ORDER[clusterEnd + 1]
			if LOW[candidate] > clusterHigh + LEVEL_GAP then
				break
			end
			clusterEnd += 1
			if HIGH[candidate] > clusterHigh then
				clusterHigh = HIGH[candidate]
			end
		end

		local height = clusterHigh - clusterLow
		local rings = math.clamp(math.floor(height / RING_SPACING) + 1, 1, MAX_RINGS - ringIndex)

		for ring = 1, rings do
			local sliceLow = clusterLow + (ring - 1) * height / rings
			local sliceHigh = clusterLow + ring * height / rings
			local ringY = (sliceLow + sliceHigh) * 0.5

			local sumX, sumZ, members = 0, 0, 0
			for i = clusterStart, clusterEnd do
				local index = ORDER[i]
				if HIGH[index] >= sliceLow and LOW[index] <= sliceHigh then
					local position = POSITIONS[index]
					sumX += position.X
					sumZ += position.Z
					members += 1
				end
			end

			if members > 0 then
				local centerX = sumX / members
				local centerZ = sumZ / members

				for angle = 1, ANGLES do
					RADII[angle] = MIN_RADIUS
				end

				for i = clusterStart, clusterEnd do
					local index = ORDER[i]
					if HIGH[index] >= sliceLow and LOW[index] <= sliceHigh then
						local position = POSITIONS[index]
						local extent = EXTENTS[index]
						local offsetX = position.X - centerX
						local offsetZ = position.Z - centerZ
						for angle = 1, ANGLES do
							local dirX = DIR_X[angle]
							local dirZ = DIR_Z[angle]
							local reach = offsetX * dirX
								+ offsetZ * dirZ
								+ math.abs(extent.X * dirX)
								+ math.abs(extent.Z * dirZ)
							if reach > RADII[angle] then
								RADII[angle] = reach
							end
						end
					end
				end

				for angle = 1, ANGLES do
					local previous = RADII[(angle - 2) % ANGLES + 1]
					local following = RADII[angle % ANGLES + 1]
					SMOOTHED[angle] = previous * 0.25 + RADII[angle] * 0.5 + following * 0.25
				end

				ringIndex += 1

				local centerSlot = (ringIndex - 1) * 3
				targetCenters[centerSlot + 1] = centerX
				targetCenters[centerSlot + 2] = ringY
				targetCenters[centerSlot + 3] = centerZ

				local base = (ringIndex - 1) * ANGLES * 3
				for angle = 1, ANGLES do
					local radius = SMOOTHED[angle]
					local slot = base + (angle - 1) * 3
					targets[slot + 1] = centerX + DIR_X[angle] * radius
					targets[slot + 2] = ringY
					targets[slot + 3] = centerZ + DIR_Z[angle] * radius
				end
			end
		end

		clusterStart = clusterEnd + 1
	end

	if ringIndex < 1 then
		if view.ringCount > 0 then
			view.expired = true
		end
		return
	end

	if view.ringCount ~= ringIndex then
		view.ringCount = ringIndex
		local points = view.points
		for i = 1, ringIndex * ANGLES * 3 do
			points[i] = targets[i]
		end
		local centers = view.centers
		for i = 1, ringIndex * 3 do
			centers[i] = targetCenters[i]
		end
	end

	local sumX, sumY, sumZ = 0, 0, 0
	for ring = 1, ringIndex do
		local slot = (ring - 1) * 3
		sumX += targetCenters[slot + 1]
		sumY += targetCenters[slot + 2]
		sumZ += targetCenters[slot + 3]
	end

	view.originX = sumX / ringIndex
	view.originY = sumY / ringIndex
	view.originZ = sumZ / ringIndex
end)

local function createSegment(parent: Instance, view: View): Segment
	local glow = instances.new("Frame", {
		AnchorPoint = CENTER_ANCHOR,
		BackgroundColor3 = view.glowColor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, GLOW_EXTRA),
		Visible = false,
		ZIndex = 1,
		Secure = true,
	}, parent) :: Frame

	instances.new("UICorner", { CornerRadius = CORNER_FULL, Secure = true }, glow)
	instances.new("UIGradient", { Rotation = 90, Transparency = GLOW_FALLOFF, Secure = true }, glow)

	local core = instances.new("Frame", {
		AnchorPoint = CENTER_ANCHOR,
		BackgroundColor3 = view.color,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, THICK_FAR),
		Visible = false,
		ZIndex = 2,
		Secure = true,
	}, parent) :: Frame

	instances.new("UICorner", { CornerRadius = CORNER_FULL, Secure = true }, core)

	return {
		glow = glow,
		core = core,
	}
end

local function acquireSegment(parent: Instance, view: View): Segment
	if POOL_SIZE < 1 then
		return createSegment(parent, view)
	end

	local segment = POOL[POOL_SIZE]
	POOL[POOL_SIZE] = nil
	POOL_SIZE -= 1

	local glow = segment.glow
	local core = segment.core
	glow.BackgroundColor3 = view.glowColor
	core.BackgroundColor3 = view.color
	if glow.Parent ~= parent then
		glow.Parent = parent
		core.Parent = parent
	end

	return segment
end

local function releaseSegment(segment: Segment): ()
	if POOL_SIZE >= POOL_LIMIT then
		segment.glow:Destroy()
		segment.core:Destroy()
		return
	end

	segment.glow.Visible = false
	segment.core.Visible = false
	POOL_SIZE += 1
	POOL[POOL_SIZE] = segment
end

local function createView(parent: Instance, settings: Settings, entry: any): View
	return {
		segments = table.create(MAX_POINTS),
		segmentCount = 0,
		parent = parent,
		entry = entry,
		leaving = false,
		expired = false,
		hidden = true,
		alpha = 0,
		scale = SCALE_START,
		nextBuild = 0,
		color = settings.color,
		glowColor = settings.glowColor,
		ringCount = 0,
		points = table.create(MAX_POINTS * 3, 0),
		targets = table.create(MAX_POINTS * 3, 0),
		centers = table.create(MAX_RINGS * 3, 0),
		targetCenters = table.create(MAX_RINGS * 3, 0),
		originX = 0,
		originY = 0,
		originZ = 0,
	}
end

local function destroyView(view: View): ()
	local segments = view.segments
	for i = 1, view.segmentCount do
		releaseSegment(segments[i])
		segments[i] = nil
	end
	view.segmentCount = 0
end

local function clearPool(): ()
	for i = 1, POOL_SIZE do
		local segment = POOL[i]
		segment.glow:Destroy()
		segment.core:Destroy()
		POOL[i] = nil
	end
	POOL_SIZE = 0
end

local hideView = LPH_NO_VIRTUALIZE(function(view: View): ()
	if view.hidden then
		return
	end
	view.hidden = true

	local segments = view.segments
	for i = 1, view.segmentCount do
		local segment = segments[i]
		segment.glow.Visible = false
		segment.core.Visible = false
	end
end)

local applyColors = LPH_NO_VIRTUALIZE(function(view: View, settings: Settings): ()
	local segments = view.segments
	local count = view.segmentCount
	if view.color ~= settings.color then
		view.color = settings.color
		for i = 1, count do
			segments[i].core.BackgroundColor3 = settings.color
		end
	end
	if view.glowColor ~= settings.glowColor then
		view.glowColor = settings.glowColor
		for i = 1, count do
			segments[i].glow.BackgroundColor3 = settings.glowColor
		end
	end
end)

local drawSegment = LPH_NO_VIRTUALIZE(function(
	view: View,
	index: number,
	first: number,
	second: number,
	nearDepth: number,
	depthRange: number,
	visibility: number,
	glowVisibility: number
): ()
	local segments = view.segments
	local segment = segments[index]
	if not segment then
		segment = acquireSegment(view.parent, view)
		segments[index] = segment
		view.segmentCount = index
	end

	local firstDepth = SCREEN_Z[first]
	local secondDepth = SCREEN_Z[second]
	if firstDepth <= NEAR_PLANE or secondDepth <= NEAR_PLANE then
		segment.glow.Visible = false
		segment.core.Visible = false
		return
	end

	local fromX, fromY = SCREEN_X[first], SCREEN_Y[first]
	local toX, toY = SCREEN_X[second], SCREEN_Y[second]

	if fromX < -SCREEN_MARGIN and toX < -SCREEN_MARGIN then
		segment.glow.Visible = false
		segment.core.Visible = false
		return
	end
	if fromX > VIEW_WIDTH + SCREEN_MARGIN and toX > VIEW_WIDTH + SCREEN_MARGIN then
		segment.glow.Visible = false
		segment.core.Visible = false
		return
	end
	if fromY < -SCREEN_MARGIN and toY < -SCREEN_MARGIN then
		segment.glow.Visible = false
		segment.core.Visible = false
		return
	end
	if fromY > VIEW_HEIGHT + SCREEN_MARGIN and toY > VIEW_HEIGHT + SCREEN_MARGIN then
		segment.glow.Visible = false
		segment.core.Visible = false
		return
	end

	local depthAlpha = math.clamp(((firstDepth + secondDepth) * 0.5 - nearDepth) / depthRange, 0, 1)
	local shaded = visibility * (1 - depthAlpha * DEPTH_FADE)
	if shaded < MIN_VISIBILITY then
		segment.glow.Visible = false
		segment.core.Visible = false
		return
	end

	local deltaX = toX - fromX
	local deltaY = toY - fromY
	local length = math.sqrt(deltaX * deltaX + deltaY * deltaY)
	local thickness = math.floor(THICK_FAR + (1 - depthAlpha) * (THICK_NEAR - THICK_FAR) + 0.5)
	local position = UDim2.new((fromX + toX) * 0.5 * INV_X, 0, (fromY + toY) * 0.5 * INV_Y, 0)
	local rotation = math.deg(math.atan2(deltaY, deltaX))

	local core = segment.core
	core.Position = position
	core.Size = UDim2.new((length + thickness) * INV_X, 0, 0, thickness)
	core.Rotation = rotation
	core.BackgroundTransparency = 1 - shaded
	core.Visible = true

	local glow = segment.glow
	local glowAlpha = glowVisibility * (1 - depthAlpha * DEPTH_FADE)
	if glowAlpha < MIN_VISIBILITY then
		glow.Visible = false
		return
	end

	local glowThickness = thickness + GLOW_EXTRA
	glow.Position = position
	glow.Size = UDim2.new((length + glowThickness) * INV_X, 0, 0, glowThickness)
	glow.Rotation = rotation
	glow.BackgroundTransparency = 1 - glowAlpha
	glow.Visible = true
end)

local updateView = LPH_JIT_MAX(function(view: View, adapter: Adapter, settings: Settings): boolean
	local resolveTiming = adapter.resolveTiming
	local remaining: number?, total: number?
	if resolveTiming and not view.leaving and not view.expired then
		remaining, total = resolveTiming(view.entry)
		if remaining and remaining <= 0 then
			view.expired = true
		end
	end

	local leaving = view.leaving or view.expired
	if leaving then
		view.alpha -= view.alpha * LEAVE_BLEND
		if view.alpha < 0.01 then
			return false
		end
		view.scale += (SCALE_LEAVE - view.scale) * LEAVE_BLEND
	else
		view.alpha += (1 - view.alpha) * ALPHA_BLEND
		view.scale += (1 - view.scale) * SCALE_BLEND
	end

	local distance = 0

	if view.ringCount > 0 then
		local offsetX = view.originX - CAM_X
		local offsetY = view.originY - CAM_Y
		local offsetZ = view.originZ - CAM_Z
		distance = math.sqrt(offsetX * offsetX + offsetY * offsetY + offsetZ * offsetZ)
		if distance > MAX_DISTANCE then
			hideView(view)
			return true
		end
	end

	local now = FRAME_TIME
	if not leaving and now >= view.nextBuild then
		view.nextBuild = now + BOUNDS_INTERVAL
		buildShape(view, adapter)

		local offsetX = view.originX - CAM_X
		local offsetY = view.originY - CAM_Y
		local offsetZ = view.originZ - CAM_Z
		distance = math.sqrt(offsetX * offsetX + offsetY * offsetY + offsetZ * offsetZ)
	end

	local ringCount = view.ringCount
	if ringCount < 1 or distance > MAX_DISTANCE then
		hideView(view)
		return true
	end

	local blend = SHAPE_BLEND
	local points = view.points
	local targets = view.targets
	local centers = view.centers
	local targetCenters = view.targetCenters

	for i = 1, ringCount * ANGLES * 3 do
		points[i] += (targets[i] - points[i]) * blend
	end
	for i = 1, ringCount * 3 do
		centers[i] += (targetCenters[i] - centers[i]) * blend
	end

	local pulse = 1
	if not leaving and remaining and total and total > 0 and remaining < total * PULSE_THRESHOLD then
		pulse = 1 - PULSE_DEPTH * (0.5 + 0.5 * math.sin(now * PULSE_SPEED))
	end

	local scale = view.scale
	local nearDepth, farDepth = math.huge, -math.huge
	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	local onScreen = 0

	for ring = 1, ringCount do
		local centerSlot = (ring - 1) * 3
		local centerX = centers[centerSlot + 1]
		local centerY = centers[centerSlot + 2]
		local centerZ = centers[centerSlot + 3]
		local base = (ring - 1) * ANGLES
		local pointBase = base * 3

		for angle = 1, ANGLES do
			local slot = pointBase + (angle - 1) * 3
			local worldX = centerX + (points[slot + 1] - centerX) * scale
			local worldY = centerY + (points[slot + 2] - centerY) * scale
			local worldZ = centerZ + (points[slot + 3] - centerZ) * scale

			local relativeX = worldX - CAM_X
			local relativeY = worldY - CAM_Y
			local relativeZ = worldZ - CAM_Z
			local depth = -(relativeX * R02 + relativeY * R12 + relativeZ * R22)

			local index = base + angle
			SCREEN_Z[index] = depth

			if depth > NEAR_PLANE then
				local inverse = FOCAL / depth
				local screenX = HALF_WIDTH + (relativeX * R00 + relativeY * R10 + relativeZ * R20) * inverse
				local screenY = HALF_HEIGHT - (relativeX * R01 + relativeY * R11 + relativeZ * R21) * inverse
				SCREEN_X[index] = screenX
				SCREEN_Y[index] = screenY

				onScreen += 1
				if depth < nearDepth then
					nearDepth = depth
				end
				if depth > farDepth then
					farDepth = depth
				end
				if screenX < minX then
					minX = screenX
				end
				if screenX > maxX then
					maxX = screenX
				end
				if screenY < minY then
					minY = screenY
				end
				if screenY > maxY then
					maxY = screenY
				end
			end
		end
	end

	if onScreen == 0 then
		hideView(view)
		return true
	end

	if
		maxX < -SCREEN_MARGIN
		or minX > VIEW_WIDTH + SCREEN_MARGIN
		or maxY < -SCREEN_MARGIN
		or minY > VIEW_HEIGHT + SCREEN_MARGIN
	then
		hideView(view)
		return true
	end

	local distanceFade = 1
	if distance > FADE_START then
		distanceFade = math.clamp(1 - (distance - FADE_START) / FADE_RANGE, 0, 1)
	end

	local strength = view.alpha * distanceFade * pulse
	local visibility = strength * (1 - settings.transparency)
	local glowVisibility = strength * (1 - settings.glowTransparency) * GLOW_STRENGTH
	if visibility < MIN_VISIBILITY and glowVisibility < MIN_VISIBILITY then
		hideView(view)
		return true
	end

	local depthRange = math.max(farDepth - nearDepth, 1)
	local index = 0
	view.hidden = false

	for ring = 1, ringCount do
		local base = (ring - 1) * ANGLES
		for angle = 1, ANGLES do
			index += 1
			drawSegment(
				view,
				index,
				base + angle,
				base + angle % ANGLES + 1,
				nearDepth,
				depthRange,
				visibility,
				glowVisibility
			)
		end
	end

	for ring = 1, ringCount - 1 do
		local lower = (ring - 1) * ANGLES
		local upper = ring * ANGLES
		for connector = 1, CONNECTORS do
			local angle = 1 + math.floor((connector - 1) * ANGLES / CONNECTORS)
			index += 1
			drawSegment(
				view,
				index,
				lower + angle,
				upper + angle,
				nearDepth,
				depthRange,
				visibility * CONNECTOR_DIM,
				glowVisibility * CONNECTOR_DIM
			)
		end
	end

	local segments = view.segments
	for i = index + 1, view.segmentCount do
		local segment = segments[i]
		segment.glow.Visible = false
		segment.core.Visible = false
	end

	return true
end)

return {
	beginFrame = beginFrame,
	createView = createView,
	destroyView = destroyView,
	clearPool = clearPool,
	hideView = hideView,
	applyColors = applyColors,
	updateView = updateView,
}
