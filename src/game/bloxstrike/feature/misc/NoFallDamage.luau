local NetworkController = require("@game/bloxstrike/network/NetworkController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")

local NoFallDamage = {}
NoFallDamage.__index = NoFallDamage

setmetatable(NoFallDamage, { __index = BaseFeature })

function NoFallDamage.new(link: gameUi.Linker): NoFallDamage
	local self = BaseFeature.new() :: any
	setmetatable(self, NoFallDamage)

	link:Toggle("noFallDamage", "No Fall Damage", false):SetTip({
		title = "No Fall Damage",
		body = "Take no damage from falling.",
	})

	self:Track(link:Get("noFallDamage"):OnChange(function(value: boolean): ()
		self:_setEnabled(value)
	end))

	return self
end

function NoFallDamage._setEnabled(self: NoFallDamage, enabled: boolean): ()
	NetworkController.UnhookPacket("Character", "FallDamage")

	if enabled then
		NetworkController.HookPacket("Character", "FallDamage", function(_damage: number): boolean
			return false
		end)
	end
end

function NoFallDamage.Destroy(self: NoFallDamage): ()
	NetworkController.UnhookPacket("Character", "FallDamage")
	BaseFeature.Destroy(self)
end

export type NoFallDamage = typeof(setmetatable({} :: {}, NoFallDamage)) & BaseFeature.BaseFeature

return NoFallDamage
