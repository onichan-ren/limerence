local NetworkController = require("@game/bloxstrike/network/NetworkController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")

local HideInspect = {}
HideInspect.__index = HideInspect

setmetatable(HideInspect, { __index = BaseFeature })

function HideInspect.new(link: gameUi.Linker): HideInspect
	local self = BaseFeature.new() :: any
	setmetatable(self, HideInspect)

	local options = link:Options("hideFromSpectators", "Hide From Spectators")
	local optionsLink = link:On(options, "hideFromSpectators")
	optionsLink:Toggle("inspectAnimations", "Inspect Animations", false):SetTip({
		title = "Inspect Animations",
		body = "Spectators cannot see your weapon inspect animation.",
	})

	self._link = link
	self._inspectAnimationsLink = optionsLink:Get("inspectAnimations")

	self:Track(self._inspectAnimationsLink:OnChange(function(value: boolean): ()
		self:_setInspectAnimations(value)
	end))

	return self
end

function HideInspect._setInspectAnimations(self: HideInspect, enabled: boolean): ()
	NetworkController.UnhookPacket("Spectate", "ReplicateSpectateEvent")

	if enabled then
		NetworkController.HookPacket("Spectate", "ReplicateSpectateEvent", function(event: string, ...)
			if event == "Inspect" then
				return false
			end

			return true
		end)
	end
end

function HideInspect.Destroy(self: HideInspect): ()
	self:_setInspectAnimations(false)
	BaseFeature.Destroy(self)
end

export type HideInspect =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_inspectAnimationsLink: any,
		},
		HideInspect
	))
	& BaseFeature.BaseFeature

return HideInspect
