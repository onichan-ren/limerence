local RunService = cloneref(game:GetService("RunService")) :: RunService
local HttpService = cloneref(game:GetService("HttpService")) :: HttpService

local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local createBeam = require("@game/universal/feature/visual/tracer/createBeam")
local createLine = require("@game/universal/feature/visual/tracer/createLine")
local createAdorn = require("@game/universal/feature/visual/tracer/createAdorn")
local FileController = require("@feature/file/FileController")

local Tracer = {}
Tracer.__index = Tracer

setmetatable(Tracer, { __index = BaseFeature })

local BEAM_DIR = "limerence.biz/assets/beams"

local function readManifest(path: string): createBeam.BeamManifest?
	if not isfile(path) then
		return nil
	end
	local raw = readfile(path)
	if type(raw) ~= "string" then
		return nil
	end
	local decoded: any = HttpService:JSONDecode(raw)
	if type(decoded) ~= "table" then
		return nil
	end
	return decoded
end

local PICKER_CONFIG = {
	assetType = "beams",
	basePath = BEAM_DIR,
	extensions = { "json" },
	assignmentTypes = {},
	creator = {
		title = "New beam style",
		description = "Create a reusable tracer style. Texture accepts an asset ID, URL, or existing file path.",
		fields = {
			{ key = "texture", label = "Texture", placeholder = "Asset ID, URL, or file path", required = true },
			{ key = "width0", label = "Start width", default = "0.25", kind = "number" },
			{ key = "width1", label = "End width", default = "0.55", kind = "number" },
			{
				key = "textureMode",
				label = "Texture mode",
				default = "Stretch",
				kind = "select",
				options = { "Stretch", "Wrap", "Static" },
			},
			{ key = "textureSpeed", label = "Texture speed", default = "1", kind = "number" },
			{ key = "textureLength", label = "Texture length", default = "1", kind = "number" },
		},
		build = function(values, name)
			return {
				name = name,
				preview = values.texture,
				texture = values.texture,
				width0 = tonumber(values.width0),
				width1 = tonumber(values.width1),
				textureMode = values.textureMode,
				textureSpeed = tonumber(values.textureSpeed),
				textureLength = tonumber(values.textureLength),
				lightInfluence = 5,
				lightEmission = 5,
				faceCamera = true,
			}
		end,
	},
	bundle = {
		urlPrefix = "https://limerence.biz/get/",
		title = "Downloading Beams",
		icon = "download",
		files = {
			"Default.json",
			"Laser.json",
			"Trail.json",
		},
	},
	previewImage = function(_source, _name, path)
		local manifest = readManifest(path)
		if not manifest then
			return nil
		end
		return FileController.ResolveImage(manifest.preview) or FileController.ResolveImage(manifest.texture)
	end,
	previewBehavior = function() end,
}

export type TracerSettings = {
	Color: Color3 | ColorSequence,
	Transparency: number,
	Type: "Beam" | "Line" | "Adorn",
	Lifetime: number,
	Thickness: number,
	Beam: createBeam.BeamManifest?,
}

local asColorSequence = LPH_NO_VIRTUALIZE(function(color: Color3 | ColorSequence): ColorSequence
	if typeof(color) == "ColorSequence" then
		return color
	end
	return ColorSequence.new(color)
end)

local sampleColor = LPH_NO_VIRTUALIZE(function(sequence: ColorSequence, t: number): Color3
	local keypoints = sequence.Keypoints
	if t <= keypoints[1].Time then
		return keypoints[1].Value
	end
	local last = keypoints[#keypoints]
	if t >= last.Time then
		return last.Value
	end
	for i = 1, #keypoints - 1 do
		local a = keypoints[i]
		local b = keypoints[i + 1]
		if t <= b.Time then
			local span = b.Time - a.Time
			return a.Value:Lerp(b.Value, span > 0 and (t - a.Time) / span or 0)
		end
	end
	return last.Value
end)

local sliceColor = LPH_NO_VIRTUALIZE(function(sequence: ColorSequence, t0: number, t1: number): ColorSequence
	if t1 - t0 <= 1e-4 then
		return ColorSequence.new(sampleColor(sequence, t0))
	end
	local points = { ColorSequenceKeypoint.new(0, sampleColor(sequence, t0)) }
	local keypoints = sequence.Keypoints
	for i = 1, #keypoints do
		local keypoint = keypoints[i]
		if keypoint.Time > t0 + 1e-4 and keypoint.Time < t1 - 1e-4 then
			points[#points + 1] = ColorSequenceKeypoint.new((keypoint.Time - t0) / (t1 - t0), keypoint.Value)
		end
	end
	points[#points + 1] = ColorSequenceKeypoint.new(1, sampleColor(sequence, t1))
	return ColorSequence.new(points)
end)

type TracerJob = {
	dead: boolean,
	step: (now: number) -> boolean,
}

local _jobs: { TracerJob } = {}
local _jobCount = 0
local _jobConn: RBXScriptConnection? = nil

local runJobs = LPH_NO_VIRTUALIZE(function(): ()
	setthreadidentity(8)
	local now = os.clock()
	local i = 1
	local n = _jobCount
	while i <= n do
		local job = _jobs[i]
		if job.dead or job.step(now) then
			job.dead = true
			_jobs[i] = _jobs[n]
			_jobs[n] = nil
			n -= 1
		else
			i += 1
		end
	end
	_jobCount = n
	if n == 0 and _jobConn then
		_jobConn:Disconnect()
		_jobConn = nil
	end
end)

local function addJob(step: (now: number) -> boolean): TracerJob
	local job: TracerJob = { dead = false, step = step }
	_jobCount += 1
	_jobs[_jobCount] = job
	if not _jobConn then
		_jobConn = RunService.PreRender:Connect(runJobs)
	end
	return job
end

local BEAM_POP_SCALE = 1.7
local BEAM_POP_DURATION = 0.08
local BEAM_FADE_DURATION = 0.25

local function spawnBeamTracer(
	origin: Vector3,
	target: Vector3,
	settings: TracerSettings,
	parentJanitor: Janitor.Janitor
): ()
	local beam, attachment0, attachment1 = createBeam(origin, target, settings.Beam)
	local baseTransparency = settings.Transparency
	beam.Color = asColorSequence(settings.Color)
	local initialW0 = beam.Width0
	local initialW1 = beam.Width1
	beam.Width0 = initialW0 * BEAM_POP_SCALE
	beam.Width1 = initialW1 * BEAM_POP_SCALE
	beam.Transparency = NumberSequence.new(baseTransparency)

	local index = {}
	local destroyed = false
	local job: TracerJob? = nil
	local fadeStart: number? = nil
	local popDone = false
	local start = os.clock()
	local lifetime = settings.Lifetime

	local function cleanup(): ()
		if destroyed then
			return
		end
		destroyed = true
		if job then
			job.dead = true
			job = nil
		end
		beam:Destroy()
		attachment0:Destroy()
		attachment1:Destroy()
	end

	parentJanitor:Add(cleanup, true, index)

	job = addJob(LPH_NO_VIRTUALIZE(function(now: number): boolean
		if destroyed then
			return true
		end
		if not fadeStart then
			if not popDone then
				local popT = (now - start) / BEAM_POP_DURATION
				if popT >= 1 then
					popT = 1
					popDone = true
				end
				local popEased = popT * popT * (3 - 2 * popT)
				local scale = BEAM_POP_SCALE + (1 - BEAM_POP_SCALE) * popEased
				beam.Width0 = initialW0 * scale
				beam.Width1 = initialW1 * scale
			end
			if now - start >= lifetime then
				fadeStart = now
			end
			return false
		end
		local t = math.min((now - fadeStart) / BEAM_FADE_DURATION, 1)
		local eased = t * t * (3 - 2 * t)
		local m = 1 - eased
		beam.Width0 = initialW0 * m
		beam.Width1 = initialW1 * m
		beam.Transparency = NumberSequence.new(baseTransparency + (1 - baseTransparency) * eased)
		if t >= 1 then
			parentJanitor:Remove(index)
			return true
		end
		return false
	end))
end

local LINE_FADE_DURATION = 0.9

local function spawnLineTracer(
	origin: Vector3,
	target: Vector3,
	settings: TracerSettings,
	parentJanitor: Janitor.Janitor
): ()
	local handle = createLine()
	local baseTransparency = settings.Transparency
	local baseThickness = settings.Thickness
	handle.gradient.Color = asColorSequence(settings.Color)
	handle.state.from = origin
	handle.state.to = target
	handle.state.thickness = baseThickness
	handle.state.transparency = baseTransparency
	handle.gradient.Transparency = NumberSequence.new(baseTransparency)

	local index = {}
	local destroyed = false
	local fadeJob: TracerJob? = nil
	local timeoutThread: thread? = nil

	local function cleanup(): ()
		if destroyed then
			return
		end
		destroyed = true
		if fadeJob then
			fadeJob.dead = true
			fadeJob = nil
		end
		if timeoutThread then
			task.cancel(timeoutThread)
			timeoutThread = nil
		end
		handle.destroy()
	end

	parentJanitor:Add(cleanup, true, index)

	timeoutThread = task.delay(
		settings.Lifetime,
		LPH_NO_VIRTUALIZE(function(): ()
			if destroyed then
				return
			end
			timeoutThread = nil
			local fadeStart = os.clock()
			fadeJob = addJob(function(now: number): boolean
				if destroyed then
					return true
				end
				local t = math.min((now - fadeStart) / LINE_FADE_DURATION, 1)
				local eased = t * t * (3 - 2 * t)
				local trans = baseTransparency + (1 - baseTransparency) * eased
				handle.state.transparency = trans
				handle.gradient.Transparency = NumberSequence.new(trans)
				if t >= 1 then
					parentJanitor:Remove(index)
					return true
				end
				return false
			end)
		end)
	)
end

local ADORN_FADE_DURATION = 0.9

local function spawnAdornTracer(
	origin: Vector3,
	target: Vector3,
	settings: TracerSettings,
	parentJanitor: Janitor.Janitor
): ()
	local handle = createAdorn(origin, target)
	local baseTransparency = settings.Transparency
	handle.setColor(sampleColor(asColorSequence(settings.Color), 0))
	handle.setThickness(settings.Thickness)
	handle.setTransparency(baseTransparency)

	local index = {}
	local destroyed = false
	local fadeJob: TracerJob? = nil
	local timeoutThread: thread? = nil

	local function cleanup(): ()
		if destroyed then
			return
		end
		destroyed = true
		if fadeJob then
			fadeJob.dead = true
			fadeJob = nil
		end
		if timeoutThread then
			task.cancel(timeoutThread)
			timeoutThread = nil
		end
		handle.destroy()
	end

	parentJanitor:Add(cleanup, true, index)

	timeoutThread = task.delay(
		settings.Lifetime,
		LPH_NO_VIRTUALIZE(function(): ()
			if destroyed then
				return
			end
			timeoutThread = nil
			local fadeStart = os.clock()
			fadeJob = addJob(function(now: number): boolean
				if destroyed then
					return true
				end
				local t = math.min((now - fadeStart) / ADORN_FADE_DURATION, 1)
				local eased = t * t * (3 - 2 * t)
				handle.setTransparency(baseTransparency + (1 - baseTransparency) * eased)
				if t >= 1 then
					parentJanitor:Remove(index)
					return true
				end
				return false
			end)
		end)
	)
end

local function spawnSegment(
	origin: Vector3,
	target: Vector3,
	settings: TracerSettings,
	parentJanitor: Janitor.Janitor
): ()
	if settings.Type == "Line" then
		spawnLineTracer(origin, target, settings, parentJanitor)
	elseif settings.Type == "Adorn" then
		spawnAdornTracer(origin, target, settings, parentJanitor)
	else
		spawnBeamTracer(origin, target, settings, parentJanitor)
	end
end

local function spawnAdornCurve(points: { Vector3 }, settings: TracerSettings, parentJanitor: Janitor.Janitor): ()
	local baseTransparency = settings.Transparency
	local colorSequence = asColorSequence(settings.Color)
	local thickness = settings.Thickness

	local total = 0
	local distances = { 0 }
	for i = 1, #points - 1 do
		total += (points[i + 1] - points[i]).Magnitude
		distances[i + 1] = total
	end
	if total <= 0 then
		total = 1
	end

	local handles = {}
	for i = 1, #points - 1 do
		local t0 = distances[i] / total
		local handle = createAdorn(points[i], points[i + 1])
		handle.setColor(sampleColor(colorSequence, t0))
		handle.setThickness(thickness)
		handle.setTransparency(baseTransparency)
		handles[i] = handle
	end

	local index = {}
	local destroyed = false
	local fadeJob: TracerJob? = nil
	local timeoutThread: thread? = nil

	local function cleanup(): ()
		if destroyed then
			return
		end
		destroyed = true
		if fadeJob then
			fadeJob.dead = true
			fadeJob = nil
		end
		if timeoutThread then
			task.cancel(timeoutThread)
			timeoutThread = nil
		end
		for _, handle in next, handles do
			handle.destroy()
		end
	end

	parentJanitor:Add(cleanup, true, index)

	timeoutThread = task.delay(
		settings.Lifetime,
		LPH_NO_VIRTUALIZE(function(): ()
			if destroyed then
				return
			end
			timeoutThread = nil
			local fadeStart = os.clock()
			fadeJob = addJob(function(now: number): boolean
				if destroyed then
					return true
				end
				local t = math.min((now - fadeStart) / ADORN_FADE_DURATION, 1)
				local eased = t * t * (3 - 2 * t)
				local trans = baseTransparency + (1 - baseTransparency) * eased
				for _, handle in next, handles do
					handle.setTransparency(trans)
				end
				if t >= 1 then
					parentJanitor:Remove(index)
					return true
				end
				return false
			end)
		end)
	)
end

local function spawnCurve(points: { Vector3 }, settings: TracerSettings, parentJanitor: Janitor.Janitor): ()
	if #points < 2 then
		return
	end

	if settings.Type == "Adorn" then
		spawnAdornCurve(points, settings, parentJanitor)
		return
	end

	local isLine = settings.Type == "Line"
	local baseTransparency = settings.Transparency
	local colorSequence = asColorSequence(settings.Color)
	local segments = {}

	local total = 0
	local distances = { 0 }
	for i = 1, #points - 1 do
		total += (points[i + 1] - points[i]).Magnitude
		distances[i + 1] = total
	end
	if total <= 0 then
		total = 1
	end

	local baseWidth0, baseWidth1 = nil, nil

	for i = 1, #points - 1 do
		local t0 = distances[i] / total
		local t1 = distances[i + 1] / total
		local color = sliceColor(colorSequence, t0, t1)

		if isLine then
			local handle = createLine()
			handle.gradient.Color = color
			handle.state.from = points[i]
			handle.state.to = points[i + 1]
			handle.state.thickness = settings.Thickness
			handle.state.transparency = baseTransparency
			handle.gradient.Transparency = NumberSequence.new(baseTransparency)
			segments[i] = handle
		else
			local beam, attachment0, attachment1 = createBeam(points[i], points[i + 1], settings.Beam)
			if not baseWidth0 then
				baseWidth0, baseWidth1 = beam.Width0, beam.Width1
			end
			local w0 = baseWidth0 + (baseWidth1 - baseWidth0) * t0
			local w1 = baseWidth0 + (baseWidth1 - baseWidth0) * t1
			beam.Color = color
			beam.Transparency = NumberSequence.new(baseTransparency)
			beam.Width0 = w0 * BEAM_POP_SCALE
			beam.Width1 = w1 * BEAM_POP_SCALE
			segments[i] =
				{ beam = beam, attachment0 = attachment0, attachment1 = attachment1, width0 = w0, width1 = w1 }
		end
	end

	local index = {}
	local destroyed = false
	local job: TracerJob? = nil
	local fadeStart: number? = nil
	local popDone = isLine
	local start = os.clock()
	local lifetime = settings.Lifetime

	local function cleanup(): ()
		if destroyed then
			return
		end
		destroyed = true
		if job then
			job.dead = true
			job = nil
		end
		for _, seg in next, segments do
			if isLine then
				seg.destroy()
			else
				seg.beam:Destroy()
				seg.attachment0:Destroy()
				seg.attachment1:Destroy()
			end
		end
	end

	parentJanitor:Add(cleanup, true, index)

	job = addJob(LPH_NO_VIRTUALIZE(function(now: number): boolean
		if destroyed then
			return true
		end
		if not fadeStart then
			if not popDone then
				local popT = (now - start) / BEAM_POP_DURATION
				if popT >= 1 then
					popT = 1
					popDone = true
				end
				local popEased = popT * popT * (3 - 2 * popT)
				local scale = BEAM_POP_SCALE + (1 - BEAM_POP_SCALE) * popEased
				for _, seg in next, segments do
					seg.beam.Width0 = seg.width0 * scale
					seg.beam.Width1 = seg.width1 * scale
				end
			end
			if now - start >= lifetime then
				fadeStart = now
			end
			return false
		end
		local fadeDuration = isLine and LINE_FADE_DURATION or BEAM_FADE_DURATION
		local t = math.min((now - fadeStart) / fadeDuration, 1)
		local eased = t * t * (3 - 2 * t)
		local transparency = baseTransparency + (1 - baseTransparency) * eased
		if isLine then
			for _, seg in next, segments do
				seg.state.transparency = transparency
				seg.gradient.Transparency = NumberSequence.new(transparency)
			end
		else
			local m = 1 - eased
			for _, seg in next, segments do
				seg.beam.Width0 = seg.width0 * m
				seg.beam.Width1 = seg.width1 * m
				seg.beam.Transparency = NumberSequence.new(transparency)
			end
		end
		if t >= 1 then
			parentJanitor:Remove(index)
			return true
		end
		return false
	end))
end

local function reloadBeamManifest(self: Tracer): ()
	local picker = self._beamPicker
	if not picker then
		self._beamManifest = nil
		return
	end
	local name = picker:GetSelected()
	local path = name and picker:GetSelectedPath()
	if not path then
		self._beamManifest = nil
		return
	end
	self._beamManifest = readManifest(path)
end

local function peekSettings(
	self: Tracer,
	colorLink: gameUi.Linker,
	optsLink: gameUi.Linker,
	fallbackColor: ColorSequence
): TracerSettings
	local colorEl: any = colorLink:Get("color")
	local color: Color3 | ColorSequence = fallbackColor
	local transparency = 0
	if colorEl then
		color = (colorEl._currentGradient :: any):getValue() :: ColorSequence
		transparency = (colorEl._currentTransparency :: any):getValue() :: number
	end

	return {
		Color = color,
		Transparency = transparency,
		Type = optsLink:Peek("type") or "Beam",
		Lifetime = optsLink:Peek("lifetime") or 2,
		Thickness = optsLink:Peek("thickness") or 1,
		Beam = self._beamManifest,
	}
end

export type TracerApi = {
	spawnSegment: (origin: Vector3, target: Vector3, settings: TracerSettings, parentJanitor: Janitor.Janitor) -> (),
	spawnCurve: (points: { Vector3 }, settings: TracerSettings, parentJanitor: Janitor.Janitor) -> (),
	peekSettings: (colorLink: gameUi.Linker, optsLink: gameUi.Linker, fallbackColor: ColorSequence) -> TracerSettings,
	attachBeamPicker: (pickerLink: gameUi.Linker, label: string?) -> any,
	newJanitor: () -> Janitor.Janitor,
	PICKER_CONFIG: any,
}

export type TracerOpts = {
	setup: (self: Tracer, link: gameUi.Linker, api: TracerApi) -> (),
}

function Tracer.new(link: gameUi.Linker, opts: TracerOpts): Tracer
	local self = BaseFeature.new() :: any
	setmetatable(self, Tracer)

	self._link = link
	self._janitor = Janitor.new()
	self._beamPicker = nil
	self._beamManifest = nil :: createBeam.BeamManifest?

	local api: TracerApi = {
		spawnSegment = spawnSegment,
		spawnCurve = spawnCurve,
		peekSettings = function(colorLink, optsLink, fallbackColor)
			return peekSettings(self, colorLink, optsLink, fallbackColor)
		end,
		attachBeamPicker = function(pickerLink: gameUi.Linker, label: string?)
			local beamPicker = pickerLink:AssetPicker("beamStyle", label or "Beam Style", PICKER_CONFIG):SetTip({
				title = "Beam Style",
				body = "Custom beam texture/shape for Beam-type tracers.",
			})
			self._beamPicker = beamPicker
			reloadBeamManifest(self)
			self:Track(beamPicker:OnChange(function(): ()
				reloadBeamManifest(self)
			end))
			return beamPicker
		end,
		newJanitor = function(): Janitor.Janitor
			return Janitor.new()
		end,
		PICKER_CONFIG = PICKER_CONFIG,
	}

	opts.setup(self, link, api)

	return self
end

function Tracer.Destroy(self: Tracer): ()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type Tracer =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_janitor: Janitor.Janitor,
			_beamPicker: any,
			_beamManifest: createBeam.BeamManifest?,
		},
		Tracer
	))
	& BaseFeature.BaseFeature

return Tracer
