local autoPeekState = require("@game/universal/feature/combat/autopeek/autoPeekState")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local autoPeekApi = {}

luauApiRegistry.RegisterFeature("autopeek", function()
	local api = {}

	function api.save(): boolean
		local instance = autoPeekState.current
		return instance ~= nil and instance:SavePosition() == true
	end

	function api.retreat(): ()
		local instance = autoPeekState.current
		if instance then
			instance:Retreat()
		end
	end

	function api.clear(): ()
		local instance = autoPeekState.current
		if instance then
			instance:ClearPosition()
		end
	end

	function api.isPeeking(): boolean
		local instance = autoPeekState.current
		return instance ~= nil and instance:IsArmed() == true
	end

	function api.isRetreating(): boolean
		local instance = autoPeekState.current
		return instance ~= nil and instance:IsRetreating() == true
	end

	return api
end)

return autoPeekApi
