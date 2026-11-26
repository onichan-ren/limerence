local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local NetworkController = require("@game/rivals/network/NetworkController")
local NotifyController = require("@ui/hud/notify/NotifyController")

local LocalPlayer = Players.LocalPlayer

local JOIN_QUEUE_PATH = "Matchmaking.JoinQueue"
local QUEUE_STATUS_PATH = "Matchmaking.UpdateQueueStatus"
local QUEUE_READY_PATH = "Misc.QueueReady"

local GRACE_PERIOD = 5

local function getMatchmakingController(): any?
	local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local controllers = scripts and scripts:FindFirstChild("Controllers")
	local module = controllers and controllers:FindFirstChild("MatchmakingController")
	if not module then
		return nil
	end
	return require(module :: ModuleScript)
end

local function getDuelController(): any?
	local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local controllers = scripts and scripts:FindFirstChild("Controllers")
	local module = controllers and controllers:FindFirstChild("DuelController")
	if not module then
		return nil
	end
	return require(module :: ModuleScript)
end

local function inDuel(): boolean
	local dc = getDuelController()
	if dc and type(dc.GetDuel) == "function" then
		return dc:GetDuel(LocalPlayer) ~= nil
	end
	return LocalPlayer:GetAttribute("TeamID") ~= nil
end

local MODES: { { label: string, name: string } } = {
	{ label = "1v1", name = "1v1" },
	{ label = "2v2", name = "2v2" },
	{ label = "3v3", name = "3v3" },
	{ label = "4v4", name = "4v4" },
	{ label = "5v5", name = "5v5" },
	{ label = "Ranked 1v1", name = "ranked_1v1" },
	{ label = "Ranked 2v2", name = "ranked_2v2" },
	{ label = "Ranked 3v3", name = "ranked_3v3" },
}

local MODE_LABELS: { string } = {}
local MODE_BY_LABEL: { [string]: string } = {}
for _, mode in next, MODES do
	MODE_LABELS[#MODE_LABELS + 1] = mode.label
	MODE_BY_LABEL[mode.label] = mode.name
end

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

	local queueLink = link:OnKey("autoQueue")
	queueLink:Submenu("opts", "Auto Queue")
	local optsLink = queueLink:OnKey("opts")
	optsLink:Dropdown("mode", "Mode", MODE_LABELS, MODE_LABELS[2]):SetTip({
		title = "Mode",
		body = "Which queue to join.",
	})

	self._link = link
	self._enabledLink = link:Get("autoQueue")
	self._janitor = Janitor.new()
	self._queued = false
	self._graceHandle = nil :: {}?
	self._notifId = nil :: string?
	self._mode = MODE_BY_LABEL[optsLink:Peek("mode") or MODE_LABELS[2]] or "2v2"

	self:Track(optsLink:Get("mode"):OnChange(function(v: string): ()
		self._mode = MODE_BY_LABEL[v] or "2v2"
	end))

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
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

function AutoQueue._clearGrace(self: AutoQueue): ()
	self._graceHandle = nil
	if self._notifId then
		NotifyController.Dismiss(self._notifId)
		self._notifId = nil
	end
end

function AutoQueue._sendQueue(self: AutoQueue): ()
	local mm = getMatchmakingController()
	if mm and type(mm.QueueInto) == "function" then
		mm:QueueInto(self._mode)
	else
		NetworkController.InvokeRemote(JOIN_QUEUE_PATH, self._mode)
	end
end

function AutoQueue._onDuelOver(self: AutoQueue): ()
	if not self._enabled then
		return
	end
	if self._requeued then
		return
	end
	self._requeued = true
	self._queued = true
	self:_sendQueue()
end

function AutoQueue._evaluate(self: AutoQueue, immediate: boolean?): ()
	if not self._enabled then
		return
	end

	if inDuel() then
		self:_clearGrace()
		return
	end

	if self._queued or self._graceHandle then
		return
	end

	if immediate then
		self:_sendQueue()
		self._queued = true
		return
	end

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
		if not self._enabled or inDuel() then
			return
		end
		self:_sendQueue()
		self._queued = true
	end)
end

function AutoQueue.Enable(self: AutoQueue): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._queued = false
	self._requeued = false
	self._graceHandle = nil
	self._notifId = nil

	self._janitor:Add(
		LocalPlayer:GetAttributeChangedSignal("TeamID"):Connect(function(): ()
			if not inDuel() then
				self._queued = false
			end
			self:_evaluate(true)
		end),
		"Disconnect"
	)

	self._janitor:Add(
		NetworkController.ConnectRemote(QUEUE_STATUS_PATH, function(): ()
			if not inDuel() then
				NetworkController.SendRemote(QUEUE_READY_PATH)
			end
		end),
		"Disconnect"
	)

	local duelJanitor = Janitor.new()
	self._janitor:Add(duelJanitor, "Destroy")

	local function watchDuel(duel: any): ()
		duelJanitor:Cleanup()
		if type(duel) ~= "table" or type(duel.GetDataChangedSignal) ~= "function" then
			return
		end
		if duel:Get("Status") == "GameOver" then
			self:_onDuelOver()
			return
		end
		duelJanitor:Add(
			duel:GetDataChangedSignal("Status"):Connect(function(): ()
				if duel:Get("Status") == "GameOver" then
					self:_onDuelOver()
				end
			end),
			"Disconnect"
		)
	end

	local dc = getDuelController()
	if dc then
		if dc.LocalPlayerJoinedDuel then
			self._janitor:Add(
				dc.LocalPlayerJoinedDuel:Connect(function(duel: any): ()
					self._requeued = false
					self._queued = true
					watchDuel(duel)
				end),
				"Disconnect"
			)
		end
		if dc.LocalPlayerLeftDuel then
			self._janitor:Add(
				dc.LocalPlayerLeftDuel:Connect(function(): ()
					duelJanitor:Cleanup()
					if self._requeued then
						self._requeued = false
						return
					end
					self._queued = false
					self:_evaluate(true)
				end),
				"Disconnect"
			)
		end
		if type(dc.GetDuel) == "function" then
			local duel = dc:GetDuel(LocalPlayer)
			if duel then
				watchDuel(duel)
			end
		end
	end

	self:_evaluate()
end

function AutoQueue.Disable(self: AutoQueue): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._queued = false
	self:_clearGrace()
	self._janitor:Cleanup()
end

function AutoQueue.Destroy(self: AutoQueue): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoQueue =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabledLink: any,
			_enabled: boolean,
			_mode: string,
			_queued: boolean,
			_requeued: boolean,
			_graceHandle: {}?,
			_notifId: string?,
			_janitor: Janitor.Janitor,
		},
		AutoQueue
	))
	& BaseFeature.BaseFeature

return AutoQueue
