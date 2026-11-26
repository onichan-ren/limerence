local NetworkController = require("@game/pf/network/NetworkController")

local BLOCKED = { "flaguser", "debug", "logmessage" }

local AntiFlag = {
	_unhooks = {} :: { () -> () },
}

local block = LPH_NO_VIRTUALIZE(function(): boolean
	return false
end)

function AntiFlag.new(): AntiFlag
	for _, name in next, BLOCKED do
		table.insert(AntiFlag._unhooks, NetworkController.HookOutbound(name, block))
	end
	return AntiFlag
end

function AntiFlag.Destroy(): ()
	for _, unhook in next, AntiFlag._unhooks do
		unhook()
	end
	table.clear(AntiFlag._unhooks)
end

export type AntiFlag = typeof(AntiFlag)

return AntiFlag
