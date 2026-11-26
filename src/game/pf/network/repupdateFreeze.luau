local NetworkController = require("@game/pf/network/NetworkController")

local MAX_HOLD_DISTANCE = 24

local repupdateFreeze = {
	_unhook = nil :: (() -> ())?,
	_anchor = nil :: Vector3?,
}

local onRepupdate = LPH_NO_VIRTUALIZE(function(position: Vector3): boolean?
	local anchor = repupdateFreeze._anchor
	if not anchor then
		repupdateFreeze._anchor = position
		return false
	end
	if (position - anchor).Magnitude > MAX_HOLD_DISTANCE then
		repupdateFreeze._anchor = position
		return
	end
	return false
end)

function repupdateFreeze.setFrozen(frozen: boolean, anchor: Vector3?): ()
	local unhook = repupdateFreeze._unhook
	if frozen then
		if unhook then
			return
		end
		repupdateFreeze._anchor = anchor
		repupdateFreeze._unhook = NetworkController.HookOutbound("repupdate", onRepupdate, true)
	elseif unhook then
		unhook()
		repupdateFreeze._unhook = nil
		repupdateFreeze._anchor = nil
	end
end

function repupdateFreeze.getAnchor(): Vector3?
	return repupdateFreeze._anchor
end

return repupdateFreeze
