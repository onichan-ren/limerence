local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local SquadController = require("@game/ar2/client/SquadController")

local SquadFriendly = {}
SquadFriendly.__index = SquadFriendly

setmetatable(SquadFriendly, { __index = BaseFeature })

function SquadFriendly.new(link: gameUi.Linker): SquadFriendly
	local self = BaseFeature.new() :: any
	setmetatable(self, SquadFriendly)

	link:Toggle("autoFriendlySquad", "Auto Friendly Squad", true):SetTip({
		title = "Auto Friendly Squad",
		body = "Marks your squadmates as friendly so they get skipped.",
	})
	local masterLink = link:OnKey("autoFriendlySquad")
	masterLink:Submenu("opts", "Auto Friendly Squad")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Toggle("notify", "Notify", true):SetTip({
		title = "Notify",
		body = "Shows a popup when a squadmate is marked friendly.",
	})

	SquadController.SetNotify(optsLink:Peek("notify") == true)
	SquadController.SetEnabled(link:Peek("autoFriendlySquad") == true)

	self:Track(link:Get("autoFriendlySquad"):OnChange(function(value: boolean): ()
		SquadController.SetEnabled(value == true)
	end))
	self:Track(optsLink:Get("notify"):OnChange(function(value: boolean): ()
		SquadController.SetNotify(value == true)
	end))

	return self
end

function SquadFriendly.Destroy(self: SquadFriendly): ()
	BaseFeature.Destroy(self)
end

export type SquadFriendly = typeof(setmetatable({} :: {}, SquadFriendly)) & BaseFeature.BaseFeature

return SquadFriendly
