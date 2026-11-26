local gameInit = require("@game/gameInit")
local gameRegistry = require("@game/gameRegistry")
local initUi = require("@game/op1/initUi")
local clientState = require("@game/op1/client/clientState")

gameRegistry.name = "operation one"

gameInit({
	function()
		gameRegistry.clientState = clientState
	end,
	initUi,
}, {})
