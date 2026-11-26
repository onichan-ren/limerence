--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local DARKLUA_CFG = "scripts/build/darklua.json"
local BOOTSTRAP_CFG = "scripts/build/bootstrap.darklua.json"
local DEBUG_CFG = "scripts/build/debug.darklua.json"
local PKG_ENTRY = "scripts/build/packages-entry.luau"
local OUTPUT_DIR = "scripts/build/output"
local SETTINGS_FILE = "settings.json"
local PERSONAL_SETTINGS_FILE = "personal.settings.json"
local ACTIVE_CFG = "scripts/build/active.darklua.json"

local env = process.env

local localAppData = env["LOCALAPPDATA"]

local EXPLOITS_WORKSPACE = {
	Potassium = `{localAppData}/Potassium/workspace`,
	Volt = `{localAppData}/Volt/workspace`,
}

local LPH_STUB = [[if not LPH_OBFUSCATED then
	local fenv = getfenv()
	fenv.LPH_ENCFUNC = function(func, ...)
		return func
	end
	fenv.LPH_JIT_MAX = function(...)
		return ...
	end
	fenv.LPH_JIT = function(...)
		return ...
	end
	fenv.LPH_NO_VIRTUALIZE = function(...)
		return ...
	end
	fenv.LPH_NO_UPVALUES = function(...)
		return ...
	end
	fenv.LPH_ENCSTR = function(...)
		return ...
	end
	fenv.LPH_CRASH = function()
		warn(debug.traceback("LPH_CRASH", 2))
	end
	fenv.LP_INIT = function(callback)
		callback()
	end
	local lpStorePath = "limerence.biz/lpstore.json"
	local function lpReadStore()
		local ok, data = pcall(function()
			return game:GetService("HttpService"):JSONDecode(readfile(lpStorePath))
		end)
		if ok and type(data) == "table" then
			return data
		end
		return {}
	end
	local function lpWriteStore(store)
		pcall(function()
			if not isfolder("limerence.biz") then
				makefolder("limerence.biz")
			end
			writefile(lpStorePath, game:GetService("HttpService"):JSONEncode(store))
		end)
	end
	fenv.LP_SAVE_VALUE = function(id, value, overwrite)
		local store = lpReadStore()
		if store[id] ~= nil and overwrite ~= true then
			return false, "Storage entry already exists."
		end
		store[id] = value
		lpWriteStore(store)
		return true
	end
	fenv.LP_GET_VALUE = function(id)
		local value = lpReadStore()[id]
		if value == nil then
			return false, "Value not found."
		end
		return true, value
	end
	fenv.LP_DELETE_VALUE = function(id)
		local store = lpReadStore()
		store[id] = nil
		lpWriteStore(store)
		return true
	end
end
]]

local function escapeForDoubleQuote(value: string): string
	local parts: { string } = {}
	for i = 1, #value do
		local ch = string.sub(value, i, i)
		local byte = string.byte(ch)
		if ch == "\\" then
			table.insert(parts, "\\\\")
		elseif ch == '"' then
			table.insert(parts, '\\"')
		elseif ch == "\n" then
			table.insert(parts, "\\n")
		elseif ch == "\r" then
			table.insert(parts, "\\r")
		elseif ch == "\t" then
			table.insert(parts, "\\t")
		elseif byte < 32 then
			table.insert(parts, string.format("\\%03d", byte))
		else
			table.insert(parts, ch)
		end
	end
	return table.concat(parts)
end

local function convertLongStringsToQuotes(source: string): string
	local parts: { string } = {}
	local index = 1
	local length = #source

	while index <= length do
		local ch = string.sub(source, index, index)

		if ch == "'" or ch == '"' then
			local quote = ch
			local start = index
			index += 1
			while index <= length do
				local current = string.sub(source, index, index)
				if current == "\\" then
					index += 2
				elseif current == quote then
					index += 1
					break
				else
					index += 1
				end
			end
			table.insert(parts, string.sub(source, start, index - 1))
			continue
		end

		if ch == "`" then
			local start = index
			index += 1
			while index <= length do
				local current = string.sub(source, index, index)
				if current == "\\" then
					index += 2
				elseif current == "`" then
					index += 1
					break
				else
					index += 1
				end
			end
			table.insert(parts, string.sub(source, start, index - 1))
			continue
		end

		if ch == "[" then
			local eqCount = 0
			local probe = index + 1
			while probe <= length and string.sub(source, probe, probe) == "=" do
				eqCount += 1
				probe += 1
			end
			if probe <= length and string.sub(source, probe, probe) == "[" then
				local contentStart = probe + 1
				local close = "]" .. string.rep("=", eqCount) .. "]"
				local closeStart = string.find(source, close, contentStart, true)
				if closeStart then
					local content = string.sub(source, contentStart, closeStart - 1)
					table.insert(parts, '"' .. escapeForDoubleQuote(content) .. '"')
					index = closeStart + #close
					continue
				end
			end
		end

		table.insert(parts, ch)
		index += 1
	end

	return table.concat(parts)
end

local function normalizeStringLiterals(path: string): ()
	local body = fs.readFile(path)
	local converted = convertLongStringsToQuotes(body)
	if converted ~= body then
		fs.writeFile(path, converted)
	end
end

local function prependLphStub(path: string): ()
	local body = fs.readFile(path)
	fs.writeFile(path, LPH_STUB .. "\n" .. body)
end

local function getDarkluaCommand(): string
	return "darklua"
end

local function getStyluaCommand(): string
	return "stylua"
end

local function runDarklua(input: string, output: string, config: string, log: { string }?): boolean
	local result = process.exec(getDarkluaCommand(), {
		"process",
		input,
		output,
		"--config",
		config,
	})
	if not result.ok then
		if result.stdout ~= "" then
			if log then
				table.insert(log, result.stdout .. "\n")
			else
				stdio.write(result.stdout)
				stdio.write("\n")
			end
		end
		if result.stderr ~= "" then
			if log then
				table.insert(log, result.stderr .. "\n")
			else
				stdio.write(result.stderr)
				stdio.write("\n")
			end
		end
	end
	return result.ok
end

local function formatOutput(path: string, log: { string }?): boolean
	local result = process.exec(getStyluaCommand(), { path })
	if not result.ok then
		if result.stdout ~= "" then
			if log then
				table.insert(log, result.stdout .. "\n")
			else
				stdio.write(result.stdout)
				stdio.write("\n")
			end
		end
		if result.stderr ~= "" then
			if log then
				table.insert(log, result.stderr .. "\n")
			else
				stdio.write(result.stderr)
				stdio.write("\n")
			end
		end
	end
	return result.ok
end

local function fileSizeKb(path: string): number
	return math.floor(#fs.readFile(path) / 1024)
end

local function copyToWorkspace(path: string, name: string): ()
	for exploitName, workspacePath in EXPLOITS_WORKSPACE do
		if fs.isDir(workspacePath) then
			local body = fs.readFile(path)
			fs.writeFile(`{workspacePath}/{name}`, body)
		end
	end
end

local function buildPackages(): boolean
	stdio.write("Building packages bundle (full inline)...\n")
	if not fs.isDir(OUTPUT_DIR) then
		fs.writeDir(OUTPUT_DIR)
	end
	local output = `{OUTPUT_DIR}/packages.luau`
	if not runDarklua(PKG_ENTRY, output, DARKLUA_CFG) then
		stdio.write("FAILED: packages bundle\n")
		return false
	end
	normalizeStringLiterals(output)
	if not formatOutput(output) then
		stdio.write("FAILED: packages bundle format\n")
		return false
	end
	stdio.write(`SUCCESS: packages.luau ({fileSizeKb(output)} KB)\n`)
	stdio.write("  Upload this file to the URL configured in src/loader/pkgManifest.luau\n")
	return true
end

local function buildGame(name: string, entry: string, final: boolean, config: string, log: { string }): boolean
	local output = `{OUTPUT_DIR}/{name}.luau`
	if not runDarklua(entry, output, config, log) then
		table.insert(log, `FAILED: {name}\n`)
		return false
	end
	normalizeStringLiterals(output)
	prependLphStub(output)
	if final then
		if not formatOutput(output, log) then
			table.insert(log, `FAILED: {name} format\n`)
			return false
		end
	end
	table.insert(log, `SUCCESS: {name}.luau ({fileSizeKb(output)} KB)\n`)
	copyToWorkspace(output, `{name}.luau`)
	return true
end

local function buildTool(name: string, final: boolean, config: string): boolean
	if not fs.isDir(OUTPUT_DIR) then
		fs.writeDir(OUTPUT_DIR)
	end

	local entry = `tools/{name}/init.luau`
	if not fs.isFile(entry) then
		stdio.write(`No tool named '{name}' found (missing {entry})\n`)
		return false
	end

	local log: { string } = {}
	stdio.write(`Building tool '{name}' from {entry}...\n`)
	local ok = buildGame(name, entry, final, config, log)
	stdio.write(table.concat(log))
	return ok
end

local function buildGames(final: boolean, only: string?, config: string): (number, number)
	if not fs.isDir(OUTPUT_DIR) then
		fs.writeDir(OUTPUT_DIR)
	end

	stdio.write("Scanning for games...\n")
	local games: { string } = {}
	for _, name in fs.readDir("src/game") do
		if only ~= nil and name ~= only then
			continue
		end
		if fs.isFile(`src/game/{name}/init.luau`) then
			table.insert(games, name)
		end
	end

	if only ~= nil and #games == 0 then
		stdio.write(`No game named '{only}' found in src/game (missing init.luau?)\n`)
	end

	local totalCount = #games
	local successCount = 0
	local pending = totalCount
	local finished = 0

	stdio.write(`Building {totalCount} games in parallel...\n`)
	for i = 1, totalCount do
		local name = games[i]
		task.spawn(function()
			local log: { string } = {}
			if buildGame(name, `src/game/{name}/init.luau`, final, config, log) then
				successCount += 1
			end
			finished += 1
			stdio.write(
				`\n[{finished}/{totalCount}] {name}\n----------------------------------------\n{table.concat(log)}`
			)
			pending -= 1
		end)
	end

	while pending > 0 do
		task.wait()
	end

	return successCount, totalCount
end

local doPackages = false
local doGames = true
local doFinal = false
local doDebug = false
local doMcp = false
local onlyGame: string? = nil
local toolName: string? = nil

local args = process.args
local argIndex = 1
while argIndex <= #args do
	local arg = args[argIndex]
	if arg == "--packages" then
		doPackages = true
	elseif arg == "--packages-only" then
		doPackages = true
		doGames = false
	elseif arg == "--final" then
		doFinal = true
	elseif arg == "--debug" then
		doDebug = true
	elseif arg == "--mcp" then
		doMcp = true
	elseif arg == "--game" then
		onlyGame = args[argIndex + 1]
		if onlyGame == nil then
			stdio.write("--game requires a game name (e.g. --game pf)\n")
			process.exit(1)
		end
		argIndex += 1
	elseif string.sub(arg, 1, 7) == "--game=" then
		onlyGame = string.sub(arg, 8)
	elseif arg == "--tool" then
		toolName = args[argIndex + 1]
		if toolName == nil then
			stdio.write("--tool requires a tool name (e.g. --tool luraph)\n")
			process.exit(1)
		end
		argIndex += 1
	elseif string.sub(arg, 1, 7) == "--tool=" then
		toolName = string.sub(arg, 8)
	elseif arg == "--help" or arg == "-h" then
		stdio.write("Usage: lune run scripts/build/build-all.luau [flags]\n")
		stdio.write("  (no flags)        Build each game with the shim/bootstrap pipeline\n")
		stdio.write("  --packages        Also rebuild the hosted packages bundle first\n")
		stdio.write("  --packages-only   Rebuild ONLY the packages bundle, skip games\n")
		stdio.write("  --game <name>     Build ONLY the named game (matches src/game/<name>)\n")
		stdio.write("  --tool <name>     Build ONLY the named tool from tools/<name>/init.luau\n")
		stdio.write("                    (skips games and src/init.luau; implies --debug unless --final)\n")
		stdio.write("  --final           Also run stylua on each game build (slower)\n")
		stdio.write("  --debug           Build games with debug.darklua.json (readable, DEBUG=true + settings.json)\n")
		stdio.write("  --mcp             Enable _G.MCP (in-game MCP server for reversing; pair with --debug)\n")
		process.exit(0)
	end
	argIndex += 1
end

local function readJson(path: string): { [string]: any }
	local body = fs.readFile(path)
	if string.sub(body, 1, 3) == "\239\187\191" then
		body = string.sub(body, 4)
	end
	return serde.decode("json", body)
end

local function loadSettings(): { [string]: any }
	local merged: { [string]: any } = { DEBUG = doDebug, MCP = doMcp }
	for key, value in readJson(SETTINGS_FILE) do
		merged[key] = value
	end
	if fs.isFile(PERSONAL_SETTINGS_FILE) then
		for key, value in readJson(PERSONAL_SETTINGS_FILE) do
			merged[key] = value
		end
	end
	return merged
end

local function writeActiveConfig(baseConfig: string, settings: { [string]: any }): string
	local config = readJson(baseConfig)

	local excludes: { string } = {}
	if not doMcp then
		table.insert(excludes, "**/mcp/**")
	end
	if #excludes > 0 then
		config.bundle.excludes = excludes
	end

	local rules: { any } = {}
	for identifier, value in settings do
		table.insert(rules, {
			rule = "inject_global_value",
			identifier = identifier,
			value = value,
		})
	end
	local baseRules = config.rules
	for i = 1, #baseRules do
		table.insert(rules, baseRules[i])
	end
	config.rules = rules
	fs.writeFile(ACTIVE_CFG, serde.encode("json", config))
	return ACTIVE_CFG
end

if toolName ~= nil then
	doGames = false
	if not doFinal then
		doDebug = true
	end
end

local gameConfig = writeActiveConfig(if doDebug then DEBUG_CFG else BOOTSTRAP_CFG, loadSettings())

if doPackages then
	if not buildPackages() then
		process.exit(1)
	end
end

if toolName ~= nil then
	if not buildTool(toolName, doFinal, gameConfig) then
		process.exit(1)
	end
end

if doGames then
	local success, total = buildGames(doFinal, onlyGame, gameConfig)
	stdio.write("\n==========================================\n")
	stdio.write("              BUILD SUMMARY\n")
	stdio.write("==========================================\n")
	stdio.write(`Total games:       {total}\n`)
	stdio.write(`Successful builds: {success}\n`)
	stdio.write(`Failed builds:     {total - success}\n`)
	if success ~= total then
		process.exit(1)
	end
end
