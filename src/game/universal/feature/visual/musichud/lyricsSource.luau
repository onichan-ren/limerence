local HttpService = cloneref(game:GetService("HttpService")) :: HttpService

local API_URL = "https://lrclib.net/api"
local DURATION_TOLERANCE = 5
local SEARCH_DURATION_TOLERANCE = 8
local MIN_SCORE = 0.45

local JUNK_KEYWORDS = {
	"official",
	"video",
	"audio",
	"lyric",
	"lyrics",
	"visualizer",
	"visualiser",
	"remaster",
	"remastered",
	"live",
	"explicit",
	"clean version",
	"hd",
	"hq",
	"4k",
	"mv",
	"archive",
	"full album",
	"color coded",
	"colour coded",
	"music video",
	"lyric video",
	"extended",
	"radio edit",
	"free download",
	"slowed",
	"reverb",
	"sped up",
	"nightcore",
	"cover",
	"feat",
	"prod",
}

local BRACKET_PATTERNS = { "%b()", "%b[]" }

local FEAT_MARKERS = { " feat.", " feat ", " ft.", " ft ", " featuring ", " prod." }

export type LyricLine = {
	time: number,
	text: string,
}

local collapse = LPH_NO_VIRTUALIZE(function(text: string): string
	text = string.gsub(text, "%s+", " ")
	return string.match(text, "^%s*(.-)%s*$") or ""
end)

local containsJunk = LPH_NO_VIRTUALIZE(function(inner: string): boolean
	local lower = string.lower(inner)
	for i = 1, #JUNK_KEYWORDS do
		if string.find(lower, JUNK_KEYWORDS[i], 1, true) then
			return true
		end
	end
	return false
end)

local stripBrackets = LPH_NO_VIRTUALIZE(function(text: string): string
	for i = 1, #BRACKET_PATTERNS do
		text = string.gsub(text, BRACKET_PATTERNS[i], function(group: string): string
			if containsJunk(string.sub(group, 2, -2)) then
				return ""
			end
			return group
		end)
	end
	return text
end)

local stripFeat = LPH_NO_VIRTUALIZE(function(text: string): string
	local lower = string.lower(text)
	local cut: number? = nil
	for i = 1, #FEAT_MARKERS do
		local idx = string.find(lower, FEAT_MARKERS[i], 1, true)
		if idx and (not cut or idx < cut) then
			cut = idx
		end
	end
	if cut then
		return string.sub(text, 1, cut - 1)
	end
	return text
end)

local normalizeTitle = LPH_NO_VIRTUALIZE(function(title: string): string
	local text = stripBrackets(title)
	text = string.gsub(text, "%s*%-%s*[Rr]emaster%w*.*$", "")
	text = stripFeat(text)
	text = string.gsub(text, "%s*%-%s*$", "")
	text = collapse(text)
	if text == "" then
		return collapse(title)
	end
	return text
end)

local normalizeArtist = LPH_NO_VIRTUALIZE(function(artist: string): string
	local text = string.gsub(artist, "%s*%-%s*[Tt]opic%s*$", "")
	text = string.gsub(text, "%s*[Vv][Ee][Vv][Oo]%s*$", "")
	text = stripFeat(text)
	return collapse(text)
end)

local dashSongPart = LPH_NO_VIRTUALIZE(function(title: string): string?
	local part = string.match(title, "%-%s*([^%-]+)%s*$")
	if part then
		return collapse(part)
	end
	return nil
end)

local tokenSet = LPH_NO_VIRTUALIZE(function(text: string): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for word in string.gmatch(string.lower(text), "%w+") do
		set[word] = true
	end
	return set
end)

local tokenSim = LPH_NO_VIRTUALIZE(function(a: string, b: string): number
	if a == "" or b == "" then
		return 0
	end
	local ta = tokenSet(a)
	local tb = tokenSet(b)
	local inter = 0
	local total = 0
	for word in next, ta do
		total += 1
		if tb[word] then
			inter += 1
		end
	end
	for word in next, tb do
		if not ta[word] then
			total += 1
		end
	end
	if total == 0 then
		return 0
	end
	return inter / total
end)

local fetchJson = LPH_NO_VIRTUALIZE(function(path: string): any
	local ok, response = pcall(request, {
		Url = API_URL .. path,
		Method = "GET",
		Headers = {
			["Accept"] = "application/json",
			["Lrclib-Client"] = "limerence",
		},
	})
	if not ok or type(response) ~= "table" then
		return nil
	end
	local statusCode = response.StatusCode or 0
	if statusCode ~= 200 then
		return nil
	end
	local body = response.Body
	if type(body) ~= "string" or body == "" then
		return nil
	end
	local decodeOk, decoded = pcall(function(): any
		return HttpService:JSONDecode(body)
	end)
	if not decodeOk then
		return nil
	end
	return decoded
end)

local parseLrc = LPH_NO_VIRTUALIZE(function(raw: string): { LyricLine }?
	local lines: { LyricLine } = {}
	for line in string.gmatch(raw, "[^\r\n]+") do
		local text = string.gsub(line, "%[%d+:%d+%.?%d*%]", "")
		text = string.match(text, "^%s*(.-)%s*$") or ""
		for minutes, seconds in string.gmatch(line, "%[(%d+):(%d+%.?%d*)%]") do
			lines[#lines + 1] = {
				time = tonumber(minutes) :: number * 60 + (tonumber(seconds) :: number),
				text = text,
			}
		end
	end
	if #lines == 0 then
		return nil
	end
	table.sort(lines, function(a: LyricLine, b: LyricLine): boolean
		return a.time < b.time
	end)
	return lines
end)

local parseRecord = LPH_NO_VIRTUALIZE(function(record: any, duration: number): { LyricLine }?
	if type(record) ~= "table" then
		return nil
	end
	if record.instrumental == true then
		return nil
	end
	if type(record.syncedLyrics) ~= "string" or record.syncedLyrics == "" then
		return nil
	end
	if duration > 0 then
		local recordDuration = tonumber(record.duration)
		if recordDuration and math.abs(recordDuration - duration) > DURATION_TOLERANCE then
			return nil
		end
	end
	return parseLrc(record.syncedLyrics)
end)

local scoreRecord = LPH_NO_VIRTUALIZE(function(record: any, title: string, artist: string, duration: number): number
	if type(record) ~= "table" then
		return -1
	end
	if record.instrumental == true then
		return -1
	end
	if type(record.syncedLyrics) ~= "string" or record.syncedLyrics == "" then
		return -1
	end
	local score = tokenSim(tostring(record.trackName or ""), title)
	score += tokenSim(tostring(record.artistName or ""), artist) * 0.6
	if duration > 0 then
		local recordDuration = tonumber(record.duration)
		if recordDuration then
			local delta = math.abs(recordDuration - duration)
			if delta > SEARCH_DURATION_TOLERANCE then
				return -1
			end
			score += (1 - delta / SEARCH_DURATION_TOLERANCE) * 0.8
		end
	end
	return score
end)

local pickBest = LPH_NO_VIRTUALIZE(
	function(results: any, title: string, artist: string, duration: number): { LyricLine }?
		if type(results) ~= "table" then
			return nil
		end
		local bestScore = MIN_SCORE
		local bestRecord: any = nil
		for i = 1, #results do
			local candidate = results[i]
			local score = scoreRecord(candidate, title, artist, duration)
			if score > bestScore then
				bestScore = score
				bestRecord = candidate
			end
		end
		if bestRecord then
			return parseLrc(bestRecord.syncedLyrics)
		end
		return nil
	end
)

local tryGet = LPH_NO_VIRTUALIZE(
	function(title: string, artist: string, album: string?, duration: number): { LyricLine }?
		if title == "" or artist == "" then
			return nil
		end
		local path = `/get?track_name={HttpService:UrlEncode(title)}&artist_name={HttpService:UrlEncode(artist)}`
		if album and album ~= "" then
			path ..= `&album_name={HttpService:UrlEncode(album)}`
		end
		if duration > 0 then
			path ..= `&duration={math.floor(duration + 0.5)}`
		end
		return parseRecord(fetchJson(path), 0)
	end
)

local trySearchStructured = LPH_NO_VIRTUALIZE(function(title: string, artist: string, duration: number): { LyricLine }?
	if title == "" then
		return nil
	end
	local path = `/search?track_name={HttpService:UrlEncode(title)}`
	if artist ~= "" then
		path ..= `&artist_name={HttpService:UrlEncode(artist)}`
	end
	return pickBest(fetchJson(path), title, artist, duration)
end)

local trySearchQuery = LPH_NO_VIRTUALIZE(
	function(query: string, title: string, artist: string, duration: number): { LyricLine }?
		if query == "" then
			return nil
		end
		return pickBest(fetchJson(`/search?q={HttpService:UrlEncode(query)}`), title, artist, duration)
	end
)

local lyricsSource = {}

function lyricsSource.fetch(title: string, artist: string, album: string?, duration: number): { LyricLine }?
	if title == "" then
		return nil
	end

	local cleanTitle = normalizeTitle(title)
	local cleanArtist = normalizeArtist(artist)

	local lines = tryGet(title, artist, album, duration)
	if lines then
		return lines
	end

	if cleanTitle ~= title or cleanArtist ~= artist then
		lines = tryGet(cleanTitle, cleanArtist, album, duration)
		if lines then
			return lines
		end
	end

	lines = trySearchStructured(cleanTitle, cleanArtist, duration)
	if lines then
		return lines
	end

	if cleanArtist ~= "" then
		lines = trySearchQuery(`{cleanTitle} {cleanArtist}`, cleanTitle, cleanArtist, duration)
		if lines then
			return lines
		end
	end

	lines = trySearchQuery(cleanTitle, cleanTitle, cleanArtist, duration)
	if lines then
		return lines
	end

	local altTitle = dashSongPart(cleanTitle)
	if altTitle and altTitle ~= cleanTitle then
		lines = trySearchQuery(altTitle, altTitle, cleanArtist, duration)
		if lines then
			return lines
		end
	end

	return nil
end

export type lyricsSource = typeof(lyricsSource)

return lyricsSource
