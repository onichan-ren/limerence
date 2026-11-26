local serverUi = require("@src/feature/server/module/serverUi")

local ServerController = {}

function ServerController.new(): ServerController
	serverUi(ServerController)

	return ServerController
end

function ServerController.Destroy(): () end

export type ServerController = typeof(ServerController)

return ServerController
