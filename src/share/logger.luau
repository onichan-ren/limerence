local RESET = "\27[0m"

if _G.DEBUG and _G.RCONSOLE_LOG then
	rconsoledestroy()
end

local function emit(instance: Logger, level: string, color: string, message: string): ()
	local name = instance.name

	if _G.RCONSOLE_LOG then
		local label = if name then `[{name} - {color}{level}{RESET}] ` else `[{color}{level}{RESET}] `
		rconsoleprint(label .. message .. "\n")
	else
		local label = if name then `[{name} - {level}] ` else `[{level}] `
		print(label .. message)
	end

	local sink = instance.sink

	if sink then
		local label = if name then `[{name} - {level}] ` else `[{level}] `
		sink(label .. message)
	end
end

local MAX_DEPTH = 6
local MAX_ENTRIES = 100

local function serialize(value: any, seen: { [any]: boolean }, depth: number): string
	local kind = typeof(value)
	if kind == "table" then
		if seen[value] then
			return "<ref>"
		end
		if depth >= MAX_DEPTH then
			return "{...}"
		end
		seen[value] = true
		local parts: { string } = {}
		local count = #value
		local shown = if count > MAX_ENTRIES then MAX_ENTRIES else count
		for i = 1, shown do
			parts[#parts + 1] = serialize(value[i], seen, depth + 1)
		end
		if count > shown then
			parts[#parts + 1] = `...{count - shown} more`
		end
		local extra = 0
		for key, entry in next, value do
			local isArrayIndex = type(key) == "number" and key % 1 == 0 and key >= 1 and key <= count
			if not isArrayIndex then
				extra += 1
				if extra > MAX_ENTRIES then
					parts[#parts + 1] = "..."
					break
				end
				local keyText = if type(key) == "string" then key else `[{serialize(key, seen, depth + 1)}]`
				parts[#parts + 1] = `{keyText} = {serialize(entry, seen, depth + 1)}`
			end
		end
		return "{ " .. table.concat(parts, ", ") .. " }"
	elseif kind == "string" then
		return `"{value}"`
	elseif kind == "Vector3" then
		return `Vector3({value.X}, {value.Y}, {value.Z})`
	elseif kind == "Vector2" then
		return `Vector2({value.X}, {value.Y})`
	elseif kind == "CFrame" then
		local rx, ry, rz = value:ToOrientation()
		return `CFrame({value.X}, {value.Y}, {value.Z} @ {math.round(math.deg(rx))}, {math.round(math.deg(ry))}, {math.round(
			math.deg(rz)
		)})`
	elseif kind == "Color3" then
		return `Color3({math.round(value.R * 255)}, {math.round(value.G * 255)}, {math.round(value.B * 255)})`
	elseif kind == "UDim2" then
		return `UDim2({value.X.Scale}, {value.X.Offset}, {value.Y.Scale}, {value.Y.Offset})`
	elseif kind == "UDim" then
		return `UDim({value.Scale}, {value.Offset})`
	elseif kind == "Instance" then
		return `{value.ClassName}({value:GetFullName()})`
	elseif kind == "EnumItem" then
		return tostring(value)
	else
		return tostring(value)
	end
end

local function format(...: any): string
	local args = table.pack(...)
	if args.n == 0 then
		return ""
	end
	local parts = table.create(args.n)
	for i = 1, args.n do
		local value = args[i]
		parts[i] = if type(value) == "string" then value else serialize(value, {}, 0)
	end
	return table.concat(parts, " ")
end

export type Sink = (message: string) -> ()

export type Logger = {
	name: string?,
	sink: Sink?,
	debug: (self: Logger, ...any) -> (),
	log: (self: Logger, ...any) -> (),
	warn: (self: Logger, ...any) -> (),
	error: (self: Logger, ...any) -> (),
}

local Logger = {}
Logger.__index = Logger

function Logger.debug(self: Logger, ...: any): ()
	if _G.DEBUG and _G.VERBOSITY == "max" then
		emit(self, "debug", "\27[36m", format(...))
	end
end

function Logger.log(self: Logger, ...: any): ()
	if _G.DEBUG and (_G.VERBOSITY == "mid" or _G.VERBOSITY == "max") then
		emit(self, "log", "\27[32m", format(...))
	end
end

function Logger.warn(self: Logger, ...: any): ()
	if _G.DEBUG and _G.VERBOSITY ~= "none" then
		emit(self, "warn", "\27[33m", format(...))
	end
end

function Logger.error(self: Logger, ...: any): ()
	if _G.DEBUG and _G.VERBOSITY ~= "none" then
		local message = format(...)
		emit(self, "error", "\27[31m", message)
		error(message, 2)
	end
end

local function new(name: string?, sink: Sink?): Logger
	return setmetatable({ name = name, sink = sink }, Logger) :: any
end

local default = new(nil)

return {
	new = new,
	debug = function(...: any): ()
		default:debug(...)
	end,
	log = function(...: any): ()
		default:log(...)
	end,
	warn = function(...: any): ()
		default:warn(...)
	end,
	error = function(...: any): ()
		default:error(...)
	end,
}
