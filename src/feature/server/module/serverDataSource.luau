local HttpService = cloneref(game:GetService("HttpService")) :: HttpService

local BASE_URL = "https://games.roblox.com/v1/games/%d/servers/Public"

type HttpResponse = {
	Success: boolean?,
	StatusCode: number?,
	StatusMessage: string?,
	Body: string?,
	Headers: { [string]: string }?,
}

type RequestFn = (options: { [string]: any }) -> HttpResponse

export type ServerEntry = {
	id: string,
	maxPlayers: number?,
	playing: number?,
	playerTokens: { string }?,
	fps: number?,
	ping: number?,
	[string]: any,
}

export type ServerPage = {
	rows: { ServerEntry },
	nextCursor: string?,
	previousCursor: string?,
	error: string?,
}

local serverDataSource = {}

function serverDataSource.buildUrl(placeId: number, cursor: string?): string
	local url = string.format(BASE_URL, placeId)
	if cursor and cursor ~= "" then
		url = url .. "?cursor=" .. HttpService:UrlEncode(cursor)
	end
	return url
end

local function snippet(body: string?): string
	if not body or body == "" then
		return "<empty>"
	end
	local trimmed = string.gsub(body, "%s+", " ")
	if #trimmed > 120 then
		return string.sub(trimmed, 1, 117) .. "..."
	end
	return trimmed
end

local function fetchBody(url: string): (boolean, string)
	local ok, response = pcall(request, {
		Url = url,
		Method = "GET",
		Headers = {
			["Accept"] = "application/json",
			["Cache-Control"] = "no-cache",
		},
	})
	if not ok then
		return false, tostring(response)
	end
	local statusCode = response.StatusCode or 0
	local body = response.Body or ""
	if statusCode < 200 or statusCode >= 300 then
		return false, `HTTP {statusCode} {response.StatusMessage or ""}: {body}`
	end
	return true, body
end

function serverDataSource.fetchPage(placeId: number, cursor: string?): ServerPage
	local url = serverDataSource.buildUrl(placeId, cursor)

	local ok, body = fetchBody(url)
	if not ok then
		return {
			rows = {},
			nextCursor = nil,
			previousCursor = nil,
			error = body,
		}
	end

	if type(body) ~= "string" or body == "" then
		return {
			rows = {},
			nextCursor = nil,
			previousCursor = nil,
			error = "Empty response from server",
		}
	end

	local decodeOk, decoded: any = pcall(function(): any
		return HttpService:JSONDecode(body)
	end)

	if not decodeOk or type(decoded) ~= "table" then
		return {
			rows = {},
			nextCursor = nil,
			previousCursor = nil,
			error = `Failed to parse response: {snippet(body)}`,
		}
	end

	if type(decoded.errors) == "table" and decoded.errors[1] then
		local first = decoded.errors[1]
		local message = (type(first) == "table" and first.message) or "API error"
		return {
			rows = {},
			nextCursor = nil,
			previousCursor = nil,
			error = tostring(message),
		}
	end

	local rows: { ServerEntry } = {}
	if type(decoded.data) == "table" then
		for _, entry in next, decoded.data do
			if type(entry) == "table" and entry.id ~= nil then
				table.insert(rows, entry)
			end
		end
	end

	return {
		rows = rows,
		nextCursor = decoded.nextPageCursor,
		previousCursor = decoded.previousPageCursor,
	}
end

function serverDataSource.makeSource(placeId: number): (cursor: string?) -> ServerPage
	return function(cursor: string?): ServerPage
		return serverDataSource.fetchPage(placeId, cursor)
	end
end

function serverDataSource.findHopTarget(placeId: number, excludeJobId: string?, maxPages: number?): ServerEntry?
	local cursor: string? = nil
	local pages = maxPages or 5
	for _ = 1, pages do
		local page = serverDataSource.fetchPage(placeId, cursor)
		if page.error then
			return nil
		end
		for _, entry in next, page.rows do
			local id = entry.id and tostring(entry.id) or nil
			local playing = tonumber(entry.playing) or 0
			local maxPlayers = tonumber(entry.maxPlayers) or 0
			if id and id ~= excludeJobId and maxPlayers > 0 and playing < maxPlayers then
				return entry
			end
		end
		if not page.nextCursor or page.nextCursor == "" then
			return nil
		end
		cursor = page.nextCursor
	end
	return nil
end

export type serverDataSource = typeof(serverDataSource)

return serverDataSource
