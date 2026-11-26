local Charm = require("@pkg/Charm")
local instances = require("@share/instances")
local grenadeState = require("@game/pf/grenade/grenadeState")

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Terrain = Workspace.Terrain

local sub = Charm.subscribe
local peek = Charm.peek

local LINE_WIDTH = 0.15
local PATH_TRANSPARENCY = 0.15
local PATH_TRANSPARENCY_SEQ = NumberSequence.new(PATH_TRANSPARENCY)
local HOLDER_SIZE = Vector3.new(0.05, 0.05, 0.05)
local END_SIZE = Vector3.new(1.2, 1.2, 1.2)

type PathInstances = {
	holder: Part,
	attachments: { Attachment },
	beams: { Beam },
	endSphere: Part,
	friendly: boolean,
	lastPathColor: Color3?,
}

type Settings = {
	enabled: boolean,
	enemyPathColor: Color3,
	friendlyPathColor: Color3,
	enemyEndColor: Color3,
	friendlyEndColor: Color3,
}

local pathRenderer = {}

local _state: Settings = {
	enabled = false,
	enemyPathColor = Color3.fromRGB(255, 85, 95),
	friendlyPathColor = Color3.fromRGB(120, 200, 255),
	enemyEndColor = Color3.fromRGB(255, 60, 60),
	friendlyEndColor = Color3.fromRGB(85, 155, 215),
}

local _instancesById: { [string]: PathInstances } = {}
local _sub: (() -> ())? = nil

local function pathColorFor(friendly: boolean): Color3
	return (friendly and _state.friendlyPathColor or _state.enemyPathColor)
end

local function endColorFor(friendly: boolean): Color3
	return (friendly and _state.friendlyEndColor or _state.enemyEndColor)
end

local createPathInstances = LPH_NO_VIRTUALIZE(function(friendly: boolean): PathInstances
	local holder = instances.new("Part", {
		Name = "GrenadePathHolder",
		Size = HOLDER_SIZE,
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Secure = true,
	}, Terrain) :: Part

	local endSphere = instances.new("Part", {
		Name = "GrenadePathEnd",
		Shape = Enum.PartType.Ball,
		Size = END_SIZE,
		Material = Enum.Material.Neon,
		Color = endColorFor(friendly),
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 0.3,
		Secure = true,
	}, Terrain) :: Part

	return {
		holder = holder,
		attachments = table.create(64),
		beams = table.create(64),
		endSphere = endSphere,
		friendly = friendly,
		lastPathColor = nil,
	}
end)

local function destroyPathInstances(p: PathInstances): ()
	for _, beam in next, p.beams do
		beam:Destroy()
	end
	for _, att in next, p.attachments do
		att:Destroy()
	end
	p.endSphere:Destroy()
	p.holder:Destroy()
end

local ensureAttachments = LPH_NO_VIRTUALIZE(function(p: PathInstances, count: number): ()
	local attachments = p.attachments
	local existing = #attachments
	if count > existing then
		local holder = p.holder
		for i = existing + 1, count do
			attachments[i] = instances.new("Attachment", { Secure = true }, holder) :: Attachment
		end
	elseif count < existing then
		for i = existing, count + 1, -1 do
			attachments[i]:Destroy()
			attachments[i] = nil
		end
	end
end)

local ensureBeams = LPH_NO_VIRTUALIZE(function(p: PathInstances, count: number, pathColor: Color3): ()
	local beams = p.beams
	local attachments = p.attachments
	local existing = #beams
	local colorChanged = p.lastPathColor ~= pathColor
	local colorSeq = colorChanged and ColorSequence.new(pathColor) or nil
	if count > existing then
		if not colorSeq then
			colorSeq = ColorSequence.new(pathColor)
		end
		local holder = p.holder
		for i = existing + 1, count do
			local b = instances.new("Beam", {
				Attachment0 = attachments[i],
				Attachment1 = attachments[i + 1],
				Width0 = LINE_WIDTH,
				Width1 = LINE_WIDTH,
				FaceCamera = true,
				LightEmission = 1,
				LightInfluence = 0,
				Segments = 1,
				TextureMode = Enum.TextureMode.Stretch,
				Transparency = PATH_TRANSPARENCY_SEQ,
				Color = colorSeq,
				Secure = true,
			}, holder) :: Beam
			beams[i] = b
		end
	elseif count < existing then
		for i = existing, count + 1, -1 do
			beams[i]:Destroy()
			beams[i] = nil
		end
	end

	for i = 1, count do
		local beam = beams[i]
		if colorChanged then
			beam.Color = colorSeq
		end
		beam.Attachment0 = attachments[i]
		beam.Attachment1 = attachments[i + 1]
	end

	p.lastPathColor = pathColor
end)

local updatePath = LPH_NO_VIRTUALIZE(function(id: string, entry: grenadeState.IncomingGrenade): ()
	local friendly = entry.isFriendly == true
	local existing = _instancesById[id]
	if existing and existing.friendly ~= friendly then
		destroyPathInstances(existing)
		_instancesById[id] = nil
		existing = nil :: any
	end
	local p: PathInstances = existing or createPathInstances(friendly)
	_instancesById[id] = p

	local points = entry.path
	if type(points) ~= "table" then
		return
	end
	local n = #points
	if n < 2 then
		return
	end

	ensureAttachments(p, n)
	local attachments = p.attachments
	for i = 1, n do
		attachments[i].WorldPosition = points[i]
	end

	ensureBeams(p, n - 1, pathColorFor(friendly))

	local endSphere = p.endSphere
	endSphere.Color = endColorFor(friendly)
	endSphere.CFrame = CFrame.new(entry.landing)
end)

local function removePath(id: string): ()
	local p = _instancesById[id]
	if not p then
		return
	end
	destroyPathInstances(p)
	_instancesById[id] = nil
end

local function clearAll(): ()
	for id, p in next, _instancesById do
		destroyPathInstances(p)
		_instancesById[id] = nil
	end
end

local function refreshColors(): ()
	for _, p in next, _instancesById do
		p.endSphere.Color = endColorFor(p.friendly)
		local seq = ColorSequence.new(pathColorFor(p.friendly))
		for _, beam in next, p.beams do
			beam.Color = seq
		end
	end
end

local function startSubscription(): ()
	if _sub then
		return
	end
	local current = peek(grenadeState.incoming)
	for key, entry in next, current do
		updatePath(tostring(key), entry)
	end

	_sub = sub(grenadeState.incoming, function(active): ()
		for key, entry in next, active do
			updatePath(tostring(key), entry)
		end
		local seen = {}
		for key in next, active do
			seen[tostring(key)] = true
		end
		for id in next, _instancesById do
			if not seen[id] then
				removePath(id)
			end
		end
	end)
end

local function stopSubscription(): ()
	if _sub then
		_sub()
		_sub = nil
	end
	clearAll()
end

function pathRenderer.setEnabled(enabled: boolean): ()
	if _state.enabled == enabled then
		return
	end
	_state.enabled = enabled
	if enabled then
		startSubscription()
	else
		stopSubscription()
	end
end

function pathRenderer.setEnemyPathColor(color: Color3): ()
	_state.enemyPathColor = color
	refreshColors()
end

function pathRenderer.setFriendlyPathColor(color: Color3): ()
	_state.friendlyPathColor = color
	refreshColors()
end

function pathRenderer.setEnemyEndColor(color: Color3): ()
	_state.enemyEndColor = color
	refreshColors()
end

function pathRenderer.setFriendlyEndColor(color: Color3): ()
	_state.friendlyEndColor = color
	refreshColors()
end

function pathRenderer.destroy(): ()
	stopSubscription()
end

return pathRenderer
