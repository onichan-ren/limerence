export type McpConfig = {
	URL: string,
	RECONNECT_DELAY: number,
	MAX_DEPTH: number,
	MAX_ENTRIES: number,
	MAX_STRING: number,
	VERSION: string,
}

local mcpConfig: McpConfig = {
	URL = "ws://127.0.0.1:8790",
	RECONNECT_DELAY = 3,
	MAX_DEPTH = 8,
	MAX_ENTRIES = 200,
	MAX_STRING = 2000000,
	VERSION = "1.0.0",
}

return mcpConfig
