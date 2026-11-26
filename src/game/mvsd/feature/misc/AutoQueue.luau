local Players = cloneref(game:GetService("Players")) :: Players
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local NotifyController = require("@ui/hud/notify/NotifyController")

local LocalPlayer = Players.LocalPlayer

local RETRY_PERIOD = 6

local MODES: { { label: string, mode: string } } = {
	{ label = "1v1", mode = "Solo" },
	{ label = "2v2", mode = "Duo" },
	{ label = "3v3", mode = "Trio" },
	{ label = "4v4", mode = "Squad" },
	{ label = "Beginner", mode = "Beginner" },
}

local MODE_LABELS: { string } = {}
local MODE_BY_LABEL: { [string]: string } = {}
for _, entry in next, MODES do
	MODE_LABELS[#MODE_LABELS + 1] = entry.label
	MODE_BY_LABEL[entry.label] = entry.mode
end

local function getRemotes(): Folder?
	local mm = ReplicatedStorage:FindFirstChild("GlobalMatchmaking")
	local remotes = mm and mm:FindFirstChild("Remotes")
	if remotes and remotes:IsA("Folder") then
		return remotes
	end
	return nil
end

local function inMatch(): boolean
	if Workspace:GetAttribute("IsQueuedMatch") == true then
		return true
	end
	return LocalPlayer:GetAttribute("Match") ~= nil
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

	self._janitor = Janitor.new()
	self._queued = false
	self._sendToken = 0
	self._ignoreDequeue = 0
	self._mode = MODE_BY_LABEL[optsLink:Peek("mode") or MODE_LABELS[2]] or "Duo"

	self:Track(optsLink:Get("mode"):OnChange(function(value: string): ()
		local mode = MODE_BY_LABEL[value] or "Duo"
		if mode == self._mode then
			return
		end
		self._mode = mode
		if not self._enabled then
			return
		end

		if not self:_leaveQueue(true) then
			self:_evaluate()
			return
		end

		task.delay(RETRY_PERIOD, function(): ()
			if self._enabled then
				self:_evaluate()
			end
		end)
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

function AutoQueue._sendQueue(self: AutoQueue): ()
	local remotes = getRemotes()
	local remote = remotes and remotes:FindFirstChild("JoinQueue") :: RemoteFunction?
	if not remote then
		self._queued = false
		return
	end

	self._sendToken += 1
	local token = self._sendToken

	task.spawn(function(): ()
		local success = remote:InvokeServer(self._mode)

		if self._sendToken ~= token or not self._enabled then
			return
		end

		if success then
			NotifyController.Push({
				title = "Auto Queue",
				subtext = `Queued for {self._mode}.`,
				icon = "aim",
				duration = 3,
			})
			return
		end

		self._queued = false
		task.delay(RETRY_PERIOD, function(): ()
			if self._enabled then
				self:_evaluate()
			end
		end)
	end)
end

function AutoQueue._leaveQueue(self: AutoQueue, requeue: boolean?): boolean
	self._sendToken += 1

	if not self._queued then
		return false
	end

	self._queued = false

	local remotes = getRemotes()
	local remote = remotes and remotes:FindFirstChild("LeaveQueue") :: RemoteEvent?
	if not remote then
		return false
	end

	if not requeue then
		self._ignoreDequeue += 1
	end

	remote:FireServer()
	return requeue == true
end

function AutoQueue._evaluate(self: AutoQueue): ()
	if not self._enabled then
		return
	end

	if inMatch() then
		self._queued = false
		return
	end

	if self._queued then
		return
	end

	if not LocalPlayer:GetAttribute("ProfileLoaded") then
		return
	end

	self._queued = true
	self:_sendQueue()
end

function AutoQueue.Enable(self: AutoQueue): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._queued = false
	self._ignoreDequeue = 0

	self._janitor:Add(
		LocalPlayer:GetAttributeChangedSignal("ProfileLoaded"):Connect(function(): ()
			self:_evaluate()
		end),
		"Disconnect"
	)

	self._janitor:Add(
		LocalPlayer:GetAttributeChangedSignal("Match"):Connect(function(): ()
			self:_evaluate()
		end),
		"Disconnect"
	)

	self._janitor:Add(
		Workspace:GetAttributeChangedSignal("IsQueuedMatch"):Connect(function(): ()
			self:_evaluate()
		end),
		"Disconnect"
	)

	local remotes = getRemotes()
	if remotes then
		local dequeued = remotes:FindFirstChild("OnDequeued") :: RemoteEvent?
		if dequeued then
			self._janitor:Add(
				dequeued.OnClientEvent:Connect(function(): ()
					if self._ignoreDequeue > 0 then
						self._ignoreDequeue -= 1
						return
					end
					self._queued = false
					self:_evaluate()
				end),
				"Disconnect"
			)
		end

		local joinError = remotes:FindFirstChild("OnQueueJoinError") :: RemoteEvent?
		if joinError then
			self._janitor:Add(
				joinError.OnClientEvent:Connect(function(): ()
					self._queued = false
					task.delay(RETRY_PERIOD, function(): ()
						if self._enabled then
							self:_evaluate()
						end
					end)
				end),
				"Disconnect"
			)
		end
	end

	self:_evaluate()
end

function AutoQueue.Disable(self: AutoQueue): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self:_leaveQueue()
	self._ignoreDequeue = 0
	self._janitor:Cleanup()
end

function AutoQueue.Destroy(self: AutoQueue): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoQueue =
	typeof(setmetatable(
		{} :: {
			_janitor: Janitor.Janitor,
			_enabled: boolean,
			_queued: boolean,
			_sendToken: number,
			_ignoreDequeue: number,
			_mode: string,
			_evaluate: (AutoQueue) -> (),
			_sendQueue: (AutoQueue) -> (),
			_leaveQueue: (AutoQueue, boolean?) -> boolean,
		},
		AutoQueue
	))
	& BaseFeature.BaseFeature

return AutoQueue
