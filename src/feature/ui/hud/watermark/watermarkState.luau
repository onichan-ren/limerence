local Charm = require("@pkg/Charm")

local watermarkOrder = require("@ui/hud/watermark/watermarkOrder")

local at = Charm.atom

local watermarkState = {
	enabled = at(false),
	position = at(UDim2.new(1, -10, 0, 10)),
	itemOrder = at(watermarkOrder.DEFAULT),
	showUsername = at(true),
	showCheat = at(true),
	showBuild = at(true),
	showGame = at(true),
	showPing = at(true),
	showFps = at(true),
	showPlaytime = at(true),
}

export type WatermarkState = typeof(watermarkState)

return watermarkState
