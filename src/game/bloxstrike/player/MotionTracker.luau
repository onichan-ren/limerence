local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local PlayerController = require("@feature/player/PlayerController")

local peek = Charm.peek

local SAMPLE_WINDOW = 0.15
local SAMPLE_RETENTION = SAMPLE_WINDOW + 0.05
local TELEPORT_THRESHOLD_SQ = 200 * 200
local MIN_DT = 0.02
local RING_CAPACITY = 256

type Sample = {
	pos: Vector3,
	time: number,
}

type Track = {
	samples: { Sample },
	head: number,
	count: number,
	lastPos: Vector3?,
}

local MotionTracker = {
	_tracks = {} :: { [any]: Track },
	_conn = nil :: RBXScriptConnection?,
	_consumers = 0,
}

local function newTrack(): Track
	return {
		samples = {},
		head = 1,
		count = 0,
		lastPos = nil,
	}
end

local pushSample = LPH_NO_VIRTUALIZE(function(track: Track, pos: Vector3, now: number): ()
	local last = track.lastPos
	if last then
		local d = pos - last
		if d:Dot(d) > TELEPORT_THRESHOLD_SQ then
			track.head = 1
			track.count = 0
		end
	end
	track.lastPos = pos

	local samples = track.samples
	local count = track.count
	if count < RING_CAPACITY then
		local writeIndex = (track.head + count - 1) % RING_CAPACITY + 1
		local entry = samples[writeIndex]
		if entry then
			entry.pos = pos
			entry.time = now
		else
			samples[writeIndex] = { pos = pos, time = now }
		end
		track.count = count + 1
	else
		local writeIndex = track.head
		local entry = samples[writeIndex]
		entry.pos = pos
		entry.time = now
		track.head = writeIndex % RING_CAPACITY + 1
	end

	local minTime = now - SAMPLE_RETENTION
	while track.count > 0 do
		local oldest = samples[track.head]
		if oldest.time >= minTime then
			break
		end
		track.head = track.head % RING_CAPACITY + 1
		track.count -= 1
	end
end)

local seenScratch: { [any]: true } = {}

local sample = LPH_NO_VIRTUALIZE(function(): ()
	local now = tick()
	local tracks = MotionTracker._tracks
	local seen = seenScratch
	table.clear(seen)

	for _, basePlayer in next, PlayerController.GetAll() do
		seen[basePlayer] = true
		local hrp = peek(basePlayer.hrp) :: BasePart?
		if not hrp then
			tracks[basePlayer] = nil
			continue
		end
		local track = tracks[basePlayer]
		if not track then
			track = newTrack()
			tracks[basePlayer] = track
		end
		pushSample(track, hrp.Position, now)
	end

	for bp in next, tracks do
		if not seen[bp] then
			tracks[bp] = nil
		end
	end
end)

MotionTracker.GetSmoothedVelocity = LPH_NO_VIRTUALIZE(function(basePlayer: any): Vector3?
	local track = MotionTracker._tracks[basePlayer]
	if not track then
		return nil
	end
	local samples = track.samples
	local head = track.head
	local count = track.count
	if count < 2 then
		return nil
	end
	local newest = samples[(head + count - 2) % RING_CAPACITY + 1]
	local target = newest.time - SAMPLE_WINDOW
	local oldest = samples[head]
	if oldest.time < target then
		local lo, hi = 1, count - 1
		while lo < hi do
			local mid = (lo + hi) // 2
			if samples[(head + mid - 1) % RING_CAPACITY + 1].time >= target then
				hi = mid
			else
				lo = mid + 1
			end
		end
		oldest = samples[(head + lo - 1) % RING_CAPACITY + 1]
	end
	local dt = newest.time - oldest.time
	if dt < MIN_DT then
		return nil
	end
	return (newest.pos - oldest.pos) / dt
end)

MotionTracker.PredictPosition = LPH_NO_VIRTUALIZE(function(basePlayer: any, lookaheadSec: number): Vector3?
	local track = MotionTracker._tracks[basePlayer]
	if not track then
		return nil
	end
	local last = track.lastPos
	if not last then
		return nil
	end
	local vel = MotionTracker.GetSmoothedVelocity(basePlayer)
	if not vel then
		return last
	end
	return last + vel * lookaheadSec
end)

function MotionTracker.Acquire(): ()
	MotionTracker._consumers += 1
	if MotionTracker._consumers == 1 then
		MotionTracker._conn = RunService.Heartbeat:Connect(sample)
	end
end

function MotionTracker.Release(): ()
	if MotionTracker._consumers == 0 then
		return
	end
	MotionTracker._consumers -= 1
	if MotionTracker._consumers == 0 then
		if MotionTracker._conn then
			MotionTracker._conn:Disconnect()
			MotionTracker._conn = nil
		end
		table.clear(MotionTracker._tracks)
	end
end

function MotionTracker.new(): typeof(MotionTracker)
	return MotionTracker
end

function MotionTracker.Destroy(): ()
	MotionTracker._consumers = 0
	if MotionTracker._conn then
		MotionTracker._conn:Disconnect()
		MotionTracker._conn = nil
	end
	table.clear(MotionTracker._tracks)
end

export type MotionTracker = typeof(MotionTracker)

return MotionTracker
