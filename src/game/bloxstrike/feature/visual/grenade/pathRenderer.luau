local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local instances = require("@share/instances")
local grenadeState = require("@game/bloxstrike/grenade/grenadeState")

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Terrain = Workspace.Terrain

local sub = Charm.subscribe
local peek = Charm.peek

local LINE_WIDTH = 0.02
local PATH_TRANSPARENCY = 0.15
local PATH_TRANSPARENCY_SEQ = NumberSequence.new(PATH_TRANSPARENCY)
local HOLDER_SIZE = Vector3.new(0.05, 0.05, 0.05)
local END_SIZE = Vector3.new(0.01, 0.01, 0.01)

type PathInstances = {
	holder: Part,
	attachments: { Attachment },
	beams: { Beam },
	endSphere: Part,
	friendly: boolean,
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
	enemyPathColor = Color3.fromRGB(195, 110, 110),
	friendlyPathColor = Color3.fromRGB(120, 175, 200),
	enemyEndColor = Color3.fromRGB(165, 75, 75),
	friendlyEndColor = Color3.fromRGB(85, 130, 155),
}

local _instancesById: { [string]: PathInstances } = {}
local _projectileSub: (() -> ())? = nil

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
	local colorSeq = ColorSequence.new(pathColor)
	if count > existing then
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
		beam.Color = colorSeq
		beam.Attachment0 = attachments[i]
		beam.Attachment1 = attachments[i + 1]
	end
end)

local updatePath = LPH_NO_VIRTUALIZE(function(id: string, entry: grenadeState.ProjectileEntry): ()
	local friendly = entry.isFriendly == true
	local existing = _instancesById[id]
	if existing and existing.friendly ~= friendly then
		destroyPathInstances(existing)
		_instancesById[id] = nil
		existing = nil :: any
	end
	local p: PathInstances = existing or createPathInstances(friendly)
	_instancesById[id] = p

	local points = entry.pathPoints
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
	endSphere.CFrame = CFrame.new(entry.landingPosition)
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
	if _projectileSub then
		return
	end
	local current = peek(grenadeState.activeProjectiles)
	for id, entry in next, current do
		updatePath(id, entry)
	end

	_projectileSub = sub(grenadeState.activeProjectiles, function(active)
		for id, entry in next, active do
			updatePath(id, entry)
		end
		for id in next, _instancesById do
			if not active[id] then
				removePath(id)
			end
		end
	end)
end

local function stopSubscription(): ()
	if _projectileSub then
		_projectileSub()
		_projectileSub = nil
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
