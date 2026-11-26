local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ClientState = require("@game/mvsd/client/clientState")
local spectatorsState = require("@ui/hud/spectators/spectatorsState")
local stateConverter = require("@feature/config/module/stateConverter")

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

local POSITION_EXTENSION = "limerence.mvsdSpectators"
local ATTRIBUTE = "SpectateMatchId"

local SpectatorList = {}
SpectatorList.__index = SpectatorList

setmetatable(SpectatorList, { __index = BaseFeature })

function SpectatorList.new(link: gameUi.Linker): SpectatorList
	local self = BaseFeature.new() :: any
	setmetatable(self, SpectatorList)

	self._watchJanitor = nil :: Janitor.Janitor?
	self._recomputeToken = 0

	stateConverter.RegisterExtension(POSITION_EXTENSION, function(): any
		local position = peek(spectatorsState.position)
		return {
			position = {
				xs = position.X.Scale,
				xo = position.X.Offset,
				ys = position.Y.Scale,
				yo = position.Y.Offset,
			},
		}
	end, function(data: any): ()
		if type(data) ~= "table" then
			return
		end
		local position = data.position
		if type(position) ~= "table" then
			return
		end
		spectatorsState.position(
			UDim2.new(
				tonumber(position.xs) or 0,
				tonumber(position.xo) or 0,
				tonumber(position.ys) or 0,
				tonumber(position.yo) or 0
			)
		)
	end)

	link:Toggle("spectatorList", "Spectator List", false):SetTip({
		title = "Spectator List",
		body = "HUD widget showing how many players are currently spectating you.",
	})
	local listLink = link:OnKey("spectatorList")
	listLink:Submenu("opts", "Spectator List Options")
	local optsLink = listLink:OnKey("opts")
	optsLink:Toggle("hideWhenEmpty", "Hide When Empty", true):SetTip({
		title = "Hide When Empty",
		body = "Hide the widget when nobody is spectating.",
	})

	local enabledLink = link:Get("spectatorList")

	self:Track(enabledLink:OnChange(function(value: boolean): ()
		spectatorsState.enabled(value)
		if value then
			self:StartWatch()
		else
			self:StopWatch()
		end
	end))
	spectatorsState.enabled(enabledLink:Peek() == true)

	self:Track(link:Get("spectatorList.opts.hideWhenEmpty"):OnChange(function(value: boolean): ()
		spectatorsState.hideWhenEmpty(value)
	end))
	spectatorsState.hideWhenEmpty(link:Peek("spectatorList.opts.hideWhenEmpty") :: boolean)

	if enabledLink:Peek() == true then
		self:StartWatch()
	end

	return self
end

function SpectatorList.Recompute(self: SpectatorList): ()
	local matchId = peek(ClientState.matchId)
	if matchId == nil then
		ClientState.spectatorCount(0)
		return
	end

	local count = 0
	for _, player in next, Players:GetPlayers() do
		if player ~= LocalPlayer and player:GetAttribute(ATTRIBUTE) == matchId then
			count += 1
		end
	end

	ClientState.spectatorCount(count)
end

function SpectatorList.QueueRecompute(self: SpectatorList): ()
	self._recomputeToken += 1
	local token = self._recomputeToken
	task.defer(function(): ()
		if token == self._recomputeToken and self._watchJanitor then
			self:Recompute()
		end
	end)
end

function SpectatorList.WatchPlayer(self: SpectatorList, player: Player): ()
	local janitor = self._watchJanitor
	if not janitor or player == LocalPlayer then
		return
	end

	janitor:Add(player:GetAttributeChangedSignal(ATTRIBUTE):Connect(function(): ()
		self:QueueRecompute()
	end), "Disconnect", player)
end

function SpectatorList.StartWatch(self: SpectatorList): ()
	if self._watchJanitor then
		return
	end

	local janitor = Janitor.new()
	self._watchJanitor = janitor

	janitor:Add(Players.PlayerAdded:Connect(function(player: Player): ()
		self:WatchPlayer(player)
		self:QueueRecompute()
	end), "Disconnect")

	janitor:Add(Players.PlayerRemoving:Connect(function(player: Player): ()
		janitor:Remove(player)
		self:QueueRecompute()
	end), "Disconnect")

	janitor:Add(sub(ClientState.matchId, function(): ()
		self:QueueRecompute()
	end), true)

	for _, player in next, Players:GetPlayers() do
		self:WatchPlayer(player)
	end

	self:Recompute()
end

function SpectatorList.StopWatch(self: SpectatorList): ()
	local janitor = self._watchJanitor
	if janitor then
		janitor:Destroy()
		self._watchJanitor = nil
	end
	self._recomputeToken += 1
	ClientState.spectatorCount(0)
end

function SpectatorList.Destroy(self: SpectatorList): ()
	stateConverter.UnregisterExtension(POSITION_EXTENSION)
	self:StopWatch()
	spectatorsState.enabled(false)
	BaseFeature.Destroy(self)
end

export type SpectatorList =
	typeof(setmetatable(
		{} :: {
			_watchJanitor: Janitor.Janitor?,
			_recomputeToken: number,
		},
		SpectatorList
	))
	& BaseFeature.BaseFeature

return SpectatorList
