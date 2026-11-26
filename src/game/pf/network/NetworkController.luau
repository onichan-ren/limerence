return LPH_JIT_MAX(function()
	local ModuleController = require("@game/pf/module/ModuleController")

	local TIME_ARG: { [string]: number } = {
		repupdate = 4,
		newbullets = 3,
		bullethit = 6,
		equip = 2,
		knifehit = 4,
		newgrenade = 3,
		spotplayers = 2,
		updatesight = 3,
	}

	local NetworkController = {
		_client = nil :: any,
		_receivers = nil :: { [string]: any }?,
		_origSend = nil :: any,
		_origReceivers = {} :: { [string]: any },
		_outHooks = {} :: { [string]: { (...any) -> ...any } },
		_inHooks = {} :: { [string]: { (...any) -> ...any } },
		_latency = 0,
		_currentAddition = 0,
	}

	local function applyTimeOffset(name: string, args: { any }, count: number): ()
		local add = NetworkController._latency + NetworkController._currentAddition
		if add == 0 then
			return
		end
		if name == "ping" then
			if type(args[2]) == "number" then
				args[2] += add
			end
			if type(args[3]) == "number" then
				args[3] += add
			end
			return
		end
		local index = TIME_ARG[name]
		if index and type(args[index]) == "number" then
			args[index] += add
		end
	end

	local function findReceiverTable(client: any): { [string]: any }?
		for _, value in next, debug.getupvalues(client.fireReady) :: { any } do
			if typeof(value) == "table" and value ~= client then
				for k, v in next, value do
					if type(k) == "string" and type(v) == "function" then
						return value
					end
				end
			end
		end
		return nil
	end

	local function runHooks(list: { (...any) -> ...any }, args: { any }, count: number): (boolean, { any }, number)
		for _, callback in next, list do
			local result, replacement = callback(table.unpack(args, 1, count))
			if result == false then
				if replacement ~= nil then
					args = replacement
					count = #replacement
				else
					return false, args, count
				end
			end
		end
		return true, args, count
	end

	function NetworkController.new(): NetworkController
		local client = ModuleController.GetModule("NetworkClient")
		if not client then
			return NetworkController
		end

		NetworkController._client = client
		NetworkController._receivers = findReceiverTable(client)

		local origSend = client.send
		NetworkController._origSend = origSend
		client.send = LPH_NO_VIRTUALIZE(function(self: any, name: string, ...): ...any
			local list = NetworkController._outHooks[name]
			local add = NetworkController._latency + NetworkController._currentAddition
			if not list and add == 0 then
				return origSend(self, name, ...)
			end
			local count = select("#", ...)
			local args = { ... }
			if list then
				setthreadidentity(8)
				local proceed, finalArgs, finalCount = runHooks(list, args, count)
				setthreadidentity(2)
				if not proceed then
					return
				end
				args = finalArgs
				count = finalCount
			end
			applyTimeOffset(name, args, count)
			return origSend(self, name, table.unpack(args, 1, count))
		end)

		return NetworkController
	end

	function NetworkController.HookOutbound(name: string, callback: (...any) -> ...any, prepend: boolean?): () -> ()
		local list = NetworkController._outHooks[name]
		if not list then
			list = {}
			NetworkController._outHooks[name] = list
		end
		if prepend then
			table.insert(list, 1, callback)
		else
			table.insert(list, callback)
		end
		return function(): ()
			local idx = table.find(list, callback)
			if idx then
				table.remove(list, idx)
			end
		end
	end

	function NetworkController.HookInbound(name: string, callback: (...any) -> ...any): () -> ()
		local receivers = NetworkController._receivers
		if not receivers then
			return function(): () end
		end

		local list = NetworkController._inHooks[name]
		if not list then
			list = {}
			NetworkController._inHooks[name] = list

			local original = receivers[name]
			NetworkController._origReceivers[name] = original

			receivers[name] = LPH_NO_VIRTUALIZE(function(...): ...any
				local hookList = NetworkController._inHooks[name]
				if not hookList then
					if original then
						return original(...)
					end
					return
				end
				local count = select("#", ...)
				local args = { ... }
				setthreadidentity(8)
				local proceed, finalArgs, finalCount = runHooks(hookList, args, count)
				setthreadidentity(2)
				if not proceed then
					return
				end
				if original then
					return original(table.unpack(finalArgs, 1, finalCount))
				end
				return
			end)
		end

		table.insert(list, callback)
		return function(): ()
			local idx = table.find(list, callback)
			if idx then
				table.remove(list, idx)
			end
		end
	end

	function NetworkController.Send(name: string, ...: any): ()
		local origSend = NetworkController._origSend
		local client = NetworkController._client
		if not origSend or not client then
			return
		end
		if NetworkController._latency + NetworkController._currentAddition == 0 then
			origSend(client, name, ...)
			return
		end
		local count = select("#", ...)
		local args = { ... }
		applyTimeOffset(name, args, count)
		origSend(client, name, table.unpack(args, 1, count))
	end

	function NetworkController.SendHooked(name: string, ...: any): ()
		local origSend = NetworkController._origSend
		local client = NetworkController._client
		if not origSend or not client then
			return
		end
		local list = NetworkController._outHooks[name]
		local count = select("#", ...)
		local args = { ... }
		if list then
			setthreadidentity(8)
			local proceed, finalArgs, finalCount = runHooks(list, args, count)
			setthreadidentity(2)
			if not proceed then
				return
			end
			args = finalArgs
			count = finalCount
		end
		applyTimeOffset(name, args, count)
		origSend(client, name, table.unpack(args, 1, count))
	end

	function NetworkController.SetLatency(value: number): ()
		NetworkController._latency = type(value) == "number" and value or 0
	end

	function NetworkController.SetCurrentAddition(value: number): ()
		NetworkController._currentAddition = type(value) == "number" and value or 0
	end

	function NetworkController.GetTimeOffset(): number
		return NetworkController._latency + NetworkController._currentAddition
	end

	function NetworkController.GetClient(): any
		return NetworkController._client
	end

	function NetworkController.Destroy(): ()
		local client = NetworkController._client
		if client and NetworkController._origSend then
			client.send = NetworkController._origSend
		end

		local receivers = NetworkController._receivers
		if receivers then
			for name, original in next, NetworkController._origReceivers do
				receivers[name] = original
			end
		end

		table.clear(NetworkController._origReceivers)
		table.clear(NetworkController._outHooks)
		table.clear(NetworkController._inHooks)
		NetworkController._client = nil
		NetworkController._receivers = nil
		NetworkController._origSend = nil
		NetworkController._latency = 0
		NetworkController._currentAddition = 0
	end

	export type NetworkController = typeof(NetworkController)

	return NetworkController
end)()
