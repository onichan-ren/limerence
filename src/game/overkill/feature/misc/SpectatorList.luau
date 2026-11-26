local Players = cloneref(game:GetService("Players")) :: Players

local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local NetworkController = require("@game/overkill/network/NetworkController")
local ModuleController = require("@game/overkill/module/ModuleController")
local spectatorsState = require("@ui/hud/spectators/spectatorsState")
local stateConverter = require("@feature/config/module/stateConverter")
local clientState = require("@game/overkill/client/clientState")

local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer

local POSITION_EXTENSION = "limerence.overkillSpectators"
local DUEL_PACKETS = { "created", "active_duels", "ended", "left_duel" }

local SpectatorList = {}
SpectatorList.__index = SpectatorList

setmetatable(SpectatorList, { __index = BaseFeature })

export type SpectatorList = typeof(setmetatable({} :: any, SpectatorList)) & BaseFeature.BaseFeature

function SpectatorList.new(link: gameUi.Linker): SpectatorList
	local self = BaseFeature.new() :: any
	setmetatable(self, SpectatorList)

	self._watchJanitor = nil :: Janitor.Janitor?
	self._recomputeToken = 0
	self._gameplayHandler = nil :: any

	stateConverter.RegisterExtension(POSITION_EXTENSION, function(): any
		local pos = peek(spectatorsState.position)
		return {
			position = {
				xs = pos.X.Scale,
				xo = pos.X.Offset,
				ys = pos.Y.Scale,
				yo = pos.Y.Offset,
			},
		}
	end, function(data: any): ()
		if type(data) ~= "table" then
			return
		end
		local pos = data.position
		if type(pos) ~= "table" then
			return
		end
		spectatorsState.position(
			UDim2.new(tonumber(pos.xs) or 0, tonumber(pos.xo) or 0, tonumber(pos.ys) or 0, tonumber(pos.yo) or 0)
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
			self:startWatch()
		else
			self:stopWatch()
		end
	end))
	spectatorsState.enabled(enabledLink:Peek() == true)

	self:Track(link:Get("spectatorList.opts.hideWhenEmpty"):OnChange(function(value: boolean): ()
		spectatorsState.hideWhenEmpty(value)
	end))
	spectatorsState.hideWhenEmpty(link:Peek("spectatorList.opts.hideWhenEmpty") :: boolean)

	if enabledLink:Peek() == true then
		self:startWatch()
	end

	return self
end

function SpectatorList.recompute(self: SpectatorList): ()
	local gameplayHandler = self._gameplayHandler
	if not gameplayHandler then
		clientState.spectatorCount(0)
		return
	end

	local duel = gameplayHandler:GetLocalDuel()
	local spectators = type(duel) == "table" and duel.spectators
	if type(spectators) ~= "table" then
		clientState.spectatorCount(0)
		return
	end

	local count = 0
	for i = 1, #spectators do
		if spectators[i] ~= LocalPlayer then
			count += 1
		end
	end

	clientState.spectatorCount(count)
end

function SpectatorList.queueRecompute(self: SpectatorList): ()
	self._recomputeToken += 1
	local token = self._recomputeToken
	task.defer(function(): ()
		if token == self._recomputeToken and self._watchJanitor then
			self:recompute()
		end
	end)
end

function SpectatorList.startWatch(self: SpectatorList): ()
	if self._watchJanitor then
		return
	end

	local janitor = Janitor.new()
	self._watchJanitor = janitor

	self._gameplayHandler = ModuleController.GetModule("gameplayHandler")

	for i = 1, #DUEL_PACKETS do
		janitor:Add(NetworkController.HookInbound(DUEL_PACKETS[i], function(): ()
			self:queueRecompute()
		end), true)
	end

	self:recompute()
end

function SpectatorList.stopWatch(self: SpectatorList): ()
	local janitor = self._watchJanitor
	if janitor then
		janitor:Destroy()
		self._watchJanitor = nil
	end
	self._recomputeToken += 1
	self._gameplayHandler = nil
	clientState.spectatorCount(0)
end

function SpectatorList.Destroy(self: SpectatorList): ()
	stateConverter.UnregisterExtension(POSITION_EXTENSION)
	self:stopWatch()
	spectatorsState.enabled(false)
	BaseFeature.Destroy(self)
end

return SpectatorList
