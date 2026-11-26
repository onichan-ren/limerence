local Players = cloneref(game:GetService("Players")) :: Players
local TeleportService = cloneref(game:GetService("TeleportService")) :: TeleportService

local NetworkController = require("@game/pf/network/NetworkController")
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
		body = "Automatically reconnects you to another server when a vote kick is started against you.",
	})

	self._enabled = false
	self._unhook = nil :: (() -> ())?
	self._hopping = false

	self:Track(link:Get("serverHopOnKick"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("serverHopOnKick") then
		self:Enable()
	end

	return self
end

function ServerHopOnKick.Enable(self: ServerHopOnKick): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._unhook = NetworkController.HookInbound("startvotekick", function(targetName: string, ...): ()
		if targetName == LocalPlayer.Name or targetName == LocalPlayer.DisplayName then
			self:Hop()
		end
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

	if self._unhook then
		self._unhook()
		self._unhook = nil
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
			_unhook: (() -> ())?,
			_hopping: boolean,
		},
		ServerHopOnKick
	))
	& BaseFeature.BaseFeature

return ServerHopOnKick
