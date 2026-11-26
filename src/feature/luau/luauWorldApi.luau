local Signal = require("@pkg/Signal")
local gameRegistry = require("@game/gameRegistry")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local luauWorldApi = {}

local mapChanged = Signal.new()
local watching = false

luauApiRegistry.Register("world", function(ctx)
	local source = gameRegistry.mapSource
	if not source then
		return {}
	end

	if not watching then
		watching = true
		source.Changed(function(map: string?): ()
			mapChanged:Fire(map)
		end)
	end

	local api = {}

	function api.getMap(): string?
		return source.GetCurrent()
	end

	function api.getMaps(): { string }
		if source.GetAll then
			return source.GetAll()
		end
		return {}
	end

	api.onMapChanged = luauApiRegistry.WrapSignal(mapChanged, ctx.onUnload)

	return api
end)

return luauWorldApi
