local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local NetworkController = require("@game/overkill/network/NetworkController")
local ModuleController = require("@game/overkill/module/ModuleController")
local NotifyController = require("@ui/hud/notify/NotifyController")

local LocalPlayer = Players.LocalPlayer

local MODES: { string } = { "1v1", "2v2", "3v3", "4v4", "5v5" }
local SEARCH_TIMEOUT = 12
local REQUEUE_DELAY = 3
local BACKOFF_DELAY = 8
local GRACE_PERIOD = 5
local LEAVE_DELAY = 2

local AutoQueue = {}
AutoQueue.__index = AutoQueue

setmetatable(AutoQueue, { __index = BaseFeature })

function AutoQueue.new(link: gameUi.Linker): AutoQueue
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoQueue)

	link:Toggle("autoQueue", "Auto Queue", false):SetTip({
		title = "Auto Queue",
		body = "Joins the selected matchmaking queue and re-queues after each match.",
	})

	local optsLink = link:OnKey("autoQueue")
	optsLink:Dropdown("mode", "Gamemode", MODES, MODES[1])

	self._enabled = false
	self._mode = optsLink:Peek("mode") or MODES[1]
	self._searching = false
	self._searchDeadline = 0
	self._nextAllowed = 0
	self._accum = 0
	self._conn = nil
	self._unhook = nil
	self._graceHandle = nil
	self._notifId = nil
	self._gameplayHandler = nil
	self._leftDuelId = nil
	self._leaveArmed = nil
	self._leaveAt = 0

	self:Track(optsLink:Get("mode"):OnChange(function(value: string): ()
		self._mode = value or MODES[1]
	end))

	self:Track(link:Get("autoQueue"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("autoQueue") then
		self:Enable()
	end

	return self
end

function AutoQueue._onState(self: AutoQueue, payload: any): ()
	local status = type(payload) == "table" and payload.status or payload
	if status == "SEARCHING" or status == "PENDING_START" then
		self._searching = true
		self._searchDeadline = os.clock() + SEARCH_TIMEOUT
	elseif status == "MATCHED" then
		self._searching = false
	elseif status == "RATE_LIMITED" or status == "PARTY_TOO_LARGE" then
		self._searching = false
		self._nextAllowed = os.clock() + BACKOFF_DELAY
	else
		self._searching = false
		self._nextAllowed = os.clock() + REQUEUE_DELAY
	end
end

function AutoQueue._maybeLeaveEnded(self: AutoQueue): ()
	local gameplayHandler = self._gameplayHandler
	if not gameplayHandler then
		return
	end

	local duel, duelId = gameplayHandler:GetLocalDuel()
	if type(duel) ~= "table" then
		self._leftDuelId = nil
		self._leaveArmed = nil
		return
	end
	if not duel.ended then
		self._leaveArmed = nil
		return
	end
	if self._leftDuelId == duelId then
		return
	end

	if self._leaveArmed ~= duelId then
		self._leaveArmed = duelId
		self._leaveAt = os.clock() + LEAVE_DELAY
		return
	end
	if os.clock() < self._leaveAt then
		return
	end

	self._leftDuelId = duelId
	self._leaveArmed = nil
	setthreadidentity(2)
	NetworkController.Fire("leave_duel")
	setthreadidentity(8)
end

function AutoQueue._inMatch(self: AutoQueue): boolean
	local gameplayHandler = self._gameplayHandler
	if gameplayHandler then
		local duel = gameplayHandler:GetLocalDuel()
		if duel ~= nil then
			return true
		end
	end
	return LocalPlayer:GetAttribute("MatchmakingOpen") == false
end

function AutoQueue._clearGrace(self: AutoQueue): ()
	self._graceHandle = nil
	if self._notifId then
		NotifyController.Dismiss(self._notifId)
		self._notifId = nil
	end
end

function AutoQueue._sendQueue(self: AutoQueue): ()
	self._nextAllowed = os.clock() + SEARCH_TIMEOUT
	setthreadidentity(2)
	NetworkController.Fire("matchmaking_queue", self._mode)
	setthreadidentity(8)
end

function AutoQueue._armGrace(self: AutoQueue): ()
	local token = {}
	self._graceHandle = token
	self._notifId = NotifyController.Push({
		title = "Auto Queue",
		subtext = `Queuing in {GRACE_PERIOD}s...`,
		icon = "aim",
		duration = GRACE_PERIOD,
		timer = true,
	})

	task.delay(GRACE_PERIOD, function(): ()
		if self._graceHandle ~= token then
			return
		end
		self._graceHandle = nil
		self._notifId = nil
		if not self._enabled or self._searching then
			return
		end
		if self:_inMatch() then
			return
		end
		self:_sendQueue()
	end)
end

function AutoQueue._tick(self: AutoQueue): ()
	self:_maybeLeaveEnded()

	if self:_inMatch() then
		self:_clearGrace()
		return
	end

	local now = os.clock()
	if self._searching then
		if now >= self._searchDeadline then
			self._searching = false
			self._nextAllowed = now + REQUEUE_DELAY
		end
		return
	end

	if self._graceHandle then
		return
	end

	if now < self._nextAllowed then
		return
	end

	self:_armGrace()
end

function AutoQueue.Enable(self: AutoQueue): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._searching = false
	self._nextAllowed = 0
	self._accum = 0
	self._graceHandle = nil
	self._notifId = nil
	self._leftDuelId = nil
	self._leaveArmed = nil
	self._leaveAt = 0
	self._gameplayHandler = ModuleController.GetModule("gameplayHandler")

	self._unhook = NetworkController.HookInbound("matchmaking_state", function(payload: any): ()
		self:_onState(payload)
	end)

	self._conn = RunService.Heartbeat:Connect(function(dt: number): ()
		self._accum += dt
		if self._accum < 1 then
			return
		end
		self._accum = 0
		self:_tick()
	end)
end

function AutoQueue.Disable(self: AutoQueue): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self:_clearGrace()

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	if self._unhook then
		self._unhook()
		self._unhook = nil
	end

	if self._searching then
		setthreadidentity(2)
		NetworkController.Fire("matchmaking_cancel")
		setthreadidentity(8)
	end
	self._searching = false
end

function AutoQueue.Destroy(self: AutoQueue): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoQueue = typeof(setmetatable(
	{} :: {
		_enabled: boolean,
		_mode: string,
		_searching: boolean,
		_searchDeadline: number,
		_nextAllowed: number,
		_accum: number,
		_conn: any,
		_unhook: (() -> ())?,
		_graceHandle: {}?,
		_notifId: string?,
		_gameplayHandler: any,
		_leftDuelId: any,
		_leaveArmed: any,
		_leaveAt: number,
	},
	AutoQueue
)) & BaseFeature.BaseFeature

return AutoQueue
