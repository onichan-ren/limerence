local Signal = require("@pkg/Signal")

export type ApiContext = {
	scriptName: string,
	onUnload: Signal.Signal<()>,
}

export type ApiContribution = {
	[string]: any,
} | (ctx: ApiContext) -> { [string]: any }

export type RegistrationHandle = {
	Release: (self: RegistrationHandle) -> (),
	IsReleased: (self: RegistrationHandle) -> boolean,
	GetPriority: (self: RegistrationHandle) -> number,
	SetPriority: (self: RegistrationHandle, priority: number) -> (),
}

export type RegistrationSpec = {
	id: any,
	fn: any?,
	priority: number?,
	remove: (id: any) -> (),
	reAdd: ((fn: any, priority: number) -> any)?,
}

export type Registry = {
	Add: (spec: RegistrationSpec) -> RegistrationHandle,
}

local luauApiRegistry = {
	_namespaces = {} :: { [string]: ApiContribution },
	_features = {} :: { [string]: ApiContribution },
	_aliases = {} :: { [string]: string },
}

function luauApiRegistry.Register(namespace: string, contribution: ApiContribution): ()
	luauApiRegistry._namespaces[namespace] = contribution
end

function luauApiRegistry.RegisterFeature(name: string, contribution: ApiContribution): ()
	luauApiRegistry._features[name] = contribution
end

function luauApiRegistry.UnregisterFeature(name: string): ()
	luauApiRegistry._features[name] = nil
end

function luauApiRegistry.RegisterAlias(name: string, path: string): ()
	luauApiRegistry._aliases[name] = path
end

-- Registers a fallback only if the namespace is not already provided. Real
-- per-game registrations use Register (overwrite) and win regardless of load
-- order, so games that never provide the namespace still get a safe table.
function luauApiRegistry.RegisterDefault(namespace: string, contribution: ApiContribution): ()
	if luauApiRegistry._namespaces[namespace] == nil then
		luauApiRegistry._namespaces[namespace] = contribution
	end
end

function luauApiRegistry.Unregister(namespace: string): ()
	luauApiRegistry._namespaces[namespace] = nil
end

local function resolve(contribution: ApiContribution, ctx: ApiContext): { [string]: any }
	if type(contribution) == "function" then
		return contribution(ctx)
	end
	return contribution
end

function luauApiRegistry.BuildInto(target: { [string]: any }, ctx: ApiContext): ()
	for namespace, contribution in next, luauApiRegistry._namespaces do
		target[namespace] = resolve(contribution, ctx)
	end

	local features: { [string]: any } = {}
	for name, contribution in next, luauApiRegistry._features do
		features[name] = resolve(contribution, ctx)
	end
	target.feature = features

	local warned: { [string]: boolean } = {}
	setmetatable(target, {
		__index = function(_, key: any): any
			local path = luauApiRegistry._aliases[key]
			if not path then
				return nil
			end
			if not warned[key] then
				warned[key] = true
				warn(`[{ctx.scriptName}] api.{key} is deprecated, use api.{path}`)
			end
			local value: any = target
			for part in string.gmatch(path, "[^.]+") do
				if type(value) ~= "table" then
					return nil
				end
				value = value[part]
			end
			return value
		end,
	})
end

function luauApiRegistry.CreateRegistry(onUnload: Signal.Signal<()>): Registry
	local registrations: { any } = {}

	local function removeReg(reg: any): ()
		if reg.released then
			return
		end
		reg.released = true
		reg.remove(reg.id)
		for i, entry in next, registrations do
			if entry == reg then
				table.remove(registrations, i)
				break
			end
		end
	end

	onUnload:Connect(function(): ()
		local pending = registrations
		registrations = {}
		for _, reg in next, pending do
			if not reg.released then
				reg.released = true
				pcall(reg.remove, reg.id)
			end
		end
	end)

	local registry = {}

	function registry.Add(spec: RegistrationSpec): RegistrationHandle
		local reg = {
			id = spec.id,
			fn = spec.fn,
			priority = spec.priority or 0,
			remove = spec.remove,
			reAdd = spec.reAdd,
			released = false,
		}
		table.insert(registrations, reg)

		local handle = {} :: any
		function handle.Release(_: any): ()
			removeReg(reg)
		end
		function handle.IsReleased(_: any): boolean
			return reg.released
		end
		function handle.GetPriority(_: any): number
			return reg.priority
		end
		if reg.reAdd then
			function handle.SetPriority(_: any, priority: number): ()
				if reg.released or reg.priority == priority then
					return
				end
				reg.remove(reg.id)
				reg.id = reg.reAdd(reg.fn, priority)
				reg.priority = priority
			end
		end
		return handle
	end

	return registry :: Registry
end

function luauApiRegistry.WrapSignal(signal: any, onUnload: Signal.Signal<()>): { Connect: (self: any, cb: (...any) -> ()) -> any }
	local connections: { any } = {}
	local cleanedUp = false

	onUnload:Connect(function(): ()
		cleanedUp = true
		local pending = connections
		connections = {}
		for _, conn in next, pending do
			conn:Disconnect()
		end
	end)

	local proxy = {}
	function proxy.Connect(_: any, callback: (...any) -> ()): any
		if cleanedUp then
			return { Disconnect = function() end, Connected = false }
		end
		local conn = signal:Connect(callback)
		table.insert(connections, conn)
		return conn
	end
	return proxy
end

return luauApiRegistry
