local logger = require("@share/logger").new("NetworkController")
local hook = require("@share/hook")
local ModuleController = require("@game/overkill/module/ModuleController")

local NetworkController = {
	_neuron = nil :: any,
	_packets = nil :: any,
	_names = {} :: { [any]: string },
	_outbound = {} :: { [string]: (...any) -> (boolean?, any?) },
	_inbound = {} :: { [string]: { (...any) -> () } },
	_inboundConns = {} :: { [string]: any },
	_fireHooks = {} :: { [any]: boolean },
	_active = false,
}

local function resolveMethod(packet: any): (string?, ((...any) -> any)?)
	if type(packet.Fire) == "function" then
		return "Fire", packet.Fire
	end
	if type(packet.Invoke) == "function" then
		return "Invoke", packet.Invoke
	end
	return nil, nil
end

local function ensureFireHook(method: (...any) -> any): ()
	if NetworkController._fireHooks[method] then
		return
	end

	local original
	original = hook.add(
		method,
		LPH_NO_VIRTUALIZE(function(self: any, ...: any)
			if NetworkController._active then
				local name = NetworkController._names[self]
				local callback = name and NetworkController._outbound[name]
				if callback then
					setthreadidentity(8)
					local continue, data = callback(...)
					setthreadidentity(2)
					if continue == false then
						if data ~= nil then
							return original(self, data)
						end
						return
					end
				end
			end
			return original(self, ...)
		end)
	)

	NetworkController._fireHooks[method] = true
end

function NetworkController.new(): NetworkController
	local neuron = ModuleController.GetModule("neuron")
	if not neuron or not neuron.net then
		logger:error("failed to resolve neuron net")
	end

	NetworkController._neuron = neuron
	NetworkController._packets = neuron.net.packets
	NetworkController._active = true

	return NetworkController
end

function NetworkController.GetNeuron(): any
	return NetworkController._neuron
end

function NetworkController.GetPacket(name: string): any?
	return NetworkController._packets[name]
end

function NetworkController.HookPacket(name: string, callback: (...any) -> (boolean?, any?)): ()
	local packet = NetworkController._packets[name]
	if not packet then
		logger:error("failed to find packet: " .. name)
		return
	end

	local _, method = resolveMethod(packet)
	if not method then
		logger:error("packet has no outbound method: " .. name)
		return
	end

	NetworkController._names[packet] = name
	NetworkController._outbound[name] = callback
	ensureFireHook(method)
end

function NetworkController.UnhookPacket(name: string): ()
	NetworkController._outbound[name] = nil
end

function NetworkController.HookInbound(name: string, callback: (...any) -> ()): () -> ()
	local packet = NetworkController._packets[name]
	if not packet then
		logger:error("failed to find packet: " .. name)
		return function() end
	end

	local subscribers = NetworkController._inbound[name]
	if not subscribers then
		subscribers = {}
		NetworkController._inbound[name] = subscribers

		local list = subscribers
		NetworkController._inboundConns[name] = packet:Connect(LPH_NO_VIRTUALIZE(function(...: any)
			if not NetworkController._active then
				return
			end
			setthreadidentity(8)
			for _, subscriber in next, list do
				subscriber(...)
			end
			setthreadidentity(2)
		end))
	end

	table.insert(subscribers, callback)

	return function(): ()
		local list = NetworkController._inbound[name]
		if not list then
			return
		end
		local index = table.find(list, callback)
		if index then
			table.remove(list, index)
		end
	end
end

function NetworkController.Fire(name: string, data: any?): ()
	local packet = NetworkController._packets[name]
	if not packet then
		logger:error("failed to find packet: " .. name)
		return
	end
	setthreadidentity(2)
	if data == nil then
		packet:Fire()
	else
		packet:Fire(data)
	end
	setthreadidentity(8)
end

function NetworkController.Destroy(): ()
	NetworkController._active = false

	for _, connection in next, NetworkController._inboundConns do
		if type(connection) == "table" and type(connection.Disconnect) == "function" then
			connection:Disconnect()
		end
	end

	for method in next, NetworkController._fireHooks do
		hook.restore(method)
	end

	table.clear(NetworkController._names)
	table.clear(NetworkController._outbound)
	table.clear(NetworkController._inbound)
	table.clear(NetworkController._inboundConns)
	table.clear(NetworkController._fireHooks)
	NetworkController._packets = nil
	NetworkController._neuron = nil
end

export type NetworkController = typeof(NetworkController)

return NetworkController
