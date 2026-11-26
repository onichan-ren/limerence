local Charm = require("@pkg/Charm")
local ClientState = require("@game/mvsd/client/clientState")
local originState = require("@game/universal/feature/visual/crosshair/originState")
local shootRay = require("@game/mvsd/weapon/shootRay")

local peek = Charm.peek

local shootPosition = LPH_NO_VIRTUALIZE(function(): Vector3?
	if peek(ClientState.weapon) ~= "gun" then
		return nil
	end

	local origin = shootRay.Origin()
	if not origin then
		return nil
	end

	return shootRay.Landing(origin)
end)

local mvsdShootOrigin = {}

function mvsdShootOrigin.Setup(): ()
	originState.SetMuzzlePositionProvider(shootPosition)
end

function mvsdShootOrigin.Destroy(): ()
	originState.SetMuzzlePositionProvider(nil)
end

return mvsdShootOrigin
