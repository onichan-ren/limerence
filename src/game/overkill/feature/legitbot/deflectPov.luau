local Charm = require("@pkg/Charm")
local ClientState = require("@game/overkill/client/clientState")

local peek = Charm.peek

local DEFLECT_POV_COS = 0.3420201433256688

local deflectPov = {}

deflectPov.isPlayerDeflecting = LPH_NO_VIRTUALIZE(function(player: any): boolean
	local atom = player.deflecting
	if atom == nil or peek(atom) ~= true then
		return false
	end
	local targetHrp = peek(player.hrp)
	local ourHrp = peek(ClientState.hrp)
	if not targetHrp or not ourHrp then
		return false
	end
	local look = targetHrp.CFrame.LookVector
	local lookX, lookZ = look.X, look.Z
	local lookMag = math.sqrt(lookX * lookX + lookZ * lookZ)
	if lookMag < 1e-4 then
		return false
	end
	local delta = ourHrp.Position - targetHrp.Position
	local dX, dZ = delta.X, delta.Z
	local deltaMag = math.sqrt(dX * dX + dZ * dZ)
	if deltaMag < 1e-4 then
		return false
	end
	return (lookX * dX + lookZ * dZ) / (lookMag * deltaMag) >= DEFLECT_POV_COS
end)

return deflectPov
