local Players = cloneref(game:GetService("Players")) :: Players
local TeleportService = cloneref(game:GetService("TeleportService")) :: TeleportService

local NetworkController = require("@game/bloxstrike/network/NetworkController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local serverDataSource = require("@feature/server/module/serverDataSource")
local NotifyController = require("@ui/hud/notify/NotifyController")

local LocalPlayer = Players.LocalPlayer

local ServerHopOnKick = {}
ServerHopOnKick.__index = ServerHopOnKick

setmetatable(ServerHopOnKick, { __index = BaseFeature })

function ServerHopOnKick.new(link: gameUi.Linker): ServerHopOnKick
	local self = BaseFeature.new() :: any
	setmetatable(self, ServerHopOnKick)

	link:Toggle("serverHopOnKick", "Server Hop On Kick", false):SetTip({
		title = "Server Hop On Kick",
		body = "Automatically reconnects you to another server when a vote kick against you gets 2 yes votes.",
	})

	self._enabled = false
	self._disconnects = {} :: { () -> () }
	self._hopping = false
	self._voteActive = false

	self:Track(link:Get("serverHopOnKick"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	return self
end

function ServerHopOnKick.Enable(self: ServerHopOnKick): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local disconnects = self._disconnects

	local startVote = NetworkController.GetPacket("VoteKick", "StartVote")
	disconnects[#disconnects + 1] = startVote.Listen(function(payload)
		self._voteActive = tonumber(payload.TargetUserId) == LocalPlayer.UserId
	end)

	local voteYesUpdate = NetworkController.GetPacket("VoteKick", "VoteYesUpdate")
	disconnects[#disconnects + 1] = voteYesUpdate.Listen(function(payload)
		if not self._voteActive then
			return
		end
		if (tonumber(payload.Amount) or 0) >= 2 then
			self:Hop()
		end
	end)

	local endVote = NetworkController.GetPacket("VoteKick", "EndVote")
	disconnects[#disconnects + 1] = endVote.Listen(function()
		self._voteActive = false
	end)
end

function ServerHopOnKick.Hop(self: ServerHopOnKick): ()
	if self._hopping then
		return
	end
	self._hopping = true

	NotifyController.Push({
		title = "Server Hop On Kick",
		subtext = "Finding a new server...",
		icon = "server",
		duration = 3,
	})

	task.spawn(function()
		local target = serverDataSource.findHopTarget(game.PlaceId, game.JobId)
		if target and target.id then
			local ok = pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, tostring(target.id), LocalPlayer)
			end)
			if ok then
				return
			end
		end
		pcall(function()
			TeleportService:Teleport(game.PlaceId, LocalPlayer)
		end)
	end)
end

function ServerHopOnKick.Disable(self: ServerHopOnKick): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._voteActive = false
	for i, disconnect in next, self._disconnects do
		disconnect()
		self._disconnects[i] = nil
	end
end

function ServerHopOnKick.Destroy(self: ServerHopOnKick): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ServerHopOnKick =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_disconnects: { () -> () },
			_hopping: boolean,
			_voteActive: boolean,
		},
		ServerHopOnKick
	))
	& BaseFeature.BaseFeature

return ServerHopOnKick
