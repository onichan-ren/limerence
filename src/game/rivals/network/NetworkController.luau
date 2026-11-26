local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local logger = require("@share/logger").new("NetworkController")
local hook = require("@share/hook")

local NetworkController = {
	_remotes = {} :: { [string]: Instance },
	_hooks = {} :: { [string]: Instance },
	_connections = {} :: { [string]: { RBXScriptConnection } },
	_folder = nil :: Instance?,
}

local function isRemote(inst: Instance): boolean
	return inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent") or inst:IsA("RemoteFunction")
end

local function indexRemotes(folder: Instance, prefix: string, store: { [string]: Instance }): ()
	for _, child in next, folder:GetChildren() do
		local path = (prefix == "" and child.Name or prefix .. "." .. child.Name)
		if isRemote(child) then
			store[path] = child
		end
		if #child:GetChildren() > 0 then
			indexRemotes(child, path, store)
		end
	end
end

function NetworkController.new(): NetworkController
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		logger:error("failed to find Remotes folder")
	end

	NetworkController._folder = folder
	indexRemotes(folder, "", NetworkController._remotes)

	return NetworkController
end

function NetworkController.GetRemote(path: string): Instance?
	local cached = NetworkController._remotes[path]
	if cached then
		return cached
	end

	local node: Instance? = NetworkController._folder
	if not node then
		return nil
	end

	for segment in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(segment)
		if not node then
			return nil
		end
	end

	if node and isRemote(node) then
		NetworkController._remotes[path] = node
		return node
	end

	return nil
end

function NetworkController.ListRemotes(): { string }
	local names: { string } = {}
	for path in next, NetworkController._remotes do
		names[#names + 1] = path
	end
	table.sort(names)
	return names
end

function NetworkController.SendRemote(path: string, ...: any): boolean
	local remote = NetworkController.GetRemote(path)
	if not remote or not remote:IsA("RemoteEvent") then
		return false
	end
	(remote :: RemoteEvent):FireServer(...)
	return true
end

function NetworkController.InvokeRemote(path: string, ...: any): (boolean, ...any)
	local remote = NetworkController.GetRemote(path)
	if not remote or not remote:IsA("RemoteFunction") then
		return false
	end
	return true, (remote :: RemoteFunction):InvokeServer(...)
end

function NetworkController.ConnectRemote(path: string, callback: (...any) -> ()): RBXScriptConnection?
	local remote = NetworkController.GetRemote(path)
	if not remote or not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then
		return nil
	end

	local connection = (remote :: RemoteEvent).OnClientEvent:Connect(callback)
	local list = NetworkController._connections[path]
	if not list then
		list = {}
		NetworkController._connections[path] = list
	end
	list[#list + 1] = connection

	return connection
end

NetworkController.HookRemote = function(path: string, callback: (...any) -> (boolean?, ...any), method: string?)
	local remote = NetworkController.GetRemote(path)
	if not remote then
		logger:error("failed to find remote: " .. path)
	end

	if NetworkController._hooks[path] then
		logger:error("remote already hooked: " .. path)
		return
	end

	local hookMethod = method or (remote:IsA("RemoteFunction") and "InvokeServer" or "FireServer")

	hook.addInstance(remote)
	hook.overrideMethod(
		remote,
		hookMethod,
		LPH_NO_VIRTUALIZE(function(...: any)
			local old = getthreadidentity()
			setthreadidentity(8)
			local results = table.pack(callback(...))
			setthreadidentity(old)
			if results[1] == false then
				if results.n <= 1 then
					return
				end
				return table.unpack(results, 2, results.n)
			end

			return ...
		end)
	)

	NetworkController._hooks[path] = remote
end

function NetworkController.UnhookRemote(path: string): ()
	local remote = NetworkController._hooks[path]
	if not remote then
		return
	end

	hook.restoreInstance(remote)
	NetworkController._hooks[path] = nil
end

function NetworkController.Destroy(): ()
	local hookedPaths: { string } = {}
	for path in next, NetworkController._hooks do
		hookedPaths[#hookedPaths + 1] = path
	end
	for _, path in next, hookedPaths do
		NetworkController.UnhookRemote(path)
	end

	for _, list in next, NetworkController._connections do
		for _, connection in next, list do
			connection:Disconnect()
		end
	end
	table.clear(NetworkController._connections)

	table.clear(NetworkController._remotes)
	NetworkController._folder = nil
end

export type NetworkController = typeof(NetworkController)

return NetworkController
