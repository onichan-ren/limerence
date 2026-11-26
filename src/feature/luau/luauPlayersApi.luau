local Players = cloneref(game:GetService("Players")) :: Players

local Signal = require("@pkg/Signal")
local gameRegistry = require("@game/gameRegistry")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")
local playerState = require("@feature/record/module/playerState")

local luauPlayersApi = {}

local augmentedHandles: { [any]: any } = setmetatable({}, { __mode = "kv" }) :: any

local stateChanged = Signal.new()
local watchingStates = false

local function ensureStateWatch(): ()
	if watchingStates then
		return
	end
	watchingStates = true
	local last = playerState.GetAssignments()
	playerState.SubscribeAssignments(function(): ()
		local current = playerState.GetAssignments()
		for userId, id in next, current do
			if last[userId] ~= id then
				local plr = Players:GetPlayerByUserId(userId)
				if plr then
					stateChanged:Fire(plr, id)
				end
			end
		end
		for userId in next, last do
			if current[userId] == nil then
				local plr = Players:GetPlayerByUserId(userId)
				if plr then
					stateChanged:Fire(plr, nil)
				end
			end
		end
		last = current
	end)
end

local function withSetState(handle: any): any
	if handle.setState == nil then
		function handle.setState(state: any): ()
			if state ~= nil and (type(state) ~= "string" or playerState.Get(state) == nil) then
				error(`api.players handle.setState: unknown state "{tostring(state)}"`, 2)
			end
			playerState.SetState(handle.getPlayer().UserId, state)
		end
	end
	return handle
end

local function getAugmentedHandle(playerApi: any, player: Player): any
	local baseHandle = playerApi.Get(player)
	if not baseHandle then
		return nil
	end
	local augment = gameRegistry.augmentPlayerHandle
	if type(augment) ~= "function" then
		return withSetState(baseHandle)
	end
	local cached = augmentedHandles[baseHandle]
	if cached then
		return cached
	end
	local handle = withSetState(augment(baseHandle))
	augmentedHandles[baseHandle] = handle
	return handle
end

local function wrapRefCounted(playerApi: any, signal: any, onUnload: any): { Connect: (self: any, cb: (...any) -> ()) -> any }
	local connections: { any } = {}
	local cleanedUp = false

	onUnload:Connect(function(): ()
		cleanedUp = true
		local pending = connections
		connections = {}
		for _, record in next, pending do
			if record.alive then
				record.alive = false
				record.conn:Disconnect()
				playerApi._bumpListeners(-1)
			end
		end
	end)

	local proxy = {}
	function proxy.Connect(_: any, callback: (...any) -> ()): any
		if cleanedUp then
			return { Disconnect = function() end, Connected = false }
		end
		playerApi._bumpListeners(1)
		local conn = signal:Connect(callback)
		local record = { conn = conn, alive = true }
		table.insert(connections, record)

		local handle = {}
		function handle.Disconnect(_: any): ()
			if not record.alive then
				return
			end
			record.alive = false
			record.conn:Disconnect()
			playerApi._bumpListeners(-1)
		end
		handle.Connected = true
		return handle
	end
	return proxy
end

luauApiRegistry.Register("players", function(ctx)
	local playerApi = gameRegistry.playerApi
	if not playerApi then
		return {}
	end

	ensureStateWatch()

	local api: { [string]: any } = {
		getAll = playerApi.GetAll,
		get = function(player: Player): any
			return getAugmentedHandle(playerApi, player)
		end,
		getStates = function(): { { id: string, label: string } }
			local defs = playerState.GetAll()
			local out = table.create(#defs)
			for i = 1, #defs do
				out[i] = { id = defs[i].id, label = defs[i].label }
			end
			return out
		end,
	}

	api.onStateChanged = luauApiRegistry.WrapSignal(stateChanged, ctx.onUnload)

	local signals = playerApi.signals
	if signals then
		for name, signal in next, signals do
			api[name] = wrapRefCounted(playerApi, signal, ctx.onUnload)
		end
	end

	return api
end)

return luauPlayersApi
