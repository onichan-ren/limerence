local gameInit = require("@game/gameInit")
local gameRegistry = require("@game/gameRegistry")
local initUi = require("@game/universal/initUi")
local bypass = require("@game/universal/bypass")
local localState = require("@game/universal/client/localState")
local clientApi = require("@game/universal/client/clientApi")
local playerApi = require("@game/universal/player/playerApi")

gameRegistry.name = "universal"

gameInit({
	function()
		gameRegistry.clientState = localState
		gameRegistry.clientApi = clientApi
		gameRegistry.playerApi = playerApi

		require("@feature/luau/luauUniversalApi")
	end,
	initUi,
}, { bypass })
