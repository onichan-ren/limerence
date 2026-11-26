local RunService = cloneref(game:GetService("RunService")) :: RunService
local Players = cloneref(game:GetService("Players")) :: Players
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local NetworkController = require("@game/bloxstrike/network/NetworkController")
local clientState = require("@game/bloxstrike/client/clientState")
local bombState = require("@game/bloxstrike/bomb/bombState")
local gameUi = require("@game/gameUi")

local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer

local RESEND_INTERVAL = 0.75
local MAX_DISTANCE = 12
local DEFUSE_TIME_KIT = 5
local DEFUSE_TIME_NO_KIT = 10
local FINISH_MARGIN = 0.05

local function sendPacket(name: string, payload: any?): ()
	setthreadidentity(2)
	NetworkController.SendPacket("C4", name, payload)
	setthreadidentity(8)
end

local AutoDefuse = {}
AutoDefuse.__index = AutoDefuse

setmetatable(AutoDefuse, { __index = BaseFeature })

function AutoDefuse.new(link: gameUi.Linker): AutoDefuse
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoDefuse)

	link:Toggle("autoDefuse", "Auto Defuse", false):SetTip({
		title = "Auto Defuse",
		body = "Starts defusing the bomb on your own the moment it is planted.",
	})

	self._enabled = false
	self._janitor = Janitor.new()
	self._sessionId = 0
	self._lastStart = 0
	self._sentDefused = false

	self:Track(link:Get("autoDefuse"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	return self
end

AutoDefuse._tick = LPH_NO_VIRTUALIZE(function(self: AutoDefuse): ()
	local bomb = peek(bombState.bomb)
	if not bomb then
		self._lastStart = 0
		self._sentDefused = false
		return
	end
	if bomb.isDefused or bomb.isExploded then
		return
	end
	if peek(clientState.team) ~= "Counter-Terrorists" or not peek(clientState.alive) then
		return
	end

	local model = bomb.model
	local prim = model and model.PrimaryPart
	local hrp = peek(clientState.parts).HumanoidRootPart :: BasePart?
	if not prim or not hrp or (prim.Position - hrp.Position).Magnitude > MAX_DISTANCE then
		return
	end

	if peek(clientState.isDefusing) then
		if self._sentDefused then
			return
		end
		local startTime = tonumber(LocalPlayer:GetAttribute("DefuseStartTime"))
		if not startTime then
			return
		end
		local hasKit = LocalPlayer:GetAttribute("HasDefuseKit") == true
		local defuseTime = hasKit and DEFUSE_TIME_KIT or DEFUSE_TIME_NO_KIT
		if Workspace:GetServerTimeNow() - startTime >= defuseTime + FINISH_MARGIN then
			self._sentDefused = true
			sendPacket("Defused")
		end
		return
	end

	local now = os.clock()
	if now - self._lastStart < RESEND_INTERVAL then
		return
	end
	self._lastStart = now
	self._sentDefused = false
	self._sessionId += 1
	sendPacket("StartDefuse", { SessionId = self._sessionId })
end)

function AutoDefuse.Enable(self: AutoDefuse): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._lastStart = 0
	self._sentDefused = false

	self._janitor:Add(
		RunService.Heartbeat:Connect(function(): ()
			self:_tick()
		end),
		"Disconnect"
	)
end

function AutoDefuse.Disable(self: AutoDefuse): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function AutoDefuse.Destroy(self: AutoDefuse): ()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type AutoDefuse =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_sessionId: number,
			_lastStart: number,
			_sentDefused: boolean,
		},
		AutoDefuse
	))
	& BaseFeature.BaseFeature

return AutoDefuse
