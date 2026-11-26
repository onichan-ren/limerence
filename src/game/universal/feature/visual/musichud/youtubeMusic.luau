local HttpService = cloneref(game:GetService("HttpService")) :: HttpService

local BASE_URL = "http://127.0.0.1:26538"
local AUTH_ID = "limerence"
local TOKEN_PATH = "limerence.biz/cache/ytmusic_token.txt"

export type Track = {
	id: string,
	title: string,
	artist: string,
	album: string?,
	coverUrl: string?,
	duration: number,
}

export type Playback = {
	elapsed: number,
	paused: boolean,
}

type HttpResponse = {
	StatusCode: number?,
	StatusMessage: string?,
	Body: string?,
	Headers: { [string]: string }?,
}

local token: string? = nil
local tokenLoaded = false
local authDenied = false

local function loadToken(): ()
	if tokenLoaded then
		return
	end
	tokenLoaded = true
	if isfile(TOKEN_PATH) then
		local stored = readfile(TOKEN_PATH)
		if type(stored) == "string" and stored ~= "" then
			token = stored
		end
	end
end

local function send(method: string, path: string): HttpResponse?
	local headers: { [string]: string } = {
		["Accept"] = "application/json",
	}
	if token then
		headers["Authorization"] = `Bearer {token}`
	end
	local ok, response = pcall(request, {
		Url = BASE_URL .. path,
		Method = method,
		Headers = headers,
	})
	if not ok or type(response) ~= "table" then
		return nil
	end
	return response
end

local function decode(body: string?): any
	if type(body) ~= "string" or body == "" then
		return nil
	end
	local ok, decoded = pcall(function(): any
		return HttpService:JSONDecode(body)
	end)
	if not ok then
		return nil
	end
	return decoded
end

local function authenticate(): boolean
	local response = send("POST", `/auth/{AUTH_ID}`)
	if not response then
		return false
	end
	local statusCode = response.StatusCode or 0
	if statusCode == 403 then
		authDenied = true
		return false
	end
	if statusCode < 200 or statusCode >= 300 then
		return false
	end
	local decoded = decode(response.Body)
	if type(decoded) ~= "table" or type(decoded.accessToken) ~= "string" then
		return false
	end
	token = decoded.accessToken
	writefile(TOKEN_PATH, decoded.accessToken)
	return true
end

local function parseSong(body: string?): (Track?, Playback?)
	local decoded = decode(body)
	if type(decoded) ~= "table" or type(decoded.videoId) ~= "string" then
		return nil, nil
	end
	local track: Track = {
		id = decoded.videoId,
		title = type(decoded.title) == "string" and decoded.title or "Unknown",
		artist = type(decoded.artist) == "string" and decoded.artist or "",
		album = type(decoded.album) == "string" and decoded.album or nil,
		coverUrl = type(decoded.imageSrc) == "string" and decoded.imageSrc or nil,
		duration = tonumber(decoded.songDuration) or 0,
	}
	local playback: Playback = {
		elapsed = tonumber(decoded.elapsedSeconds) or 0,
		paused = decoded.isPaused == true,
	}
	return track, playback
end

local youtubeMusic = {}

youtubeMusic.name = "YouTube Music"
youtubeMusic.interval = 0.25

function youtubeMusic.reset(): ()
	authDenied = false
end

function youtubeMusic.poll(): (Track?, Playback?)
	if authDenied then
		return nil, nil
	end
	loadToken()
	local response = send("GET", "/api/v1/song")
	if not response then
		return nil, nil
	end
	local statusCode = response.StatusCode or 0
	if statusCode == 401 or statusCode == 403 then
		token = nil
		if not authenticate() then
			return nil, nil
		end
		response = send("GET", "/api/v1/song")
		if not response then
			return nil, nil
		end
		statusCode = response.StatusCode or 0
	end
	if statusCode ~= 200 then
		return nil, nil
	end
	return parseSong(response.Body)
end

export type youtubeMusic = typeof(youtubeMusic)

return youtubeMusic
