local logger = require("@share/logger").new("mcp")
local config = require("@feature/mcp/mcpConfig")
local server = require("@feature/mcp/mcpServer")

local transport = {}

local connection: any = nil
local stopped = true

local function detach(): ()
	connection = nil
	server.setEmitter(nil)
end

local function connect(): ()
	if stopped then
		return
	end

	local ok, socket = pcall(function(): any
		return WebSocket.connect(config.URL)
	end)
	if not ok or not socket then
		task.delay(config.RECONNECT_DELAY, connect)
		return
	end

	connection = socket

	server.setEmitter(function(message: string): ()
		pcall(function(): ()
			socket:Send(message)
		end)
	end)

	socket.OnMessage:Connect(function(message: string): ()
		setthreadidentity(8)
		local response = server.handle(message)
		if response then
			pcall(function(): ()
				socket:Send(response)
			end)
		end
	end)

	socket.OnClose:Connect(function(): ()
		detach()
		if not stopped then
			task.delay(config.RECONNECT_DELAY, connect)
		end
	end)

	logger:log("connected to mcp bridge")
end

function transport.start(): ()
	stopped = false
	task.spawn(connect)
end

function transport.stop(): ()
	stopped = true
	local socket = connection
	detach()
	if socket then
		pcall(function(): ()
			socket:Close()
		end)
	end
end

return transport
