local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local peek = Charm.peek

export type PublicTrack = {
	id: string,
	title: string,
	artist: string,
	album: string?,
	coverUrl: string?,
	duration: number,
}

export type PublicPlayback = {
	elapsed: number,
	duration: number,
	paused: boolean,
}

export type PublicLyric = {
	time: number,
	text: string,
}

export type CustomSource = {
	name: string,
	interval: number,
	reset: () -> (),
	poll: () -> (PublicTrack?, { elapsed: number, paused: boolean }?),
}

local signals = {
	onTrack = Signal.new(),
	onPause = Signal.new(),
	onSourceChanged = Signal.new(),
	onLyricsChanged = Signal.new(),
}

local hud: any = nil
local sourceOverride: CustomSource? = nil
local sourceOwner: any = nil
local lyricsOverride: any = nil
local lyricsOwner: any = nil

local musicHudApi = {
	signals = signals,
}

local function toPublicTrack(track: any): PublicTrack?
	if not track then
		return nil
	end
	return {
		id = track.id,
		title = track.title,
		artist = track.artist,
		album = track.album,
		coverUrl = track.coverUrl,
		duration = track.duration,
	}
end

local function sanitizeTrack(raw: any): PublicTrack?
	if type(raw) ~= "table" then
		return nil
	end
	local title = raw.title
	local duration = raw.duration
	if type(title) ~= "string" or title == "" or type(duration) ~= "number" or duration ~= duration or duration <= 0 then
		return nil
	end
	local artist = ""
	if type(raw.artist) == "string" then
		artist = raw.artist
	end
	local album: string? = nil
	if type(raw.album) == "string" and raw.album ~= "" then
		album = raw.album
	end
	local coverUrl: string? = nil
	if type(raw.coverUrl) == "string" and string.sub(raw.coverUrl, 1, 4) == "http" then
		coverUrl = raw.coverUrl
	end
	local id = raw.id
	if type(id) ~= "string" or id == "" then
		id = title .. "\0" .. artist
	end
	return {
		id = id,
		title = title,
		artist = artist,
		album = album,
		coverUrl = coverUrl,
		duration = duration,
	}
end

local function sanitizePlayback(raw: any, duration: number): { elapsed: number, paused: boolean }?
	if type(raw) ~= "table" then
		return nil
	end
	local elapsed = raw.elapsed
	if type(elapsed) ~= "number" or elapsed ~= elapsed or elapsed < 0 then
		elapsed = 0
	end
	if elapsed > duration then
		elapsed = duration
	end
	return { elapsed = elapsed, paused = raw.paused == true }
end

local function sanitizeLyrics(lines: { any }): { PublicLyric }?
	local out = table.create(#lines)
	for i = 1, #lines do
		local line = lines[i]
		if
			type(line) == "table"
			and type(line.time) == "number"
			and line.time == line.time
			and type(line.text) == "string"
		then
			out[#out + 1] = { time = line.time, text = line.text }
		end
	end
	if #out == 0 then
		return nil
	end
	table.sort(out, function(a: PublicLyric, b: PublicLyric): boolean
		return a.time < b.time
	end)
	return out
end

local function livePlayback(): PublicPlayback?
	if not hud or not peek(hud._track) then
		return nil
	end
	local pb = hud._playback
	local elapsed = pb.elapsed
	if not pb.paused then
		elapsed += os.clock() - pb.at
	end
	if pb.duration > 0 and elapsed > pb.duration then
		elapsed = pb.duration
	end
	return { elapsed = elapsed, duration = pb.duration, paused = pb.paused }
end

local function setSourceInternal(spec: any, owner: any): ()
	if spec == nil then
		if sourceOverride == nil then
			return
		end
		sourceOverride = nil
		sourceOwner = nil
		signals.onSourceChanged:Fire()
		return
	end
	local interval = 1
	if type(spec.interval) == "number" and spec.interval == spec.interval then
		interval = math.clamp(spec.interval, 0.25, 30)
	end
	local name = "Custom"
	if type(spec.name) == "string" and spec.name ~= "" then
		name = spec.name
	end
	local pollFn = spec.poll
	local resetFn = spec.reset
	sourceOverride = {
		name = name,
		interval = interval,
		reset = function(): ()
			if type(resetFn) == "function" then
				pcall(resetFn)
			end
		end,
		poll = function(): (PublicTrack?, { elapsed: number, paused: boolean }?)
			local ok, rawTrack, rawPlayback = pcall(pollFn)
			if not ok then
				return nil, nil
			end
			local track = sanitizeTrack(rawTrack)
			if not track then
				return nil, nil
			end
			local playback = sanitizePlayback(rawPlayback, track.duration)
			if not playback then
				return nil, nil
			end
			return track, playback
		end,
	}
	sourceOwner = owner
	signals.onSourceChanged:Fire()
end

local function setLyricsInternal(fn: any, owner: any): ()
	if fn == nil and lyricsOverride == nil then
		return
	end
	lyricsOverride = fn
	lyricsOwner = fn ~= nil and owner or nil
	signals.onLyricsChanged:Fire()
end

function musicHudApi.Attach(instance: any): ()
	hud = instance
end

function musicHudApi.NotifyTrack(track: any): ()
	signals.onTrack:Fire(toPublicTrack(track))
end

function musicHudApi.NotifyPaused(paused: boolean): ()
	signals.onPause:Fire(paused)
end

function musicHudApi.GetSourceOverride(): CustomSource?
	return sourceOverride
end

function musicHudApi.ResolveLyrics(track: any): { PublicLyric }?
	local fn = lyricsOverride
	if not fn then
		return nil
	end
	local ok, lines = pcall(fn, toPublicTrack(track))
	if ok and type(lines) == "table" then
		return sanitizeLyrics(lines)
	end
	return nil
end

luauApiRegistry.RegisterFeature("musichud", function(ctx)
	local onUnload = ctx.onUnload
	local wrap = luauApiRegistry.WrapSignal

	onUnload:Connect(function(): ()
		if sourceOwner == ctx then
			setSourceInternal(nil, nil)
		end
		if lyricsOwner == ctx then
			setLyricsInternal(nil, nil)
		end
	end)

	local api = {}

	function api.isEnabled(): boolean
		return hud ~= nil and hud._running == true
	end

	function api.isPaused(): boolean
		return hud == nil or peek(hud._paused) == true
	end

	function api.getTrack(): PublicTrack?
		if not hud then
			return nil
		end
		return toPublicTrack(peek(hud._track))
	end

	api.getPlayback = livePlayback

	function api.getLyrics(): { PublicLyric }?
		if not hud then
			return nil
		end
		local lines = peek(hud._lyrics)
		if not lines then
			return nil
		end
		local copy = table.create(#lines)
		for i = 1, #lines do
			local line = lines[i]
			copy[i] = { time = line.time, text = line.text }
		end
		return copy
	end

	function api.getLyric(): string?
		if not hud then
			return nil
		end
		local lines = peek(hud._lyrics)
		if not lines then
			return nil
		end
		local playback = livePlayback()
		if not playback then
			return nil
		end
		local current: string? = nil
		for i = 1, #lines do
			if lines[i].time <= playback.elapsed then
				current = lines[i].text
			else
				break
			end
		end
		return current
	end

	function api.setSource(spec: any): ()
		if spec ~= nil and (type(spec) ~= "table" or type(spec.poll) ~= "function") then
			error("api.feature.musichud.setSource: spec.poll must be a function", 2)
		end
		setSourceInternal(spec, ctx)
	end

	function api.setLyrics(fn: any): ()
		if fn ~= nil and type(fn) ~= "function" then
			error("api.feature.musichud.setLyrics: callback must be a function", 2)
		end
		setLyricsInternal(fn, ctx)
	end

	api.onTrackChanged = wrap(signals.onTrack, onUnload)
	api.onPauseChanged = wrap(signals.onPause, onUnload)

	return api
end)

return musicHudApi
