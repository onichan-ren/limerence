local NetworkController = require("@game/bloxstrike/network/NetworkController")

local PACKET_TYPE = "Player"
local PACKET_NAME = "AFKTeleport"

local antiAfkBlock = {}

function antiAfkBlock.Enable(): ()
	NetworkController.UnhookPacket(PACKET_TYPE, PACKET_NAME)
	NetworkController.HookPacket(PACKET_TYPE, PACKET_NAME, function(): boolean
		return false
	end)
end

function antiAfkBlock.Disable(): ()
	NetworkController.UnhookPacket(PACKET_TYPE, PACKET_NAME)
end

return antiAfkBlock
