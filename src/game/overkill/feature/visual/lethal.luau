local Charm = require("@pkg/Charm")
local PlayerController = require("@feature/player/PlayerController")

local peek = Charm.peek

local function isLethal(player: Player): boolean
	local playerData = PlayerController.Get(player)
	if not playerData then
		return false
	end
	return peek((playerData :: any).alive) == false
end

return isLethal
