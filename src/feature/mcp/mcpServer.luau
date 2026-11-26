local logger = require("@share/logger").new("mcp")
local config = require("@feature/mcp/mcpConfig")

local HttpService = cloneref(game:GetService("HttpService"))
local bufferTostring = getrenv().buffer.tostring

export type Tool = {
	description: string,
	handler: (params: any) -> any,
}

local tools: { [string]: Tool } = {}
local emitter: ((message: string) -> ())? = nil

local function encode(value: any): string
	local ok, result = pcall(function(): string
		return HttpService:JSONEncode(value)
	end)
	return if ok then result else "{}"
end

local function decode(text: string): any
	local ok, result = pcall(function(): any
		return HttpService:JSONDecode(text)
	end)
	return if ok then result else nil
end

local function toHex(bytes: string): string
	local parts = table.create(#bytes)
	for index = 1, #bytes do
		parts[index] = string.format("%02X", string.byte(bytes, index))
	end
	return table.concat(parts, " ")
end

local function sanitize(value: any, seen: { [any]: boolean }, depth: number): any
	local kind = typeof(value)
	if kind == "string" then
		if #value > config.MAX_STRING then
			return string.sub(value, 1, config.MAX_STRING) .. "..."
		end
		return value
	elseif kind == "number" or kind == "boolean" then
		return value
	elseif kind == "buffer" then
		return `<buffer {toHex(bufferTostring(value))}>`
	elseif kind == "table" then
		if seen[value] then
			return "<ref>"
		end
		if depth >= config.MAX_DEPTH then
			return "<max-depth>"
		end
		seen[value] = true
		local out: { [string]: any } = {}
		local count = 0
		for key, entry in next, value do
			count += 1
			if count > config.MAX_ENTRIES then
				out["..."] = "truncated"
				break
			end
			out[tostring(key)] = sanitize(entry, seen, depth + 1)
		end
		return out
	elseif kind == "Instance" then
		return `<Instance {value.ClassName}: {value:GetFullName()}>`
	end
	return `<{kind}: {tostring(value)}>`
end

local server = {}

function server.register(name: string, description: string, handler: (params: any) -> any): ()
	tools[name] = { description = description, handler = handler }
end

function server.unregister(name: string): ()
	tools[name] = nil
end

function server.setEmitter(fn: ((message: string) -> ())?): ()
	emitter = fn
end

function server.emit(channel: string, data: any): ()
	local send = emitter
	if not send then
		return
	end
	send(encode({ event = channel, data = sanitize(data, {}, 0) }))
end

function server.handle(raw: string): string?
	local request = decode(raw)
	if type(request) ~= "table" then
		return nil
	end

	local id = request.id
	local method = request.method
	local tool = tools[method]
	if not tool then
		return encode({ id = id, ok = false, error = `unknown tool: {tostring(method)}` })
	end

	local ok, result = pcall(tool.handler, request.params)
	if not ok then
		return encode({ id = id, ok = false, error = tostring(result) })
	end

	return encode({ id = id, ok = true, result = sanitize(result, {}, 0) })
end

server.register("listTools", "list every registered reversing tool", function(): any
	local list = {}
	for name, tool in next, tools do
		list[#list + 1] = { name = name, description = tool.description }
	end
	return { version = config.VERSION, tools = list }
end)

server.register("eval", "compile and run a luau expression, returning its results", function(params: any): any
	local source = if type(params) == "table" then params.source else params
	if type(source) ~= "string" then
		error("source must be a string")
	end

	local fn, compileError = loadstring(source)
	if not fn then
		error(compileError or "compile failed")
	end

	setthreadidentity(8)
	local packed = table.pack(fn())
	local results = table.create(packed.n)
	for index = 1, packed.n do
		results[index] = packed[index]
	end
	return { count = packed.n, results = results }
end)

server.register("readFile", "read a file from the workspace directory", function(params: any): any
	local path = if type(params) == "table" then params.path else params
	if type(path) ~= "string" or not isfile(path) then
		error("file not found")
	end
	return readfile(path)
end)

server.register("listFiles", "list files under a workspace directory", function(params: any): any
	local path = if type(params) == "table" then params.path else params
	if type(path) ~= "string" or not isfolder(path) then
		error("folder not found")
	end
	return listfiles(path)
end)

logger:debug("mcp server ready")

return server
