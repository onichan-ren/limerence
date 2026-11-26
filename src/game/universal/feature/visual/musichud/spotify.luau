local HttpService = cloneref(game:GetService("HttpService")) :: HttpService

local ACCOUNTS_URL = "https://accounts.spotify.com"
local API_URL = "https://api.spotify.com/v1"
local REDIRECT_URI = "http://127.0.0.1:8888/callback"
local SCOPE = "user-read-playback-state"
local AUTH_PATH = "limerence.biz/cache/spotify_auth.json"

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

local clientId: string? = nil
local clientSecret: string? = nil
local refreshToken: string? = nil
local accessToken: string? = nil
local expiresAt = 0
local cooldownUntil = 0
local authLoaded = false

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

local function loadAuth(): ()
	if authLoaded then
		return
	end
	authLoaded = true
	if not isfile(AUTH_PATH) then
		return
	end
	local stored = decode(readfile(AUTH_PATH))
	if type(stored) ~= "table" then
		return
	end
	if type(stored.clientId) == "string" and stored.clientId ~= "" then
		clientId = stored.clientId
	end
	if type(stored.clientSecret) == "string" and stored.clientSecret ~= "" then
		clientSecret = stored.clientSecret
	end
	if type(stored.refreshToken) == "string" and stored.refreshToken ~= "" then
		refreshToken = stored.refreshToken
	end
end

local function saveAuth(): ()
	writefile(
		AUTH_PATH,
		HttpService:JSONEncode({
			clientId = clientId,
			clientSecret = clientSecret,
			refreshToken = refreshToken,
		})
	)
end

local function send(method: string, url: string, headers: { [string]: string }, body: string?): HttpResponse?
	local ok, response = pcall(request, {
		Url = url,
		Method = method,
		Headers = headers,
		Body = body,
	})
	if not ok or type(response) ~= "table" then
		return nil
	end
	return response
end

local function formEncode(fields: { [string]: string }): string
	local parts = {}
	for key, value in next, fields do
		parts[#parts + 1] = `{key}={HttpService:UrlEncode(value)}`
	end
	return table.concat(parts, "&")
end

local function exchangeToken(fields: { [string]: string }): (boolean, string?)
	if not clientId or not clientSecret then
		return false, "Missing client id or secret"
	end
	fields.client_id = clientId :: string
	fields.client_secret = clientSecret :: string
	local response = send("POST", `{ACCOUNTS_URL}/api/token`, {
		["Content-Type"] = "application/x-www-form-urlencoded",
	}, formEncode(fields))
	if not response then
		return false, "Request failed"
	end
	local decoded = decode(response.Body)
	local statusCode = response.StatusCode or 0
	if statusCode < 200 or statusCode >= 300 then
		local reason = type(decoded) == "table" and type(decoded.error_description) == "string" and decoded.error_description
			or `Status {statusCode}`
		return false, reason
	end
	if type(decoded) ~= "table" or type(decoded.access_token) ~= "string" then
		return false, "Bad token response"
	end
	accessToken = decoded.access_token
	expiresAt = os.clock() + (tonumber(decoded.expires_in) or 3600) - 60
	if type(decoded.refresh_token) == "string" and decoded.refresh_token ~= "" then
		refreshToken = decoded.refresh_token
		saveAuth()
	end
	return true, nil
end

local function refreshAccess(): boolean
	if not refreshToken then
		return false
	end
	local ok = exchangeToken({
		grant_type = "refresh_token",
		refresh_token = refreshToken :: string,
	})
	if not ok then
		accessToken = nil
	end
	return ok
end

local function ensureToken(): boolean
	loadAuth()
	if accessToken and os.clock() < expiresAt then
		return true
	end
	return refreshAccess()
end

local function pickCover(images: any): string?
	if type(images) ~= "table" or #images == 0 then
		return nil
	end
	local best = images[#images]
	for i = #images, 1, -1 do
		local image = images[i]
		if type(image) == "table" and tonumber(image.width) and tonumber(image.width) >= 64 then
			best = image
			break
		end
	end
	if type(best) == "table" and type(best.url) == "string" then
		return best.url
	end
	return nil
end

local function parsePlayer(body: string?): (Track?, Playback?)
	local decoded = decode(body)
	if type(decoded) ~= "table" then
		return nil, nil
	end
	local item = decoded.item
	if type(item) ~= "table" or type(item.id) ~= "string" or type(item.name) ~= "string" then
		return nil, nil
	end
	local artistNames = {}
	local artists = item.artists
	if type(artists) == "table" then
		for i = 1, #artists do
			local artist = artists[i]
			if type(artist) == "table" and type(artist.name) == "string" then
				artistNames[#artistNames + 1] = artist.name
			end
		end
	end
	local album = item.album
	local albumName: string? = nil
	local coverUrl: string? = nil
	if type(album) == "table" then
		if type(album.name) == "string" and album.name ~= "" then
			albumName = album.name
		end
		coverUrl = pickCover(album.images)
	end
	local track: Track = {
		id = item.id,
		title = item.name,
		artist = table.concat(artistNames, ", "),
		album = albumName,
		coverUrl = coverUrl,
		duration = (tonumber(item.duration_ms) or 0) / 1000,
	}
	local playback: Playback = {
		elapsed = (tonumber(decoded.progress_ms) or 0) / 1000,
		paused = decoded.is_playing ~= true,
	}
	return track, playback
end

local spotify = {}

spotify.name = "Spotify"
spotify.interval = 1

function spotify.SetCredentials(id: string, secret: string): ()
	loadAuth()
	if clientId ~= id or clientSecret ~= secret then
		clientId = id
		clientSecret = secret
		accessToken = nil
		refreshToken = nil
		expiresAt = 0
		saveAuth()
	end
end

function spotify.HasCredentials(): boolean
	loadAuth()
	return clientId ~= nil and clientSecret ~= nil
end

function spotify.IsLinked(): boolean
	loadAuth()
	return refreshToken ~= nil
end

function spotify.GetAuthUrl(): string?
	loadAuth()
	if not clientId then
		return nil
	end
	return `{ACCOUNTS_URL}/authorize?response_type=code&client_id={HttpService:UrlEncode(clientId :: string)}&scope={HttpService:UrlEncode(
		SCOPE
	)}&redirect_uri={HttpService:UrlEncode(REDIRECT_URI)}`
end

function spotify.GetRedirectUri(): string
	return REDIRECT_URI
end

function spotify.SubmitRedirect(input: string): (boolean, string?)
	loadAuth()
	local trimmed = string.gsub(input, "%s+", "")
	local code = string.match(trimmed, "[?&]code=([^&#]+)")
	if not code and not string.find(trimmed, "://", 1, true) and #trimmed > 20 then
		code = trimmed
	end
	if not code then
		return false, "No code in that link"
	end
	local ok, reason = exchangeToken({
		grant_type = "authorization_code",
		code = code :: string,
		redirect_uri = REDIRECT_URI,
	})
	return ok, reason
end

function spotify.reset(): ()
	cooldownUntil = 0
end

function spotify.poll(): (Track?, Playback?)
	if os.clock() < cooldownUntil then
		return nil, nil
	end
	if not ensureToken() then
		cooldownUntil = os.clock() + 5
		return nil, nil
	end
	local headers = {
		["Authorization"] = `Bearer {accessToken}`,
		["Accept"] = "application/json",
	}
	local response = send("GET", `{API_URL}/me/player/currently-playing`, headers)
	if not response then
		return nil, nil
	end
	local statusCode = response.StatusCode or 0
	if statusCode == 401 then
		accessToken = nil
		if not refreshAccess() then
			cooldownUntil = os.clock() + 10
			return nil, nil
		end
		headers["Authorization"] = `Bearer {accessToken}`
		response = send("GET", `{API_URL}/me/player/currently-playing`, headers)
		if not response then
			return nil, nil
		end
		statusCode = response.StatusCode or 0
	end
	if statusCode == 429 then
		local retryAfter = 5
		local responseHeaders = response.Headers
		if type(responseHeaders) == "table" then
			retryAfter = tonumber(responseHeaders["Retry-After"] or responseHeaders["retry-after"]) or 5
		end
		cooldownUntil = os.clock() + retryAfter
		return nil, nil
	end
	if statusCode ~= 200 then
		return nil, nil
	end
	return parsePlayer(response.Body)
end

export type spotify = typeof(spotify)

return spotify
