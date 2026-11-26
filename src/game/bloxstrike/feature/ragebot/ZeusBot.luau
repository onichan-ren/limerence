-- if u ever feel useless just remember this file exists

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")

local ZeusBot = {}
ZeusBot.__index = ZeusBot

setmetatable(ZeusBot, { __index = BaseFeature })

function ZeusBot.new(link: gameUi.Linker): ZeusBot
	local self = BaseFeature.new() :: any
	setmetatable(self, ZeusBot)

	link:Toggle("zeusBot", "Zeus Bot", false):SetTip({
		title = "Zeus Bot",
		body = "Automatically shoots with the zeus when equipped, and near a player.",
	})

	return self
end

function ZeusBot.Destroy(self: ZeusBot): ()
	BaseFeature.Destroy(self)
end

export type ZeusBot = typeof(setmetatable({} :: {}, ZeusBot)) & BaseFeature.BaseFeature

return ZeusBot
