local server = require("@feature/mcp/mcpServer")

local mcpApi = {}

function mcpApi.registerTool(name: string, description: string, handler: (params: any) -> any): ()
	server.register(name, description, handler)
end

function mcpApi.unregisterTool(name: string): ()
	server.unregister(name)
end

function mcpApi.emit(channel: string, data: any): ()
	server.emit(channel, data)
end

return mcpApi
