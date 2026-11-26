local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local spectatorsState = require("@ui/hud/spectators/spectatorsState")

local SpectatorList = {}
SpectatorList.__index = SpectatorList

setmetatable(SpectatorList, { __index = BaseFeature })

function SpectatorList.new(link: gameUi.Linker): SpectatorList
	local self = BaseFeature.new() :: any
	setmetatable(self, SpectatorList)

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

	self:Track(link:Get("spectatorList"):OnChange(function(value: boolean): ()
		spectatorsState.enabled(value)
	end))
	spectatorsState.enabled(link:Peek("spectatorList") :: boolean)

	self:Track(link:Get("spectatorList.opts.hideWhenEmpty"):OnChange(function(value: boolean): ()
		spectatorsState.hideWhenEmpty(value)
	end))
	spectatorsState.hideWhenEmpty(link:Peek("spectatorList.opts.hideWhenEmpty") :: boolean)

	return self
end

function SpectatorList.Destroy(self: SpectatorList): ()
	spectatorsState.enabled(false)
	BaseFeature.Destroy(self)
end

export type SpectatorList = typeof(setmetatable({} :: {}, SpectatorList)) & BaseFeature.BaseFeature

return SpectatorList
