local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local PlayerController = require("@feature/player/PlayerController")
local spectatorsState = require("@ui/hud/spectators/spectatorsState")
local stateConverter = require("@feature/config/module/stateConverter")
local clientState = require("@game/op1/client/clientState")

local peek = Charm.peek
local sub = Charm.subscribe

local POSITION_EXTENSION = "limerence.op1Spectators"

local SpectatorList = {}
SpectatorList.__index = SpectatorList

setmetatable(SpectatorList, { __index = BaseFeature })

export type SpectatorList = typeof(setmetatable({} :: any, SpectatorList)) & BaseFeature.BaseFeature

function SpectatorList.new(link: gameUi.Linker): SpectatorList
	local self = BaseFeature.new() :: any
	setmetatable(self, SpectatorList)

	self._watchJanitor = nil :: Janitor.Janitor?

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

function SpectatorList.recompute(_: SpectatorList): ()
	local count = 0

	for _, basePlayer in next, PlayerController.GetAll() do
		if basePlayer.spectating and peek(basePlayer.spectating) then
			count += 1
		end
	end

	clientState.spectatorCount(count)
end

function SpectatorList.startWatch(self: SpectatorList): ()
	if self._watchJanitor then
		return
	end

	local janitor = Janitor.new()
	self._watchJanitor = janitor

	local function addWrapper(basePlayer: any): ()
		if basePlayer.spectating then
			janitor:Add(sub(basePlayer.spectating, function(): ()
				self:recompute()
			end), true, basePlayer)
		end
	end

	janitor:Add(
		PlayerController.playerAdded:Connect(function(basePlayer: any): ()
			addWrapper(basePlayer)
			self:recompute()
		end),
		"Disconnect"
	)
	janitor:Add(
		PlayerController.playerRemoving:Connect(function(basePlayer: any): ()
			janitor:Remove(basePlayer)
			self:recompute()
		end),
		"Disconnect"
	)

	for _, basePlayer in next, PlayerController.GetAll() do
		addWrapper(basePlayer)
	end

	self:recompute()
end

function SpectatorList.stopWatch(self: SpectatorList): ()
	local janitor = self._watchJanitor
	if janitor then
		janitor:Destroy()
		self._watchJanitor = nil
	end
	clientState.spectatorCount(0)
end

function SpectatorList.Destroy(self: SpectatorList): ()
	stateConverter.UnregisterExtension(POSITION_EXTENSION)
	self:stopWatch()
	spectatorsState.enabled(false)
	BaseFeature.Destroy(self)
end

return SpectatorList
