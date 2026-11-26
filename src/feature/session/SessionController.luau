local MarketplaceService = cloneref(game:GetService("MarketplaceService")) :: MarketplaceService
local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService
local DataPing = cloneref((game:GetService("Stats") :: any).Network.ServerStatsItem["Data Ping"])

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local sessionState = require("@feature/session/sessionState")
local displayUsername = require("@feature/session/displayUsername")
local UserController = require("@feature/config/UserController")

local LocalPlayer = Players.LocalPlayer

local peek = Charm.peek

local SLOW_POLL_INTERVAL = 0.75
local PLAYTIME_INTERVAL = 1
local FPS_SAMPLE_WINDOW = 15

local SessionController = {
	_janitor = nil :: Janitor.Janitor?,
	_samples = {} :: { number },
	_sampleIndex = 0,
	_sampleCount = 0,
	_slowAccum = 0,
	_playAccum = 0,
	_sessionStart = 0,
	state = sessionState,
}

local function computeBuild(): string
	local scriptName = LP_SCRIPT_NAME :: any
	if scriptName == nil or scriptName == "" then
		return "Dev"
	end
	if string.find(scriptName, "Nightly", 1, true) then
		return "Nightly"
	end
	return "Public"
end

local function fetchGameName(): string
	local ok, result = pcall(function()
		return MarketplaceService:GetProductInfoAsync(game.PlaceId).Name
	end)
	return ok and typeof(result) == "string" and result or "Unknown"
end

local function fetchPing(): number
	return math.floor(DataPing.GetValue(DataPing))
end

local computeFps = LPH_NO_VIRTUALIZE(function(): number
	local count = SessionController._sampleCount
	if count == 0 then
		return 0
	end
	local sum = 0
	for _, dt in next, SessionController._samples do
		sum += dt
	end
	if sum <= 0 then
		return 0
	end
	return math.floor(count / sum + 0.5)
end)

local function set<T>(atom: Charm.Atom<T>, value: T): ()
	if peek(atom) ~= value then
		atom(value)
	end
end

local function refreshSlow(): ()
	set(sessionState.fps, computeFps())
	set(sessionState.ping, fetchPing())
end

local function refreshPlayTime(): ()
	set(sessionState.playTime, os.time() - SessionController._sessionStart)
end

local onHeartbeat = LPH_NO_VIRTUALIZE(function(dt: number): ()
	local idx = SessionController._sampleIndex % FPS_SAMPLE_WINDOW + 1
	SessionController._samples[idx] = dt
	SessionController._sampleIndex = idx
	if SessionController._sampleCount < FPS_SAMPLE_WINDOW then
		SessionController._sampleCount += 1
	end

	SessionController._slowAccum += dt
	if SessionController._slowAccum >= SLOW_POLL_INTERVAL then
		SessionController._slowAccum = 0
		refreshSlow()
	end

	SessionController._playAccum += dt
	if SessionController._playAccum >= PLAYTIME_INTERVAL then
		SessionController._playAccum = 0
		refreshPlayTime()
	end
end)

function SessionController.new(): SessionController
	local janitor = Janitor.new()
	SessionController._janitor = janitor
	SessionController._samples = {}
	SessionController._sampleIndex = 0
	SessionController._sampleCount = 0
	SessionController._slowAccum = 0
	SessionController._playAccum = 0
	SessionController._sessionStart = os.time()

	task.spawn(function()
		sessionState.gameName(fetchGameName())
	end)
	sessionState.playTime(0)
	displayUsername.apply(
		displayUsername.normalizeMode(UserController.GetUsernameDisplayMode()),
		UserController.GetUsernameCustom()
	)
	sessionState.cheat("Limerence")
	sessionState.build(computeBuild())

	refreshSlow()
	refreshPlayTime()
	janitor:Add(RunService.Heartbeat:Connect(onHeartbeat), "Disconnect")

	return SessionController
end

function SessionController.GetUsername(): string
	return peek(sessionState.username)
end

function SessionController.GetCheat(): string
	return peek(sessionState.cheat)
end

function SessionController.SetCheat(name: string): ()
	set(sessionState.cheat, name)
end

function SessionController.GetGameName(): string
	return peek(sessionState.gameName)
end

function SessionController.GetPing(): number
	return peek(sessionState.ping)
end

function SessionController.GetFps(): number
	return peek(sessionState.fps)
end

function SessionController.GetPlayTime(): number
	return peek(sessionState.playTime)
end

function SessionController.Destroy(): ()
	local janitor = SessionController._janitor
	if janitor then
		janitor:Destroy()
		SessionController._janitor = nil
	end
	SessionController._samples = {}
	SessionController._sampleIndex = 0
	SessionController._sampleCount = 0
	SessionController._slowAccum = 0
	SessionController._playAccum = 0
	SessionController._sessionStart = 0
end

export type SessionController = typeof(SessionController)

return SessionController
