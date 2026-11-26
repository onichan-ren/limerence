local transport = require("@feature/mcp/mcpTransport")

local McpController = {}

function McpController.new(): McpController
	transport.start()
	return McpController
end

function McpController.Destroy(): ()
	transport.stop()
end

export type McpController = typeof(McpController)

return McpController
