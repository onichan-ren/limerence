local logger = require("@share/logger").new("NetworkController")
local hook = require("@share/hook")

local NetworkController = {
	_packets = {},
	_hooks = {},
}

local function findModule(): ModuleScript?
	for _, module in next, getloadedmodules(true) do
		local fullName = module:GetFullName()
		if fullName:find("Security.Remotes") and not fullName:find("Security.Remotes.") then
			return module
		end
	end

	return nil
end

function NetworkController.new(): NetworkController
	local module = findModule()

	if not module then
		logger:error("failed to find remotes module")
	end

	local moduleData = (require :: any)(module)
	local stored = NetworkController._packets

	for packetType, packets in next, moduleData do
		stored[packetType] = packets
	end

	return NetworkController
end

function NetworkController.GetPacketGroup(packetType: string): { [string]: any }?
	return NetworkController._packets[packetType]
end

function NetworkController.GetPacket(packetType: string, packetName: string): any?
	local packets = NetworkController._packets[packetType]
	if not packets then
		return nil
	end
	return packets[packetName]
end

function NetworkController.ListPacketTypes(): { string }
	local names: { string } = {}
	for name in next, NetworkController._packets do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

function NetworkController.ListPackets(packetType: string): { string }
	local packets = NetworkController._packets[packetType]
	if not packets then
		return {}
	end
	local names: { string } = {}
	for name in next, packets do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

function NetworkController.SendPacket(packetType: string, packetName: string, payload: any?): boolean
	local packet = NetworkController.GetPacket(packetType, packetName)
	if not packet or type(packet.Send) ~= "function" then
		return false
	end
	if payload == nil then
		packet.Send()
	else
		packet.Send(payload)
	end
	return true
end

NetworkController.HookPacket = function(packetType: string, packetName: string, callback: (...any) -> boolean?)
	local packets = NetworkController._packets[packetType]

	if not packets then
		logger:error("failed to find packets for packet type: " .. packetType)
	end

	local packet = packets[packetName]

	if not packet then
		logger:error("failed to find packet: " .. packetName)
	end

	local key = `{packetType}.{packetName}`

	if NetworkController._hooks[key] then
		logger:error("packet already hooked: " .. key)
		return
	end

	local sendFunc = rawget(packet, "Send") :: any
	hook.addInstance(getupvalue(sendFunc, 5))

	hook.overrideMethod(
		getupvalue(sendFunc, 5),
		"FireServer",
		LPH_NO_VIRTUALIZE(function(...: any)
			local doContinue, data: any? = callback(...)

			if doContinue == false then
				if data then
					return data
				end
				return
			end

			return ...
		end)
	)

	NetworkController._hooks[key] = getupvalue(sendFunc, 5)
end

function NetworkController.UnhookPacket(packetType: string, packetName: string): ()
	local key = `{packetType}.{packetName}`

	local hooked = NetworkController._hooks[key] :: (...any) -> () | nil
	if not hooked then
		return
	end

	hook.restoreInstance(hooked :: any)
	NetworkController._hooks[key] = nil
end

function NetworkController.Destroy(): ()
	local hookedKeys: { string } = {}
	for key in next, NetworkController._hooks do
		hookedKeys[#hookedKeys + 1] = key
	end
	for _, key in next, hookedKeys do
		local packetType, packetName = string.match(key, "^([^%.]+)%.(.+)$")
		if packetType and packetName then
			NetworkController.UnhookPacket(packetType, packetName)
		end
	end
	for key in next, NetworkController._packets do
		NetworkController._packets[key] = nil
	end
end

export type NetworkController = typeof(NetworkController)

return NetworkController
