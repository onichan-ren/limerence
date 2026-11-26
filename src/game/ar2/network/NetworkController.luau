local NetworkController = {}

local ModuleController = require("@game/ar2/module/ModuleController")
local hook = require("@share/hook")

local _receiverHooks = {}
local _senderHooks = {}
local _sendObservers = {}
local _sendDelays = {}
local _receivers
local _networkModule
local _rawSend

function NetworkController.new(): NetworkController
	if not _networkModule then
		_networkModule = ModuleController.GetModule("Network")
	end

	if not _receivers then
		_receivers = debug.getupvalue(_networkModule.module.Add, 1)
	end

	local old
	old = hook.add(
		_networkModule.module.Send,
		LPH_NO_VIRTUALIZE(function(self, name: string, ...)
			local senderHookList = _senderHooks[name]
			local delaySpec = _sendDelays[name]
			local observerList = _sendObservers[name]

			if not senderHookList and delaySpec == nil and not observerList then
				return old(self, name, ...)
			end

			local args = table.pack(...)

			if senderHookList then
				for index = 1, #senderHookList do
					local result = table.pack(senderHookList[index](table.unpack(args, 1, args.n)))
					for i = 1, result.n do
						if result[i] ~= nil then
							args[i] = result[i]
							if i > args.n then
								args.n = i
							end
						end
					end
				end
			end

			if observerList then
				for index = 1, #observerList do
					observerList[index](table.unpack(args, 1, args.n))
				end
			end

			if delaySpec ~= nil then
				local seconds = delaySpec
				if type(delaySpec) == "function" then
					seconds = delaySpec(table.unpack(args, 1, args.n))
				end
				if type(seconds) == "number" and seconds > 0 then
					task.delay(seconds, function()
						old(self, name, table.unpack(args, 1, args.n))
					end)
					return
				end
			end

			return old(self, name, table.unpack(args, 1, args.n))
		end)
	)

	_rawSend = old

	return NetworkController
end

function NetworkController.setSendDelay(name: string, delay: any)
	_sendDelays[name] = delay
end

function NetworkController.clearSendDelay(name: string)
	_sendDelays[name] = nil
end

type GenericFunction = (...any) -> ...any?

function NetworkController.send(name: string, ...)
	_networkModule.module:Send(name, ...)
end

function NetworkController.sendRaw(name: string, ...)
	_rawSend(_networkModule.module, name, ...)
end

function NetworkController.getReceiver(name: string): any
	return _receivers and _receivers[name]
end

function NetworkController.hookReceiver(name: string, replacement: GenericFunction)
	local receiver = _receivers[name]

	if not receiver then
		return
	end

	local old
	old = hook.add(
		receiver,
		LPH_NO_VIRTUALIZE(function(...)
			local args = { ... }

			for i, v in { replacement(...) } do
				args[i] = v
			end

			return old(table.unpack(args))
		end)
	)

	_receiverHooks[name] = receiver
end

function NetworkController.hookSend(name: string, replacement: GenericFunction)
	local list = _senderHooks[name]
	if not list then
		list = {}
		_senderHooks[name] = list
	end

	for _, fn in next, list do
		if fn == replacement then
			return
		end
	end

	table.insert(list, replacement)
end

function NetworkController.observeSend(name: string, observer: GenericFunction)
	local list = _sendObservers[name]
	if not list then
		list = {}
		_sendObservers[name] = list
	end

	for _, fn in next, list do
		if fn == observer then
			return
		end
	end

	table.insert(list, observer)
end

function NetworkController.unobserveSend(name: string, observer: GenericFunction?)
	local list = _sendObservers[name]
	if not list then
		return
	end

	if observer == nil then
		_sendObservers[name] = nil
		return
	end

	for i = #list, 1, -1 do
		if list[i] == observer then
			table.remove(list, i)
		end
	end

	if #list == 0 then
		_sendObservers[name] = nil
	end
end

function NetworkController.restoreSend(name: string, replacement: GenericFunction?)
	local list = _senderHooks[name]
	if not list then
		return
	end

	if replacement == nil then
		_senderHooks[name] = nil
		return
	end

	for i = #list, 1, -1 do
		if list[i] == replacement then
			table.remove(list, i)
		end
	end

	if #list == 0 then
		_senderHooks[name] = nil
	end
end

function NetworkController.restoreReceiver(name: string)
	local hookedReceiver = _receiverHooks[name]

	if hookedReceiver then
		hook.restore(hookedReceiver)
	end
end

function NetworkController.Destroy()
	for name, receiver in _receiverHooks do
		hook.restore(receiver)
	end

	hook.restore(_networkModule.module.Send)
end

export type NetworkController = typeof(NetworkController)

return NetworkController
