local gameRegistry = require("@game/gameRegistry")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local luauClientApi = {}

local function toCamel(name: string): string
	return name:sub(1, 1):lower() .. name:sub(2)
end

local function isGetter(name: string): boolean
	return name:match("^Get") ~= nil or name:match("^Is") ~= nil or name:match("^Has") ~= nil
end

luauApiRegistry.Register("client", function(ctx)
	local clientApi = gameRegistry.clientApi
	if not clientApi then
		return {}
	end
	local wrap = luauApiRegistry.WrapSignal
	local api: { [string]: any } = {}

	for key, value in next, clientApi do
		if type(value) == "function" and isGetter(key) then
			api[toCamel(key)] = value
		end
	end

	if clientApi.GetLocalPlayer then
		api.getPlayer = clientApi.GetLocalPlayer
	end

	local actions = clientApi.actions
	if type(actions) == "table" then
		for name, fn in next, actions do
			if type(fn) == "function" then
				api[name] = fn
			end
		end
	end

	local signals = clientApi.signals
	if signals then
		for name, signal in next, signals do
			api[name] = wrap(signal, ctx.onUnload)
		end
	end

	return api
end)

return luauClientApi
