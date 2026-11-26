local ModuleController = require("@game/op1/module/ModuleController")
local hook = require("@share/hook")

local StateController = {}

local _stateObject
local _net
local _netHooks

local _classUnhooks = {}
local _senderHooks = {}
local _fastSenderHooks = {}
local _receiveListeners = {}
local _receiveOriginals = {}

type GenericFunction = (...any) -> ...any?

local function dispatchSend(hooks: { [string]: GenericFunction }, original, name: string, ...)
	local list = hooks[name]

	if not list then
		return original(name, ...)
	end

	local args = table.pack(...)

	for index = 1, #list do
		local result = table.pack(list[index](table.unpack(args, 1, args.n)))

		for i = 1, result.n do
			if result[i] ~= nil then
				args[i] = result[i]

				if i > args.n then
					args.n = i
				end
			end
		end
	end

	return original(name, table.unpack(args, 1, args.n))
end

function StateController.new(): StateController
	if not _stateObject then
		_stateObject = ModuleController.GetModule("StateObject")
	end

	if not _net then
		_net = ModuleController.GetModule("Net")
	end

	if _net then
		local env = getfenv(_net.hook)
		_netHooks = env and rawget(env, "hooks") or nil

		local oldSend
		oldSend = hook.add(_net.send, function(name: string, ...)
			return dispatchSend(_senderHooks, oldSend, name, ...)
		end)

		local oldFastSend
		oldFastSend = hook.add(_net.fast_send, function(name: string, ...)
			return dispatchSend(_fastSenderHooks, oldFastSend, name, ...)
		end)
	end

	return StateController
end

function StateController.HookClass(tag: string, callback: (object: any) -> ()): () -> ()
	if not _stateObject then
		return function() end
	end

	local handle = _stateObject.hook(tag, callback)
	local unhook = handle and handle.unhook or function() end

	table.insert(_classUnhooks, unhook)

	return unhook
end

function StateController.GetAll(tag: string): { [Instance]: any }
	return _stateObject and _stateObject.get_all(tag) or {}
end

function StateController.Get(tag: string, instance: Instance): any
	return _stateObject and _stateObject.get(tag, instance) or nil
end

function StateController.HookState(state: any, callback: GenericFunction, dontReplicate: boolean?): () -> ()
	if type(state) ~= "table" or type(state.hook) ~= "function" then
		return function() end
	end

	local elevated = function(...)
		setthreadidentity(8)
		callback(...)
		setthreadidentity(2)
	end

	local handle = state:hook(elevated, dontReplicate)
	return handle and handle.unhook or function() end
end

function StateController.Send(name: string, ...)
	if not _net then
		return
	end

	local old = getthreadidentity()
	setthreadidentity(2)
	_net.send(name, ...)
	setthreadidentity(old)
end

function StateController.FastSend(name: string, ...)
	if not _net then
		return
	end

	local old = getthreadidentity()
	setthreadidentity(2)
	_net.fast_send(name, ...)
	setthreadidentity(old)
end

function StateController.Invoke(name: string, ...): any
	if not _net then
		return nil
	end

	local old = getthreadidentity()
	setthreadidentity(2)
	local result = table.pack(_net.get(name, ...))
	setthreadidentity(old)

	return table.unpack(result, 1, result.n)
end

function StateController.OnReceive(name: string, callback: GenericFunction): () -> ()
	if not _netHooks then
		return function() end
	end

	local list = _receiveListeners[name]

	if not list then
		list = {}
		_receiveListeners[name] = list
		_receiveOriginals[name] = rawget(_netHooks, name)

		rawset(_netHooks, name, function(...)
			local original = _receiveOriginals[name]

			if original then
				original(...)
			end

			for _, listener in next, list do
				task.spawn(listener, ...)
			end
		end)
	end

	table.insert(list, callback)

	return function()
		local index = table.find(list, callback)

		if index then
			table.remove(list, index)
		end
	end
end

function StateController.HookSend(name: string, callback: GenericFunction)
	local list = _senderHooks[name]

	if not list then
		list = {}
		_senderHooks[name] = list
	end

	if not table.find(list, callback) then
		table.insert(list, callback)
	end
end

function StateController.HookFastSend(name: string, callback: GenericFunction)
	local list = _fastSenderHooks[name]

	if not list then
		list = {}
		_fastSenderHooks[name] = list
	end

	if not table.find(list, callback) then
		table.insert(list, callback)
	end
end

function StateController.RestoreSend(name: string)
	_senderHooks[name] = nil
end

function StateController.RestoreFastSend(name: string)
	_fastSenderHooks[name] = nil
end

function StateController.Destroy()
	for _, unhook in next, _classUnhooks do
		unhook()
	end
	table.clear(_classUnhooks)

	if _netHooks then
		for name, original in next, _receiveOriginals do
			rawset(_netHooks, name, original)
		end
	end
	table.clear(_receiveListeners)
	table.clear(_receiveOriginals)

	if _net then
		hook.restore(_net.send)
		hook.restore(_net.fast_send)
	end
	table.clear(_senderHooks)
	table.clear(_fastSenderHooks)
end

export type StateController = typeof(StateController)

return StateController
