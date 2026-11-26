local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local AppController = require("@feature/app/AppController")
local FileController = require("@feature/file/FileController")
local gameUi = require("@game/gameUi")
local NotifyController = require("@ui/hud/notify/NotifyController")
local youtubeMusic = require("@game/universal/feature/visual/musichud/youtubeMusic")
local spotify = require("@game/universal/feature/visual/musichud/spotify")
local lyricsSource = require("@game/universal/feature/visual/musichud/lyricsSource")
local musicHudApi = require("@game/universal/feature/visual/musichud/musicHudApi")
local musicHudView = require("@game/universal/feature/visual/musichud/musicHudView")

local at = Charm.atom
local peek = Charm.peek
local e = React.createElement

local COVER_CACHE: FileController.UrlCacheOptions = { folder = "music", maxFiles = 50 }
local DEFAULT_ACCENT = Color3.fromRGB(70, 220, 176)
local DEFAULT_POSITION = UDim2.new(0.5, 0, 0.12, 0)
local SEEK_THRESHOLD = 1.5

type Provider = {
	name: string,
	interval: number,
	reset: () -> (),
	poll: () -> (youtubeMusic.Track?, youtubeMusic.Playback?),
}

local PROVIDERS: { [string]: Provider } = {
	["YouTube Music"] = youtubeMusic :: any,
	["Spotify"] = spotify :: any,
}

export type DisplayTrack = youtubeMusic.Track & {
	coverImage: string?,
}

export type PlaybackState = {
	elapsed: number,
	duration: number,
	at: number,
	paused: boolean,
}

local MusicHud = {}
MusicHud.__index = MusicHud

setmetatable(MusicHud, { __index = BaseFeature })

function MusicHud.new(link: gameUi.Linker): MusicHud
	local self = BaseFeature.new() :: any
	setmetatable(self, MusicHud)

	self._mounted = false
	self._running = false
	self._session = 0
	self._open = at(false)
	self._track = at(nil :: DisplayTrack?)
	self._lyrics = at(nil :: { lyricsSource.LyricLine }?)
	self._paused = at(true)
	self._playback = {
		elapsed = 0,
		duration = 0,
		at = 0,
		paused = true,
	} :: PlaybackState
	self._lyricsFor = nil :: string?
	self._lastRaw = -1
	self._provider = PROVIDERS["YouTube Music"]

	musicHudApi.Attach(self)

	local enableToggle = link:Toggle("musicHud", "Music HUD", false)
	enableToggle:SetBindable(false)
	enableToggle:SetTip({
		title = "Music HUD",
		body = "Shows the song you are playing in YouTube Music or Spotify with its cover art, playback progress and live synced lyrics. YouTube Music requires the desktop app with its API server enabled, Spotify requires linking your account in the options. While the menu is open, drag it to move it and right-click it to reset its position.",
	})
	local rootLink = link:OnKey("musicHud")

	rootLink:Submenu("opts", "Music HUD")
	local optionsLink = rootLink:OnKey("opts")

	optionsLink:Options("general", "General")
	local generalLink = optionsLink:OnKey("general")

	generalLink:Dropdown("provider", "Provider", { "YouTube Music", "Spotify" }, "YouTube Music"):SetTip({
		title = "Provider",
		body = "Music player your playback is read from.",
	})

	local hideWhenPaused = generalLink:Toggle("hideWhenPaused", "Hide When Paused", false):SetTip({
		title = "Hide When Paused",
		body = "Fades the HUD out while playback is paused.",
	})
	hideWhenPaused:SetBindable(false)
	local showLyrics = generalLink:Toggle("showLyrics", "Show Lyrics", true):SetTip({
		title = "Show Lyrics",
		body = "Shows the current lyric line under the song card when synced lyrics are available for the track.",
	})
	showLyrics:SetBindable(false)

	optionsLink:Options("spotify", "Spotify")
	local spotifyLink = optionsLink:OnKey("spotify")

	local spotifyClientId: any
	local spotifyClientSecret: any
	local spotifyStage = at(0)

	local function updateSpotifyStage(): ()
		if spotify.IsLinked() then
			spotifyStage(2)
			return
		end
		local id = spotifyClientId and spotifyClientId:Peek()
		local secret = spotifyClientSecret and spotifyClientSecret:Peek()
		if type(id) == "string" and id ~= "" and type(secret) == "string" and secret ~= "" then
			spotifyStage(1)
		else
			spotifyStage(0)
		end
	end

	local function copyLoginLink(): ()
		local id = spotifyClientId:Peek()
		local secret = spotifyClientSecret:Peek()
		if type(id) ~= "string" or id == "" or type(secret) ~= "string" or secret == "" then
			NotifyController.Push({
				title = "Spotify setup",
				subtext = "Enter your client id and secret first",
				icon = "x",
				duration = 3,
			})
			return
		end
		spotify.SetCredentials(id, secret)
		updateSpotifyStage()
		setclipboard(spotify.GetAuthUrl() :: string)
		NotifyController.Push({
			title = "Login link copied",
			subtext = "Open it in your browser",
			icon = "copy_link",
			duration = 3,
		})
	end

	spotifyLink:Guide("Spotify Setup", {
		stage = spotifyStage,
		badge = { doneText = "Linked", pendingText = "Not Linked", doneAt = 2 },
		steps = {
			{
				title = "Create a Spotify app",
				body = "Open the Spotify developer dashboard in your browser, log in and create a new app.",
				doneAt = 1,
				action = {
					label = "Copy Dashboard Link",
					icon = FileController.Get("image", "copy_link") :: string,
					onClick = function(): ()
						setclipboard("https://developer.spotify.com/dashboard")
						NotifyController.Push({
							title = "Dashboard link copied",
							subtext = "Open it in your browser",
							icon = "copy_link",
							duration = 3,
						})
					end,
				},
			},
			{
				title = "Fill in the app details",
				body = "In the app's settings, add the copied address as a redirect URI, then paste its Client ID and Client Secret into the boxes below.",
				doneAt = 1,
				action = {
					label = "Copy Redirect URI",
					icon = FileController.Get("image", "copy_link") :: string,
					onClick = function(): ()
						setclipboard(spotify.GetRedirectUri())
						NotifyController.Push({
							title = "Redirect URI copied",
							subtext = "Add it to your app's settings",
							icon = "copy_link",
							duration = 3,
						})
					end,
				},
			},
			{
				title = "Approve access",
				body = "Copy the login link, open it in your browser and allow access to your account.",
				doneAt = 2,
				action = {
					label = "Copy Login Link",
					icon = FileController.Get("image", "copy_link") :: string,
					onClick = copyLoginLink,
				},
			},
			{
				title = "Paste the response",
				body = "Your browser ends on a page that fails to load. Copy that page's full address and paste it into the Login Response box below.",
				doneAt = 2,
			},
		},
	})

	spotifyClientId = spotifyLink:Textbox("clientId", "Client ID", "", "Client ID"):SetTip({
		title = "Client ID",
		body = "Client ID of your Spotify app, shown in its dashboard settings.",
	})
	spotifyClientSecret = spotifyLink:Textbox("clientSecret", "Client Secret", "", "Client Secret"):SetTip({
		title = "Client Secret",
		body = "Client secret of your Spotify app, shown in its dashboard settings.",
	})
	local spotifyResponse =
		spotifyLink:Textbox("loginResponse", "Login Response", "", "Paste the redirected url"):SetTip({
			title = "Login Response",
			body = "After approving access, your browser lands on an unreachable 127.0.0.1 page. Copy that page's full url from the address bar and paste it here to finish linking.",
		})

	self:Track(spotifyClientId:OnChange(updateSpotifyStage))
	self:Track(spotifyClientSecret:OnChange(updateSpotifyStage))

	spotifyResponse:OnChange(function(value: any): ()
		if type(value) ~= "string" or value == "" then
			return
		end
		task.spawn(function(): ()
			local id = spotifyClientId:Peek()
			local secret = spotifyClientSecret:Peek()
			if type(id) == "string" and id ~= "" and type(secret) == "string" and secret ~= "" then
				spotify.SetCredentials(id, secret)
			end
			local ok, reason = spotify.SubmitRedirect(value)
			if ok then
				NotifyController.Push({
					title = "Spotify linked",
					subtext = "Your account is connected",
					icon = "checkmark",
					duration = 3,
				})
			else
				NotifyController.Push({
					title = "Spotify login failed",
					subtext = tostring(reason),
					icon = "x",
					duration = 4,
				})
			end
			updateSpotifyStage()
			spotifyResponse:SetValue("")
		end)
	end)

	updateSpotifyStage()

	optionsLink:Options("colors", "Colors")
	local colorsLink = optionsLink:OnKey("colors")

	local customColors = colorsLink:Toggle("customColors", "Custom Colors", false):SetTip({
		title = "Custom Colors",
		body = "Overrides the theme with the colors below.",
	})
	customColors:SetBindable(false)
	local accentColor = colorsLink:Colorpicker("accent", "Accent", DEFAULT_ACCENT, 0):SetTip({
		title = "Accent",
		body = "Color of the progress bar and playing indicator.",
	})
	local backgroundColor = colorsLink:Colorpicker("background", "Background", Color3.fromRGB(30, 30, 30), 0.2)
	local strokeColor = colorsLink:Colorpicker("stroke", "Stroke", Color3.fromRGB(33, 33, 33), 0.5)
	local titleColor = colorsLink:Colorpicker("title", "Title", Color3.fromRGB(229, 229, 229), 0)
	local textColor = colorsLink:Colorpicker("text", "Text", Color3.fromRGB(115, 115, 115), 0)
	local lyricColor = colorsLink:Colorpicker("lyric", "Lyrics", Color3.fromRGB(229, 229, 229), 0)
	local trackColor = colorsLink:Colorpicker("track", "Progress Track", Color3.fromRGB(42, 42, 42), 0)

	local position = rootLink:Value("position", DEFAULT_POSITION)

	self._showLyricsEl = showLyrics
	self._hideWhenPausedEl = hideWhenPaused
	self._accentEl = accentColor
	self._customColorsEl = customColors
	self._bgEl = backgroundColor
	self._strokeEl = strokeColor
	self._titleEl = titleColor
	self._textEl = textColor
	self._lyricEl = lyricColor
	self._trackEl = trackColor
	self._position = position

	self:Track(generalLink:Get("provider"):OnChange(function(value: string): ()
		self:_setProvider(value)
	end))
	self:_setProvider(generalLink:Peek("provider"))

	self:Track(musicHudApi.signals.onSourceChanged:Connect(function(): ()
		self:_resetPlayback()
	end))
	self:Track(musicHudApi.signals.onLyricsChanged:Connect(function(): ()
		self._lyricsFor = nil
	end))

	self:Track(link:Get("musicHud"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("musicHud") then
		self:Enable()
	end

	return self
end

function MusicHud._ensureMounted(self: MusicHud): ()
	if self._mounted then
		return
	end
	self._mounted = true
	AppController.Render(e(musicHudView, {
		open = self._open,
		track = self._track,
		lyrics = self._lyrics,
		paused = self._paused,
		playback = self._playback,
		position = self._position,
		resetPosition = DEFAULT_POSITION,
		showLyricsEl = self._showLyricsEl,
		hideWhenPausedEl = self._hideWhenPausedEl,
		accentEl = self._accentEl,
		customColorsEl = self._customColorsEl,
		bgEl = self._bgEl,
		strokeEl = self._strokeEl,
		titleEl = self._titleEl,
		textEl = self._textEl,
		lyricEl = self._lyricEl,
		trackEl = self._trackEl,
	}))
end

function MusicHud._source(self: MusicHud): Provider
	return (musicHudApi.GetSourceOverride() :: any) or self._provider
end

function MusicHud._resetPlayback(self: MusicHud): ()
	self:_source().reset()
	self._lastRaw = -1
	self._lyricsFor = nil
	if peek(self._track) then
		self._track(nil)
		self._lyrics(nil)
		musicHudApi.NotifyTrack(nil)
	end
end

function MusicHud._setProvider(self: MusicHud, name: string): ()
	local provider = PROVIDERS[name] or PROVIDERS["YouTube Music"]
	if self._provider == provider then
		return
	end
	self._provider = provider
	self:_resetPlayback()
end

function MusicHud._poll(self: MusicHud): ()
	local track, playback = self:_source().poll()
	if not track or not playback then
		if peek(self._track) then
			self._track(nil)
			self._lyrics(nil)
			self._lyricsFor = nil
			musicHudApi.NotifyTrack(nil)
		end
		return
	end

	local trackChanged = false
	local current = peek(self._track)
	if not current or current.id ~= track.id then
		trackChanged = true
		local stored = table.clone(track) :: DisplayTrack
		stored.coverImage = track.coverUrl and FileController.ResolveImage(track.coverUrl, COVER_CACHE) or nil
		self._track(stored)
		self._lyrics(nil)
		self._lyricsFor = nil
		musicHudApi.NotifyTrack(stored)
	end

	local pb = self._playback
	local now = os.clock()
	local raw = playback.elapsed
	local predicted = pb.elapsed
	if not pb.paused then
		predicted += now - pb.at
	end
	if trackChanged or playback.paused ~= pb.paused or math.abs(raw - predicted) > SEEK_THRESHOLD then
		pb.elapsed = raw
		pb.at = now
	elseif raw ~= self._lastRaw then
		pb.elapsed = math.clamp(predicted, raw, raw + 0.75)
		pb.at = now
	end
	self._lastRaw = raw
	pb.duration = track.duration
	pb.paused = playback.paused
	if peek(self._paused) ~= playback.paused then
		self._paused(playback.paused)
		musicHudApi.NotifyPaused(playback.paused)
	end

	if self._lyricsFor ~= track.id and peek(self._showLyricsEl._state) then
		self._lyricsFor = track.id
		local lines = musicHudApi.ResolveLyrics(track)
			or lyricsSource.fetch(track.title, track.artist, track.album, track.duration)
		if self._running and self._lyricsFor == track.id then
			self._lyrics(lines)
		end
	end
end

function MusicHud.Enable(self: MusicHud): ()
	self:_ensureMounted()
	self._open(true)
	if self._running then
		return
	end
	self._running = true
	self._session += 1
	local session = self._session
	self:_source().reset()
	task.spawn(function(): ()
		while self._running and self._session == session do
			self:_poll()
			task.wait(self:_source().interval)
		end
	end)
end

function MusicHud.Disable(self: MusicHud): ()
	self._running = false
	self._open(false)
end

export type MusicHud =
	typeof(setmetatable(
		{} :: {
			_mounted: boolean,
			_running: boolean,
			_session: number,
			_open: Charm.Atom<boolean>,
			_track: Charm.Atom<DisplayTrack?>,
			_lyrics: Charm.Atom<{ lyricsSource.LyricLine }?>,
			_paused: Charm.Atom<boolean>,
			_playback: PlaybackState,
			_lyricsFor: string?,
			_lastRaw: number,
			_provider: Provider,
			_showLyricsEl: any,
			_hideWhenPausedEl: any,
			_accentEl: any,
			_customColorsEl: any,
			_bgEl: any,
			_strokeEl: any,
			_titleEl: any,
			_textEl: any,
			_lyricEl: any,
			_trackEl: any,
			_position: any,
		},
		MusicHud
	))
	& BaseFeature.BaseFeature

return MusicHud
