local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local speedometerState = require("@ui/hud/speedometer/speedometerState")

local MovementMods = {}
MovementMods.__index = MovementMods
setmetatable(MovementMods, { __index = BaseFeature })

function MovementMods.new(link: gameUi.Linker): MovementMods
	local self = BaseFeature.new() :: any
	setmetatable(self, MovementMods)

	link:Toggle("speedometer", "Speedometer", false):SetTip({
		title = "Speedometer",
		body = "Shows horizontal speed on the HUD while moving.",
	})
	link:Toggle("autoStrafer", "Auto Strafer", false):SetTip({
		title = "Auto Strafer",
		body = "Alternates A/D strafe keys in the air (or always) to help maintain speed.",
	})
	--[[local autoStraferLink = link:OnKey("autoStrafer")
	autoStraferLink:Submenu("opts", "Auto Strafer")
	local optionsLink = autoStraferLink:OnKey("opts")
	optionsLink:Toggle("airOnly", "Air Only", true):SetTip({
		title = "Air Only",
		body = "Only auto-strafe while airborne. When off, strafing also runs on the ground.",
	})--]]

	self:Track(link:Get("speedometer"):OnChange(function(value: boolean)
		speedometerState.enabled(value)
	end))

	speedometerState.enabled(link:Peek("speedometer") :: boolean)

	return self
end

function MovementMods.Destroy(self: MovementMods): ()
	speedometerState.enabled(false)
	BaseFeature.Destroy(self)
end

export type MovementMods = typeof(setmetatable({} :: {}, MovementMods)) & BaseFeature.BaseFeature

return MovementMods
