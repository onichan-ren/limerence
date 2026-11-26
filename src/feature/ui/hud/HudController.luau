local React = require("@pkg/React")
local AppController = require("@src/feature/app/AppController")
local hudCanvas = require("@src/feature/ui/hud/hudCanvas")

local e = React.createElement

local HudController = {
	_initialized = false,
}

function HudController.new(): HudController
	if HudController._initialized then
		return HudController
	end
	HudController._initialized = true
	AppController.Render(e(hudCanvas))
	return HudController
end

export type HudController = typeof(HudController)

return HudController
